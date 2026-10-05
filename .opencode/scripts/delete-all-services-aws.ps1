#Requires -Version 7.0
<#
.SYNOPSIS
  Borra los servicios AWS del proyecto (usa AWS CLI, NO Terraform).

.DESCRIPTION
  DESTRUCTIVO E IRREVERSIBLE. Solo afecta a los recursos del proyecto
  (quizsmart/app): ECR, Lambda, API Gateway, Cognito, SNS, SQS, DynamoDB, SSM,
  Secrets Manager, IAM y los grupos de log de sus Lambdas — Y LA PLATAFORMA completa de
  library/platform: pipeline, proyectos CodeBuild, regla de release, bucket de buildspecs,
  repos de CodeCommit, ECR de la imagen base, roles IAM epc-*, y el dominio con sus repos de
  CodeArtifact. Sin parametros borra TODO, sin excepcion.

  ATENCION: borrar CodeArtifact destruye los artefactos Maven ya publicados
  (com.epc.common:*). Despues hay que republicarlos con publish-common.ps1.

  -SkipPlatform limita el borrado a la aplicacion y conserva la plataforma.

  Sin -Force pide confirmacion interactiva escribiendo "SI". En un shell no
  interactivo (agente) se abstiene de borrar salvo -Force con autorizacion
  explicita del usuario. Soporta -WhatIf para ver el plan sin ejecutar nada.

  Los estados de Terraform locales NO se tocan: al borrar los recursos, el
  siguiente `terraform plan`/`up.ps1` los refresca y los quita del estado.

.EXAMPLE
  Borra TODO (aplicacion y plataforma). Revisa la lista antes de confirmar.

.EXAMPLE
  .opencode/scripts/delete-all-services-aws.ps1 -WhatIf

.EXAMPLE
  .opencode/scripts/delete-all-services-aws.ps1 -Force

.EXAMPLE
  .opencode/scripts/delete-all-services-aws.ps1 -SkipPlatform -WhatIf
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
  [string[]]$DynamoDbTableNames = @('quizapiSubscription', 'quizapiWebhookEvent'),
  [string]$TopicName = 'main-topic',
  [string]$UserPoolName = 'user-management-user-pool',
  [string[]]$RoleNames = @('quizapi', 'CognitoAuthenticatedRole'),
  [string[]]$PolicyNames = @('CognitoPolicy'),
  [string[]]$LogGroupNames = @('/aws/lambda/quizapi'),
  [string]$LogPath = (Join-Path ([IO.Path]::GetTempPath()) (
    "delete-all-services-aws-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff').log")),
  [switch]$Force,

  # --- Plataforma (library/platform). Se borra por defecto: -SkipPlatform lo desactiva ---
  [switch]$SkipPlatform,
  [string]$PlatformPrefix = 'epc',
  [string]$BuildspecsBucket = 'epc-buildspecs',
  [string]$CommonBaseEcr = 'epc/common-base',
  [string[]]$PlatformRepositories = @('common', 'platform'),
  [string]$CommonPipeline = 'common',
  [string]$BumpProject = 'platform-bump-bom',
  [string]$ReleaseRule = 'common-release',
  [string]$CodeArtifactDomain = 'epc',
  [string[]]$CodeArtifactRepositories = @('maven-central', 'common')
)

# La plataforma entra por defecto. -SkipPlatform es el opt-out explicito.
$includePlatform = -not $SkipPlatform

# --- utilidades -------------------------------------------------------------

function Write-Log {
  param([Parameter(Mandatory)][string]$Message)
  $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
  Add-Content -LiteralPath $LogPath -Value $entry -Encoding utf8 -ErrorAction Stop
}

function Invoke-AwsRaw {
  # Ejecuta AWS CLI devolviendo codigo de salida y salida combinada.
  param([Parameter(Mandatory)][string[]]$AwsArguments)
  $lines = & aws @AwsArguments --region $Region --output json 2>&1
  $exitCode = $LASTEXITCODE
  $output = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
  $command = "aws $($AwsArguments -join ' ') --region $Region --output json"
  if ($exitCode -ne 0) { Write-Log "ERROR $command ExitCode=$exitCode Output=$output" }
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output   = $output
    Command  = $command
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

try {
  Set-Content -LiteralPath $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Inicio" -Encoding utf8 -ErrorAction Stop
}
catch {
  Write-Error "No se pudo crear el log '$LogPath': $_"
  exit 1
}
Write-Output "Log: $LogPath"

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
  DynamoDb  = @('dynamodb', 'list-tables')
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
  $text = ($lines | ForEach-Object { "$_" }) -join [Environment]::NewLine
  $parsed = $null
  if ($exitCode -eq 0) {
    if (-not [string]::IsNullOrWhiteSpace($text)) {
      try { $parsed = $text | ConvertFrom-Json } catch { $parsed = $null }
    }
  }
  [pscustomobject]@{
    Name = $_.Key; Data = $parsed; ExitCode = $exitCode
    Output = $text; Arguments = ($awsArgs -join ' ')
  }
} -ThrottleLimit 13 | ForEach-Object { $query[$_.Name] = $_ }

