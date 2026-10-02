# Implementación — Objetivo 001

## Qué cambió

Se implementó `architecture-001.md` completo: capa IA en el backend (puerto agnóstico + adaptador OpenRouter + `POST /api/v1/ai/generate`), cliente Flutter contra el backend en lugar de OpenRouter directo, API key sembrada en AWS Secret Manager y parámetros públicos del proveedor en SSM Parameter Store. Sin cambios en Terraform (decisión de menor coste de la arquitectura §6).

**Observaciones del `plan-review-001.md` aplicadas** (numeración real del review, con el título de cada una entre paréntesis):

1. **Obs. 1** — `@JsonInclude(JsonInclude.Include.NON_NULL)` en `OpenRouterChatRequest`.
2. **Obs. 2** — `ai.temperature` / `ai.max-tokens` se inyectan como `String` y se parsean en el constructor del adaptador (`parseDecimal`/`parseInteger` devuelven `null` ante valor vacío o inválido) para que la Lambda no falle al arrancar.
3. **Obs. 3** — **Corrección de la premisa de mock/real**: el modo se resuelve desde `ParametersInitializer` (`strategy_factory.dart.scriban:16,24`), no desde `.env.dev` (`flutter_dotenv` solo se carga en un test). Por tanto **el cambio de comportamiento (pasar de mock a real) solo aplica en AWS**; en local `ParametersInitializer` queda vacío → `mode = none` → sigue `MockAIStrategy`. Ver "Comportamiento" más abajo.
4. **Obs. 4** — Paso de despliegue documentado (no ejecutado) en "Cómo verificarlo" y "Pendiente de despliegue".
5. **Obs. 5** — **Se mantiene el diseño de la arquitectura**: `IAiServicePort` + `AiUseCase` se conservan (8 plantillas backend, no 6). No hay razón para reducirlas: el build pasa y ArchUnit no las viola (`domain` no importa `application`/`infrastructure`; `AiUseCase` solo depende de `domain`). Se mantienen por coherencia con el precedente `ISubscriptionServicePort` → `SubscriptionUseCase` y como punto de extensión.
6. **Obs. 6** — **Omitido**: `"ai-api-key"` en `EXCLUDED` de `parameter-properties.scriban` (sería código muerto: solo recorre property sources de Parameter Store, y la clave vive en Secrets Manager).
7. **Obs. 7** — KISS en frontend: el cliente reutiliza el acceso existente a `API_BASE_URL` en lugar de añadir un quinto lookup inline. *Revisado después por el code review (Media 3): esa reutilización se hizo sobre `MonetizationEnv`, semánticamente incorrecto; ahora hay un `ApiEnv.baseUrl` propio reutilizado por los 4 puntos de uso.*
8. **Obs. 8** — **No se añadió CORS** (fuera de alcance). Desajuste preexistente documentado en "Notas".
9. **Obs. 9** — Citas de nombre de plantilla corregidas: `terraform-secrets.scriban` (no `terraform-secrets-manager.scriban`).

## Archivos

**Backend — creados** (`generator/components/backend/spring-boot-3.5.16/templates/`, destino `{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/…`):

- `ai-generation.scriban` — record de dominio `AiGeneration(model, content, providerPayload)`.
- `ia-provider-port.scriban` — `IAProviderPort` con `Mono<AiGeneration> generate(String prompt)`.
- `iai-service-port.scriban` — `IAiServicePort`, puerto de servicio.
- `ai-usecase.scriban` — `@Service AiUseCase` que delega en el puerto.
- `ai-generate-request-dto.scriban` — POJO `prompt` (sin validación: no hay `spring-boot-starter-validation`).
- `openrouter-adapter.scriban` — `WebClient` + parseo defensivo de `choices[0].message.content` + guarda de API key vacía.
- `openrouter-chat-request.scriban` — record JSON de salida con `@JsonInclude(NON_NULL)`.
- `ai-controller.scriban` — `POST /api/v1/ai/generate`, validación de prompt (≤ 8000), `ApiResponse` con `data` tipado `Map`.

