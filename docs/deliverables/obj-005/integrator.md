# Integrator OBJ-005 (ejecución AWS)

- Fecha: `2026-10-11`
- Objetivo: re-sembrará en `us-east-1` tras el borrado.
- Estado: **borrado ejecutado**. 70 de 72 recursos eliminados. 2 pendientes por bug del script.
- Cuenta: `577638384397` · Caller: `arn:aws:iam::577638384397:user/eisner.puerta`
- PS 7.6.6 · aws-cli/2.28.6

## 1. Inventario previo (GETAWS)

- Comando:
  `.opencode/scripts/get-services-aws.ps1`
- Log: `scratchpad/getaws-before.log`
- ExitCode: `0`. Sin fallos de AWS CLI.

| Servicio | AWS | Detalle |
|---|---|---|
| ECR repositories | 2 | epc/common-base, quizapi |
| Lambda functions | 1 | quizapi |
| API Gateway (HTTP) | 1 | api-gateway |
| SNS topics | 1 | main-topic |
| SQS queues | 1 | quizapi |
| Cognito user pools | 1 | user-management-user-pool |
| SSM (`/develop/com.quizsmart.app/`) | 37 | `/develop/com.quizsmart.app/quizapi/*` |
| Secrets (`develop/com.quizsmart.app`) | 1 | develop/com.quizsmart.app |
| IAM roles (proyecto) | 2 | CognitoAuthenticatedRole, quizapi |
| IAM policies (proyecto) | 1 | CognitoPolicy |
| DynamoDB tables | 2 | quizapiSubscription, quizapiWebhookEvent |
| CloudWatch log groups | 1 | /aws/lambda/quizapi |
| S3 keystore buckets | 0 | - |

- Estados Terraform locales: `app` 0, `quizapi` 0 (vacíos). Sin desfases estado/AWS.
- CodeArtifact: dominio `epc`, repos `common` y `maven-central`.
  - 4 paquetes `com.epc.common:*` v`1.1.5`: common-bom, common-error, common-log, common-web.
  - Endpoint coincide con Terraform.

## 2. Plan de borrado (DELETEALL `-WhatIf`)

- Comando:
  `.opencode/scripts/delete-all-services-aws.ps1 -WhatIf`
- Log: `scratchpad/deleteall-whatif.log` y log propio del script en `%TEMP%`.
- ExitCode: `0`. No se borró nada.
- Total: **72 recursos**.

### Bloque de la aplicación (24)

- API Gateway `api-gateway`
- Cognito: dominio `user-management-domain` + pool `user-management-user-pool`
- Lambda `quizapi`
- SNS `main-topic`
- SQS `quizapi`
- DynamoDB `quizapiSubscription`, `quizapiWebhookEvent`
- ECR `quizapi`
- Secrets `develop/com.quizsmart.app`
- SSM: 37 parámetros `/develop/com.quizsmart.app/quizapi/*`
- S3 keystore `com.quizsmart.app-keystore-develop`
- CloudWatch `/aws/lambda/quizapi`
- IAM: roles `quizapi`, `CognitoAuthenticatedRole`; policy `CognitoPolicy`

### Bloque de plataforma (24) — `-SkipPlatform` lo evita

- CodePipeline `common`
- CodeBuild `common-build`, `common-publish`, `platform-bump-bom`
- EventBridge `common-release` (target `terraform-Zxd3ZRRXwHhrk8iBLz6KkdnH2v`) + regla
- CodeCommit `common`, `platform`, `com.quizsmart.app`
- CodeArtifact `common`, `maven-central`, dominio `epc`
- ECR `epc/common-base`
- S3 `epc-buildspecs`
- IAM roles `epc-bump-trigger`, `epc-common-pipeline`, `epc-codebuild`,
  `epc-buildspecs-publisher`, `epc-common-reader`, `epc-common-publisher`

## 3. Ejecución del borrado

- Alcance confirmado por el usuario antes de ejecutar: **los 72 recursos**, plataforma incluida.
- Comando:
  `.opencode/scripts/delete-all-services-aws.ps1 -Force`
- Log: `scratchpad/deleteall-force.log` y log propio en
  `%TEMP%\delete-all-services-aws-20261011-231244-712.log`
- ExitCode: `1` (el script sale con 1 si hay algún error).
- Resultado: **Eliminados 70 · Con error 2 · Total 72**
- IAM: 1 detach (`CognitoAuthenticatedRole <- CognitoPolicy`) y 7 inline borradas, todas `ok`.

### Los 2 errores (bug del script, no de AWS)

- `EventBridge common-release -> target terraform-Zxd3ZRRXwHhrk8iBLz6KkdnH2v`
- `EventBridge common-release`
- Error del primero (código de salida `252`):
  `aws.exe: error: the following arguments are required: --ids`