Write-Log "Cuenta=$($query.Sts.Data.Account) Region=$Region"
foreach ($failedQuery in @($query.Values | Where-Object { $_.ExitCode -ne 0 })) {
  Write-Log "ERROR consulta aws $($failedQuery.Arguments): $($failedQuery.Output)"
}

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

# DynamoDB
$tables = $query.DynamoDb.Data
foreach ($tableName in Get-ListFrom $tables 'TableNames') {
  if ($DynamoDbTableNames -contains $tableName) {
    Add-Target -Servicio 'DynamoDB' -Recurso $tableName -AwsArguments @('dynamodb', 'delete-table', '--table-name', $tableName)
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

# --- plataforma (library/platform) ------------------------------------------
#
# Solo sin -SkipPlatform. El orden importa: se anade en orden de borrado, y el bucle de
# ejecucion los recorre en ese orden. Dependencias:
#   pipeline -> proyectos CodeBuild (CodePipeline borra stages, no los proyectos)
#   regla    -> remove-targets antes de delete-rule
#   dominio  -> repos antes que el dominio (si no, RepositoryNotFoundException)
#   S3       -> el bucket esta versionado: hay que vaciar todas las versiones antes

if ($includePlatform) {
  Add-Target -Servicio 'CodePipeline' -Recurso $CommonPipeline -AwsArguments @('codepipeline', 'delete-pipeline', '--name', $CommonPipeline)

  foreach ($projectName in @("$CommonPipeline-build", "$CommonPipeline-publish", $BumpProject)) {
    Add-Target -Servicio 'CodeBuild' -Recurso $projectName -AwsArguments @('codebuild', 'delete-project', '--name', $projectName)
  }

  Add-Target -Servicio 'EventBridge' -Recurso $ReleaseRule -AwsArguments @('events', 'remove-targets', '--rule', $ReleaseRule)
  Add-Target -Servicio 'EventBridge' -Recurso $ReleaseRule -AwsArguments @('events', 'delete-rule', '--name', $ReleaseRule)

  foreach ($repositoryName in $PlatformRepositories) {
    Add-Target -Servicio 'CodeCommit' -Recurso $repositoryName -AwsArguments @('codecommit', 'delete-repository', '--repository-name', $repositoryName)
  }

  foreach ($repositoryName in $CodeArtifactRepositories) {
    Add-Target -Servicio 'CodeArtifact' -Recurso $repositoryName -AwsArguments @('codeartifact', 'delete-repository', '--domain', $CodeArtifactDomain, '--repository', $repositoryName)
  }
  Add-Target -Servicio 'CodeArtifact' -Recurso "$CodeArtifactDomain (dominio)" -AwsArguments @('codeartifact', 'delete-domain', '--domain', $CodeArtifactDomain)

  Add-Target -Servicio 'ECR' -Recurso $CommonBaseEcr -AwsArguments @('ecr', 'delete-repository', '--repository-name', $CommonBaseEcr, '--force')

  # El bucket va al final de los datos: CodePipeline y CodeBuild escriben artefactos y logs.
  Add-Target -Servicio 'S3' -Recurso $BuildspecsBucket -AwsArguments @('s3', 'rb', "s3://$BuildspecsBucket", '--force')

  # Las 6 politicas de la plataforma son INLINE (aws_iam_role_policy): no aparecen en
  # `iam list-policies --scope Local`. Las borra el pre-step de inline que ya existe abajo,
  # asi que aqui solo van los roles.
  foreach ($roleName in @(
      "$PlatformPrefix-bump-trigger", "$PlatformPrefix-common-pipeline", "$PlatformPrefix-codebuild",
      "$PlatformPrefix-buildspecs-publisher", "$PlatformPrefix-common-reader", "$PlatformPrefix-common-publisher")) {
    Add-Target -Servicio 'IAM role' -Recurso $roleName -AwsArguments @('iam', 'delete-role', '--role-name', $roleName)
  }
}

# --- plan -------------------------------------------------------------------

$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Output "delete-all-services-aws  $generatedAt"
Write-Output ("Cuenta: {0}   Region: {1}" -f $query.Sts.Data.Account, $Region)
Write-Output ''
Write-Output ('{0,-14} {1}' -f 'SERVICIO', 'RECURSO')
Write-Output ('{0,-14} {1}' -f ('-' * 14), ('-' * 50))
if ($targets.Count -eq 0) {
  Write-Output '  (no hay recursos que borrar)'
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
    Write-Log "IAM detach $($result.Command) ExitCode=$($result.ExitCode) Output=$($result.Output)"
    Write-Output ("detach {0} <- {1}: {2}" -f $roleName, $policyArn, $(if ($result.ExitCode -eq 0) { 'ok' } else { 'error' }))
  }
  $inline = Get-AwsData -AwsArguments @('iam', 'list-role-policies', '--role-name', $roleName)
  foreach ($policyName in Get-ListFrom $inline 'PolicyNames') {
    $result = Invoke-AwsRaw -AwsArguments @('iam', 'delete-role-policy', '--role-name', $roleName, '--policy-name', $policyName)
    Write-Log "IAM inline $($result.Command) ExitCode=$($result.ExitCode) Output=$($result.Output)"
    Write-Output ("delete inline {0}/{1}: {2}" -f $roleName, $policyName, $(if ($result.ExitCode -eq 0) { 'ok' } else { 'error' }))
  }
}

# --- bucket de buildspecs: hay que vaciarlo antes ----------------------------
#
# El bucket esta versionado yTerraform lo declara con force_destroy = false. `delete-bucket`
# no acepta un bucket con versiones: se purgan todas (con sus marcadores de borrado) en lotes
# de 1000 y luego se borra el bucket. Es la unica operacion que no cabe en un unico target.

if ($includePlatform -and -not $WhatIfPreference -and ($targets.Recurso -contains $BuildspecsBucket)) {
  $keys = [System.Collections.Generic.List[object]]::new()
  $versioning = Get-AwsData -AwsArguments @('s3api', 'get-bucket-versioning', '--bucket', $BuildspecsBucket)
  $versions = Get-AwsData -AwsArguments @('s3api', 'list-object-versions', '--bucket', $BuildspecsBucket)
  foreach ($v in Get-ListFrom $versions 'Versions') {
    $keys.Add([pscustomobject]@{ Key = $v.Key; VersionId = $v.VersionId }) | Out-Null
  }
  foreach ($d in Get-ListFrom $versions 'DeleteMarkers') {
    $keys.Add([pscustomobject]@{ Key = $d.Key; VersionId = $d.VersionId }) | Out-Null
  }
  Write-Output "Bucket $BuildspecsBucket versionado=$($null -ne $versioning.Status) objetos+versiones=$($keys.Count)"
  for ($offset = 0; $offset -lt $keys.Count; $offset += 1000) {
    $batch = $keys[$offset..([Math]::Min($offset + 999, $keys.Count - 1))]
    $payload = @{ Objects = @($batch) } | ConvertTo-Json -Depth 4 -Compress
    $result = Invoke-AwsRaw -AwsArguments @('s3api', 'delete-objects', '--bucket', $BuildspecsBucket, '--delete', $payload)
    Write-Log "S3 purge $BuildspecsBucket ExitCode=$($result.ExitCode) Output=$($result.Output)"
    if ($result.ExitCode -ne 0) {
      Write-Output "No se pudo vaciar el bucket ${BuildspecsBucket}: $($result.Output)"
      Write-Output 'Se omite su borrado.'
      $targets = @($targets | Where-Object { $_.Recurso -ne $BuildspecsBucket })
    }
  }
}

# --- ejecucion -------------------------------------------------------------

$report = [System.Collections.Generic.List[object]]::new()

foreach ($target in $targets) {
  if (-not $PSCmdlet.ShouldProcess($target.Recurso, "Eliminar ($($target.Servicio))")) {
    Write-Log "OMIT $($target.Servicio) $($target.Recurso): ShouldProcess no autorizo la ejecucion"
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
  Write-Log "DELETE $($result.Command) ExitCode=$($result.ExitCode) Result=$status Output=$($result.Output)"
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
