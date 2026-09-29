#Requires -Version 7.0
<#
.SYNOPSIS
  Borra los servicios AWS del proyecto (usa AWS CLI, NO Terraform).

.DESCRIPTION
  DESTRUCTIVO E IRREVERSIBLE. Solo afecta a los recursos del proyecto
  (quizsmart/app): ECR, Lambda, API Gateway, Cognito, SNS, SQS, SSM,
  Secrets Manager, IAM y los grupos de log de sus Lambdas.

  Sin -Force pide confirmacion interactiva escribiendo "SI". En un shell no
  interactivo (agente) se abstiene de borrar salvo -Force con autorizacion
  explicita del usuario. Soporta -WhatIf para ver el plan sin ejecutar nada.

  Los estados de Terraform locales NO se tocan: al borrar los recursos, el
  siguiente `terraform plan`/`up.ps1` los refresca y los quita del estado.

.EXAMPLE
  .opencode/scripts/delete-all-services-aws.ps1 -WhatIf

.EXAMPLE
  .opencode/scripts/delete-all-services-aws.ps1 -Force
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [string]$Region = $(if ($env:AWS_REGION) { $env:AWS_REGION } else { 'us-east-1' }),
  [string]$SsmPrefix = '/develop/com.quizsmart.app/',
  [string]$SecretPrefix = 'develop/com.quizsmart.app',
  [string[]]$EcrNames = @('quizapi'),
  [string[]]$LambdaNames = @('quizapi'),
  [string]$ApiName = 'api-gateway',
  [string]$QueueName = 'quizapi',
  [string]$TopicName = 'main-topic',
  [string]$UserPoolName = 'user-management-user-pool',
  [string[]]$RoleNames = @('quizapi', 'CognitoAuthenticatedRole'),
  [string[]]$PolicyNames = @('CognitoPolicy'),
  [string[]]$LogGroupNames = @('/aws/lambda/quizapi'),
  [switch]$Force
)

# --- utilidades -------------------------------------------------------------

function Invoke-AwsRaw {
  # Ejecuta AWS CLI devolviendo codigo de salida y salida combinada.
  param([Parameter(Mandatory)][string[]]$AwsArguments)
  $lines = & aws @AwsArguments --region $Region --output json 2>&1
  return [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Output   = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
  }
}

function Get-AwsData {
  param([Parameter(Mandatory)][string[]]$AwsArguments)
  $result = Invoke-AwsRaw -AwsArguments $AwsArguments
  if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Output)) { return $null }
  try { return ($result.Output | ConvertFrom-Json) } catch { return $null }
}

function Get-NamesFrom {
  # Extrae un campo de una lista devuelta por AWS CLI.
  param($Collection, [string]$FieldName)
  $names = @()
  foreach ($item in @($Collection)) {
    if ($null -eq $item) { continue }
    $member = $item.PSObject.Properties[$FieldName]
    if ($null -ne $member -and $null -ne $member.Value) { $names += $member.Value }
  }
  return $names
}

function Get-ListFrom {
  # Devuelve siempre una lista; tolera respuesta nula o campo ausente.
  param($RootObject, [string]$FieldName)
  if ($null -eq $RootObject) { return @() }
  $member = $RootObject.PSObject.Properties[$FieldName]
  if ($null -eq $member -or $null -eq $member.Value) { return @() }
  return @($member.Value | Where-Object { $null -ne $_ })
}

function Test-IsMissingError {
  # Clasifica errores que solo indican que el recurso ya no existe.
  param([string]$Message)
  return ($Message -match 'NotFound|NoSuchEntity|ResourceDeleted|does not exist|RepositoryNotFoundException|QueueDoesNotExist')
}

# --- recoleccion de objetivos ----------------------------------------------

if (-not (Get-Command -Name aws -ErrorAction SilentlyContinue)) {
  Write-Error 'No se encontro el comando "aws" en el PATH.'
  exit 1
}

