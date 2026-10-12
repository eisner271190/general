# OBJ-005 · developer-powershell-fix

- Fecha: `2026-10-11` · Correccion autorizada sobre `delete-all-services-aws.ps1`.
- Alcance: solo `.opencode/scripts/delete-all-services-aws.ps1`. Nada mas.
- Sin commit ni push. Sin tocar `generator/` ni `/projects`. Sin tests creados ni modificados.

## Cambio 1 · SNS: desuscribir antes de borrar el topic

- Motivo: el script solo hacia `delete-topic`. SNS conserva las suscripciones aunque el
  topic desaparezca, por eso quedaban 4 suscripciones huerfanas hacia la cola `quizapi`.
- Se consulta `sns list-subscriptions-by-topic --topic-arn <arn>` y se anade un objetivo
  `sns unsubscribe --subscription-arn <arn>` por cada suscripcion.
- Orden: el bucle de ejecucion (linea 484) recorre `$targets` en orden de insercion, asi
  que basta con anadir las suscripciones ANTES del `Add-Target` de `delete-topic`.
  No hizo falta ninguna logica extra de ordenacion; el diseno actual ya lo garantiza.
- Si `Get-AwsData` falla (topic ya borrado) devuelve `$null` y `Get-ListFrom` devuelve
  `@()`: no rompe el plan.

```diff
 # SNS
+# El bucle de ejecucion recorre $targets en orden de insercion, asi que las
+# suscripciones se desuscriben ANTES de borrar el topic. Sin esto, `list-subscriptions`
+# deja suscripciones huerfanas hacia las colas ya borradas.
 $topics = $query.Sns.Data
 foreach ($topicArn in @(Get-NamesFrom (Get-ListFrom $topics 'Topics') 'TopicArn')) {
   if ($topicArn -like "*:$TopicName") {
+    $subscriptions = Get-ListFrom (Get-AwsData -AwsArguments @('sns', 'list-subscriptions-by-topic', '--topic-arn', $topicArn)) 'Subscriptions'
+    foreach ($subscription in $subscriptions) {
+      $subscriptionArn = $subscription.PSObject.Properties['SubscriptionArn']
+      if ($null -eq $subscriptionArn -or [string]::IsNullOrWhiteSpace($subscriptionArn.Value)) { continue }
+      Add-Target -Servicio 'SNS' -Recurso "$topicArn -> suscripcion $($subscriptionArn.Value)" -AwsArguments @('sns', 'unsubscribe', '--subscription-arn', $subscriptionArn.Value)
+    }
     Add-Target -Servicio 'SNS' -Recurso $topicArn -AwsArguments @('sns', 'delete-topic', '--topic-arn', $topicArn)
   }
 }
```

## Cambio 2 · EventBridge: `--targets` -> `--ids`

- `aws events remove-targets` exige `--ids`, no `--targets`. Con el flag antiguo el
  comando fallaba y `delete-rule` abortaba despues con `ValidationException`.

```diff
-  # --targets Id=<id>. El id lo autogenera Terraform (bump_bom.tf no lo declara: sale como
-  # `common-release-terraform-XXXX` y cambia en cada apply), asi que hay que consultarlo.
+  # --ids <id> (un id por target). El id lo autogenera Terraform (bump_bom.tf no lo declara: sale
+  # como `common-release-terraform-XXXX` y cambia en cada apply), asi que hay que consultarlo.
-    ... 'remove-targets', '--rule', $ReleaseRule, '--targets', "Id=$($targetId.Value)"
+    ... 'remove-targets', '--rule', $ReleaseRule, '--ids', $targetId.Value
```

## Verificacion

- Parseo del script: `PARSE OK: sin errores de sintaxis`.
- `-WhatIf` ejecutado, sin borrado real:

```
Log: ...\delete-all-services-aws-20261011-233209-188.log
Buckets del keystore detectados: 0
delete-all-services-aws  2026-10-11 23:32:15
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
IAM role       epc-codebuild
IAM role       epc-buildspecs-publisher
IAM role       epc-common-reader
IAM role       epc-common-publisher

Total: 20 recursos
Modo -WhatIf: no se ha borrado nada.
```

- El target de EventBridge aparece y su comando ya usa `--ids` (verificado en el diff).

## Hallazgo relevante: el WhatIf NO muestra objetivos SNS

- Motivo: `sns list-topics` devuelve `{"Topics": []}`. El topic `main-topic` ya fue
  borrado por una ejecucion anterior, asi que el bloque SNS no entra y el plan no lista
  suscripciones. No es un fallo del cambio, es el estado actual de la cuenta.
- Consecuencia: las 4 suscripciones huerfanas que quedan NO las limpia esta correccion.
  `list-subscriptions-by-topic` sobre ese ARN responde
  `NotFound ... Topic does not exist`, y el script solo itera topics existentes.
- Es decir: el cambio previene el problema en futuras ejecuciones, pero las 4 huerfanas
  actuales requieren borrarlas a mano (`aws sns unsubscribe --subscription-arn <arn>`),
  y su ARN solo se puede leer ya truncado en la salida de `list-subscriptions`.
- Queda pendiente de decision: si tambien hay que barrer suscripciones huerfanas
  de topics ya inexistentes, haria falta iterar `sns list-subscriptions` y filtrar por
  `TopicArn`. No se implemento por quedar fuera de lo autorizado.

## Estado

- Fichero modificado: `.opencode/scripts/delete-all-services-aws.ps1` (2 bloques).
- El diff total del fichero incluye cambios previos ya presentes en el working tree
  (buckets del keystore, `Remove-VersionedBucketContent`), ajenos a esta correccion.
- Sin commit ni push.