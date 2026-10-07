#Requires -Version 7.0
<#
.SYNOPSIS
  Inventario rapido y de SOLO LECTURA de los servicios AWS del proyecto.

.DESCRIPTION
  Lanza todas las llamadas a AWS CLI en paralelo (una sola ronda), resume el
  resultado en una tabla y lo compara con los estados de Terraform locales
  para senalar desfases (recursos en el estado que ya no existen en AWS, o al
  reves). No crea, modifica ni borra nada.

  Anade un bloque CodeArtifact: repositorios del dominio, paquetes maven
  publicados y el desfase del endpoint maven contra el output
  `codeartifact_endpoint` del estado de plataforma.

.EXAMPLE
  .opencode/scripts/get-services-aws.ps1

.EXAMPLE
  .opencode/scripts/get-services-aws.ps1 -AsJson
#>
[CmdletBinding()]
param(
  [string]$Region = $(if ($env:AWS_REGION) { $env:AWS_REGION } else { 'us-east-1' }),
  [string]$SsmPrefix = '/develop/com.quizsmart.app/',
  [string]$SecretPrefix = 'develop/com.quizsmart.app',
  [string[]]$RoleNames = @('quizapi', 'CognitoAuthenticatedRole'),
  [string[]]$PolicyNames = @('CognitoPolicy'),
  [string]$TerraformRoot = (Join-Path $PSScriptRoot '..' '..' 'projects' 'com.quizsmart.app' 'cloud' 'terraform'),
  # Estado de plataforma: es OTRO estado de Terraform, no mezclar con -TerraformRoot.
  [string]$CodeArtifactDomain = 'epc',
  [string]$CodeArtifactRepository = 'common',
  [string]$CodeArtifactTerraformRoot = (Join-Path $PSScriptRoot '..' '..' 'library' 'platform' 'terraform'),
  [switch]$AsJson
)

# --- utilidades -------------------------------------------------------------

function Get-ObjectProperty {
  param($InputObject, [string[]]$Names)
  if ($null -eq $InputObject) { return $null }
  foreach ($name in $Names) {
    $property = $InputObject.PSObject.Properties[$name]
    if ($null -ne $property) { return $property.Value }
  }
  return $null
}

function Select-Values {
  # Extrae una propiedad de una coleccion mixta (objetos o escalares).
  # El parametro se llama PropertyName y no Property: una asignacion local
  # $property = ... lo sobrescribiria (PowerShell es insensible a mayusculas)
  # y [string] convertiria el objeto a texto, dejando .Value en $null.
  param($Collection, [string]$PropertyName)
  $values = @()
  foreach ($item in @($Collection)) {
    if ($null -eq $item) { continue }
    if ($item -is [string] -or $item -is [ValueType]) { $values += $item; continue }
    $member = $item.PSObject.Properties[$PropertyName]
    if ($null -ne $member -and $null -ne $member.Value) { $values += $member.Value }
  }
  return $values
}

function Select-SafeArray {
  # $null y @( ) se normalizan a @(): sin esto, @($null) cuenta como 1 recurso.
  param($Value)
  return @(@($Value) | Where-Object { $null -ne $_ -and "$_" -ne '' })
}

function Format-Detail {
  param([string[]]$Values, [int]$MaxLength = 90)
  if (-not $Values -or $Values.Count -eq 0) { return '-' }
  $text = ($Values -join ', ')
  if ($text.Length -gt $MaxLength) { return $text.Substring(0, $MaxLength) + ' ...' }
  return $text
}

# --- recoleccion (una sola ronda, en paralelo) ------------------------------

if (-not (Get-Command -Name aws -ErrorAction SilentlyContinue)) {
  Write-Error 'No se encontro el comando "aws" en el PATH.'
  exit 1
}

# El paginador de AWS CLI v2 puede retener la salida; aqui solo interesa el JSON.
$env:AWS_PAGER = ''

