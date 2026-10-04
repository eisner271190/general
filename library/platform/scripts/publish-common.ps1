#Requires -Version 7.0
<#
.SYNOPSIS
    Publica `common` en CodeArtifact y confirma que el repositorio ya lo contiene.
.DESCRIPTION
    1. terraform init + apply del dominio y del repositorio maven `common`.
    2. Lectura del endpoint maven del output codeartifact_endpoint.
    3. Token de CodeArtifact con get-authorization-token: se pide ahora, dura 12 h y
       no se persiste ni en disco ni en Secrets Manager (ADR-0022).
    4. mvn deploy del reactor con -Depc.codeartifact.url=endpoint.
    5. aws codeartifact list-packages para confirmar.
    `common-parent` queda fuera del deploy (maven.deploy.skip, ADR-0020).
.PARAMETER TerraformDirectory
    Directorio con los .tf de plataforma.
.PARAMETER CommonDirectory
    Directorio del reactor `common` (el pom padre).
.PARAMETER SkipApply
    No ejecuta terraform apply: solo publica con el estado ya existente.
.EXAMPLE
    ./publish-common.ps1
.EXAMPLE
    ./publish-common.ps1 -SkipApply
#>
[CmdletBinding()]
param(
    [string]$TerraformDirectory = (Join-Path -Path $PSScriptRoot -ChildPath '../terraform'),
    [string]$CommonDirectory = (Join-Path -Path $PSScriptRoot -ChildPath '../../common'),
    [switch]$SkipApply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Domain = 'epc'
$script:Repository = 'common'
# Debe coincidir con el <id> del distributionManagement de common/pom.xml: es el id del
# servidor que Maven busca en settings.xml, no el nombre del repositorio en CodeArtifact.
$script:RepositoryId = 'codeartifact'
# `--format` de codeartifact list-packages es el formato del PAQUETE (maven, npm, pypi...),
# no el de salida. Es el que lleva `--output`.
$script:PackageFormat = 'maven'
$script:TokenVariable = 'CODEARTIFACT_AUTH_TOKEN'
$script:EndpointOutput = 'codeartifact_endpoint'
$script:ExitCode = 1

# La coma tiene mas precedencia que + en PowerShell: sin parentesis,
# @('-chdir=' + $Path, 'init') concatena el array entero en una sola cadena.
function Get-TerraformArguments {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    return @(("-chdir=$Path")) + $Arguments
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [publish-common] $Message"
}

function Stop-WithError {
    param([Parameter(Mandatory)][string]$Reason)

    Write-Step -Message "ERROR: $Reason"
    exit $script:ExitCode
}

function Resolve-Directory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) {
        Stop-WithError -Reason "No existe el directorio '$Path'."
    }

    return (Resolve-Path -Path $Path).Path
}

function Assert-ExitCode {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][int]$ExitCode
    )

    if ($ExitCode -ne 0) {
        Stop-WithError -Reason "$FilePath falló con código $ExitCode."
    }
}

# Un único canal para las herramientas externas: sin -Capture la salida va a consola,
# con -Capture se devuelve como texto para usarlo como valor.
function Invoke-Process {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Capture
    )

    Write-Step -Message "$FilePath $($Arguments -join ' ')"
    if ($Capture) {
        return (Invoke-Captured -FilePath $FilePath -Arguments $Arguments)
    }

    & $FilePath @Arguments | Out-Host
    Assert-ExitCode -FilePath $FilePath -ExitCode $LASTEXITCODE
}

function Invoke-Captured {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = @(& $FilePath @Arguments)
    Assert-ExitCode -FilePath $FilePath -ExitCode $LASTEXITCODE
    return ($output -join '').Trim()
}

function Get-TerraformVarFile {
    param([Parameter(Mandatory)][string]$Path)

    $varFile = Join-Path -Path $Path -ChildPath 'terraform.tfvars'
    if (-not (Test-Path -Path $varFile)) {
        Stop-WithError -Reason "Falta $varFile. Copia terraform.example.tfvars y ajústalo."
    }

    return $varFile
}

