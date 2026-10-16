# OBJ-005 · developer-powershell

- Fecha: `2026-10-11` · Fase: plantillas PowerShell del generador.
- Autorización: Q48 concedida por el coordinador para esta fase.
- Alcance: `generator/` y, por excepción (Q84, Q85), `.opencode/scripts/`.
- Sin commit ni push. Sin tocar `/projects`. Sin tests creados ni modificados.

## Ficheros modificados

### Cloud `generator/components/cloud/aws/templates/up.ps1.scriban`
- Ruta del parámetro: `/$Environment/{{ APPLICATION_ID }}/secrets` (antes
  `$Environment/{{ APPLICATION_ID }}`).
- `Invoke-AwsSecretsManager` sustituida por `Invoke-AwsSsm`; fuera todo
  `describe-secret`, `get-secret-value` y `put-secret-value` (Q33).
- Lectura con `ssm get-parameter --with-decryption`; escritura con
  `ssm put-parameter --type SecureString --overwrite` (Q30).
- `Test-SecretPlaceholder` + `Update-ApplicationSecret`: siembra solo si el
  parámetro falta o si su valor es el `placeholder` que deja Terraform (Q77).
  Con un JSON ya sembrado no se escribe nada: las claves existentes nunca se
  sobrescriben. El helper `ConvertTo-SecretHashtable` deja de usarse y se elimina.
- Cabecera, etiqueta de `secrets.tf` y mensajes de log sin "secreto".

### Cloud `generator/components/cloud/aws/templates/down.ps1.scriban`
- `Get-ApplicationSecretState` y `Restore-ScheduledSecret` eliminadas; con ello
  los estados `scheduled` y `active` y toda la lógica de `restore-secret` (Q32).
- `Remove-ApplicationSecret` usa `ssm delete-parameter`; idempotente si el
  parámetro ya no existe (Q31).
- `Get-KeystoreBucketName`: `{{ APPLICATION_ID }}-keystore-$Environment`, el mismo
  nombre que genera Terraform (Q56, Q93).
- `Remove-KeystoreBucketContent`: purga por CLI todas las versiones y marcadores
  de borrado en lotes de 1000, antes del `terraform destroy` (D42).
- `Remove-KeystoreBucketLeftover`: `s3api delete-bucket` después del destroy;
  idempotente si Terraform ya lo eliminó (D41). El destroy del bucket lo hace
  Terraform, no el CLI.
- Orden final en `Invoke-MicroserviceDown`: `delete-parameter` → purga del bucket
  → `terraform destroy` → CLI final de restos.

### Flutter `generator/components/frontend/flutter3.47.2/templates/up.ps1.scriban`
- Lectura del SecureString con `get-parameter --with-decryption`; escritura con
  `put-parameter --type SecureString --overwrite` (Q33).
- Sin `-Sign` y sin parámetro: mensaje explícito y se continúa (Q34).
- `New-AndroidSigningMaterial` genera el `.jks` en una ruta indicada (keytool,
  RSA 2048, JKS) y ya no devuelve `keystore-base64`; devuelve solo `key-alias`,
  `store-password` y `key-password`.
- `Get-KeystoreBucketName` y `Get-KeystoreObjectKey`:
  `{{ APPLICATION_ID }}-keystore-$Environment` y
  `keystore/{{ APPLICATION_ID }}/keystore.jks`.
- `Get-KeystoreFromBucket` descarga siempre a un temporal nuevo
  (`New-KeystoreTempPath`, sin caché local) y lee el metadato `sha256`.
- `Get-VerifiedKeystore` compara el SHA-256 del fichero con el del metadato y
  aborta si no coinciden o si el metadato no existe (Q80, Q75).
- `Test-KeystoreObjectExists` + `Get-OrCreateAndroidSigning`: si el objeto existe
  no se regenera ni se sobrescribe nada; si falta, se genera, se sube con
  `put-object --metadata sha256=...` y se guarda `android-signing` (Q88, Q35).