**Backend — modificados:**

- `templates/application-properties.scriban` — bloque `ai.*` al final (5 líneas).
- `component.json` — 8 entradas nuevas en `files` (sin `directories`: las carpetas destino ya existen).

**Frontend — creado:**

- `templates/lib/features/quiz/data/backend_ai_api_client.dart.scriban` — `BackendAiApiClient implements IApiClient` contra `POST $API_BASE_URL/api/v1/ai/generate`; devuelve `data` del `ApiResponse` para que `RealAIStrategy` siga leyendo `choices[0].message.content` sin cambios.

**Frontend — modificados:**

- `templates/lib/features/quiz/application/strategy_factory.dart.scriban` — importa el cliente nuevo; condición `mode == real` (sin `apiKey`); texto del log.
- `templates/lib/features/quiz/application/strategy_config.dart.scriban` — sin campo `apiKey` ni import de `ParametersInitializer`.
- `templates/lib/features/quiz/config/ai_env.dart.scriban` — solo `keyPrompt`; `allKeys = [keyPrompt]`.
- `templates/lib/shared/env/env_config.dart.scriban` — eliminados los getters `apiKey`, `apiUrl` y `model` (los usaba solo el cliente eliminado). Se conserva el import de `ai_env.dart` (`keyPrompt`).
- `templates/assets/.env.dev.scriban`, `templates/assets/.env.mock.scriban` — fuera `API_KEY`, `API_URL`, `MODEL`. `API_BASE_URL` se queda.
- `component.json` — 1 alta (`backend_ai_api_client.dart`), 8 bajas.

**Frontend — borrados del disco y del registro** (código muerto + modelos Freezed huérfanos): `ai_api_client.dart.scriban`, `openai_api_client.dart.scriban`, `openai_message.dart.scriban`, `openai_message.freezed.dart.scriban`, `openai_message.g.dart.scriban`, `openai_payload.dart.scriban`, `openai_payload.freezed.dart.scriban`, `openai_payload.g.dart.scriban`. `i_api_client.dart.scriban` se conserva (es el contrato). `pubspec.yaml` no se toca: `freezed` sigue usándose por 9 modelos.

**Cloud — modificado:**

- `generator/components/cloud/aws/templates/up.ps1.scriban` — `New-ApplicationSecretDefault` gana el caso `ai-api-key` → `AI_API_KEY_PLACEHOLDER`; `$seededKeys` incluye `ai-api-key`. Nada más. Ningún `terraform-*.scriban` tocado; `component.json` de cloud sin cambios.

**Entrada del generador — modificado:**

- `generator/target/com.quizsmart.app/com.quizsmart.app.json` — fuera `API_URL`; `MODEL` → `AI_MODEL`; añadidos `AI_API_BASE_URL`, `AI_TEMPERATURE`, `AI_MAX_TOKENS`. Ninguna clave con la API key.

## Cómo verificarlo

**Build (ejecutado):**

```
> dotnet build          # en generator/
  Determinando los proyectos que se van a restaurar...
  Todos los proyectos están actualizados para la restauración.
  Generator -> C:\epc\general\generator\bin\Debug\net9.0\Generator.dll

Compilación correcta.
    0 Advertencia(s)
    0 Errores

Tiempo transcurrido 00:00:04.32
```

No se ejecutó ningún test.

**Criterios de aceptación, sin tests** (comandos PowerShell equivalents a los `rg` de la arquitectura §10):