$awsCalls = [ordered]@{
  Sts       = @('sts', 'get-caller-identity')
  Ecr       = @('ecr', 'describe-repositories')
  Lambda    = @('lambda', 'list-functions')
  ApiGw     = @('apigatewayv2', 'get-apis')
  Sns       = @('sns', 'list-topics')
  Sqs       = @('sqs', 'list-queues')
  Cognito   = @('cognito-idp', 'list-user-pools', '--max-results', '60')
  Ssm       = @('ssm', 'describe-parameters', '--parameter-filters', "Key=Name,Option=BeginsWith,Values=$SsmPrefix")
  Secrets   = @('secretsmanager', 'list-secrets')
  IamRoles  = @('iam', 'list-roles')
  IamPolicy = @('iam', 'list-policies', '--scope', 'Local')
  Tables    = @('dynamodb', 'list-tables')
  LogGroups = @('logs', 'describe-log-groups')
}

# Estados de Terraform locales (solo rutas, sin red)
$tfDirectories = @()
if (Test-Path -Path $TerraformRoot) {
  $tfDirectories = @(Get-ChildItem -Path $TerraformRoot -Directory |
    Where-Object { $_.Name -ne 'modules' -and (Test-Path -Path (Join-Path $_.FullName '*.tf')) } |
    ForEach-Object FullName)
}

# Una sola ola paralela: llamadas AWS + lectura de estados
$tasks = @()
foreach ($entry in $awsCalls.GetEnumerator()) {
  $tasks += [pscustomobject]@{ Kind = 'aws'; Name = $entry.Key; Target = $entry.Value }
}
foreach ($directory in $tfDirectories) {
  $tasks += [pscustomobject]@{ Kind = 'tf'; Name = (Split-Path -Path $directory -Leaf); Target = $directory }
}

$results = $tasks | ForEach-Object -Parallel {
  $task = $_
  if ($task.Kind -eq 'aws') {
    $raw = & aws @($task.Target) --region $using:Region --output json 2>$null
    $exitCode = $LASTEXITCODE
    $payload = $null
    if ($exitCode -eq 0) {
      try { $payload = ($raw -join [Environment]::NewLine) | ConvertFrom-Json } catch { $exitCode = -1 }
    }
    return [pscustomobject]@{ Kind = 'aws'; Name = $task.Name; ExitCode = $exitCode; Data = $payload; Total = 0; Types = $null }
  }

  $entries = @()
  Push-Location -Path $task.Target
  try { $entries = @(terraform state list 2>$null) } finally { Pop-Location }

  $counts = [ordered]@{}
  foreach ($stateEntry in $entries) {
    $address = $stateEntry -replace '^module\.[^.]+\.', ''
    $type = ($address -split '[\.\[]', 2)[0]
    if ([string]::IsNullOrWhiteSpace($type)) { continue }
    if ($counts.Contains($type)) { $counts[$type]++ } else { $counts[$type] = 1 }
  }
  return [pscustomobject]@{ Kind = 'tf'; Name = $task.Name; ExitCode = 0; Data = $null; Total = @($entries).Count; Types = $counts }
} -ThrottleLimit 16

$data = @{}
foreach ($result in $results) {
  if ($result.Kind -eq 'aws') { $data[$result.Name] = $result }
}

$states = @($results | Where-Object { $_.Kind -eq 'tf' } | ForEach-Object {
    [pscustomobject]@{ Directory = $_.Name; Total = $_.Total; Types = $_.Types }
  })

$failures = @($results | Where-Object { $_.Kind -eq 'aws' -and $_.ExitCode -ne 0 })
if ($failures.Count -gt 0) {
  Write-Warning ("Fallos de AWS CLI: " + (($failures | ForEach-Object Name) -join ', '))
}

$caller = $data.Sts.Data
$accountId = Get-ObjectProperty $caller @('Account')
$callerArn = Get-ObjectProperty $caller @('Arn')

# --- normalizacion ----------------------------------------------------------