# El paginador de AWS CLI v2 puede retener la salida; aqui solo interesa el JSON.
$env:AWS_PAGER = ''

# Reconocimiento: todas las consultas en una sola ola paralela
$queryCalls = [ordered]@{
  Sts       = @('sts', 'get-caller-identity')
  ApiGw     = @('apigatewayv2', 'get-apis')
  Cognito   = @('cognito-idp', 'list-user-pools', '--max-results', '60')
  Lambda    = @('lambda', 'list-functions')
  Sns       = @('sns', 'list-topics')
  Sqs       = @('sqs', 'list-queues')
  Ecr       = @('ecr', 'describe-repositories')
  Secrets   = @('secretsmanager', 'list-secrets')
  Ssm       = @('ssm', 'describe-parameters', '--parameter-filters', "Key=Name,Option=BeginsWith,Values=$SsmPrefix")
  LogGroups = @('logs', 'describe-log-groups')
  IamRoles  = @('iam', 'list-roles')
  IamPolicy = @('iam', 'list-policies', '--scope', 'Local')
}

$query = @{}
$queryCalls.GetEnumerator() | ForEach-Object -Parallel {
  $awsArgs = $_.Value
  $lines = & aws @awsArgs --region $using:Region --output json 2>&1
  $exitCode = $LASTEXITCODE
  $parsed = $null
  if ($exitCode -eq 0) {
    $text = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
    if (-not [string]::IsNullOrWhiteSpace($text)) {
      try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $null }
    }
  }
  [pscustomobject]@{ Name = $_.Key; Data = $parsed; ExitCode = $exitCode }
} -ThrottleLimit 13 | ForEach-Object { $query[$_.Name] = $_ }

$failedQueries = @($query.Values | Where-Object { $_.ExitCode -ne 0 })
if ($failedQueries.Count -gt 0) {
  Write-Warning ("Fallos de AWS CLI: " + (($failedQueries | ForEach-Object Name) -join ', '))
}

$targets = [System.Collections.Generic.List[object]]::new()

function Add-Target {
  param([string]$Servicio, [string]$Recurso, [string[]]$AwsArguments)
  $targets.Add([pscustomobject]@{
      Servicio     = $Servicio
      Recurso      = $Recurso
      AwsArguments = $AwsArguments
    }) | Out-Null
}

# API Gateway (al borrar la API caen stage, rutas e integraciones)
$apis = $query.ApiGw.Data
foreach ($apiObject in Get-ListFrom $apis 'Items') {
  if ($apiObject.Name -ne $ApiName) { continue }
  Add-Target -Servicio 'API Gateway' -Recurso $apiObject.Name -AwsArguments @('apigatewayv2', 'delete-api', '--api-id', $apiObject.ApiId)
}

# Cognito (al borrar el pool caen client y domain)
$pools = $query.Cognito.Data
foreach ($poolObject in Get-ListFrom $pools 'UserPools') {
  if ($poolObject.Name -ne $UserPoolName) { continue }
  Add-Target -Servicio 'Cognito' -Recurso $poolObject.Name -AwsArguments @('cognito-idp', 'delete-user-pool', '--user-pool-id', $poolObject.Id)
}

# Lambda
$functions = $query.Lambda.Data
foreach ($fn in @(Get-NamesFrom (Get-ListFrom $functions 'Functions') 'FunctionName')) {
  if ($LambdaNames -contains $fn) {
    Add-Target -Servicio 'Lambda' -Recurso $fn -AwsArguments @('lambda', 'delete-function', '--function-name', $fn)
  }
}

# SNS
$topics = $query.Sns.Data
foreach ($topicArn in @(Get-NamesFrom (Get-ListFrom $topics 'Topics') 'TopicArn')) {
  if ($topicArn -like "*:$TopicName") {
    Add-Target -Servicio 'SNS' -Recurso $topicArn -AwsArguments @('sns', 'delete-topic', '--topic-arn', $topicArn)
  }
}

