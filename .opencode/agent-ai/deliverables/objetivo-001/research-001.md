# Investigación — Objetivo 001

API de IA agnóstica al proveedor (backend Spring Boot) + consumo desde Flutter + secretos en AWS.

## Problema

El frontend Flutter llama directo a OpenRouter (`https://openrouter.ai/api/v1/chat/completions`) con una API key disponible en el cliente, y manda el payload OpenAI (`model`, `messages`, `temperature`, `max_tokens`). Eso acopla la app al proveedor, expone credenciales y no hay control central. Se quiere un endpoint `/api/v1/ai/generate` en el backend detrás de un puerto, con la key en Secrets Manager y los parámetros públicos en SSM.

## Estado actual del código

### Backend (`generator/components/backend/spring-boot-3.5.16/`)

- **Capas reales** (no hay "features"): `domain/{model,ports,servicePorts,usecase,dto}`, `application/{services,dto,mappers}`, `infrastructure/{controllers,adapters,configuration,rest,persistence}`. Árbol completo en `component.json:4-60`.
- **WebFlux reactivo**: `spring-boot-starter-webflux` (`templates/pom.scriban:104`) y `spring.main.web-application-type=reactive` (`application-properties.scriban:33`). Los controladores devuelven `Mono<ResponseEntity<ApiResponse>>` (`subscription-controller.scriban:25-40`).
- **Nombres**: puertos de salida `domain/ports/*Port.java` (`ExchangePort`, `SubscriptionPort`), puertos de servicio `domain/servicePorts/I*ServicePort.java` (`ISubscriptionServicePort`), adaptadores `infrastructure/adapters/*Adapter.java`. El patrón "puerto agnóstico + adaptador HTTP" ya existe y es la referencia a copiar: `domain/ports/ISubscriptionProviderPort.java` (`templates/isubscription-provider-port.scriban:13-17`) ← `infrastructure/adapters/RevenueCatAdapter.java` (`templates/revenuecat-adapter.scriban:22-49`), que además consume config con `@Value("${subscription.api-base-url}")` y `@Value("${subscription.secret-key}")` (`revenuecat-adapter.scriban:32-38`).
- **Config AWS**: perfil cloud `templates/application-cloud-properties.scriban:1` → `spring.config.import=aws-parameterstore:/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/{{ MICROSERVICE_NAME }}/,aws-secretsmanager:{{ ENVIRONMENT }}/{{ APPLICATION_ID }}`. Secretos = claves JSON aplanadas a propiedades (docs Spring Cloud AWS: <https://docs.awspring.io/spring-cloud-aws/reference/html/index.html>). Mapeo equivalente en properties: `subscription.secret-key=${SUBSCRIPTION_SECRET_KEY:${subscription-secret-key:}}` (`application-properties.scriban:44-48`).
- **`ParameterProperties`** (`templates/parameter-properties.scriban:22-91`) no lee una config de la app: **expone al cliente** todo Parameter Store salvo la lista `EXCLUDED` (líneas 25-56), vía `GET /api/v1/parameters` (`parameter-controller.scriban:15-41`). Los secretos de Secrets Manager no se exponen (property source distinto, `parameter-properties.scriban:19-20`).
- **Registro de endpoints**: no hay tabla de rutas; cada `@RestController` se escanea. API Gateway enruta `ANY /{proxy+}` a la Lambda (`terraform-apigateway-lambda.scriban:24-28`), luego un endpoint nuevo queda expuesto sin tocar Terraform. **No hay filtros de auth** (`jwt-authentication-filter.scriban` no está en `component.json`); auth por header `X-User-Id` sin validar (`subscription-controller.scriban:31,37`).
- **Arquitectura validada por ArchUnit** (`templates/hexagonal-architecture-test.scriban:13-37`): `domain` no depende de `application`/`infrastructure`, `application` no depende de `infrastructure`, y **sin ciclos entre slices**. `*.scriban` sin condicionales ⇒ se generan en todos los microservicios del componente (hoy solo `quizapi`, `target/com.quizsmart.app.json:56`).
- Errores: `GeneralException` + `GlobalExceptionHandler` (`templates/global-exception-handler.scriban:13-32`) → `ErrorApiResponse` 500.

### Flutter (`generator/components/frontend/flutter3.47.2/`)

- **Interfaz**: `abstract class IApiClient { Future<Map<String,dynamic>> callApi(String prompt); }` (`templates/lib/features/quiz/data/i_api_client.dart.scriban:1-3`).
- **Implementaciones (2, y una es código muerto)**: `ai_api_client.dart.scriban:13` (`class OpenAiApiClient`, lee `API_URL`/`MODEL`/`API_KEY` de `ParametersInitializer`, líneas 22-37) y `openai_api_client.dart.scriban:11` (mismo nombre de clase, lee de `EnvConfig`). Ambas registradas (`component.json:864,876`) pero **solo se importa `openai_api_client.dart`** (`strategy_factory.dart.scriban:8,65`): `ai_api_client.dart` es alcanzable desde nadie y duplica el nombre de clase.
- **Único call-site**: `templates/lib/features/quiz/application/strategy_factory.dart.scriban:44-70` → `RealAIStrategy(OpenAiApiClient(), config.promptTemplate)`. `RealAIStrategy` (`templates/lib/features/quiz/data/real_ai_strategy.dart.scriban:15-53`) construye el prompt desde `EnvConfig.promptTemplate` y parsea `body['choices'][0]['message']['content']`. Sin proveedor (provider de DI): instanciación directa en la factory.
- **Config**: nada de `.env` en runtime; todo llega por `ParametersInitializer` (`templates/lib/core/parameters_initializer.dart.scriban:9-40`), que llama a `GET /api/v1/parameters` con `API_BASE_URL` (`templates/lib/features/parameters/data/api_parameters_repository.dart.scriban:13-30`). `AI_SERVICE_MODE` decide mock/real (`strategy_factory.dart.scriban:23-42`).
- **`.env.*`**: `templates/assets/.env.dev.scriban:1-22` (contiene `API_KEY=REPLACE_...` línea 11 y `API_URL=https://REPLACE_WITH_API_HOST/v1/chat/completions` línea 12) y `templates/assets/.env.mock.scriban:20-22`. Ya existe `API_BASE_URL=http://10.0.2.2:5000` (`env.dev:8`) = **URL base del backend ya resuelta**; en AWS la inyecta `up.ps1` post-apply (`cloud/aws/templates/up.ps1.scriban:73-80`, escribe en SSM con `Set-ParameterStoreValue`, líneas 171-213).
- **Cliente HTTP**: `IHttpClient`/`HttpClientImpl` (`templates/lib/shared/consume/i_http_client.dart.scriban:1-23`), `post(url, headers:, body:)`. No hay interceptores; el auth de negocio va en headers puntuales (p. ej. RevenueCat). Los repos hacia el backend (`api_health_repository.dart.scriban:10,21-30`) no mandan auth.

### Cloud (`generator/components/cloud/aws/`)

- **SSM**: `templates/terraform-ssm.scriban:3-9` → `aws_ssm_parameter.environment` con `for_each = var.environment_variables`, nombre `/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/{{ MICROSERVICE_NAME }}/${each.key}`; valores desde `templates/terraform-tfvars.scriban:5` (`environment_variables = {{ ENVIRONMENT_VARIABLES_HCL }}`) ← variables de `environments[].variables` del JSON target.
- **Secretos**: contenedor único por app `module "secrets"` (`templates/terraform-secrets.scriban:6-13`, módulo en `terraform/modules/secrets-manager`, sin CMK propia por coste); **el valor lo siembra `cloud/up.ps1`**: claves fijas en `up.ps1.scriban:290`, valores por defecto en `up.ps1.scriban:265-285`, escritura con `put-secret-value` (`up.ps1.scriban:404-419`, invocada en `up.ps1.scriban:607`).

### `component.json`

Formato `{"name","type","directories":[...],"files":[{"key":<dest>,"value":<plantilla>}...],"defaultFiles":[]}`; **solo se copia lo listado** (`generator/AGENTS.md`, reglas de `component.json`). Backend: 4-60 directorios, 62-204 archivos. Flutter: `component.json:138-137+` (dirs) y `files` con rutas `frontend/{{ FRONTEND_NAME }}/lib/...`. Cloud: `component.json:13-41`.

### Modelo de datos / flujo que NO cambia

Prompt: `PROMPT` del SSM (`com.quizsmart.app.json:35`) con placeholders `{numQuestions} {topic} {language} {optionsCount}` reemplazados en `real_ai_strategy.dart.scriban:26-32`. Request actual al proveedor: `{model, messages:[{role:'user',content:prompt}], temperature:0.7, max_tokens:1000}` (`ai_api_client.dart.scriban:55-64`). Respuesta: JSON de OpenRouter/OpenAI; el contenido es texto con `{"questions":[...]}` que el cliente parsea (`real_ai_strategy.dart.scriban:56-102`). El objetivo mantiene prompt y formato.

## Restricciones

- Plantillas Scriban como fuente de verdad; `generator/target/com.quizsmart.app/com.quizsmart.app.json` es **entrada**.
- No tocar tests, no ejecutar tests, no commit/push, no `terraform apply/destroy`, no editar `.env` reales, no secretos en código.
- Hexagonal (ArchUnit con reglas activas) y estructura `features/` en Flutter.
- Registrar toda plantilla nueva/renombrada en el `component.json` de su componente en el mismo cambio.
- Minimizar coste AWS (un endpoint, sin CMK propia).

## Alternativas

| Alternativa | Ventajas | Desventajas |
|---|---|---|
| A. Puerto `IAProviderPort` + `OpenRouterAdapter` + `AiController` (propuesta del objetivo) | Copia literal del patrón ya validado `ISubscriptionProviderPort`/`RevenueCatAdapter`;agnóstico y testeable; coste 0 incremental | Hay que crear 4-5 plantillas backend y registrar `ai.*` en `application-properties` |
| B. Solo cliente Flutter nuevo sin endpoint | Cambio mínimo | No cumple el objetivo: la key seguiría sin centralizar; sin control ni agnosticismo real |
| C. Proveedor único detrás de Spring AI (`ChatClient`) | Abstracción ya resuelta por el framework | Cambio grande de dependencias, sin patrón equivalente en el repo, riesgo de Spring AI en Lambda nativa; fuera de "cambio mínimo" |
| D. Integración en `security` (Cognito ya vive ahí) | Reutiliza CORS/auth | Empareja IA con seguridad y crea dependencia entre microservicios; contradice "solo `quizapi`" |

Notas de diseño (fuente: [Spring Cloud AWS](https://docs.awspring.io/spring-cloud-aws/reference/html/index.html), [OpenRouter API ref](https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion)):
- La clave del secreto JSON se lee como propiedad suelta; conviene aislarla: `ai.api-key=${AI_API_KEY:${ai-api-key:}}` (mismo patrón que `subscription.secret-key`).
- OpenRouter es OpenAI-compatible: `POST /api/v1/chat/completions`, respuesta `choices[0].message.content`; el adaptador solo necesita translate-request/response.
- Coste AWS incremental: 0 USD (sin CMK, sin recursos nuevos; Lambda ya existe; solo parámetros SSM, gratis hasta 10k).

## Archivos a crear/modificar (propuesta)

Backend — component `spring-boot-3.5.16` (`component.json` + plantillas):

| Acción | Destino generado | Plantilla |
|---|---|---|
| Crear | `.../domain/ports/IAProviderPort.java` | `templates/ia-provider-port.scriban` |
| Crear | `.../domain/model/AiPrompt.java` (o record) | `templates/ai-prompt.scriban` |
| Crear | `.../application/dto/AiGenerateRequestDTO.java` | `templates/ai-generate-request-dto.scriban` |
| Crear | `.../infrastructure/adapters/OpenRouterAdapter.java` | `templates/openrouter-adapter.scriban` |
| Crear | `.../infrastructure/controllers/AiController.java` | `templates/ai-controller.scriban` |
| Opcional | `.../domain/usecase/AiUseCase.java` + `application/services/IAiService` | `templates/ai-usecase.scriban`, `templates/iai-service.scriban` |
| Modificar | `.../src/main/resources/application.properties` | `templates/application-properties.scriban` (añadir `ai.*`) |

Frontend — component `flutter3.47.2`:

| Acción | Destino | Nota |
|---|---|---|
| Crear | `lib/features/quiz/data/backend_ai_api_client.dart` | implementa `IApiClient`; `POST $API_BASE_URL/api/v1/ai/generate` vía `IHttpClient` |
| Modificar | `lib/features/quiz/application/strategy_factory.dart.scriban` | nueva instancia + condición sin `API_KEY` (ver `question-005`) |
| Modificar | `lib/features/quiz/application/strategy_config.dart.scriban` | sin `apiKey` |
| Modificar | `lib/features/quiz/config/ai_env.dart.scriban` | quitar `keyApiKey`/`keyApiUrl`/`keyModel` |
| Modificar | `lib/shared/env/env_config.dart.scriban` | quitar `apiKey`/`apiUrl`/`model` |
| Eliminar (registro) | `lib/features/quiz/data/ai_api_client.dart` | código muerto + nombre de clase duplicado |
| Eliminar (registro) | `lib/features/quiz/data/openai_api_client.dart` (+ `openai_payload*`, `openai_message*` si quedan sin uso) | revisar si `freezed` sigue usándose |
| Modificar | `assets/.env.dev.scriban`, `assets/.env.mock.scriban` | quitar `API_KEY`/`API_URL`/`MODEL` |

Cloud — component `cloud/aws`:

| Acción | Destino | Nota |
|---|---|---|
| Modificar | `templates/up.ps1.scriban` | añadir clave del secreto de IA a `$seededKeys` (290) y su valor por defecto (265-285) |
| (sin tocar) | `templates/terraform-ssm.scriban` | los parámetros públicos salen de `environment_variables`; basta el JSON target |

Generador (entrada):

| Acción | Archivo | Nota |
|---|---|---|
| Modificar | `generator/target/com.quizsmart.app/com.quizsmart.app.json` | quitar `API_URL` (línea 31); añadir parámetros públicos de IA (`AI_API_BASE_URL`, `AI_MODEL`, `AI_TEMPERATURE`, `AI_MAX_TOKENS`); decidir `API_KEY` |

## Riesgos

- **ArchUnit**: `domain` no puede depender de nada externo; `IAProviderPort` debe usar solo tipos propios/`Mono`. Y **no ciclos**: si el adaptador importa un DTO de `application`, cuidado (`applicationNoInfrastructureDependency`, `noCircularDependencies`).
- **Doble fuente de verdad de la URL**: `api-url` de SSM (backend) vs `API_BASE_URL` (frontend). Si `ParameterProperties` publica `AI_API_BASE_URL` no es problema, pero cualquier secreto nuevo en Parameter Store se expondría al cliente: la key **debe** ir solo en Secrets Manager.
- **`up.ps1` no pisa valores existentes** (`up.ps1.scriban:410-419`): cambiar el nombre de la clave del secreto dejaría la vieja huérfana y la nueva en `PLACEHOLDER`.
- **Frontend en modo mock hoy**: `API_KEY` no está en las variables de `develop` (`com.quizsmart.app.json:23-51`), así que `develop` cae a `MockAIStrategy`. Quitar la condición de `apiKey` cambia el comportamiento real/mock → hay que decidir (duda 005).
- **GraalVM/native**: el Dockerfile/`GraalHints` (`graalvm-hints.scriban:1-15`) no tienen hints de reflexión para DTOs; los records Jackson en WebFlux funciona, pero conviene verificar si el build nativo está activo (`pom.scriban:371` condicional `{{ if(Graalvm) }}`).
- **Coste**: sin rate limiting (fuera de alcance), un endpoint público de IA es susceptible de abuso que sí genera coste en OpenRouter. Riesgo aceptado por el objetivo.
- **Postman/docs**: `postman-collection.scriban:4` y `:127` documentan `api-url` de OpenRouter como parámetro público → quedan desactualizados.
- **No compilar**: la regla de no ejecutar tests/build impide validar localmente; el Developer deberá informar de cualquier placeholder sin resolver.

## Dudas registradas

| # | Severidad | Asunto |
|---|---|---|
| `question-001` | NON_BLOCKING | ¿Condicionar las plantillas de IA a `quizapi` o generarlas en todos los microservicios? |
| `question-002` | NON_BLOCKING | ¿Clave nueva `openrouter-api-key` en el secreto existente o reutilizar `api-key`? |
| `question-003` | NON_BLOCKING | ¿Endpoint de IA público (sin auth) o autenticado? |
| `question-004` | NON_BLOCKING | Forma de la respuesta: `ApiResponse.data` = cuerpo crudo de OpenRouter. |
| `question-005` | NON_BLOCKING | Condición mock/real sin `API_KEY` en frontend. |

## Coste estimado

0 USD incremental en AWS (mismo secreto, mismos parámetros SSM, sin CMK, sin recursos nuevos). Coste variable ya existente: tokens de OpenRouter (`MODEL` actual `gpt-4o-mini`, `max_tokens` 1000). Sin coste de licencia.