$ecrNames = Select-SafeArray (Select-Values (Get-ObjectProperty $data.Ecr.Data @('Repositories', 'repositories')) 'repositoryName')
$lambdaNames = Select-SafeArray (Select-Values (Get-ObjectProperty $data.Lambda.Data @('Functions')) 'functionName')
$apiNames = Select-SafeArray (Select-Values (Get-ObjectProperty $data.ApiGw.Data @('Items')) 'Name')
$topicArns = Select-SafeArray (Select-Values (Get-ObjectProperty $data.Sns.Data @('Topics')) 'TopicArn')
$queueUrls = Select-SafeArray (Get-ObjectProperty $data.Sqs.Data @('QueueUrls', 'QueueURLs'))
$poolNames = Select-SafeArray (Select-Values (Get-ObjectProperty $data.Cognito.Data @('UserPools')) 'Name')
$ssmNames = Select-SafeArray (Select-Values (Get-ObjectProperty $data.Ssm.Data @('Parameters')) 'Name')
$secretNames = Select-SafeArray (Select-Values (Get-ObjectProperty $data.Secrets.Data @('SecretList', 'Secrets')) 'Name') |
  Where-Object { $_ -like "$SecretPrefix*" }
$roleNamesFound = Select-SafeArray (Select-Values (Get-ObjectProperty $data.IamRoles.Data @('Roles')) 'RoleName') |
  Where-Object { $RoleNames -contains $_ }
$policyNamesFound = Select-SafeArray (Select-Values (Get-ObjectProperty $data.IamPolicy.Data @('Policies')) 'PolicyName') |
  Where-Object { $PolicyNames -contains $_ }
$tableNames = Select-SafeArray (Get-ObjectProperty $data.Tables.Data @('TableNames'))
$logGroups = Select-SafeArray (Select-Values (Get-ObjectProperty $data.LogGroups.Data @('logGroups', 'LogGroups')) 'logGroupName') |
  Where-Object { $_ -like '/aws/lambda/*' }

# --- filas de servicios -----------------------------------------------------

$services = @(
  [pscustomobject]@{ Servicio = 'ECR repositories';       AWS = $ecrNames.Count;      Detalle = (Format-Detail $ecrNames) }
  [pscustomobject]@{ Servicio = 'Lambda functions';       AWS = $lambdaNames.Count;   Detalle = (Format-Detail $lambdaNames) }
  [pscustomobject]@{ Servicio = 'API Gateway (HTTP)';     AWS = $apiNames.Count;      Detalle = (Format-Detail $apiNames) }
  [pscustomobject]@{ Servicio = 'SNS topics';             AWS = $topicArns.Count;     Detalle = (Format-Detail $topicArns) }
  [pscustomobject]@{ Servicio = 'SQS queues';             AWS = $queueUrls.Count;     Detalle = (Format-Detail $queueUrls) }
  [pscustomobject]@{ Servicio = 'Cognito user pools';     AWS = $poolNames.Count;     Detalle = (Format-Detail $poolNames) }
  [pscustomobject]@{ Servicio = "SSM ($SsmPrefix)";       AWS = $ssmNames.Count;      Detalle = (Format-Detail $ssmNames 40) }
  [pscustomobject]@{ Servicio = "Secrets ($SecretPrefix)"; AWS = $secretNames.Count;  Detalle = (Format-Detail $secretNames) }
  [pscustomobject]@{ Servicio = 'IAM roles (proyecto)';   AWS = $roleNamesFound.Count; Detalle = (Format-Detail $roleNamesFound) }
  [pscustomobject]@{ Servicio = 'IAM policies (proyecto)'; AWS = $policyNamesFound.Count; Detalle = (Format-Detail $policyNamesFound) }
  [pscustomobject]@{ Servicio = 'DynamoDB tables';        AWS = $tableNames.Count;    Detalle = (Format-Detail $tableNames) }
  [pscustomobject]@{ Servicio = 'CloudWatch log groups';  AWS = $logGroups.Count;     Detalle = (Format-Detail $logGroups 60) }
)

# --- desfases estado vs AWS -------------------------------------------------

