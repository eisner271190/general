# Parámetros → AWS Parameter Store

**Convención de rutas (se mantiene):** `/develop/com.quizsmart.app/quizapi/<NOMBRE>` (`ssm.tf`).
**Origen:** `D` = Desde Target · `C` = Depende de Cloud · `S` = Secret · `X` = No se crea

Fuente de los valores: `generator/target/com.quizsmart.app/com.quizsmart.app.json` (25 `environments[].variables`) + `D:\codigo\app\app\quiz_generator\assets\.env.dev`.

## 1. Desde Target (29)

| Parámetro | Nuevo nombre (SSM) | Archivos referenciados | Origen | Estado |
|---|---|---|---|---|
| APPLICATION_NAME | `…/quizapi/APPLICATION_NAME` | `terraform-tfvars.scriban`, `terraform-ssm.scriban`, `terraform-lambda.scriban:54` | D · `applicationName` | ✅ |
| APPLICATION_ID | `…/quizapi/APPLICATION_ID` | tfvars, `component.json` (backend+frontend), `buildspec.yml:5`, `codepipeline.yml:7` | D · `applicationId` | ✅ |
| APPLICATION_PACKAGE | `…/quizapi/APPLICATION_PACKAGE` | `component.json` backend:10-53, frontend:35,329 | D · derivado (`GenerationPlanBuilder.cs:85`) | ✅ automático |
| ENVIRONMENT | `…/quizapi/ENVIRONMENT` | tfvars, `up.ps1` backend `:38` y cloud `:30` | D · `environments[].name` | ✅ |
| SERVICE_MODE | `…/quizapi/SERVICE_MODE` | `.env.dev:2`, `.env.mock:1`, `service_env.dart.scriban:4` | D · `REAL` | ✅ añadido |
| AI_SERVICE_MODE | `…/quizapi/AI_SERVICE_MODE` | `.env.dev:3`, `.env.mock:2`, `service_env.dart.scriban:5` | D · `REAL` | ✅ añadido |
| AUTH_SERVICE_MODE | `…/quizapi/AUTH_SERVICE_MODE` | `.env.dev:4`, `.env.mock:3`, `service_env.dart.scriban:6` | D · `REAL` | ✅ añadido |
| AD_SERVICE_MODE | `…/quizapi/AD_SERVICE_MODE` | `.env.dev:5`, `.env.mock:4`, `service_env.dart.scriban:7` | D · `REAL` | ✅ añadido |
| SUBSCRIPTION_SERVICE_MODE | `…/quizapi/SUBSCRIPTION_SERVICE_MODE` | `.env.dev:6`, `.env.mock:5`, `service_env.dart.scriban:8` | D · `REAL` | ✅ añadido |
| HEALTH_SERVICE_MODE | `…/quizapi/HEALTH_SERVICE_MODE` | `.env.mock:6`, `service_env.dart.scriban:9` | D · **falta** en `.env.dev` y en target | ⚠️ pendiente |
| PROFILE | `…/quizapi/PROFILE` | `.env.dev:12`, `.env.mock:7`, `app_config.dart.scriban:23` | D · `DEV` | ✅ añadido |
| API_URL (API de IA) | `…/quizapi/API_URL` | `ai_api_client.dart.scriban:26` — **no lo consume el backend** | D · `https://openrouter.ai/api/v1/chat/completions` | ✅ corregido |
| MODEL | `…/quizapi/MODEL` | `.env.dev:11`, `.env.mock:22`, `ai_api_client.dart.scriban:34` | D · `gpt-4o-mini` | ✅ corregido |
| THEME_STYLE | `…/quizapi/THEME_STYLE` | `.env.dev:13`, `.env.mock:9`, `app_config.dart.scriban:38` | D · `CHATGPT` | ✅ |
| PROMPT | `…/quizapi/PROMPT` | `.env.dev:14`, `ai_env.dart.scriban:4,13`, `env_config.dart.scriban:19`, `strategy_factory.dart:40,59` | D · **se usa** | ✅ corregido |
| AWS_REGION | `…/quizapi/AWS_REGION` | `application-properties.scriban:34`, `docker-compose.scriban:94`, `dynamodb/sns/sqs-config` | D · fijo antes de iniciar `us-east-1` | ✅ |
| JWT_EXPIRATION | `…/quizapi/JWT_EXPIRATION` | `application-properties.scriban:29`, `jwt-provider.scriban:20,28` | D · `86400000` | ✅ |
| AUTH_BACKEND_HOST | `…/quizapi/AUTH_BACKEND_HOST` | `.env.dev:17`, `.env.mock:11` | D · `http://localhost:8081` → **post-apply** se sobrescribe con `http_api_url` | ✅ añadido |
| AUTH_TOKEN_EXCHANGE_PATH | `…/quizapi/AUTH_TOKEN_EXCHANGE_PATH` | `.env.dev:18`, `.env.mock:12` | D · `/api/v1/auth/exchange` | ✅ añadido |
| AUTH_LOGOUT_PATH | `…/quizapi/AUTH_LOGOUT_PATH` | `.env.dev:19`, `.env.mock:13` | D · `/auth/logout` | ✅ añadido |
| AUTH_COGNITO_DOMAIN | `…/quizapi/AUTH_COGNITO_DOMAIN` | `.env.dev:20`, `.env.mock:14` | D (valor previo) → **actualizar post-apply** con `user_pool_domain_url` | ✅ añadido |
| AUTH_CLIENT_ID | `…/quizapi/AUTH_CLIENT_ID` | `.env.dev:21`, `.env.mock:15` | D (valor previo) → **actualizar post-apply** con `user_pool_client_id` | ✅ añadido |
| AUTH_REDIRECT_URI | `…/quizapi/AUTH_REDIRECT_URI` | `.env.dev:22`, `.env.mock:16` | D · `myapp://auth/callback` | ✅ añadido |
| AUTH_REDIRECT_URI_WEB | `…/quizapi/AUTH_REDIRECT_URI_WEB` | `.env.dev:23`, `.env.mock:17` | D · `http://localhost:3000/callback` | ✅ añadido |
| AUTH_SCOPES | `…/quizapi/AUTH_SCOPES` | `.env.dev:24`, `.env.mock:18` | D · `openid email profile` | ✅ añadido |
| AUTH_IDENTITY_PROVIDER | `…/quizapi/AUTH_IDENTITY_PROVIDER` | `.env.dev:25`, `.env.mock:19` | D · `Google` | ✅ añadido |
| PRIVACY_URL | `…/quizapi/PRIVACY_URL` | `.env.mock:25` | D | ✅ |
| TERMS_URL | `…/quizapi/TERMS_URL` | `.env.mock:26` | D | ✅ |
| REVENUECAT_PUBLIC_KEY | `…/quizapi/REVENUECAT_PUBLIC_KEY` | `.env.mock:23` | D · **placeholder** | ⚠️ valor real |
| ADMOB_BANNER_ID | `…/quizapi/ADMOB_BANNER_ID` | `.env.mock:24` | D · **placeholder** | ⚠️ valor real |