| # | Criterio | Verificación (resultado ya comprobado) |
|---|---|---|
| 1 | `POST /api/v1/ai/generate` recibe prompt y devuelve la generación | `Select-String templates/ai-controller.scriban -Pattern '/api/v1/ai'` → presente. Contrato contrastado contra `subscription-controller.scriban`. Sin tests. |
| 2 | Agnóstico: existe puerto y adaptador | `Select-String templates/ia-provider-port.scriban -Pattern 'interface IAProviderPort'` → 1; `'implements IAProviderPort'` en `openrouter-adapter.scriban` → 1; `Select-String domain/*.scriban -Pattern 'openrouter'` → 0 (el dominio no conoce el proveedor). ArchUnit lo valida cuando el usuario lance `mvn test`. |
| 3 | La API key está en Secret Manager, no en código ni en el frontend | `Select-String templates/assets/*.scriban -Pattern 'API_KEY'` → 0; `Select-String -Recurse generator -Pattern 'AI_API_KEY_PLACEHOLDER'` → solo `up.ps1.scriban`. En `application-properties.scriban` solo la referencia `${AI_API_KEY:${ai-api-key:}}`, sin valor. |
| 4 | Parámetros públicos en SSM | `Select-String com.quizsmart.app.json -Pattern 'AI_API_BASE_URL\|AI_MODEL\|AI_TEMPERATURE\|AI_MAX_TOKENS'` → 4, cada una mapeada a una propiedad `ai.*`. Terraform las crea desde `environment_variables` sin tocar `.tf`. |
| 5 | El frontend consume el backend, no OpenRouter | `Select-String -Recurse components/frontend -Pattern 'openrouter\|openai' (case-insensitive)` → 0. `strategy_factory.dart.scriban` importa `backend_ai_api_client.dart`. |
| 6 | Sin `openrouter.ai` en el frontend | Covered por el punto 5 → 0. |
| 7 | `.env.*` sin la API key | `Select-String templates/assets/*.scriban -Pattern 'API_KEY\|API_URL\|MODEL'` → 0 (verificado). |
| 8 | Plantillas registradas en `component.json` | Las 8 claves backend y la 1 frontend están en su `component.json` (verificado). Las 8 borradas: 0 coincidencias y `Test-Path` de la plantilla → `False`. Carpetas destino backend presentes en `directories`. |
| 9 | El generador compila | `dotnet build` → salida real arriba, 0 errores. |
| 10 | No se rompen endpoints existentes | `git diff --stat`: solo `application-properties.scriban` (5 líneas añadidas al final), `up.ps1.scriban` (1 caso + 1 clave en un array), `component.json` (+8 backend / +1 −8 frontend) y el `component.json` del target. No se toca `auth`, `subscription`, `parameters`, `dynamodb`, `cognito`, `sns/sqs`. Bonus: el test Postman "Sin secretos" (`/api-key|apikey|secret|password|credential/i`) no se dispara con los 4 parámetros nuevos. |
| Extra | Placeholders Scriban resueltos | Todas las plantillas nuevas/modificadas contienen solo `{{ PACKAGE }}` y `{{ FRONTEND_NAME }}`. |
| Extra | JSON válido | `ConvertFrom-Json` sobre los 4 JSON (2 `component.json` + target + cloud) → todos OK. |
| Extra | PowerShell válido | Diff de `up.ps1.scriban`: 2 cambios lógicos. El `up.ps1` generado no se ejecuta. |

## Desviaciones respecto a la arquitectura

| # | Arquitectura | Implementado | Motivo |
|---|---|---|---|
| 1 | `OpenRouterChatRequest` sin `@JsonInclude` | Con `@JsonInclude(NON_NULL)` | Obs. 1 del reviewer: sin él Jackson manda `{"temperature":null,...}` en vez de omitir. |
| 2 | `@Value(...) Double temperature` / `Integer maxTokens` | `@Value(...) String` + parseo defensivo en el constructor | Obs. 2: si `AI_TEMPERATURE` llega vacío desde SSM, la conversión aborta el arranque de la Lambda. |
| 3 | `parameter-properties.scriban`: añadir `"ai-api-key"` a `EXCLUDED` | **No aplicado** | Obs. 6: código muerto (solo lee property sources de Parameter Store; la clave viene de Secrets Manager). Contradice "cambio mínimo". |
| 4 | `_baseUrl()` con lookup inline de `API_BASE_URL` | `ApiEnv.baseUrl` (`core/config/api_env.dart`) reutilizado por los 4 puntos de uso | Obs. 7 (KISS) pedía reutilizar el acceso existente; la primera versión lo hizo sobre `MonetizationEnv` y el code review (Media 3) lo corrigió por acoplamiento semántico. Sin quinto lookup. |
| 5 | `AiController` → `IAiServicePort` → `AiUseCase` → `IAProviderPort` (8 plantillas) | Igual (8 plantillas) | Obs. 5: se mantiene el diseño; la compilación y ArchUnit no exigen reducirlo. |
| 6 | §5.3 / `question-005`: "en develop antes caía a mock, ahora intenta el endpoint" | ** redactado corregido** | Obs. 3: el modo viene de `ParametersInitializer`, no de `.env.dev`. Ver "Comportamiento". |
| 7 | Tarea 2.6 (opcional): refrescar `postman-collection.scriban:127` | No aplicado | Marcado como cosmético y sin efecto en ningún criterio. No se amplía el alcance. |

