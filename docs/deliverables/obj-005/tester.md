# OBJ-005 · tester

- Fecha: `2026-10-11` · Ejecución: `2026-10-11 04:07-04:11` (UTC-5).
- Alcance: verificación no destructiva. Sin tocar producto, tests ni `/projects`.
- Sin `terraform apply` ni `destroy`. Sin commit ni push.
- Generación real ejecutada en sandbox fuera de `/projects` (ver punto 7).

## 1. Grep de restos de Secrets Manager

Comando:

```
rg -i "secretsmanager|secrets-manager|aws_secretsmanager_secret|get-secret-value|
put-secret-value|describe-secret|delete-secret|restore-secret|keystore-base64" generator/
```

- Resultado: `No matches found`. 0 coincidencias en `generator/` (todo el árbol).

```
rg -i "secretsmanager|Secrets Manager" generator/
```

- Resultado: `No matches found`. 0 en plantillas y manifiestos.

Sobre `.opencode/scripts/` (excepción Q84):

```
rg -i "secretsmanager|secrets-manager|aws_secretsmanager_secret|delete-secret|keystore-base64"
  .opencode/scripts/
```

- 4 coincidencias, todas en código de inventario/borrado previo, no en el alcance obj-005:
  - `get-services-aws.ps1:105` → `Secrets = @('secretsmanager','list-secrets')`.
  - `get-services-aws.ps1:242` → `'aws_secretsmanager_secret' = $secretNames.Count`.
  - `delete-all-services-aws.ps1:166` → `Secrets = @('secretsmanager','list-secrets')`.
  - `delete-all-services-aws.ps1:271` → `Add-Target ... @('secretsmanager','delete-secret',...)`.
- Lectura: son leftovers del inventario genérico de servicios; los objetivos de obj-005 en
  esos scripts (bucket del keystore) sí están implementados. Ver Q99.

## 2. JSON de las plantillas generadas

- Los 3 `component.json` (backend, cloud/aws, frontend) parsean OK con `ConvertFrom-Json`.
- Las 5 plantillas `*.json.scriban` del frontend parsean OK tras sustituir los placeholders.
- `postman-collection.scriban`: el placeholder de llaves sigue correcto.
  - Línea 1: `{{ open_b = "{" + "{" }}{{ close_b = "}" + "}" }}`.
  - Todas las llaves literales del JSON usan `{{ open_b }}` / `{{ close_b }}`.
    Coincidencias en líneas 42, 43, 74, 75, 114, 115, 154, 155, 188, 192, 193, 227, 231, 232,
    261, 265, 266, 283, 307, 311, 312, 352, 361, 362, 404, 408, 409, 444, 446, 474, 483,
    484, 516, 520, 521, 549, 554, 558, 559, 587, 592, 596, 597, 633, 634, 662, 666, 667,
    695, 699, 700, 728, 732, 733, 766, 776, 804, 813, 842, 847, 851, 885, 889, 890, 918,
    922, 923, 951, 956, 957, 989, 994, 1022, 1027, 1031, 1032, 1060, 1069, 1087, 1106,
    1107, 1138, 1139, 1175, 1176, 1219, 1220.
  - Control de flujo Scriban balanceado: `{{ if }}` en 211, 283, 1087; `{{ end }}` en 283,
    1087, 1253.
  - Simulación de render (`open_b`→`{`, `close_b`→`}`, resto→vacío) → `ConvertFrom-Json` OK.
- En la salida generada (punto 7) el JSON final parsea OK y su descripción cita la ruta
  `develop/com.quizsmart.app/secrets` (Q41 correcto).

## 3. Sintaxis PowerShell

Parser: `System.Management.Automation.Language.Parser` (solo parseo, sin ejecutar).
`PSScriptAnalyzer` no está instalado en esta máquina.

Plantillas (placeholders `{{ ... }}` sustituidos por `X` antes de parsear):

- OK `generator/components/cloud/aws/templates/up.ps1.scriban`
- OK `generator/components/cloud/aws/templates/down.ps1.scriban`
- OK `generator/components/frontend/flutter3.47.2/templates/up.ps1.scriban`
- OK `generator/components/frontend/flutter3.47.2/templates/down.ps1.scriban`

Scripts del workspace (parseo directo del fichero):

- OK `.opencode/scripts/delete-all-services-aws.ps1` → 0 errores
- OK `.opencode/scripts/get-services-aws.ps1` → 0 errores

Salida generada en sandbox (parseo directo, ya sin placeholders):

- OK `cloud/up.ps1`
- OK `cloud/down.ps1`
- OK `frontend/quizsmart/up.ps1`
- OK `frontend/quizsmart/down.ps1`
- OK `up.ps1` (raíz) y OK `down.ps1` (raíz)

## 4. Placeholders `{{ ... }}` sin resolver

Sobre las plantillas tocadas:

- 0 unresolved en los `.scriban` de PowerShell: el generador los sustituye en el render.
- `postman-collection.scriban`: los `{{ Name }}`, `{{ ENVIRONMENT }}`, `{{ APPLICATION_ID }}`
  se resuelven; sobreviven solo `{{baseUrl}}`, `{{token}}`, `{{username}}`, que son variables
  de Postman por diseño, no placeholders Scriban.

Sobre la salida generada (sandbox):

- `backend/quizapi/postman/quizapi.postman_collection.json`: 19 coincidencias, todas
  `{{baseUrl}}`, `{{token}}`, `{{username}}` → variables de Postman. Correcto.
- `generation-plan.json`: 1 coincidencia, es el valor embebido del mismo JSON de Postman.
- 0 coincidencias en el resto de los 477 ficheros generados.

## 5. Coherencia del nombre del bucket

Definición en Terraform (`terraform-keystore-bucket.scriban:7`):

```
bucket = "{{ APPLICATION_ID }}-keystore-${var.environment}"
```

Con `project_name = "{{ APPLICATION_ID }}"` (`terraform-secrets.scriban:9`), equivale a
`${var.project_name}-keystore-${var.environment}` que exige el criterio de aceptación.

Consumidores:

- `cloud/terraform/app/keystore_bucket.tf` (generado): `com.quizsmart.app-keystore-${var.environment}`
- `cloud/up.ps1` y `cloud/down.ps1` (generados): `com.quizsmart.app-keystore-$Environment`
- `frontend/quizsmart/up.ps1` (generado): `com.quizsmart.app-keystore-$Environment`
- `frontend/quizsmart/codepipeline.yml:73`: `${ApplicationId}-keystore-${Environment}`
- `frontend/quizsmart/README.md:43,81`: `{applicationId}-keystore-{environment}`

Veredicto: coherente en las 5 ubicaciones. La varianza `${var.environment}` vs
`{environment}` es solo la forma de interpolación de cada lenguaje, no el valor.

Prefijo del objeto, también coherente:

- Terraform (comentario): `keystore/{{ APPLICATION_ID }}/keystore.jks`
- `up.ps1` Flutter: `keystore/com.quizsmart.app/keystore.jks`
- IAM CodeBuild Flutter: `.../keystore/com.quizsmart.app/*`

## 6. `use-cases.md`: verificabilidad por lectura

- Los 23 casos (TC-01..TC-23) son verificables por lectura o por comando local no destructivo.
- Ninguno exige crear ni modificar tests.
- Marcados como validados en `checklist.md` (sección 6): TC-01, TC-02, TC-08, TC-09, TC-10,
  TC-11, TC-12, TC-13, TC-14, TC-15, TC-17, TC-18, TC-19, TC-20, TC-22.
- No verificables aquí (requieren AWS o una decisión del usuario): TC-03, TC-04, TC-05,
  TC-06, TC-07, TC-16, TC-21, TC-23.

### Desviaciones encontradas

- TC-02: el esqueleto medido da 113 bytes sin valores y 294 bytes con los valores por defecto
  de `up.ps1`, no los 210 bytes de referencia de Q62/Q76. Los tres están muy por debajo de
  4 KB, así que la conclusión no cambia, pero la cifra de referencia no se reproduce. Ver Q100.
- TC-09: `pom.xml` generado conserva `spring-cloud-aws-starter-parameter-store` y ya no trae
  el starter de Secrets Manager. Correcto.
- TC-10: `main.tf` generado tiene `aws_ssm_parameter.app_secret`, `type = "SecureString"`,
  `value = "placeholder"` y `lifecycle { ignore_changes = [value] }`. Correcto.
- TC-11: 0 referencias a `modules/secrets-manager`; `source = "../modules/secure-parameters"`
  y existe el directorio. Correcto.
- TC-12/13/14: IAM generado sin `ssm:PutParameter` en Lambda, sin permisos S3 en Lambda ni en
  CodeBuild cloud, y `KeystoreBucketAccess` acotado al prefijo en Flutter. Correcto.
- TC-15: 0 coincidencias en `generator/`. Los 4 restos de `.opencode/scripts` (punto 1) no
  violan este TC, que habla de plantillas del generador.
- TC-17: el orden en `down.ps1.scriban` es `delete-parameter` (línea 337) → purga del bucket
  (341) → `terraform destroy` (348) → CLI final idempotente (353). Coincide con Q90/D41/D42.
  La ejecución real queda para integrator.
- TC-22: `library/platform/terraform/pipeline/main.tf:30` y
  `library/platform/buildspecs/java-ci.yml:7` son ambos comentarios, no código. Verificado.

## 7. Generación real con el generador

Autorizado como validación local. Ejecutado sin tocar `/projects`:

- `dotnet build Generator.csproj` → `Compilación correcta. 0 Error(es)`.
- Copia del árbol `generator/` (sin `bin`, `obj`, `.vs`) y de `target/` a
  `C:\Users\EISNE\AppData\Local\Temp\opencode\obj005-workspace\generator`.
