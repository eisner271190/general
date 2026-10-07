#Requires -Version 7.0
<#
.SYNOPSIS
    Publica `common` en CodeArtifact y confirma que el repositorio ya lo contiene.
.DESCRIPTION
    No hace Terraform: la infraestructura la levanta `scripts/up.ps1`.

    1. Lectura del endpoint maven con `aws codeartifact get-repository-endpoint`.
    2. Token con `get-authorization-token`: se pide ahora, dura 12 h y no se persiste ni en disco
       ni en Secrets Manager (ADR-0022).
    3. `mvn deploy` del reactor con `-Depc.codeartifact.url=<endpoint>`.
    4. `aws codeartifact list-packages` para confirmar.

    Es idempotente: se puede reejecutar sin efecto si no cambio el POM.
    `common-parent` queda fuera del deploy (maven.deploy.skip, ADR-0020).
.PARAMETER CommonDirectory
    Directorio del reactor `common` (el pom padre).
.PARAMETER DryRun
    No publica: solo comprueba endpoint, token y POM.
.EXAMPLE
    ./publish-common.ps1
.EXAMPLE
    ./publish-common.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [string]$CommonDirectory = (Join-Path -Path $PSScriptRoot -ChildPath '../../common'),
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Constantes (un unico sitio) ----------------------------------------------
$script:LogTag = 'publish-common'
$script:ExitCode = 1
$script:Domain = 'epc'
$script:Repository = 'common'
# Debe coincidir con el <id> del distributionManagement de common/pom.xml: es el id del
# servidor que Maven busca en settings.xml, no el nombre del repositorio en CodeArtifact.
$script:RepositoryId = 'codeartifact'
# `--format` de codeartifact list-packages es el formato del PAQUETE (maven, npm, pypi...),
# no el de salida. Es el que lleva `--output`.
$script:PackageFormat = 'maven'
$script:TokenVariable = 'CODEARTIFACT_AUTH_TOKEN'
$script:AwsCommand = 'aws'
$script:MavenCommand = 'mvn'
$script:MavenUser = 'aws'
$script:RootPomName = 'pom.xml'
$script:SettingsFilePattern = 'common-settings-{0}.xml'
# Plantilla del settings.xml efimero: Maven solo envia credenciales si un <server> declara el
# id del repositorio (`codeartifact` en el distributionManagement de common/pom.xml).
$script:SettingsTemplate = @"
<settings>
  <servers>
    <server>
      <id>$script:RepositoryId</id>
      <username>$script:MavenUser</username>
      <password>`$Token</password>
    </server>
  </servers>
</settings>
"@

# --- Mensajes (centralizados, sin concatenacion inline) -----------------------
$script:FormatCommand = '{0} {1}'
$script:FormatCommandFailed = '{0} falló con código {1}.'
$script:FormatMissingDirectory = "No existe el directorio '{0}'."
$script:FormatEmptyToken = 'AWS devolvió un token vacío.'
$script:FormatDeployTarget = 'mvn deploy -> {0}'
$script:FormatTokenInfo = 'token obtenido (longitud {0}); no se persiste.'
$script:FormatPackages = 'paquetes en {0}/{1}: {2}'

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$script:LogTag] $Message"
}

function Stop-WithError {
    param([Parameter(Mandatory)][string]$Reason)

    Write-Step -Message "ERROR: $Reason"
    exit $script:ExitCode
}

function Resolve-Directory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) {
        Stop-WithError -Reason ($script:FormatMissingDirectory -f $Path)
    }

    return (Resolve-Path -Path $Path).Path
}

function Test-ProcessFailed {
    param([Parameter(Mandatory)][string]$FilePath)

    if ($LASTEXITCODE -ne 0) {
        Stop-WithError -Reason ($script:FormatCommandFailed -f $FilePath, $LASTEXITCODE)
    }
}

function Invoke-Captured {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = @(& $FilePath @Arguments)
    Test-ProcessFailed -FilePath $FilePath
    return ($output -join '').Trim()
}

# Un único canal para las herramientas externas: Invoke-Process deja la salida en consola,
# Invoke-Captured la devuelve como texto para usarlo como valor. Ninguno lleva un flag: el
# modo se decide con la función que se llama.
function Invoke-Process {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    Write-Step -Message ($script:FormatCommand -f $FilePath, ($Arguments -join ' '))
    & $FilePath @Arguments | Out-Host
    Test-ProcessFailed -FilePath $FilePath
}

# `aws` es el único cliente que devuelve valores (endpoint, token, paquetes).
function Invoke-Aws {
    param([Parameter(Mandatory)][string[]]$Arguments)

    return Invoke-Captured -FilePath $script:AwsCommand -Arguments $Arguments
}

function Get-RepositoryEndpoint {
    Write-Step -Message 'endpoint maven'
    return Invoke-Aws -Arguments @(
        'codeartifact', 'get-repository-endpoint',
        '--domain', $script:Domain,
        '--repository', $script:Repository,
        '--format', $script:PackageFormat,
        '--query', 'repositoryEndpoint',
        '--output', 'text'
    )
}

function Get-CodeArtifactToken {
    # El token vive solo en memoria y caduca a las 12 h: persistirlo sería guardar
    # algo expirado.
    Write-Step -Message 'token de CodeArtifact'
    $token = Invoke-Aws -Arguments @(
        'codeartifact', 'get-authorization-token',
        '--domain', $script:Domain,
        '--query', 'authorizationToken',
        '--output', 'text'
    )

    if ([string]::IsNullOrWhiteSpace($token)) {
        Stop-WithError -Reason $script:FormatEmptyToken
    }

    Write-Step -Message ($script:FormatTokenInfo -f $token.Length)
    return $token
}

# Agrupa lo que necesita el deploy: asi Publish-Common y Publish-CommonWithToken no acumulan
# parametros (R7).
function New-PublishContext {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Endpoint
    )

    return @{ Path = $Path; Endpoint = $Endpoint }
}

function Publish-Common {
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$SettingsPath
    )

    Write-Step -Message ($script:FormatDeployTarget -f $Context.Endpoint)
    Invoke-Process -FilePath $script:MavenCommand -Arguments @(
        '-B', '-ntp', '-s', $SettingsPath,
        '-f', (Join-Path -Path $Context.Path -ChildPath $script:RootPomName),
        'deploy', "-Depc.codeartifact.url=$($Context.Endpoint)"
    )
}

function Confirm-PublishedPackages {
    $packages = Invoke-Aws -Arguments @(
        'codeartifact', 'list-packages',
        '--domain', $script:Domain,
        '--repository', $script:Repository,
        '--format', $script:PackageFormat,
        '--query', 'packages[].package',
        '--output', 'json'
    )

    Write-Step -Message ($script:FormatPackages -f $script:Domain, $script:Repository, $packages)
}

# Maven solo envia credenciales si un <server> declara el id del repositorio, que es
# `codeartifact` en el distributionManagement de common/pom.xml. La variable de entorno
# por si sola produce 401. El fichero se crea en TEMP y se borra: el token no queda en disco
# mas alla del proceso, y el settings.xml de `common/` no se toca (tiene la URL con
# placeholders <cuenta>/<region> que rompen la resolucion de terceros).
function New-CodeArtifactSettings {
    param([Parameter(Mandatory)][string]$Token)

    Write-Step -Message 'settings.xml efimero con el server codeartifact'
    $uniqueId = [System.Guid]::NewGuid().ToString('N')
    $fileName = $script:SettingsFilePattern -f $uniqueId
    $path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $fileName
    $xml = $script:SettingsTemplate.Replace('$Token', $Token)
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
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$Token
    )

    $settingsPath = New-CodeArtifactSettings -Token $Token
    try {
        Set-Item -Path "Env:$script:TokenVariable" -Value $Token
        Publish-Common -Context $Context -SettingsPath $settingsPath
    }
    finally {
        Remove-Item -Path "Env:$script:TokenVariable" -ErrorAction SilentlyContinue
        Remove-CodeArtifactSettings -Path $settingsPath
    }
}

function Test-DryRunStop {
    if ($DryRun) {
        Write-Step -Message 'DryRun: no se publica. Endpoint y token OK.'
        return $true
    }

    return $false
}

# Facade: endpoint -> token -> deploy -> confirmación.
function Invoke-PublishCommon {
    Write-Step -Message 'Inicio de la publicación de common'

    $context = New-PublishContext -Path (Resolve-Directory -Path $CommonDirectory) -Endpoint (Get-RepositoryEndpoint)
    Write-Step -Message "Endpoint: $($context.Endpoint)"

    $token = Get-CodeArtifactToken

    if (Test-DryRunStop) {
        return
    }

    Publish-CommonWithToken -Context $context -Token $token

    Confirm-PublishedPackages
    Write-Step -Message 'common publicado.'
}

Invoke-PublishCommon
exit 0