## 2. Depende de Cloud → `aws ssm put-parameter` post-apply (6)

| Parámetro | Nuevo nombre (SSM) | Archivos referenciados | Valor (`terraform output -raw`) |
|---|---|---|---|
| AWS_SNS_TOPIC_ARN | `…/quizapi/AWS_SNS_TOPIC_ARN` | `application-properties.scriban:36`, `docker-compose.scriban:98`, `sns-event-publisher.scriban:17` | `sns_topic_arn` |
| AWS_SQS_URL_{ms} | `…/quizapi/AWS_SQS_URL_QUIZAPI` | `application-properties.scriban:35` (sólo si `consumedEvents>0`; hoy no se emite) | `sqs_queue_url_quizapi` |
| API_BASE_URL | `…/quizapi/API_BASE_URL` | `.env.dev:6`, `.env.mock:8`, `api_health_repository.dart.scriban:21` | `http_api_url` |
| AUTH_BACKEND_HOST | `…/quizapi/AUTH_BACKEND_HOST` | `.env.dev:17`, `.env.mock:11` | `http_api_url` (sobrescribe el `localhost` de target) |
| AUTH_COGNITO_DOMAIN | `…/quizapi/AUTH_COGNITO_DOMAIN` | `.env.dev:20`, `.env.mock:14` | `user_pool_domain_url` (sobrescribe el valor previo de target) |
| AUTH_CLIENT_ID | `…/quizapi/AUTH_CLIENT_ID` | `.env.dev:21`, `.env.mock:15` | `user_pool_client_id` (sobrescribe el valor previo de target) |

> ✅ Implementado en `cloud/up.ps1.scriban`: `$script:PostApplyParameters` + `Set-ParameterStoreValue` + `Update-PostApplyParameters`, invocado en `Invoke-MicroserviceApplyPhases` junto al log de `environment_parameter_path` (previo a `Update-PostmanBaseUrl`). Salta si no hay `aws` CLI; falla el `up` si `put-parameter` devuelve error.

## 3. Secret (Secrets Manager — T04)

| Parámetro | Nombre | Archivos referenciados | Acción |
|---|---|---|---|
| JWT_SECRET | secreto `develop/com.quizsmart.app` → clave `JWT_SECRET` | `application-properties.scriban:28`, `jwt-provider.scriban:18` | generar `openssl rand -base64 48` |
| API_KEY | secreto → clave `API_KEY` (**OpenRouter**, existe en `.env.dev:9`) | `.env.dev:9`, `ai_api_client.dart.scriban:22`, `strategy_config.dart.scriban:11` | **no va en target** (credencial en git) → T04 |

## 4. No se crean

| Parámetro | Archivos referenciados | Motivo |
|---|---|---|
| AWS_ACCESS_KEY_ID | `application-properties.scriban:42`, `docker-compose.scriban:96` | rol IAM |
| AWS_SECRET_ACCESS_KEY | `application-properties.scriban:43`, `docker-compose.scriban:97` | rol IAM |
| AWS_PROFILE | `application-properties.scriban:35`, `docker-compose.scriban:95` | sólo local, no existe en Lambda |

## 5. Resumen

| Origen | Nº |
|---|---|
| Desde Target | 29 |
| Depende de Cloud | 3 |
| Secret | 2 |
| No se crean | 3 |
| **Total** | **37** |

**Pendientes**
1. `HEALTH_SERVICE_MODE`: está en `.env.mock` y en `service_env.dart` pero **no** en `.env.dev` ni en target → añadir `REAL`.
2. Plantilla `.env.dev.scriban` sólo define 4 modos (`SERVICE_MODE`, `AI_`, `AUTH_`, `HEALTH_`): faltan `AD_SERVICE_MODE` y `SUBSCRIPTION_SERVICE_MODE` → corregir plantilla (fuente de verdad).
3. `REVENUECAT_PUBLIC_KEY` y `ADMOB_BANNER_ID` = placeholder → valor real.
4. `API_KEY` y `JWT_SECRET` → sembrar en Secrets Manager (T04), nunca en target.
5. ~~Los 3 de §2 → bloque post-apply en `cloud/up.ps1`~~ ✅ implementado (§2, 6 parámetros).
6. Prefijo frontend: todo cae en `/quizapi/` (un único `for_each` en `ssm.tf`); ¿separar `/frontend/quizsmart/`?
