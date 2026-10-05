#Requires -Version 7.0
<#
.SYNOPSIS
    Sube `common` y `platform` a sus repos de CodeCommit.
.DESCRIPTION
    Los repos de plataforma (ADR-0024) son repos git independientes, pero en el monorepo
    `general` son subdirectorios. Este script los siembra desde una copia temporal: copia,
    `git init`, un commit y push. No toca el indice de `general` ni su `.gitignore`.

    El historial no se conserva: cada repo arranca con un commit. Los repos son nuevos, asi que
    no hay nada que perder. Para conservar historia, usar `git subtree split --prefix=...`.

    Credenciales: cero secretos y cero ventanas. Git consulta el Credential Manager de Windows
    (helper `manager`, en el config de sistema) antes que el helper de AWS, y por ahi sale un
    dialogo de usuario y contrasena. Cada invocacion pasa `-c credential.helper=` para resetear
    esa lista y dejar solo el helper de CodeCommit, que pide un token temporal por rol IAM
    (ADR-0022). Se exporta tambien GIT_TERMINAL_PROMPT=0 para que un fallo no deje el prompt
    colgado.

    Idempotente: si el remoto ya tiene commits, no los reescribe; informa y sigue.
.PARAMETER Region
    Region AWS. Por defecto, la del entorno.
.PARAMETER SourceRoot
    Raiz del monorepo. Por defecto, `../..` desde este repositorio.
.PARAMETER TempRoot
    Donde copiar. Por defecto, una carpeta bajo el temporal del sistema.
.PARAMETER KeepTemp
    No borra las copias temporales al terminar.
.PARAMETER DryRun
    Informa de lo que haria sin copiar ni subir nada.
.EXAMPLE
    ./seed-repos.ps1 -DryRun
.EXAMPLE
    ./seed-repos.ps1 -Region us-east-1
#>
[CmdletBinding()]
param(
    [string]$Region = $(if ($env:AWS_REGION) { $env:AWS_REGION } elseif ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { 'us-east-1' }),
    [string]$SourceRoot = (Join-Path -Path $PSScriptRoot -ChildPath '../../..'),
    [string]$TempRoot = '',
    [switch]$KeepTemp,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Constantes (un unico sitio) ----------------------------------------------
$script:LogTag = 'seed-repos'
$script:ExitCode = 1
$script:Branch = 'main'
$script:RemoteBase = 'https://git-codecommit.{0}.amazonaws.com/v1/repos/{1}'

# Repos de plataforma: directorio origen relativo a la raiz y nombre en CodeCommit.
$script:PlatformRepos = @(
    [pscustomobject]@{ Folder = 'library/common'; Repository = 'common' },
    [pscustomobject]@{ Folder = 'library/platform'; Repository = 'platform' }
)

# --- Mensajes (centralizados, sin concatenacion inline) -----------------------
$script:FormatStart = 'Inicio. Origen: {0}'
$script:FormatMissingSource = "No existe el directorio '{0}'."
$script:FormatCommand = 'git {0}'
$script:FormatCommandFailed = 'git {0} falló con código {1}.'
$script:FormatCopying = 'copiando {0} -> {1}'
$script:FormatSeeded = 'sembrando {0} ({1} archivos)'
$script:FormatPushing = 'subiendo {0} a {1}'
$script:FormatPushed = 'subido: {0} -> {1}'
$script:FormatRemoteHasCommits = '{0} ya tiene commits en remoto; no se reescribe.'
$script:FormatDryRunRepo = '  {0}: {1} -> s3/CodeCommit repo {1} [se omitiria]'
$script:FormatDryRunSummary = 'DryRun: se subirian {0} repos. No se copio ni se subio nada.'
$script:FormatCleaned = 'copias temporales eliminadas: {0}'

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$script:LogTag] $Message"
}

function Stop-WithError {
    param([Parameter(Mandatory)][string]$Reason)

    Write-Step -Message "ERROR: $Reason"
    exit $script:ExitCode
}

# El Credential Manager de Windows se consulta antes que el helper de AWS si esta en la lista.
# El helper vacio lo resetea: a partir de ahi solo corre `aws codecommit credential-helper`,
# que devuelve un token de 12 h por identidad IAM y no abre ningun dialogo.
function Get-GitArguments {
    param([Parameter(Mandatory)][string[]]$Arguments)

    return @('-c', 'credential.helper=', '-c', "credential.helper=!aws codecommit credential-helper `$@") + $Arguments
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $description = $Arguments -join ' '
    Write-Step -Message ($script:FormatCommand -f $description)
    & git -C $Path @(Get-GitArguments -Arguments $Arguments)
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError -Reason ($script:FormatCommandFailed -f $description, $LASTEXITCODE)
    }
}

function Get-OriginPath {
    param([Parameter(Mandatory)][string]$Path)

    return Join-Path -Path $Path -ChildPath '.git'
}