## Comportamiento mock/real (corrección de la obs. 3)

- **Local**: `ParametersInitializer` se llena desde `GET /api/v1/parameters`, que a su vez necesita `API_BASE_URL`. Sin backend, queda vacío → `getParameterOrDefault` devuelve `'none'` → `ServiceMode.none` → **sigue cayendo a `MockAIStrategy`** (`strategy_factory.dart.scriban:68-69`). El cambio en la condición `mode == real` **no** altera el comportamiento local.
- **AWS**: los parámetros (`SERVICE_MODE`/`AI_SERVICE_MODE=REAL`) llegan por el backend → `RealAIStrategy` con `BackendAiApiClient`. Con `ai-api-key` sembrada funciona; con el placeholder devuelve 500 y la app lo muestra como error de generación.
- `AI_SERVICE_MODE=MOCK` sigue sin tocar el backend.

## Correcciones tras revisión (`reviews/code-review-2026-10-01-17-06-19.md`)

Ninguno de los hallazgos era bloqueante. Se aplicaron todos los Media salvo el 7 (tests: lo gestiona el usuario) y las cuatro Bajas indicadas. No se aplicaron los Nits.

### Media

| # | `ruta:línea` | Cambio |
|---|---|---|
| 1 | `generator/components/backend/spring-boot-3.5.16/templates/parameter-properties.scriban:28-33` | Añadidos `AI_API_BASE_URL`, `AI_MAX_TOKENS`, `AI_MODEL` y `AI_TEMPERATURE` a `EXCLUDED`, con un comentario que explica el motivo (no son secretos, pero el cliente no los usa y publicarlos revelaría proveedor y modelo en un endpoint público sin auth). Verificado primero el mecanismo: `collectIfParameterStore` (`parameter-properties.scriban:78-90`) recorre `getPropertyNames()` y solo filtra por `EXCLUDED`, así que la exclusión es el único punto de corte. Los 4 parámetros **siguen existiendo en SSM** y el backend los sigue leyendo; solo deja de publicarlos. 0 USD. |
| 2 | `openrouter-adapter.scriban:103-112` (`toGeneration`, nuevo) y `:96` | `content == null`/en blanco ya no produce un 200 con payload ilegible: `toGeneration` lanza `IllegalStateException("El proveedor de IA no devolvio contenido utilizable")`, que `GlobalExceptionHandler` traduce a 500. Ahora `AiGeneration.content` sí tiene consumidor (la propia validación), que era su único propósito. |
| 3 | `templates/lib/core/config/api_env.dart.scriban` (nuevo), `monetization_env.dart.scriban:1-2,41-42`, `features/parameters/data/api_parameters_repository.dart.scriban:5-6,24`, `features/health/data/api_health_repository.dart.scriban:4,21`, `features/quiz/data/backend_ai_api_client.dart.scriban:7,51` | Nuevo `ApiEnv.baseUrl` en `core/config/` como punto único de lectura de `API_BASE_URL`. Los 4 puntos de uso (los 3 previos más el cliente de IA) delegan en él: sigue siendo **una sola clave y un solo lookup**, no un quinto. `MonetizationEnv.apiBaseUrl` se conserva como getter delegante porque `revenuecat_provider.dart.scriban:122,136` lo usa y tocarlo ampliaría el diff. Registrado en `component.json` de Flutter (`lib/core/config/api_env.dart`). |
| 4 | `backend_ai_api_client.dart.scriban:28-32` | `final url = _generateUrl();` se calcula **antes** del `try`: un `API_BASE_URL` no configurada ya no se registra como `'[AI] Unexpected error calling backend AI'`, sino que propaga su propio mensaje. |
| 5 | `openrouter-adapter.scriban:33-34,67-68,127-144` | `parseDecimal`/`parseInteger` reciben la clave y registran `LOG.warn("{} invalido, se omite: {}", key, value)` antes de devolver `null`. Un valor mal puesto en SSM deja traza en CloudWatch en lugar de ignorarse en silencio; el arranque sigue sin romperse (requisito de la obs. 2 del plan-review). |
| 6 | `openrouter-adapter.scriban:41-45,92-93` | `.timeout(Duration.ofSeconds(20), Mono.error(...))` antes del `.map`. Aborta 10 s antes que el cliente Flutter (30 s) y muy por debajo del timeout de la Lambda (60 s), de modo que no se sigue facturando una petición que nadie espera. El mensaje de error es propio ("El proveedor de IA no respondio en 20 s") en vez del `TimeoutException` crudo. Coste AWS: reduce gasto, no lo aumenta. |
| 7 | — | **No aplicado.** Los tests los gestiona el usuario. `parameter-controller-test.scriban:40,52,65,82` sigue afirmando que `model` y `api-url` son públicos; con el hallazgo 1 aplicado, ese test ya no refleja ni la reality ni la configuración. Pendiente del usuario. |
| 8 | `implementation-001.md:9-17` y `:104` | Renumerada la lista de las 9 observaciones del `plan-review-001.md` con sus números reales (antes estaban cruzadas 5↔9 y 7↔8) y cada entrada lleva el título de la observación para que sea trazable. |