- `Get-SigningPassword`: con `Set-StrictMode` indexar una clave ausente lanza;
  las contraseñas ya sembradas se leen con `ContainsKey`. Si el objeto no existe
  pero el parámetro ya tiene `android-signing`, el keystore nuevo se genera con
  esas contraseñas; si el objeto existe y el bloque falta, se aborta con un
  mensaje explícito (las contraseñas no se pueden recuperar).
- `Write-AndroidSigningArtifacts` copia el fichero descargado; `Remove-KeystoreTempPath`
  borra el temporal al terminar.
- Cabecera y `.PARAMETER` sin referencias a Secrets Manager.

### Flutter `generator/components/frontend/flutter3.47.2/templates/README.md.scriban`
-developer-scriban ya lo había reescrito: ya no describía Secrets Manager ni la
  caché local. Solo sedledo:
  - Descarga siempre desde S3, sin caché local, con verificación de SHA-256.
  - El keystore vive solo en un temporal.
  - `./up.ps1 -Sign` lee el parámetro SSM y el keystore de S3.

### Flutter `generator/components/frontend/flutter3.47.2/templates/down.ps1.scriban`
- Revisado (punto 8). No toca el secreto, el parámetro, el keystore ni el bucket:
  solo detiene `flutter run` y ejecuta `flutter clean`. No se modifica. El borrado
  del bucket es del `down.ps1` de cloud (Q89).

### `.opencode/scripts/delete-all-services-aws.ps1` (excepción Q84)
- Nuevos parámetros `-ApplicationId` y el nombre del bucket derivado de él.
- Los entornos NO se hardcodean: se deducen con la regex `^/<env>/<app>/` sobre
  los parámetros SSM ya sembrados, de modo que se borran los buckets de todos los
  entornos presentes (Q91, Q93).
- Se añade un target `S3 keystore` con `s3api delete-bucket` por bucket detectado.
- La purga de versiones del bucket de buildspecs se extrae a
  `Remove-VersionedBucketContent` y se reutiliza para los buckets del keystore;
  si un bucket no existe o no se puede vaciar, su borrado se omite.
- Cabecera actualizada.

### `.opencode/scripts/get-services-aws.ps1` (excepción Q84)
- Nuevos parámetros `-ApplicationId` y `-KeystoreEnvironments`.
- Fila nueva `S3 keystore buckets`: una llamada `s3api head-bucket` por entorno.
  Solo informa de la existencia; no lista objetos ni versiones (Q92).
- La captura paralela tolera la respuesta vacía de `head-bucket` y esos fallos no
  cuentan como error de AWS CLI (un bucket inexistente no es un fallo).

## Verificaciones
- Los cinco scripts y plantillas modificados parsean sin errores con
  `System.Management.Automation.Language.Parser` tras sustituir los
  placeholders `{{ ... }}`.
- `git status`: ningún cambio fuera de `generator/`, `.opencode/scripts/` y
  `docs/deliverables/obj-005/`.
- Sin coincidencias de `secretsmanager`, `Secrets Manager`, `secreto` ni
  `keystore-base64` en las plantillas de cloud y Flutter.
- Las líneas largas que introduces respetan el estilo ya presente en los ficheros
  (el límite de 100 caracteres no lo cumplía ningún script de estos antes del
  cambio).

## Fuera de esta fase
- ADR y documentación de `library/platform` (developer-java / fase de docs).
- `component.json` sin cambios: no se añadieron ni renombraron plantillas en esta
  fase; las de Terraform ya las registró developer-scriban.

## Dudas
- Q97: el encargo pedía generar el keystore en `cloud/up.ps1` y en
  `flutter/up.ps1`; se ha implementado solo en Flutter por Q35, Q59 y Q88.
- Q98: el CLI final de restos en `cloud/down.ps1` no debe fallar si Terraform ya
  destruyó el bucket; queda para verificar en tester.