# SQS
$queues = $query.Sqs.Data
foreach ($queueUrl in Get-ListFrom $queues 'QueueUrls') {
  if ($queueUrl -like "*/$QueueName") {
    Add-Target -Servicio 'SQS' -Recurso $queueUrl -AwsArguments @('sqs', 'delete-queue', '--queue-url', $queueUrl)
  }
}

# ECR (con imagenes)
$repos = $query.Ecr.Data
foreach ($repoName in @(Get-NamesFrom (Get-ListFrom $repos 'repositories') 'repositoryName')) {
  if ($EcrNames -contains $repoName) {
    Add-Target -Servicio 'ECR' -Recurso $repoName -AwsArguments @('ecr', 'delete-repository', '--repository-name', $repoName, '--force')
  }
}

# Secrets Manager (borrado definitivo, sin ventana de recuperacion)
$secrets = $query.Secrets.Data
foreach ($secretName in @(Get-NamesFrom (Get-ListFrom $secrets 'SecretList') 'Name')) {
  if ($secretName -like "$SecretPrefix*") {
    Add-Target -Servicio 'Secrets' -Recurso $secretName -AwsArguments @('secretsmanager', 'delete-secret', '--secret-id', $secretName, '--force-delete-without-recovery')
  }
}

# SSM Parameter Store
$parameters = $query.Ssm.Data
foreach ($parameterName in @(Get-NamesFrom (Get-ListFrom $parameters 'Parameters') 'Name')) {
  Add-Target -Servicio 'SSM' -Recurso $parameterName -AwsArguments @('ssm', 'delete-parameter', '--name', $parameterName)
}

# Grupos de log de CloudWatch
$logGroups = $query.LogGroups.Data
foreach ($groupName in @(Get-NamesFrom (Get-ListFrom $logGroups 'logGroups') 'logGroupName')) {
  if ($LogGroupNames -contains $groupName) {
    Add-Target -Servicio 'CloudWatch' -Recurso $groupName -AwsArguments @('logs', 'delete-log-group', '--log-group-name', $groupName)
  }
}

# IAM: roles del proyecto (primero se desengancharan politicas)
$iamRoles = $query.IamRoles.Data
foreach ($roleName in @(Get-NamesFrom (Get-ListFrom $iamRoles 'Roles') 'RoleName')) {
  if ($RoleNames -contains $roleName) {
    Add-Target -Servicio 'IAM role' -Recurso $roleName -AwsArguments @('iam', 'delete-role', '--role-name', $roleName)
  }
}

# IAM: politicas administradas del proyecto
$iamPolicies = $query.IamPolicy.Data
foreach ($policyObject in Get-ListFrom $iamPolicies 'Policies') {
  if ($PolicyNames -notcontains $policyObject.PolicyName) { continue }
  Add-Target -Servicio 'IAM policy' -Recurso $policyObject.PolicyName -AwsArguments @('iam', 'delete-policy', '--policy-arn', $policyObject.Arn)
}

# --- plan -------------------------------------------------------------------

$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Output "delete-all-services-aws  $generatedAt"
Write-Output ("Cuenta: {0}   Region: {1}" -f $query.Sts.Data.Account, $Region)
Write-Output ''
Write-Output ('{0,-14} {1}' -f 'SERVICIO', 'RECURSO')
Write-Output ('{0,-14} {1}' -f ('-' * 14), ('-' * 50))
if ($targets.Count -eq 0) {
  Write-Output '  (no hay recursos del proyecto que borrar)'
  exit 0
}
foreach ($target in $targets) {
  Write-Output ('{0,-14} {1}' -f $target.Servicio, $target.Recurso)
}
Write-Output ''
Write-Output ("Total: {0} recursos" -f $targets.Count)

if ($WhatIfPreference) {
  Write-Output 'Modo -WhatIf: no se ha borrado nada.'
  exit 0
}