### Baja

| # | `ruta:línea` | Cambio |
|---|---|---|
| 9 | `architecture-001.md:411`, `research-001.md:34` | Cita `terraform-secrets-manager.scriban` → `terraform-secrets.scriban:6-13`, con la aclaración de que el nombre real del secreto lo produce `up.ps1.scriban:252`. |
| 10 | `ai-controller.scriban:63-72` | El controlador ya no delega el error al `GlobalExceptionHandler`: añade `onErrorResume` que registra el `ex` completo con `LOG.error` y devuelve `ApiResponse` con `data: null`, `message: "Error generating text"`, `status: 500`. Así un 401/429 de OpenRouter deja de responder `"401 Unauthorized from POST https://openrouter.ai/api/v1/chat/completions"`. **No se modificó `global-exception-handler.scriban`**: cambiarlo afectaría a todos los endpoints del microservicio (fuera de alcance) — es el mismo criterio que el review recomienda. |
| 12 | `parameter-properties.scriban:92-98` | La heurística por prefijo `/` se deja tal cual; se añade un comentario que explica por qué hoy no es un bug (el secreto se llama `<environment>/<applicationId>`, sin `/` inicial, y no es un `ParameterStorePropertySource`) y qué habría que revisar si algún día el secreto empezara por `/`. |
| 13 | `iai-service-port.scriban:10` | Typo `application/application` → `application`. |

### No aplicados (anotados)

