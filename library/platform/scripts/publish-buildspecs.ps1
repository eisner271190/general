#Requires -Version 7.0
<#
.SYNOPSIS
    Publica los buildspecs compartidos en el bucket versionado.
.DESCRIPTION
    Idempotente: compara el MD5 de cada fichero local con el ETag del objeto remoto y solo sube
    los que cambiaron. Sin cambios no hay version nueva en el bucket.

    Los codigos de construccion referencian los buildspecs por ARN
    (`arn:aws:s3:::<bucket>/java-ci.yml`), asi que publicar uno nuevo no obliga a editar el
    pipeline de ningun microservicio.
.PARAMETER Bucket
    Bucket de buildspecs. Por defecto, el valor de BUILDSPECS_BUCKET o `epc-buildspecs`.
.PARAMETER Region
    Region AWS. Por defecto, la del entorno.
.PARAMETER BuildspecsDirectory
    Directorio con los .yml. Por defecto, `buildspecs/` de este repositorio.
.PARAMETER DryRun
    Informa de lo que subiria sin subir nada.
.EXAMPLE
    ./publish-buildspecs.ps1 -DryRun
.EXAMPLE
    ./publish-buildspecs.ps1 -Region us-east-1
#>
[CmdletBinding()]
param(
    [string]$Bucket = $(if ($env:BUILDSPECS_BUCKET) { $env:BUILDSPECS_BUCKET } else { 'epc-buildspecs' }),
    [string]$Region = $(if ($env:AWS_REGION) { $env:AWS_REGION } elseif ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { '' }),
    [string]$BuildspecsDirectory = (Join-Path -Path $PSScriptRoot -ChildPath '../buildspecs'),
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Constantes (un unico sitio) ----------------------------------------------
$script:LogTag = 'publish-buildspecs'
$script:ExitCode = 1
$script:DefaultBucket = 'epc-buildspecs'
$script:FileFilter = '*.yml'
$script:BucketVariable = 'BUILDSPECS_BUCKET'
$script:RegionVariable = 'AWS_REGION'

# --- Mensajes (centralizados, sin concatenacion inline) -----------------------
$script:FormatCommand = 'aws {0}'
$script:FormatCommandFailed = 'aws {0} falló con código {1}.'
$script:FormatMissingRegion = 'Falta la región: usa -Region o define {0}.'
$script:FormatStart = 'Inicio. Bucket: {0}'
$script:FormatMissingDirectory = "No existe el directorio '{0}'."
$script:FormatNoBuildspecs = "No hay buildspecs en '{0}'."
$script:FormatRemoteMissing = 's3://{0}/{1} no existe todavia'
$script:FormatUnchanged = 'sin cambios: {0}'
$script:FormatUploading = 'subiendo: {0}'
$script:FormatUpToDate = 'Nada que subir: {0} ya está al día.'
$script:FormatDryRunSummary = 'DryRun: se subirían {0} de {1} a s3://{2}/. No se subió nada.'
$script:FormatPublished = 'Buildspecs publicados en s3://{0}/ ({1} de {2}).'

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$script:LogTag] $Message"
}

function Stop-WithError {
    param([Parameter(Mandatory)][string]$Reason)

    Write-Step -Message "ERROR: $Reason"
    exit $script:ExitCode
}

function Get-Description {
    param([Parameter(Mandatory)][string[]]$Arguments)

    return ($Arguments -join ' ')
}

function Get-RegionArgument {
    if ([string]::IsNullOrWhiteSpace($Region)) {
        Stop-WithError -Reason ($script:FormatMissingRegion -f $script:RegionVariable)
    }

    return @('--region', $Region)
}

function Test-AwsFailed {
    param([Parameter(Mandatory)][string]$Description)

    if ($LASTEXITCODE -ne 0) {
        Stop-WithError -Reason ($script:FormatCommandFailed -f $Description, $LASTEXITCODE)
    }
}

function Invoke-Aws {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Capture
    )

    $description = Get-Description -Arguments $Arguments
    Write-Step -Message ($script:FormatCommand -f $description)
    if ($Capture) {
        $output = @(& aws @Arguments)
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join '').Trim() }
    }

    & aws @Arguments | Out-Host
    Test-AwsFailed -Description $description
}

# ETag de un objeto simple = MD5 hexadecimal de su contenido, asi que es comparable con el
# hash local sin descargar nada. Si el objeto no existe todavia, devuelve cadena vacia.
function Get-RemoteETag {
    param([Parameter(Mandatory)][string]$Key)

    $arguments = @('s3api', 'head-object', '--bucket', $Bucket, '--key', $Key) + (Get-RegionArgument)
    $result = Invoke-Aws -Arguments $arguments -Capture
    if ($result.ExitCode -ne 0) {
        Write-Step -Message ($script:FormatRemoteMissing -f $Bucket, $Key)
        return ''
    }

    return ($result.Output.Trim('"'))
}

function Get-LocalMD5 {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -Path $Path -Algorithm MD5).Hash.ToLowerInvariant()
}

function Test-NeedsUpload {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key
    )

    return ((Get-LocalMD5 -Path $Path) -ne (Get-RemoteETag -Key $Key))
}

function Publish-File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not (Test-NeedsUpload -Path $Path -Key $Key)) {
        Write-Step -Message ($script:FormatUnchanged -f $Key)
        return 0
    }

    Write-Step -Message ($script:FormatUploading -f $Key)
    if ($DryRun) {
        return 1
    }

    Invoke-Aws -Arguments (@('s3', 'cp', $Path, "s3://$Bucket/$Key") + (Get-RegionArgument))
    return 1
}

function Get-BuildspecFiles {
    if (-not (Test-Path -Path $BuildspecsDirectory)) {
        Stop-WithError -Reason ($script:FormatMissingDirectory -f $BuildspecsDirectory)
    }

    $files = @(Get-ChildItem -Path $BuildspecsDirectory -Filter $script:FileFilter -File | Sort-Object -Property Name)
    if ($files.Count -eq 0) {
        Stop-WithError -Reason ($script:FormatNoBuildspecs -f $BuildspecsDirectory)
    }

    return $files
}

function Count-Uploads {
    param([Parameter(Mandatory)][object[]]$Files)

    $uploaded = 0
    foreach ($file in $Files) {
        $uploaded += Publish-File -Path $file.FullName -Key $file.Name
    }

    return $uploaded
}

function Write-Result {
    param(
        [Parameter(Mandatory)][int]$Uploaded,
        [Parameter(Mandatory)][int]$Total
    )

    if ($Uploaded -eq 0) {
        Write-Step -Message ($script:FormatUpToDate -f $Bucket)
        return
    }

    if ($DryRun) {
        Write-Step -Message ($script:FormatDryRunSummary -f $Uploaded, $Total, $Bucket)
        return
    }

    Write-Step -Message ($script:FormatPublished -f $Bucket, $Uploaded, $Total)
}

# Facade: recorre los .yml de buildspecs/ y sube solo los que cambiaron.
function Invoke-PublishBuildspecs {
    Write-Step -Message ($script:FormatStart -f $Bucket)

    $files = Get-BuildspecFiles
    Write-Result -Uploaded (Count-Uploads -Files $files) -Total $files.Count
}

Invoke-PublishBuildspecs
exit 0