$checks = [ordered]@{
  'aws_ecr_repository'        = $ecrNames.Count
  'aws_lambda_function'       = $lambdaNames.Count
  'aws_apigatewayv2_api'      = $apiNames.Count
  'aws_sns_topic'             = $topicArns.Count
  'aws_sqs_queue'             = $queueUrls.Count
  'aws_cognito_user_pool'     = $poolNames.Count
  'aws_ssm_parameter'         = $ssmNames.Count
  'aws_secretsmanager_secret' = $secretNames.Count
  'aws_iam_role'              = $roleNamesFound.Count
  'aws_iam_policy'            = $policyNamesFound.Count
}

$mismatches = @()
foreach ($state in $states) {
  if ($null -eq $state) { continue }
  foreach ($type in $checks.Keys) {
    $inState = 0
    if ($state.Types.Contains($type)) { $inState = $state.Types[$type] }
    if ($inState -gt 0 -and $inState -ne $checks[$type]) {
      $mismatches += [pscustomobject]@{
        Estado   = $state.Directory
        Tipo     = $type
        EnEstado = $inState
        EnAws    = $checks[$type]
      }
    }
  }
}

# --- codeartifact ------------------------------------------------------------
# Workarounds para AWS CLI 2.28.6 (solo lectura, nunca `codeartifact login`):
# - `list-repositories` falla con `Unknown options: --domain`: se llama sin
#   `--domain` y se filtra por `domainName` en PowerShell.
# - Los flags camelCase fallan: no se usa `--originType`; se filtra por
#   `originConfiguration.restrictions.publish == 'ALLOW'`.
# - `terraform -chdir=<ruta>` sin comillas falla: se construye $chdir.
# - `describe-repository` no expone `assetSize`: esa columna no existe aqui.

$caConstants = @{
  Format       = 'maven'
  SortBy       = 'PUBLISHED_TIME'
  PublishAllow = 'ALLOW'
  TfOutput     = 'codeartifact_endpoint'
  Placeholder  = '-'
}

$caMsg = @{
  NoDomain      = 'No se encontro ningun repositorio en el dominio (revisa dominio o permisos).'
  NoPackages    = '(sin paquetes publicados)'
  NoTfRoot      = 'No existe el directorio de Terraform: {0}'
  NoTfOutput    = 'No se pudo leer el output codeartifact_endpoint de Terraform.'
  SameEndpoint  = 'coincide con Terraform'
  DiffEndpoint  = 'DIFIERE de Terraform'
  NoTfEndpoint  = 'sin endpoint en Terraform'
  NoAwsEndpoint = 'sin endpoint en AWS'
  AwsCallFailed = 'AWS CLI fallo en: {0}'
  OkState       = 'OK'
  FailState     = 'fallo'
}

$caCtx = [pscustomobject]@{
  Region        = $Region
  Domain        = $CodeArtifactDomain
  Repository    = $CodeArtifactRepository
  Format        = $caConstants.Format
  TerraformRoot = $CodeArtifactTerraformRoot
}

# --- utilidades codeartifact -------------------------------------------------

function Test-EmptyText {
  param($Text)
  return [string]::IsNullOrWhiteSpace("$Text")
}

function Convert-JsonPayload {
  param($Raw)
  if ($null -eq $Raw) { return $null }
  $text = ($Raw -join [Environment]::NewLine)
  if (Test-EmptyText $text) { return $null }
  return $text | ConvertFrom-Json
}

function Invoke-Aws {
  param([string[]]$Arguments)
  $full = @($Arguments) + @('--region', $caCtx.Region, '--output', 'json')
  $raw = & aws @full 2>$null
  return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Data = (Convert-JsonPayload $raw) }
}

function Write-CallFailure {
  param($Command)
  Write-Warning ($caMsg.AwsCallFailed -f $Command)
}

function Format-Value {
  param($Value)
  if (Test-EmptyText $Value) { return $caConstants.Placeholder }
  return "$Value"
}