- Error del segundo:
  `ValidationException: Rule can't be deleted since it has targets.`
- Causa raíz: `delete-all-services-aws.ps1:345` construye
  `aws events remove-targets --rule <rule> --targets Id=<id>`.
  El AWS CLI exige `--ids`, no `--targets`. El flag correcto es `--ids`.
- Consecuencia en cascada: sin quitar el target, `delete-rule` falla.
- Reproducido a mano (solo lectura/diagnóstico), comando exacto:
  `aws events remove-targets --rule common-release --targets Id=terraform-Zxd3ZRRXwHhrk8iBLz6KkdnH2v`
  → `error: the following arguments are required: --ids` (exit `252`).
- No se corrigió ni se editó el script (regla del encargo). Queda pendiente de decisión.
- El target apunta al rol `epc-bump-trigger`, que **sí** se borró: la regla quedó apuntando
  a un rol inexistente.

## 3-bis. Alcance del encargo vs. script (desviación detectada antes de ejecutar)

- El encargo decía "borrado total ... en el entorno `develop` del proyecto".
- El script **por defecto no se limita a `develop`**: borra además toda la plataforma
  `library/platform`, el dominio CodeArtifact y los buckets de keystore de **todos** los
  entornos (Q91). Parámetro documentado que lo acota: `-SkipPlatform`.
- Se avisó al usuario y se confirmó explícitamente el alcance de 72 recursos.
- Aviso del propio script, ahora materializado: borrar CodeArtifact destruyó los artefactos
  Maven publicados (`com.epc.common:*` 1.1.5). Se republican con
  `library/platform/scripts/publish-common.ps1`.

## 4. Hallazgos que registrar

- **Q49 desactualizada**: `questions.md:178` afirma que el usuario ya borró los secretos, pero
  el inventario encontraba 1 vivo: `develop/com.quizsmart.app`. DELETEALL lo borró.
- **Bucket de keystore**: GETAWS reportaba `S3 keystore buckets = 0` (no existía), pero
  DELETEALL lo detectó por regex sobre los nombres SSM, no por existencia. Resultado:
  `ya no existia`. No había keystore que perder.
- **Q83/Q86**: sin copia externa del keystore. Sin impacto: nunca se subió (Q57 pendiente).
- **Cobertura incompleta del script**: 2 buckets `*-aab-artifacts` y la regla
  `probe-codecommit` quedan fuera de DELETEALL. Decisión del usuario: documentar, no borrar.
- **CodeArtifact destruido**: los 4 paquetes `com.epc.common:*` 1.1.5 ya no están. Hay que
  republicarlos con `library/platform/scripts/publish-common.ps1` antes de que el backend
  resuelva dependencias.
- **Autorización Q48**: `checklist.md:259` sigue `[ ]`. Este encargo cubre el borrado, no la
  implementación de obj-005.

## 5. Qué queda por re-sembrar con `up.ps1`

Tras el borrado (si se ejecuta) queda todo por recrear:

- **Secretos SSM**: los 37 parámetros `/develop/com.quizsmart.app/quizapi/*`, incluido
  `/develop/com.quizsmart.app/quizapi/secrets` (SecureString nuevo de obj-005, Q10).
  `up.ps1` siembra solo si falta o si el valor es `placeholder` (Q77).
- **Keystore S3**: bucket `com.quizsmart.app-keystore-develop` y el objeto
  `keystore/{{APPLICATION_ID}}/keystore.jks`. Lo crea Terraform; lo sube `flutter/up.ps1 -Sign`
  (Q57, Q59, Q97). Genera uno nuevo si falta; no hay copia (Q63, Q88).
- **Imágenes ECR**: `quizapi` y `epc/common-base`. Se reconstruyen con el pipeline.
- **CodeArtifact**: si se borra la plataforma, republicar `com.epc.common:*` 1.1.5 con
  `library/platform/scripts/publish-common.ps1` antes de que el backend resuelva dependencias.
- **Resto**: Lambda, API Gateway, Cognito (pool + dominio), SNS, SQS, DynamoDB, IAM y el
  pipeline `common`. Los crea `projects/com.quizsmart.app/up.ps1` y los de `library/platform`.
- **Estados Terraform**: no se tocan. El siguiente `plan`/`up.ps1` los refresca y sincroniza.

## 6. Verificación posterior (GETAWS)

- Comando: `.opencode/scripts/get-services-aws.ps1`
- Log: `scratchpad/getaws-after.log`
- ExitCode: `254` (no es un fallo real: `codeartifact list-packages` falla porque el dominio
  ya no existe; el script lo emite como advertencia).
- Advertencia: `AWS CLI fallo en: codeartifact list-packages` → esperado tras borrar el dominio.