if (-not $Force) {
  if ([Console]::IsInputRedirected) {
    Write-Output 'Shell no interactivo: no se borra nada. Reintenta con -Force si tienes autorizacion explicita.'
    exit 2
  }
  $answer = Read-Host 'Esto es irreversible. Escribe SI para borrar'
  if ($answer -notmatch '^(SI|S|YES|Y)$') {
    Write-Output 'Borrado cancelado.'
    exit 0
  }
}

# --- politicas IAM: desenganchar antes de borrar roles ---------------------

$roleNamesToDelete = @($targets | Where-Object { $_.Servicio -eq 'IAM role' } | ForEach-Object Recurso)
foreach ($roleName in $roleNamesToDelete) {
  $attached = Get-AwsData -AwsArguments @('iam', 'list-attached-role-policies', '--role-name', $roleName)
  foreach ($policyArn in @(Get-NamesFrom (Get-ListFrom $attached 'AttachedPolicies') 'PolicyArn')) {
    $result = Invoke-AwsRaw -AwsArguments @('iam', 'detach-role-policy', '--role-name', $roleName, '--policy-arn', $policyArn)
    Write-Output ("detach {0} <- {1}: {2}" -f $roleName, $policyArn, $(if ($result.ExitCode -eq 0) { 'ok' } else { 'error' }))
  }
  $inline = Get-AwsData -AwsArguments @('iam', 'list-role-policies', '--role-name', $roleName)
  foreach ($policyName in Get-ListFrom $inline 'PolicyNames') {
    $result = Invoke-AwsRaw -AwsArguments @('iam', 'delete-role-policy', '--role-name', $roleName, '--policy-name', $policyName)
    Write-Output ("delete inline {0}/{1}: {2}" -f $roleName, $policyName, $(if ($result.ExitCode -eq 0) { 'ok' } else { 'error' }))
  }
}

# --- ejecucion -------------------------------------------------------------

$report = [System.Collections.Generic.List[object]]::new()

foreach ($target in $targets) {
  if (-not $PSCmdlet.ShouldProcess($target.Recurso, "Eliminar ($($target.Servicio))")) {
    $report.Add([pscustomobject]@{ Servicio = $target.Servicio; Recurso = $target.Recurso; Resultado = 'omitido' }) | Out-Null
    continue
  }

  $result = Invoke-AwsRaw -AwsArguments $target.AwsArguments
  if ($result.ExitCode -eq 0) {
    $status = 'eliminado'
  }
  elseif (Test-IsMissingError -Message $result.Output) {
    $status = 'ya no existia'
  }
  else {
    # Se recorta sobre el texto ya normalizado: recortar el original puede desbordar.
    $message = ($result.Output -replace '\s+', ' ').Trim()
    $status = 'ERROR: ' + $message.Substring(0, [Math]::Min(160, $message.Length))
  }
  $report.Add([pscustomobject]@{ Servicio = $target.Servicio; Recurso = $target.Recurso; Resultado = $status }) | Out-Null
}

# --- informe ----------------------------------------------------------------

Write-Output ''
Write-Output 'RESULTADO'
Write-Output ('{0,-14} {1,-45} {2}' -f 'SERVICIO', 'RECURSO', 'ESTADO')
Write-Output ('{0,-14} {1,-45} {2}' -f ('-' * 14), ('-' * 45), ('-' * 20))
foreach ($row in $report) {
  Write-Output ('{0,-14} {1,-45} {2}' -f $row.Servicio, $row.Recurso, $row.Resultado)
}

$deleted = @($report | Where-Object Resultado -eq 'eliminado').Count
$errors = @($report | Where-Object Resultado -like 'ERROR*').Count
Write-Output ''
Write-Output ("Eliminados: {0}   Con error: {1}   Total: {2}" -f $deleted, $errors, $report.Count)
Write-Output 'Los estados de Terraform locales no se tocaron: el siguiente plan/refresh los sincroniza.'
if ($errors -gt 0) { exit 1 }
exit 0