- `dotnet run --project Generator.csproj` → `Resumen: OK=1, Duracion=3,5s`.
  `OutputPath: ...\obj005-workspace\projects\com.quizsmart.app` (fuera de `/projects`).

Revisión de la salida generada:

- 0 coincidencias de `secretsmanager|secrets-manager|Secrets Manager|keystore-base64|
  aws_secretsmanager_secret|get-secret-value|describe-secret|restore-secret`.
- `cloud/terraform/modules/secure-parameters/main.tf` y `variables.tf` generados.
- `cloud/terraform/app/secrets.tf` con `source = "../modules/secure-parameters"`.
- `cloud/terraform/app/keystore_bucket.tf` con los 4 recursos (bucket, versionado, SSE-S3,
  bloqueo de acceso público).
- `application-cloud-properties.yaml` generado:
  `spring.config.import=aws-parameterstore:/develop/com.quizsmart.app/quizapi/,aws-parameterstore:/develop/com.quizsmart.app/secrets`.
- `lambda.tf` con `ssm:GetParameter`, `ssm:GetParametersByPath` sobre
  `arn:aws:ssm:*:*:parameter/develop/com.quizsmart.app/*` y `kms:Decrypt` sobre
  `arn:aws:kms:us-east-1:*:alias/aws/ssm`. Sin `PutParameter`, sin S3.
- `modules/pipeline/main.tf` con `ssm:GetParameter|PutParameter|GetParametersByPath` y
  `kms:Decrypt` sobre `alias/aws/ssm`. Sin S3 al keystore.
- `codepipeline.yml` con `SecureParameterAccess` y `KeystoreBucketAccess`; sin
  `SecretsManagerAccess`.
- `README.md` Flutter: caché local eliminada, SHA-256 y bucket documentados.

Terraform sobre la salida generada (solo `init -backend=false`, `validate`, `fmt -check`;
nunca `plan`/`apply`/`destroy`):

- `cloud/terraform/app` → `terraform validate`: `Success! The configuration is valid.`
- `cloud/terraform/quizapi` → `Success!`
- `cloud/terraform/modules/pipeline` → `Success!`
- `cloud/terraform/modules/secure-parameters` → `Success!`
- `terraform fmt -recursive -check` (desde `cloud/terraform`): exit 3, marca 5 ficheros
  **no tocados por obj-005**: `quizapi\apigateway.tf`, `apigateway_lambda.tf`, `cognito.tf`,
  `cognito_client.tf`, `cognito_iam.tf`. Ningún `.tf` de obj-005 (keystore bucket,
  secrets, secure-parameters, lambda, pipeline) aparece en la lista. Preexistente.

## 8. Qué queda pendiente de AWS (para integrator)

- TC-03: `up.ps1 -Sign` sube el `.jks` a `keystore/{appId}/keystore.jks` con metadato `sha256`.
- TC-04: con el objeto ya existente, 0 escrituras (no sobrescribe).
- TC-05: bucket en AWS con versionado, SSE-S3 y bloqueo total de acceso público.
- TC-06: el pipeline descarga y verifica el SHA-256 antes de firmar.
- TC-07: siembra solo si el parámetro falta o sigue en `placeholder` (Q77).
- TC-16: crear `docs/adr/0027-*.md`, marcar 0010 como sustituida, corregir 0022 (hoy sigue
  diciendo `ADR-0023` en la línea 70) y 0012. Es trabajo de redacción, no de AWS.
- TC-21: confirmar que la app no está publicada antes de subir a Play.
- Q98: el CLI final de restos de `cloud/down.ps1` tras el destroy; idempotencia con
  `NoSuchBucket` ya está en el código, falta ejecutarlo.
- Validar que `terraform state` queda limpio tras `down.ps1` (riesgo 3.6 del checklist).

## 9. Puntos que pasan a integrator

- Despliegue del módulo `secure-parameters` y del bucket del keystore.
- `terraform plan` primero (nunca `apply` sin autorización).
- Siembra del parámetro con `cloud/up.ps1`.
- Firma con `frontend/quizsmart/up.ps1 -Sign`.
- Retirada con `cloud/down.ps1` y comprobación del estado.

## 10. Dudas nuevas

- Q99: los 4 restos de Secrets Manager en `.opencode/scripts` (punto 1).
- Q100: la referencia de 210 bytes del esqueleto no se reproduce (113/294 bytes medidos).

## 11. Reproducibilidad

- Sandbox: `C:\Users\EISNE\AppData\Local\Temp\opencode\obj005-workspace`.
- Es desechable: se puede borrar entero sin afectar al repositorio.
- Nada del sandbox se ha copiado a `C:\epc\general\projects`.
- `git status` tras la verificación: sin cambios nuevos por parte de tester.