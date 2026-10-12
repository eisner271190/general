# OBJ-005 · developer-scriban

- Fecha: `2026-10-11` · Fase: plantillas Scriban del generador.
- Autorización: Q48 concedida por el coordinador para esta fase.
- Alcance: solo `generator/`. Sin commit ni push. Sin tocar `/projects`.

## Ficheros modificados

### Backend Spring (`components/backend/spring-boot-3.5.16/templates/`)
- `application-cloud-properties.scriban`: fuera `aws-secretsmanager:`; importa el SecureString
  como `aws-parameterstore:/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/secrets` (Q16).
- `pom.scriban`: fuera `spring-cloud-aws-starter-secrets-manager`; se mantiene
  `spring-cloud-aws-starter-parameter-store` (Q37).
- `ai-properties.scriban:20` y `openrouter-adapter.scriban:31`: el comentario dice Parameter Store
  (SecureString) en lugar de Secrets Manager (Q40).
- `parameter-properties.scriban:19` y `:95-97`: comentarios actualizados; la heurística del prefijo
  `/` documenta ahora la ruta `/env/app/secrets` (Q40).
- `postman-collection.scriban:4`: la clave `ai-api-key` se siembra en el SecureString
  `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/secrets` (Q41). Línea 1223 sin mención de Secrets Manager:
  no se toca.
- `application-context-test.scriban:74-76`: excepción autorizada (Q72, Q38); el filtro pasa a
  `aws-parameterstore:` + `name.contains("/secrets")` + `type.contains("ParameterStore")`. Se elimina
  `aws-secretsmanager:` y `type.contains("SecretsManager")`. Ningún otro cambio en el fichero.

### Cloud AWS (`components/cloud/aws/`)
- `templates/terraform-secrets-manager.scriban` → `templates/terraform-ssm-parameter.scriban`
  (renombrado): recurso `aws_ssm_parameter.app_secret`, `type = "SecureString"`,
  nombre `/${var.environment}/${var.project_name}/secrets`, `value = "placeholder"` y
  `lifecycle { ignore_changes = [value] }` (Q17, Q18/Q69, Q24). Se conserva el nombre del recurso.
- `templates/terraform-secrets-manager-variables.scriban` →
  `templates/terraform-ssm-parameter-variables.scriban` (renombrado): quedan `environment` y
  `project_name`; se elimina `kms_key_arn` (Q21, Q24).
- `templates/terraform-secrets.scriban`: `source = "../modules/secure-parameters"` y fuera el
  argumento `kms_key_arn` con su comentario (Q20, Q24).
- `templates/terraform-keystore-bucket.scriban` (nuevo): bucket `{{ APPLICATION_ID }}-keystore-
  ${var.environment}` con versionado, SSE-S3 (`AES256`) y bloqueo total de acceso público
  (Q56, Q58, Q60, Q73). Se registra como `cloud/terraform/app/keystore_bucket.tf`.
- `templates/terraform-lambda.scriban`: la regla de Secrets Manager se sustituye por
  `ssm:GetParameter` + `ssm:GetParametersByPath` sobre
  `arn:aws:ssm:*:*:parameter/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/*` y `kms:Decrypt` sobre
  `arn:aws:kms:{{ CLOUD_REGION }}:*:alias/aws/ssm`. Sin `PutParameter` y sin permisos S3
  (Q25, Q27, Q28, Q66).
- `templates/terraform-pipeline.scriban:201`: la regla `secretsmanager:GetSecretValue` con
  `resources = ["*"]` se sustituye por `ssm:GetParameter`, `ssm:PutParameter` y
  `ssm:GetParametersByPath` sobre la ruta del parámetro, más `kms:Decrypt` sobre `alias/aws/ssm`.
  Sin S3 (Q26, Q59).
- `component.json`: directorios y ficheros del módulo `secrets-manager` → `secure-parameters`
  (Q20, Q22); registro de las dos plantillas renombradas y de la nueva del bucket.
- `AGENTS.md:4`: módulos `{secrets-manager,pipeline}` → `{secure-parameters,pipeline}` (Q20).

### Flutter (`components/frontend/flutter3.47.2/templates/`)
- `codepipeline.yml.scriban:53-73`: `SecretsManagerAccess` → dos políticas nuevas:
  `SecureParameterAccess` (`ssm:GetParameter`, `ssm:PutParameter`, `kms:Decrypt` sobre la ruta y
  `alias/aws/ssm`) y `KeystoreBucketAccess` (`s3:GetObject`, `s3:PutObject` sobre
  `{applicationId}-keystore-{environment}/keystore/{applicationId}/*`) (Q29, Q59, Q67).
- `README.md.scriban:19-90`: sección de firma reescrita (SecureString, keystore en S3, objeto vacío
  creado por Terraform, SHA-256 en metadatos, sin caché local) y bloque de permisos IAM actualizado
  (Q36, Q41, Q59, Q75, Q80).

## Verificaciones
- `component.json` sigue siendo JSON válido y sus 30 plantillas existen en disco.
- Sin coincidencias de `secretsmanager`, `Secrets Manager` ni `secrets-manager` en los templates de
  backend. Restan en `up.ps1.scriban` y `down.ps1.scriban`, que pertenecen a developer-powershell.
- `application-context-test.scriban`: el diff se limita al filtro (Q72).

## Fuera de esta fase (developer-powershell)
- `cloud/aws/templates/up.ps1.scriban:321-404` y `down.ps1.scriban:176-227` (Q30, Q31, Q32, Q77, Q89).
- `flutter/templates/up.ps1.scriban` completo: `get-parameter`, keystore en S3, SHA-256, sin caché
  (Q33, Q34, Q35, Q57, Q59, Q75, Q80, Q88).
- Documentación (`library/platform`, ADR, `docs/adr/`) y `.opencode/scripts/*` (Q3, Q4, Q84, Q92).

## Dudas
- Ninguna bloqueante. Las dudas abiertas de esta fase están en `questions.md` (D44, D45).