function Initialize-Terraform {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][bool]$Apply
    )

    Write-Step -Message 'terraform init'
    Invoke-Process -FilePath 'terraform' `
        -Arguments (Get-TerraformArguments -Path $Path -Arguments @('init'))
    if (-not $Apply) {
        Write-Step -Message 'apply omitido (-SkipApply): se usa el estado existente.'
        return
    }

    $applyArguments = Get-TerraformArguments -Path $Path -Arguments @(
        'apply', '-auto-approve', '-var-file', (Get-TerraformVarFile -Path $Path)
    )
    Invoke-Process -FilePath 'terraform' -Arguments $applyArguments
}

function Get-RepositoryEndpoint {
    param([Parameter(Mandatory)][string]$Path)

    Write-Step -Message 'lectura del endpoint maven'
    return Invoke-Process -FilePath 'terraform' -Capture -Arguments (
        Get-TerraformArguments -Path $Path -Arguments @('output', '-raw', $script:EndpointOutput)
    )
}

function Get-CodeArtifactToken {
    # El token vive solo en memoria y caduca a las 12 h: persistirlo sería guardar
    # algo expirado.
    Write-Step -Message 'token de CodeArtifact'
    $token = Invoke-Process -FilePath 'aws' -Capture -Arguments @(
        'codeartifact', 'get-authorization-token',
        '--domain', $script:Domain,
        '--query', 'authorizationToken',
        '--output', 'text'
    )

    if ([string]::IsNullOrWhiteSpace($token)) {
        Stop-WithError -Reason 'AWS devolvió un token vacío.'
    }

    Write-Step -Message "token obtenido (longitud $($token.Length)); no se persiste."
    return $token
}

function Set-CodeArtifactToken {
    param([Parameter(Mandatory)][string]$Token)

    Write-Step -Message "se expone $script:TokenVariable solo durante el deploy"
    Set-Item -Path "Env:$script:TokenVariable" -Value $Token
}

function Clear-CodeArtifactToken {
    Write-Step -Message "se retira $script:TokenVariable del entorno"
    Remove-Item -Path "Env:$script:TokenVariable" -ErrorAction SilentlyContinue
}

function Publish-Common {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][string]$SettingsPath
    )

    Write-Step -Message "mvn deploy -> $Endpoint"
    Invoke-Process -FilePath 'mvn' -Arguments @(
        '-B', '-ntp', '-s', $SettingsPath,
        '-f', (Join-Path -Path $Path -ChildPath 'pom.xml'),
        'deploy', "-Depc.codeartifact.url=$Endpoint"
    )
}

function Confirm-PublishedPackages {
    $arguments = @(
        'codeartifact', 'list-packages',
        '--domain', $script:Domain,
        '--repository', $script:Repository,
        '--format', $script:PackageFormat,
        '--query', 'packages[].package',
        '--output', 'json'
    )

    Write-Step -Message 'confirmación de paquetes publicados'
    $packages = Invoke-Process -FilePath 'aws' -Capture -Arguments $arguments
    Write-Step -Message "paquetes en ${script:Domain}/${script:Repository}: $packages"
}

# Maven solo envia credenciales si un <server> declara el id del repositorio, que es
# `codeartifact` en el distributionManagement de common/pom.xml. La variable de entorno
# por si sola produce 401. El fichero se crea en TEMP y se borra: el token no queda en disco
# mas alla del proceso, y el settings.xml de `common/` no se toca (tiene la URL con
# placeholders <cuenta>/<region> que rompen la resolucion de terceros).
function New-CodeArtifactSettings {
    param([Parameter(Mandatory)][string]$Token)

    Write-Step -Message 'settings.xml efimero con el server codeartifact'
    $path = Join-Path -Path ([System.IO.Path]::GetTempPath()) `
        -ChildPath "common-settings-$([System.Guid]::NewGuid().ToString('N')).xml"

    $xml = @"
<settings>
  <servers>
    <server>
      <id>$script:RepositoryId</id>
      <username>aws</username>
      <password>$Token</password>
    </server>
  </servers>
</settings>
"@
    [System.IO.File]::WriteAllText($path, $xml, [System.Text.UTF8Encoding]::new($false))
    return $path
}

function Remove-CodeArtifactSettings {
    param([Parameter(Mandatory)][string]$Path)

    Write-Step -Message 'se borra el settings.xml efimero'
    Remove-Item -Path $Path -ErrorAction SilentlyContinue
}

function Publish-CommonWithToken {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][string]$Token
    )

    $settingsPath = New-CodeArtifactSettings -Token $Token
    try {
        Set-CodeArtifactToken -Token $Token
        Publish-Common -Path $Path -Endpoint $Endpoint -SettingsPath $settingsPath
    }
    finally {
        Clear-CodeArtifactToken
        Remove-CodeArtifactSettings -Path $settingsPath
    }
}

# Facade: apply -> endpoint -> token -> deploy -> confirmación.
function Invoke-PublishCommon {
    Write-Step -Message 'Inicio de la publicación de common'

    $terraformPath = Resolve-Directory -Path $TerraformDirectory
    $commonPath = Resolve-Directory -Path $CommonDirectory

    Initialize-Terraform -Path $terraformPath -Apply (-not $SkipApply)

    $endpoint = Get-RepositoryEndpoint -Path $terraformPath
    Write-Step -Message "Endpoint: $endpoint"

    $token = Get-CodeArtifactToken
    Publish-CommonWithToken -Path $commonPath -Endpoint $endpoint -Token $token

    Confirm-PublishedPackages
    Write-Step -Message 'common publicado.'
}

Invoke-PublishCommon