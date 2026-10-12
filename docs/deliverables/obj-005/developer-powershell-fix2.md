# OBJ-005 · developer-powershell-fix2

- Fecha: `2026-10-11` · Segunda correccion autorizada sobre `delete-all-services-aws.ps1`.
- Alcance: solo `.opencode/scripts/delete-all-services-aws.ps1`. Nada mas.
- Sin commit ni push. Sin tocar `generator/` ni `/projects`. Sin tests creados ni modificados.

## Motivo

- La correccion anterior cubria solo suscripciones cuyo topic existe (`list-subscriptions-by-topic`
  dentro del bucle de topics).
- Las suscripciones cuyo topic ya no existe (huerfanas) no salen de ahi: el script solo itera
  topics existentes y esas quedan colgadas.
- Cierre del hallazgo "Queda pendiente de decision" de `developer-powershell-fix.md:104-105`.

## Cambio 1 · Consulta paralela de suscripciones

- Se anade `SnsSubs = @('sns', 'list-subscriptions')` a `$queryCalls`, con el mismo patron que
  las demas entradas. Entra en la ola paralela, no en el bucle secuencial.

```diff
   Sns       = @('sns', 'list-topics')
+  SnsSubs   = @('sns', 'list-subscriptions')
   Sqs       = @('sqs', 'list-queues')
```

## Cambio 2 · Barrido de suscripciones huerfanas

- Tras el bucle de topics se recorre la lista completa de suscripciones de la cuenta.
- Se anade `sns unsubscribe --subscription-arn <arn>` para las que no se hayan desuscrito ya.
- Anti-duplicados: `$unsubscribed` (List[string]) registra cada ARN anadido, en el bucle de
  topics y en el barrido. Mismo patron que `$keystoreBuckets` (List + `Contains`).
- Orden: estas entradas se insertan DESPUES de los `delete-topic`. No importa: por definicion
  su topic ya no existe, asi que no hay nada queiliconear en el topic.

```diff
 $topics = $query.Sns.Data
+$unsubscribed = [System.Collections.Generic.List[string]]::new()
 foreach ($topicArn in @(Get-NamesFrom (Get-ListFrom $topics 'Topics') 'TopicArn')) {
   if ($topicArn -like "*:$TopicName") {
     $subscriptions = Get-ListFrom (Get-AwsData ... 'Subscriptions')
     foreach ($subscription in $subscriptions) {
       ...
+      $unsubscribed.Add($subscriptionArn.Value) | Out-Null
       Add-Target -Servicio 'SNS' -Recurso "$topicArn -> suscripcion ..." ...
     }
     Add-Target -Servicio 'SNS' -Recurso $topicArn -AwsArguments @('sns','delete-topic',...)
   }
 }

+# Barrido de suscripciones huerfanas: las que apuntan a un topic ya borrado no salen de
+# `list-subscriptions-by-topic` porque el topic no existe. Se recorren todas de la cuenta
+# y se filtran por el mismo criterio de topic que el bloque anterior ($TopicName), sin
+# inventar un criterio de proyecto nuevo. Se omiten las ya desuscritas en el bucle de topics.
+foreach ($subscription in Get-ListFrom $query.SnsSubs.Data 'Subscriptions') {
+  $subscriptionArn = $subscription.PSObject.Properties['SubscriptionArn']
+  if ($null -eq $subscriptionArn -or [string]::IsNullOrWhiteSpace($subscriptionArn.Value)) { continue }
+  if ($unsubscribed.Contains($subscriptionArn.Value)) { continue }
+  $subscriptionTopicArn = $subscription.PSObject.Properties['TopicArn']
+  if ($null -eq $subscriptionTopicArn -or $subscriptionTopicArn.Value -notlike "*:$TopicName") { continue }
+  $unsubscribed.Add($subscriptionArn.Value) | Out-Null
+  Add-Target -Servicio 'SNS' -Recurso "huerfana $($subscriptionArn.Value)" -AwsArguments @('sns','unsubscribe','--subscription-arn',$subscriptionArn.Value)
+}
```

## Decision sobre el filtro por proyecto

- El script NO filtra suscripciones por proyecto en ningun otro bloque: no existe ese criterio.
- Los bloques filtran por nombre de recurso (`$TopicName`, `$QueueName`, `$EcrNames`,
  `$RoleNames`...). La suscripcion no tiene nombre de recurso propio; el unico campo de
  proyecto que trae es `TopicArn`.
- Se aplica el MISMO criterio del bloque SNS de arriba: `TopicArn -like "*:$TopicName"`.
  No se inventa ningun criterio nuevo.
- Consecuencia: una suscripcion huerfana cuyo topic tenga otro nombre NO se borra. Es
  coherente con el resto del script (que tampoco borra topics con otro nombre), y evita
  desuscribir recursos de otros proyectos de la misma cuenta.
- Si algun dia el topic del proyecto cambia de nombre, el filtro hay que actualizarlo aqui
  tambien; queda documentado en el informe.

## Verificacion

- Parseo: `PARSE OK: sin errores de sintaxis`.

```
pwsh -NoProfile -File .opencode/scripts/delete-all-services-aws.ps1 -WhatIf
```

```
Log: ...\delete-all-services-aws-20261011-233621-204.log
Buckets del keystore detectados: 0
delete-all-services-aws  2026-10-11 23:36:30
Cuenta: 577638384397   Region: us-east-1

SERVICIO       RECURSO
-------------- --------------------------------------------------
CodePipeline   common
CodeBuild      common-build
CodeBuild      common-publish
CodeBuild      platform-bump-bom
EventBridge    common-release -> target terraform-Zxd3ZRRXwHhrk8iBLz6KkdnH2v
EventBridge    common-release
CodeCommit     common
CodeCommit     platform
CodeCommit     com.quizsmart.app
CodeArtifact   common
CodeArtifact   maven-central
CodeArtifact   epc (dominio)
ECR            epc/common-base
S3             epc-buildspecs
IAM role       epc-bump-trigger
IAM role       epc-common-pipeline
IAM role       epc-common-pipeline
IAM role       epc-buildspecs-publisher
IAM role       epc-common-reader
IAM role       epc-common-publisher

Total: 20 recursos
Modo -WhatIf: no se ha borrado nada.
```

- Sin borrado real. Sin errores de AWS CLI en consola.

## Por que el plan no muestra lineas SNS

- `sns list-topics` devuelve `{"Topics": []}`: el topic `main-topic` ya no existe.
- `sns list-subscriptions` devuelve `{"Subscriptions": []}`: las 4 huerfanas ya se
  dessuscribieron a mano entre la correccion anterior y esta.
- Por eso el plan sale con los mismos 20 recursos de plataforma que antes: no hay nada que
  listar. No es un fallo del cambio; es el estado actual de la cuenta.
- Verificado con `aws sns list-subscriptions --region us-east-1 --output json`.
- La correccion queda aplicada y no ejecutable hasta que exista una suscripcion huerfana;
  es prevention, no cleanup.

## Estado

- Fichero modificado: `.opencode/scripts/delete-all-services-aws.ps1` (2 bloques).
- El `git diff` total del fichero incluye cambios previos ya presentes en el working tree
  (buckets del keystore, `Remove-VersionedBucketContent`, `--ids` de EventBridge), ajenos a
  esta correccion.
- Sin commit ni push.