# Recorre cada clave y proyecta cada elemento con $Select. Un solo bucle para las
# dos colecciones de CodeArtifact, que si no quedan duplicados.
function Select-Rows {
  param([string[]]$Keys, [scriptblock]$Select)
  $rows = @()
  foreach ($key in $Keys) { $rows += (& $Select $key) }
  return @($rows)
}

# --- repositorios -----------------------------------------------------------

function Get-CodeArtifactRepositoryNames {
  # Sin `--domain`: ver workaround en la cabecera del bloque.
  $call = Invoke-Aws @('codeartifact', 'list-repositories')
  if ($call.ExitCode -ne 0) {
    Write-CallFailure 'codeartifact list-repositories'
    return @()
  }
  $repositories = @(Get-ObjectProperty $call.Data @('repositories'))
  return @($repositories |
    Where-Object { (Get-ObjectProperty $_ @('domainName')) -eq $caCtx.Domain } |
    ForEach-Object { Get-ObjectProperty $_ @('name') } |
    Where-Object { $_ })
}

function Select-CodeArtifactRepository {
  param([string]$Name)
  $call = Invoke-Aws @('codeartifact', 'describe-repository',
    '--domain', $caCtx.Domain, '--repository', $Name)
  $repository = Get-ObjectProperty $call.Data @('repository')
  $upstreams = @(Get-ObjectProperty $repository @('upstreams') |
    ForEach-Object { Get-ObjectProperty $_ @('repositoryName') } | Where-Object { $_ })
  $externals = @(Get-ObjectProperty $repository @('externalConnections') |
    ForEach-Object { Get-ObjectProperty $_ @('externalConnectionName') } | Where-Object { $_ })
  return [pscustomobject]@{
    Nombre    = $Name
    Upstreams = @($upstreams)
    Externas  = @($externals)
    Creado    = (Format-Value (Get-ObjectProperty $repository @('createdTime')))
  }
}

function Get-CodeArtifactRepositories {
  return Select-Rows -Keys (Get-CodeArtifactRepositoryNames) `
    -Select { param($name) Select-CodeArtifactRepository $name }
}

# --- paquetes ---------------------------------------------------------------

function Test-PublishAllowed {
  param($Package)
  $origin = Get-ObjectProperty $Package @('originConfiguration')
  $restrictions = Get-ObjectProperty $origin @('restrictions')
  return (Get-ObjectProperty $restrictions @('publish')) -eq $caConstants.PublishAllow
}

function Get-PublishedCoordinates {
  $call = Invoke-Aws @('codeartifact', 'list-packages', '--domain', $caCtx.Domain,
    '--repository', $caCtx.Repository, '--format', $caCtx.Format)
  if ($call.ExitCode -ne 0) {
    Write-CallFailure 'codeartifact list-packages'
    return @()
  }
  $packages = @(Get-ObjectProperty $call.Data @('packages') |
    Where-Object { Test-PublishAllowed $_ })
  return @($packages | ForEach-Object { "$($_.namespace):$($_.package)" })
}

function Select-CodeArtifactPackage {
  param([string]$Coordinates)
  $parts = $Coordinates.Split(':')
  $call = Invoke-Aws @('codeartifact', 'list-package-versions', '--domain', $caCtx.Domain,
    '--repository', $caCtx.Repository, '--format', $caCtx.Format,
    '--namespace', $parts[0], '--package', $parts[1], '--sort-by', $caConstants.SortBy)
  $versions = @(Get-ObjectProperty $call.Data @('versions') |
    ForEach-Object { Get-ObjectProperty $_ @('version') } | Where-Object { $_ })
  return [pscustomobject]@{
    Paquete   = $Coordinates
    Versiones = @($versions)
    Latest    = (Format-Value (Get-ObjectProperty $call.Data @('defaultDisplayVersion')))
    ExitCode  = $call.ExitCode
  }
}

function Get-CodeArtifactPackages {
  return Select-Rows -Keys (Get-PublishedCoordinates) `
    -Select { param($coordinates) Select-CodeArtifactPackage $coordinates }
}

