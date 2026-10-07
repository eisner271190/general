#Requires -Version 7.0
<#
.SYNOPSIS
    Levanta la infraestructura de la plataforma (Terraform de library/platform/terraform).
.DESCRIPTION
    init -> plan -> apply, leyendo terraform.tfvars. Sin comandos sueltos: este script es la
    unica via para crear o modificar la plataforma, y lo lanza una persona o `integrator`.

    -WhatIf hace init + plan y se detiene (equivale a `-PlanOnly`).
    Sin -AutoApprove pide confirmacion antes del apply.

    Cero secretos: el token de CodeArtifact lo pide cada build con la identidad del rol de
    CodeBuild (ADR-0022), asi que no hay nada que sembrar en Secrets Manager.
.PARAMETER TerraformDirectory
    Directorio con los .tf de plataforma.
.PARAMETER WhatIf
    Solo plan: no aplica nada.
.PARAMETER AutoApprove
    Omite la confirmacion previa al apply.
.EXAMPLE
    ./up.ps1 -WhatIf
.EXAMPLE
    ./up.ps1 -AutoApprove
#>
[CmdletBinding()]
param(
    [string]$TerraformDirectory = (Join-Path -Path $PSScriptRoot -ChildPath '../terraform'),
    [switch]$WhatIf,
    [switch]$AutoApprove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Constantes (un unico sitio) ----------------------------------------------
$script:LogTag = 'up'
$script:ExitCode = 1
$script:VarFileName = 'terraform.tfvars'
$script:ConfirmQuestion = '¿Aplicar los cambios de la plataforma? [s/N]'
$script:ConfirmPattern = '^[sS]$'

# --- Mensajes (centralizados, sin concatenacion inline) -----------------------
$script:FormatCommand = 'terraform {0}'
$script:FormatCommandFailed = 'terraform {0} falló con código {1}.'
$script:FormatMissingDirectory = "No existe el directorio '{0}'."
$script:FormatMissingVarFile = 'Falta {0}. Copia terraform.example.tfvars y ajústalo.'
$script:FormatConfirmation = 'confirmación: {0}'

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

function Get-Description {
    param([Parameter(Mandatory)][string[]]$Arguments)

    return ($Arguments -join ' ')
}

# La coma tiene mas precedencia que + en PowerShell: sin parentesis,
# @('-chdir=' + $Path, 'init') concatena el array entero en una sola cadena.
function Get-TerraformArguments {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    return @(("-chdir=$Path")) + $Arguments
}

function Test-TerraformFailed {
    param([Parameter(Mandatory)][string]$Description)

    if ($LASTEXITCODE -ne 0) {
        Stop-WithError -Reason ($script:FormatCommandFailed -f $Description, $LASTEXITCODE)
    }
}

function Invoke-Terraform {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $description = Get-Description -Arguments $Arguments
    Write-Step -Message ($script:FormatCommand -f $description)
    & terraform @(Get-TerraformArguments -Path $Path -Arguments $Arguments)
    Test-TerraformFailed -Description $description
}

function Get-VarFile {
    param([Parameter(Mandatory)][string]$Path)

    $varFile = Join-Path -Path $Path -ChildPath $script:VarFileName
    if (-not (Test-Path -Path $varFile)) {
        Stop-WithError -Reason ($script:FormatMissingVarFile -f $varFile)
    }

    return $varFile
}

function Confirm-Apply {
    $answer = Read-Host $script:ConfirmQuestion
    Write-Step -Message ($script:FormatConfirmation -f $answer)
    return ($answer -match $script:ConfirmPattern)
}

function Test-ShouldApply {
    if ($WhatIf) {
        Write-Step -Message 'Plan generado; no se aplica (-WhatIf).'
        return $false
    }

    if ($AutoApprove) {
        return $true
    }

    if (Confirm-Apply) {
        return $true
    }

    Write-Step -Message 'Apply omitido (confirmación rechazada).'
    return $false
}

function Initialize-Platform {
    param([Parameter(Mandatory)][string]$Path)

    Invoke-Terraform -Path $Path -Arguments @('init', '-input=false')
}

function Plan-Platform {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$VarFile
    )

    Invoke-Terraform -Path $Path -Arguments @('plan', '-input=false', '-var-file', $VarFile)
}

function Apply-Platform {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$VarFile
    )

    Invoke-Terraform -Path $Path -Arguments @('apply', '-input=false', '-auto-approve', '-var-file', $VarFile)
}

# Facade: init -> plan -> (apply).
function Invoke-PlatformUp {
    Write-Step -Message 'Inicio'

    $path = Resolve-Directory -Path $TerraformDirectory
    $varFile = Get-VarFile -Path $path

    Initialize-Platform -Path $path
    Plan-Platform -Path $path -VarFile $varFile

    if (-not (Test-ShouldApply)) {
        return
    }

    Apply-Platform -Path $path -VarFile $varFile
    Write-Step -Message 'Plataforma aplicada.'
}

Invoke-PlatformUp
exit 0