function Resolve-ExistingDirectory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -Path $Path)) {
        Stop-WithError -Reason ($script:FormatMissingSource -f $Path)
    }

    return (Resolve-Path -Path $Path).Path
}

function Get-SeedDirectory {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Repository)

    return Join-Path -Path $Root -ChildPath "seed-$Repository"
}

function Copy-Seed {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    if (Test-Path -Path $Destination) {
        Remove-Item -Path $Destination -Recurse -Force
    }
    Write-Step -Message ($script:FormatCopying -f $Source, $Destination)
    Copy-Item -Path $Source -Destination $Destination -Recurse -Force
}

function Test-RemoteHasCommits {
    param([Parameter(Mandatory)][string]$Path)

    $refs = @(& git -C $Path @(Get-GitArguments -Arguments @('ls-remote', 'origin')))
    return (@($refs) | Where-Object { $_ -match 'refs/heads/' } | Measure-Object).Count -gt 0
}

function Seed-Repository {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$TempRoot,
        [Parameter(Mandatory)]$Platform
    )

    $source = Resolve-ExistingDirectory -Path (Join-Path -Path $SourceRoot -ChildPath $Platform.Folder)
    $seed = Get-SeedDirectory -Root $TempRoot -Repository $Platform.Repository

    Copy-Seed -Source $source -Destination $seed
    Invoke-Git -Path $seed -Arguments @('init', '-b', $script:Branch) | Out-Null
    Invoke-Git -Path $seed -Arguments @('add', '-A') | Out-Null
    Invoke-Git -Path $seed -Arguments @('commit', '-q', '-m', "chore: estado inicial de $($Platform.Repository)") | Out-Null

    $fileCount = @(& git -C $seed ls-files | Measure-Object).Count
    Write-Step -Message ($script:FormatSeeded -f $Platform.Repository, $fileCount)

    # El remoto se anade tras el commit: `git init` no necesita credenciales y asi la copia
    # temporal no queda con un `origin` a medio configurar si el push falla.
    Invoke-Git -Path $seed -Arguments @('remote', 'add', 'origin', ($script:RemoteBase -f $Region, $Platform.Repository)) | Out-Null

    if (Test-RemoteHasCommits -Path $seed) {
        Write-Step -Message ($script:FormatRemoteHasCommits -f $Platform.Repository)
        return $seed
    }

    Write-Step -Message ($script:FormatPushing -f $Platform.Repository, $Platform.Repository)
    Invoke-Git -Path $seed -Arguments @('push', '-u', 'origin', $script:Branch) | Out-Null
    Write-Step -Message ($script:FormatPushed -f $Platform.Repository, $Platform.Repository)
    return $seed
}

function Remove-Seeds {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Seeds,
        [Parameter(Mandatory)][string]$Root
    )

    foreach ($seed in $Seeds) {
        $gitDir = Get-OriginPath -Path $seed
        if (Test-Path -Path $gitDir) { Remove-Item -Path $seed -Recurse -Force }
    }
    if (-not (Test-Path -Path $Root)) { return }
    Write-Step -Message ($script:FormatCleaned -f $Root)
    Remove-Item -Path $Root -Recurse -Force -ErrorAction SilentlyContinue
}

# --- facade -------------------------------------------------------------------

function Invoke-SeedRepos {
    Write-Step -Message ($script:FormatStart -f $SourceRoot)

    if (-not (Get-Command -Name git -ErrorAction SilentlyContinue)) {
        Stop-WithError -Reason 'No se encontro el comando "git" en el PATH.'
    }

    $sourceRootPath = Resolve-ExistingDirectory -Path $SourceRoot

    if ($DryRun) {
        foreach ($platform in $script:PlatformRepos) {
            $source = Join-Path -Path $sourceRootPath -ChildPath $platform.Folder
            Write-Step -Message ($script:FormatDryRunRepo -f $source, $platform.Repository)
        }
        Write-Step -Message ($script:FormatDryRunSummary -f $script:PlatformRepos.Count)
        return
    }

    $tempRoot = if ($TempRoot) { $TempRoot } else {
        Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath "epc-seed-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"
    }
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

    # Sin esto, un helper que falle deja git esperando usuario y contrasena en consola.
    $env:GIT_TERMINAL_PROMPT = '0'

    $seeds = @()
    try {
        foreach ($platform in $script:PlatformRepos) {
            $seeds += @(Seed-Repository -SourceRoot $sourceRootPath -TempRoot $tempRoot -Platform $platform)
        }
    }
    finally {
        if (-not $KeepTemp) {
            Remove-Seeds -Seeds $seeds -Root $tempRoot
        }
    }

    Write-Step -Message 'Repos de plataforma sembrados.'
}

Invoke-SeedRepos
exit 0