# --- endpoint ---------------------------------------------------------------

function Get-TerraformCodeArtifactEndpoint {
  if (-not (Test-Path -Path $caCtx.TerraformRoot)) {
    Write-Warning ($caMsg.NoTfRoot -f $caCtx.TerraformRoot)
    return $null
  }
  # Con comillas: sin ellas PowerShell no expande bien -chdir=<ruta>.
  $chdir = "-chdir=$($caCtx.TerraformRoot)"
  $raw = & terraform $chdir output -json $caConstants.TfOutput 2>$null
  if ($LASTEXITCODE -ne 0) { Write-Warning $caMsg.NoTfOutput; return $null }
  return Convert-JsonPayload $raw
}

function Get-AwsCodeArtifactEndpoint {
  $call = Invoke-Aws @('codeartifact', 'get-repository-endpoint', '--domain', $caCtx.Domain,
    '--repository', $caCtx.Repository, '--format', $caCtx.Format)
  return Get-ObjectProperty $call.Data @('repositoryEndpoint')
}

function Test-MissingEndpoint {
  param($Endpoints, [string]$Property)
  return (Format-Value $Endpoints.$Property) -eq $caConstants.Placeholder
}

function Test-SameEndpoint {
  param($Endpoints)
  $terraform = (Format-Value $Endpoints.Terraform).TrimEnd('/')
  $aws = (Format-Value $Endpoints.Aws).TrimEnd('/')
  return $terraform -eq $aws
}

function Compare-CodeArtifactEndpoint {
  param($Endpoints)
  if (Test-MissingEndpoint $Endpoints 'Terraform') { return $caMsg.NoTfEndpoint }
  if (Test-MissingEndpoint $Endpoints 'Aws') { return $caMsg.NoAwsEndpoint }
  if (Test-SameEndpoint $Endpoints) { return $caMsg.SameEndpoint }
  return $caMsg.DiffEndpoint
}

# --- informe ----------------------------------------------------------------

function Get-CodeArtifactEndpoints {
  return [pscustomobject]@{
    Terraform = (Get-TerraformCodeArtifactEndpoint)
    Aws       = (Get-AwsCodeArtifactEndpoint)
  }
}

function Get-CodeArtifactReport {
  $endpoints = Get-CodeArtifactEndpoints
  return [pscustomobject]@{
    Domain        = $caCtx.Domain
    Repository    = $caCtx.Repository
    Format        = $caCtx.Format
    TerraformRoot = $caCtx.TerraformRoot
    Repositories  = (Get-CodeArtifactRepositories)
    Packages      = (Get-CodeArtifactPackages)
    Endpoint      = [pscustomobject]@{
      Terraform   = $endpoints.Terraform
      Aws         = $endpoints.Aws
      Comparacion = (Compare-CodeArtifactEndpoint $endpoints)
    }
  }
}

# --- salida codeartifact ----------------------------------------------------

function Get-PackageState {
  param($Package)
  if ($Package.ExitCode -eq 0) { return $caMsg.OkState }
  return $caMsg.FailState
}

function Write-CodeArtifactRepositories {
  param($Repositories)
  if ($Repositories.Count -eq 0) {
    Write-Output ("  {0}" -f $caMsg.NoDomain)
    return
  }
  Write-Output ('  {0,-18} {1,-20} {2,-20} {3}' -f 'REPOSITORIO', 'UPSTREAM', 'EXTERNAS', 'CREADO')
  foreach ($repository in $Repositories) {
    Write-Output ('  {0,-18} {1,-20} {2,-20} {3}' -f
      $repository.Nombre,
      (Format-Detail $repository.Upstreams),
      (Format-Detail $repository.Externas),
      $repository.Creado)
  }
}

function Write-CodeArtifactPackageRow {
  param($Package)
  Write-Output ('  {0,-44} {1,-5} {2,-12} {3}' -f
    $Package.Paquete, $Package.Versiones.Count, $Package.Latest, (Get-PackageState $Package))
}