| # | Por qué no |
|---|---|
| 11 | `postman-collection.scriban:1193-1253` (nuevo grupo) y `:127` | **Aplicado en una tanda posterior** (ver "Postman" más abajo): grupo "AI" con `Generate` y ejemplos 200/400/500, y ejemplo de `GET /api/v1/parameters` rehecho con los parámetros públicos reales (sin `api-url`/`model`, que ya no existen). Deja de estar pendiente. |
| 14 | `parameter-properties.scriban:20` ("Cualquier parametro nuevo debe agregarse a la lista de exclusion si es sensible") no matiza el caso de Secrets Manager y puede inducir a "arreglarlo" con `ai-api-key`. **Anotado, no aplicado** por decisión del usuario. |
| Nits | `strategy_config.dart.scriban` (factory wrapper), `ai_env.dart.scriban` (`requiredKeys` == `allKeys`), `ai-generation.scriban` (record en dos líneas). Cosméticos, sin efecto funcional. |

### Verificación de esta corrección

- `dotnet build` en `generator/`: **Compilación correcta, 0 advertencias, 0 errores** (salida real al final del documento).
- Sin tests ejecutados.
- `Select-String` sobre el componente frontend: 0 referencias residuales a `ParametersInitializer` en los 3 archivos migrados a `ApiEnv`, y 0 imports de `monetization_env.dart` fuera de sus consumidores reales (`paywall_widget`, `admob_banner_widget`, `revenuecat_provider`, `admob_provider`, `app_bootstrapper`).
- Los 4 JSON siguen siendo válidos; `api_env.dart` registrado en el `component.json` de Flutter y presente en disco.

## Postman — cierre del hallazgo Baja 11

Añadido el grupo **"AI"** a `generator/components/backend/spring-boot-3.5.16/templates/postman-collection.scriban` para poder probar a mano el endpoint del objetivo.

| `ruta:línea` | Cambio |
|---|---|
| `postman-collection.scriban:1193-1253` | Nuevo grupo `"AI"` → item `"Generate"`: `POST /api/v1/ai/generate`, cabecera `Content-Type: application/json`, body raw `{"prompt": "..."}`. **Sin `auth`** (ruta pública, decisión `question-003`). El test de Postman acepta los tres códigos documentados (200/400/500) en vez de exigir 2xx, porque sin la key sembrada el 500 es el estado esperado. |
| `postman-collection.scriban:1226-1236` | Ejemplos de respuesta: `OK` 200 con `data` = cuerpo crudo del proveedor (`choices[0].message.content` con el JSON de preguntas anidado y escapado, `usage`), `Error` 400 con `data:null` y el mensaje literal de la validación manual, y `Error` 500 con `"Error generating text"`. Sigue la convención de la plantilla: comillas escapadas `\"` y `{{ open_b }}`/`{{ close_b }}` en el `raw`/`host` de la URL. |
| `postman-collection.scriban:1217-1221` | La `description` del request documenta los tres resultados esperados, incluido el 500 mientras `ai-api-key` siga siendo `AI_API_KEY_PLACEHOLDER`, y que el detalle del proveedor solo queda en los logs de la Lambda. |
| `postman-collection.scriban:4` | `description` de la colección: `/api/v1/ai/**` añadida a las rutas públicas y nueva sección "IA GENERATIVA" con la nota de que requiere la key sembrada y de que responde 500 con el placeholder. |
| `postman-collection.scriban:127` | **Ejemplo obsoleto corregido**: `\"api-url\":\"https://api.openrouter.ai/...\"` y `\"model\"` (claves que ya no existen) sustituidos por los parámetros públicos reales que quedan tras `EXCLUDED`: `API_BASE_URL`, los `*_SERVICE_MODE`, `PROFILE`, `THEME_STYLE`, `PROMPT`, `REVENUECAT_PUBLIC_KEY`, `SUBSCRIPTION_API_BASE_URL`, `ADMOB_BANNER_ID`, `PRIVACY_URL`, `TERMS_URL`, `AUTH_*` y `JWT_EXPIRATION`. Valores TOMADOS de `generator/target/com.quizsmart.app/com.quizsmart.app.json:24-52` + `up.ps1.scriban:73-80` (`PostApplyParameters`); los de infra y credenciales van enmascarados con `xxx` porque los escribe el `apply`. Los `AI_*` **no** aparecen: están en `EXCLUDED`. |
| `postman-collection.scriban:118` | Descripción del grupo Parameters ajustada: ya no habla de "modelos" y nombra explícitamente los `AI_*` como omitidos. |