| Servicio | Antes | Después |
|---|---|---|
| ECR repositories | 2 | 0 |
| Lambda functions | 1 | 0 |
| API Gateway (HTTP) | 1 | 0 |
| SNS topics | 1 | 0 |
| SQS queues | 1 | 0 |
| Cognito user pools | 1 | 0 |
| SSM (`/develop/com.quizsmart.app/`) | 37 | 0 |
| Secrets (`develop/com.quizsmart.app`) | 1 | 0 |
| IAM roles (proyecto) | 2 | 0 |
| IAM policies (proyecto) | 1 | 0 |
| DynamoDB tables | 2 | 0 |
| CloudWatch log groups | 1 | 0 |
| S3 keystore buckets | 0 | 0 |

- CodeArtifact: dominio `epc` sin repositorios; endpoint AWS `-` (Terraform aún lo declara:
  desfase esperado hasta el próximo `plan`).
- Estados Terraform locales: `app` 0, `quizapi` 0. Sin desfases estado/AWS.

### Comprobación de restos fuera del inventario de GETAWS

- EventBridge: quedan `common-release` (ENABLED) y `probe-codecommit` (ENABLED).
  - `common-release`: el fallo del script. `probe-codecommit` es preexistente y **no** está
    en el alcance de DELETEALL.
- CodePipeline: 0. CodeBuild: 0. CodeCommit: 0. CodeArtifact: 0 dominios.
- S3: quedan 4 buckets, **ninguno** en el alcance del script:
  `app-20250717231135`, `com-quizsmart-app-aab-artifacts`,
  `com.quizsmart.app-aab-artifacts`, `quiz-epc-politica-privacidad`.
  - Los dos `*-aab-artifacts` son de la app Flutter. DELETEALL no tiene objetivo para ellos:
    si el borrado debía incluirlos, falta cobertura en el script.

## 7. Revisión: por qué no borra todo en una sola pasada

Pedido por el usuario tras el fallo. Hallazgos en `delete-all-services-aws.ps1`:

1. **Bloqueante — `--targets` en vez de `--ids`** (línea 345).
   `aws events remove-targets` exige `--ids`. Provoca el fallo y el de `delete-rule` en
   cascada. Deja 2 recursos sin borrar. Es el único fallo real de esta ejecución.
2. **Los buckets del keystore se deducen del SSM** (líneas 285-292).
   Se listan los entornos por regex sobre `^/(?<environment>[^/]+)/<ApplicationId>/` en los
   nombres de parámetro. Si un entorno no tiene parámetros SSM, su bucket no se detecta.
   Al borrarse el SSM en esta misma pasada, **una segunda pasada ya no los detectaría**.
   El borrado de todos los entornos no está garantizado en una sola pasada.
3. **Sin objetivo para los buckets de artefactos Flutter** (`*-aab-artifacts`).
   El script no los menciona; quedan en la cuenta. Decisión del usuario: dejarlos y
   documentarlos.
4. **Solo borra la regla `$ReleaseRule`** (línea 347). Reglas EventBridge ajenas quedan:
   ahora `probe-codecommit` (preexistente, fuera de alcance).
5. **IAM sin instance profiles** (líneas 410-424): desengancha políticas gestionadas e
   inline, pero no elimina instance profiles. En esta cuenta no quedó ninguno, así que
   no hubo impacto; sigue siendo un hueco si Terraform los crea en otro entorno.
6. **Idempotencia**: correcta en lo demás. Los recursos ausentes se clasifican
   `ya no existia` (`Test-IsMissingError`, línea 131), sin abortar. Por eso el bucket del
   keystore, que no existía, no rompió la pasada.

- Nada de lo anterior se corrigió: el encargo prohíbe editar el script.
- Los puntos 1, 2 y 5 son cambios de código; requieren objetivo y autorización aparte.

## 8. Comandos ejecutados

- `.opencode/scripts/get-services-aws.ps1` → exit `0` (solo lectura, antes)
- `.opencode/scripts/delete-all-services-aws.ps1 -WhatIf` → exit `0` (sin borrado)
- `.opencode/scripts/delete-all-services-aws.ps1 -Force` → exit `1` (70/72 eliminados)
- `.opencode/scripts/get-services-aws.ps1` → exit `254` (verificación, dominio ya borrado)
- Consultas de diagnóstico: `aws events describe-rule`, `aws events list-targets-by-rule`,
  `aws events list-rules`, `aws codepipeline list-pipelines`, `aws codebuild list-projects`,
  `aws codecommit list-repositories`, `aws codeartifact list-domains`, `aws s3api list-buckets`
- Reproducción del fallo: `aws events remove-targets --rule common-release --targets Id=...`
  (solo diagnóstico; exit `252`, nada borrado)