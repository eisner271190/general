#Requires -Version 7.0
<#
.SYNOPSIS
  Inventario rapido y de SOLO LECTURA de los servicios AWS del proyecto.

.DESCRIPTION
  Lanza todas las llamadas a AWS CLI en paralelo (una sola ronda), resume el
  resultado en una tabla y lo compara con los estados de Terraform locales
  para senalar desfases (recursos en el estado que ya no existen en AWS, o al
  reves). No crea, modifica ni borra nada.

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
  } | ConvertTo-Json -Depth 6
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
