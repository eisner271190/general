# OBJ-005 · developer-terraform

- Objetivo: `OBJ-005: Reemplazar AWS Secrets Manager por SSM Parameter Store SecureString`
- Agente: `developer-terraform` (informe creado por decisión del usuario, Q109)
- Estado: `documentado; cambios registrados por developer-scriban; verificación de tester`
- Fecha de registro: `2026-10-12`
- Fuente: solo lo registrado en `developer-scriban.md`, `tester.md` y `architect.md`.

## Resumen

- Los cambios Terraform los aplicó `developer-scriban` en las plantillas del generador.
- No existe informe Terraform previo: este documento solo recoge lo ya registrado.
- Sin `terraform apply` ni `destroy`. Sin commit ni push.

## Plantillas Terraform tocadas (`cloud/aws/templates/`)

- `terraform-ssm-parameter.scriban` (renombrada desde `terraform-secrets-manager.scriban`):
  - Recurso `aws_ssm_parameter.app_secret`, `type = "SecureString"`.
  - Nombre `/${var.environment}/${var.project_name}/secrets`.
  - `value = "placeholder"` y `lifecycle { ignore_changes = [value] }` (Q69).
  - Nombre del recurso sin cambio (Q17).
- `terraform-ssm-parameter-variables.scriban` (renombrada desde
  `terraform-secrets-manager-variables.scriban`):
  - Quedan `environment` y `project_name`; se elimina `kms_key_arn` (Q21, Q24).
- `terraform-keystore-bucket.scriban` (nueva):
  - Bucket `{{ APPLICATION_ID }}-keystore-${var.environment}`.
  - Versionado, SSE-S3 (`AES256`) y bloqueo total de acceso público (Q56, Q58, Q60, Q73).
  - Se registra como `cloud/terraform/app/keystore_bucket.tf`.
- `terraform-lambda.scriban`:
  - `ssm:GetParameter` y `ssm:GetParametersByPath` sobre
    `parameter/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/*`.
  - `kms:Decrypt` sobre `alias/aws/ssm`.
  - Sin `PutParameter` y sin permisos S3 (Q25, Q27, Q28, Q66).
- `terraform-pipeline.scriban:201`:
  - Sustituye `secretsmanager:GetSecretValue` (`resources = ["*"]`).
  - `ssm:GetParameter`, `ssm:PutParameter` y `ssm:GetParametersByPath` sobre la ruta.
  - `kms:Decrypt` sobre `alias/aws/ssm`. Sin S3 (Q26, Q59).
- `terraform-secrets.scriban`:
  - `source = "../modules/secure-parameters"`.
  - Fuera `kms_key_arn` y su comentario (Q20, Q24).

## Módulo `secure-parameters`

- Carpeta renombrada desde `modules/secrets-manager` (Q20).
- `component.json`: rutas de `modules/secure-parameters` en las líneas 10, 37-38 y registro
  de las plantillas renombradas y de la nueva del bucket (Q22).
- `cloud/aws/AGENTS.md:4`: módulos `{secure-parameters,pipeline}` (Q20).
- Verificado por tester: `secure-parameters` y `app/secrets.tf` con el `source` correcto.

## IAM por rol

- Lambda: solo lectura de la ruta y `aws/ssm`. Sin S3 ni `PutParameter` (Q27, Q59).
- CodeBuild cloud (`modules/pipeline`): `PutParameter` sobre la ruta para la siembra (Q26).
  Sin acceso a S3 ni al keystore (Q59).
- CodeBuild Flutter (`codepipeline.yml.scriban`): política `SecureParameterAccess` y
  `KeystoreBucketAccess` (`s3:GetObject`, `s3:PutObject` sobre el prefijo del keystore).
  La registra developer-scriban (Q29, Q67).

## Bucket por entorno

- Nombre: `${var.project_name}-keystore-${var.environment}` (Q56, Q68).
- Objeto: `keystore/{{APPLICATION_ID}}/keystore.jks`, un objeto por app.
- Terraform crea el bucket vacío. La subida la hace solo `up.ps1 -Sign` (Q57, Q59).
- Tester verifica la coherencia del nombre en 5 ubicaciones (`tester.md`, punto 5).

## Orden de purga y destroy (D41, D42)

- Orden efectivo, de architect (`architect.md`):
  1. Purga CLI de versiones y objeto (requisito AWS: bucket vacío).
  2. `terraform destroy` del bucket.
  3. CLI final idempotente de restos.
- Implementado en `down.ps1.scriban` por developer-powershell (`developer-powershell.md`).
- Tester: orden verificado en `down.ps1` generado (TC-17). Ejecución real pendiente.

## Verificación (tester, `tester.md`)

- `terraform validate` OK en:
  - `cloud/terraform/app`.
  - `cloud/terraform/quizapi`.
  - `cloud/terraform/modules/pipeline`.
  - `cloud/terraform/modules/secure-parameters`.
- Ejecutado con `init -backend=false`, `validate` y `fmt -check`. Sin `plan`, `apply` ni `destroy`.
- `terraform fmt -check` marca 5 ficheros no tocados por obj-005 (preexistente):
  - `quizapi\apigateway.tf`, `apigateway_lambda.tf`, `cognito.tf`, `cognito_client.tf`,
    `cognito_iam.tf`.
- Ningún `.tf` de obj-005 aparece en la lista de `fmt`.

## Pendientes

- Verificación AWS (integrator): `terraform plan` primero; sin `apply` sin autorización.
- TC-05: bucket en AWS con versionado, SSE-S3 y bloqueo público.
- TC-10 y TC-11: confirmar en el despliegue real.
- Q98: el CLI final de `down.ps1` debe ser idempotente tras el destroy; falta ejecutarlo.
- Validar que `terraform state` queda limpio tras `down.ps1` (riesgo 3.6 del checklist).
- Fuera de Terraform: `fmt` preexistente en 5 ficheros de `quizapi` (no es alcance de obj-005).

## Bloqueos

- Ninguno para documentación.
- Implementación bloqueada por Q103 (autorización por escrito pendiente en `questions.md`).
- Sin acceso AWS en este informe; la verificación real queda para integrator.