**Ubicación**: el grupo va dentro del bloque `{{ if(Name == "quizapi") }}` que abre en la línea 1087 (y cierra en la 1253), tal como se pidió. Nota: las 8 plantillas de IA se generan **sin** condición en todos los microservicios (`question-001`), así que la colección no refleja al 100% qué código existe en un `security` futuro; se acepta porque hoy solo hay `quizapi` y una entrada de más en la colección es inocua, mientras que un endpoint inexistente en otro ms sería engañoso.

**Verificación** (sin tests):

- Se renderizó la plantilla sustituyendo los artefactos Scriban (`open_b`/`close_b`, `if`/`end`, `{{ Name }}`, `{{ ENVIRONMENT }}`, `{{ APPLICATION_ID }}`) y se parseó con `ConvertFrom-Json`: **JSON válido**, grupos = `Hola Mundo, Parameters, Actuator, SNS, SQS, Auth, Users, Registration, Admin Users, Password, Subscriptions, AI`. Repetido con y sin el bloque `quizapi`: válido en ambos casos, así que las comas y llaves no dependen del condicional.
- `dotnet build` en `generator/` → **Compilación correcta, 0 advertencias, 0 errores** (1.54 s).
- `git diff` de `postman-collection.scriban`: 63 inserciones, 3 eliminaciones, todas en los 4 puntos de la tabla.

## Despliegue pendiente (no ejecutado)

1. **Sustituir el placeholder en AWS**: editar el secreto `develop/com.quizsmart.app` y poner el valor real en la clave `ai-api-key`. `up.ps1` siembra `AI_API_KEY_PLACEHOLDER` y **no pisa valores existentes**; es una acción manual.
2. **Desplegar el código nuevo del backend**: `up.ps1 -Fast` **NO** refresca la imagen `:latest` de la Lambda si solo cambia código (Terraform no ve el cambio en `image_uri`). Hace falta ejecutar `<proyecto>/backend/update-ms.ps1` (solo `quizapi`) o `<proyecto>/backend/update-all.ps1` (todos). Sin este paso el endpoint no existe en AWS aunque el diff sea correcto.
3. **`terraform apply`** para crear los 4 parámetros nuevos de SSM y borrar `MODEL`/`API_URL`. Requiere autorización del usuario; no ejecutado.
4. **Higiene en proyectos ya generados**: el generador copia, no borra. Hay que borrar a mano `lib/features/quiz/data/openai_*.dart` y `ai_api_client.dart` del proyecto generado, o regenerar limpio.

## Notas (desajustes preexistentes, no introducidos aquí)

- **CORS**: API Gateway es catch-all (`ANY /{proxy+}`) y `cors-config.scriban:1` está dentro de `{{ if(Name == "security") }}`, luego **no hay CORS en `quizapi`**. Un `POST` con `Content-Type: application/json` desde Flutter **web** dispara preflight y falla. Afecta igual a `auth`, `health` y `parameters`; es una limitación preexistente, no una regresión de este objetivo. No se añadió CORS (fuera de alcance).
- `.env.dev.scriban:8` apunta a `API_BASE_URL=http://10.0.2.2:5000` mientras `quizapi` corre en `port: 8080`. Preexistente.
- **Endpoint público sin auth ni rate limiting** (decisión `question-003`): cualquiera que conozca la URL puede gastar tokens. Riesgo de coste asumido y documentado en la arquitectura §11; mitigación sugerida para un objetivo posterior.

## Coste AWS

**0 USD incrementales.** No se crean CMK propia, ni secretos nuevos, ni políticas IAM nuevas (`terraform-lambda.scriban` ya concede `secretsmanager:GetSecretValue` y `ssm:GetParametersByPath` sobre la ruta del microservicio). SSM Parameter Store tiene 10 000 parámetros estándar gratis y aquí hay ~25. Coste variable ya existente: invocaciones de Lambda y tokens del proveedor de IA.