function Write-CodeArtifactPackageVersions {
  param($Packages)
  foreach ($package in $Packages) {
    Write-Output ("    {0}: {1}" -f $package.Paquete, (Format-Detail $package.Versiones))
  }
}

function Write-CodeArtifactPackages {
  param($Packages)
  if ($Packages.Count -eq 0) {
    Write-Output ("  {0}" -f $caMsg.NoPackages)
    return
  }
  Write-Output ('  {0,-44} {1,-5} {2,-12} {3}' -f 'PAQUETE', 'VERS', 'LATEST', 'ESTADO')
  foreach ($package in $Packages) { Write-CodeArtifactPackageRow $package }
  Write-CodeArtifactPackageVersions $Packages
}

function Write-CodeArtifactEndpoint {
  param($Report)
  Write-Output ''
  Write-Output '  ENDPOINT maven'
  Write-Output ("    terraform : {0}" -f (Format-Value $Report.Endpoint.Terraform))
  Write-Output ("    aws       : {0}" -f (Format-Value $Report.Endpoint.Aws))
  Write-Output ("    estado    : {0}" -f $Report.Endpoint.Comparacion)
}

function Write-CodeArtifactReport {
  param($Report)
  Write-Output ''
  Write-Output ("CODEARTIFACT (dominio: {0}  repositorio: {1}  formato: {2})" -f
    $Report.Domain, $Report.Repository, $Report.Format)
  Write-CodeArtifactRepositories $Report.Repositories
  Write-Output ''
  Write-CodeArtifactPackages $Report.Packages
  Write-CodeArtifactEndpoint $Report
}

$codeArtifact = Get-CodeArtifactReport

# --- salida -----------------------------------------------------------------

$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

if ($AsJson) {
  [pscustomobject]@{
    GeneratedAt = $generatedAt
    Region      = $Region
    AccountId   = $accountId
    CallerArn   = $callerArn
    Services    = $services
    Terraform   = @($states | Where-Object { $_ })
    Mismatches  = $mismatches
    AwsFailures = @($failures | ForEach-Object Name)
    CodeArtifact = $codeArtifact
  } | ConvertTo-Json -Depth 8
  exit 0
}

Write-Output "AWS services status  $generatedAt  (solo lectura)"
Write-Output ("Cuenta: {0}   Region: {1}   Caller: {2}" -f $accountId, $Region, $callerArn)
Write-Output ''
Write-Output ('{0,-32} {1,-6} {2}' -f 'SERVICIO', 'AWS', 'DETALLE')
Write-Output ('{0,-32} {1,-6} {2}' -f ('-' * 32), ('-' * 6), ('-' * 40))
foreach ($row in $services) {
  Write-Output ('{0,-32} {1,-6} {2}' -f $row.Servicio, $row.AWS, $row.Detalle)
}

Write-Output ''
Write-Output 'ESTADOS TERRAFORM (local)'
if ($states.Count -eq 0 -or -not ($states | Where-Object { $_ })) {
  Write-Output '  (sin estados encontrados)'
}
foreach ($state in $states) {
  if ($null -eq $state) { continue }
  $breakdown = @($state.Types.GetEnumerator() | ForEach-Object { "$($_.Key) x$($_.Value)" }) -join ', '
  if ([string]::IsNullOrWhiteSpace($breakdown)) { $breakdown = '(vacio)' }
  Write-Output ("  {0,-12} {1,3} recursos: {2}" -f $state.Directory, $state.Total, $breakdown)
}

Write-Output ''
Write-Output 'DESFASES ESTADO vs AWS (conteo aproximado por tipo)'
if ($mismatches.Count -eq 0) {
  Write-Output '  (sin desfases detectados)'
}
else {
  foreach ($mismatch in $mismatches) {
    Write-Output ("  {0}: {1} -> estado={2} aws={3}" -f $mismatch.Estado, $mismatch.Tipo, $mismatch.EnEstado, $mismatch.EnAws)
  }
}

Write-CodeArtifactReport $codeArtifact
