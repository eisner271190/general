# Revisión de arquitectura — Objetivo 001

Revisado: `deliverables/objetivo-001/architecture-001.md` (630 líneas) contra el código real de `generator/components/**` y `generator/target/com.quizsmart.app/com.quizsmart.app.json`. Sin ediciones de código ni de plantillas.

## Veredicto

**Sin observaciones bloqueantes — pasa a Developer.**

Los 10 criterios de aceptación quedan cubiertos por el diseño; los nombres de archivo, símbolo y clave declarados existen donde se dice (con una única cita documental errónea); el `component.json` es coherente con la lista real de plantillas en los tres componentes; el diseño respeta las tres reglas de ArchUnit; el coste AWS incremental es 0. Las 9 observaciones de abajo son no bloqueantes y el developer puede resolverlas siguiendo la recomendación.

## Observaciones

| # | Severidad | Qué cambiar | Por qué |
|---|---|---|---|
| 1 | Media | Añadir `@JsonInclude(JsonInclude.Include.NON_NULL)` a `OpenRouterChatRequest` (`architecture-001.md:126-148`). | El comentario dice que `temperature`/`maxTokens` son nulables "para poder omitirlos", pero sin `@JsonInclude` Jackson **sí** serializa los null explícitamente: el payload saldría `{"temperature":null,"max_tokens":null}`. Hoy los defaults de `application-properties.scriban:264-265` lo evitan, así que no rompe, pero el diseño no cumple su propia intención. |
| 2 | Media | Leer `ai.temperature` y `ai.max-tokens` como `String` y parsear en el constructor de `OpenRouterAdapter`, en vez de `@Value(...) Double/Integer`. | `application-properties.scriban:264-265` fija defaults, así que solo falla si `AI_TEMPERATURE` llega **vacío** en SSM: entonces `@Value` no puede convertir `""` a `Double` y **el Lambda no arranca**. Es un modo de fallo nuevo: las propiedades existentes (`application-properties.scriban:46-48`) son todas `String`. |
| 3 | Media | Corregir la redacción de §5.3 y de §12 (`question-005`) sobre el "efecto colateral en develop". | Es **incorrecta**: el modo se resuelve desde `ParametersInitializer` (`strategy_factory.dart.scriban:16,24` → `service_env.dart.scriban:6`), no desde `.env.dev`. `flutter_dotenv` solo se carga en `test/health_repository_test.dart.scriban:50`, así que `AI_SERVICE_MODE=REAL` de `.env.dev.scriban:2` nunca se lee en runtime. En local `ParametersInitializer` queda vacío (el propio repositorio de parámetros necesita `API_BASE_URL` para llenarse, `api_parameters_repository.dart.scriban:24-27`) → `mode = none` → **sigue cayendo a `MockAIStrategy`** por `strategy_factory.dart.scriban:68-69`. El cambio de comportamiento solo ocurre en AWS. |
| 4 | Media | Añadir a `implementation-001.md` (y a §5.3) el paso de despliegue: `up.ps1 -Fast` **no** refresca la imagen de la Lambda si solo cambia código, hace falta `backend/update-all.ps1` o `backend/update-ms.ps1` (ver `generator/components/backend/spring-boot-3.5.16/AGENTS.md`, sección "Despliegue"). | Todo el backend de este objetivo es código nuevo. Sin ese paso el criterio 1 no queda desplegado en AWS aunque el diff sea correcto, y el §11 (rollback) da por hecho un despliegue que no ocurre. |
| 5 | Media | KISS: evaluar eliminar `IAiServicePort` + `AiUseCase` y que `AiController` dependa directamente de `IAProviderPort` (8 → 6 plantillas backend). | `AiUseCase` (`architecture-001.md:100-110`) es delegación pura sin transformar nada. El precedente `ISubscriptionServicePort`→`SubscriptionUseCase` sí justifica la capa porque traduce `Subscription` → `SubscriptionStatusResponseDTO` (`subscription-controller.scriban:33`); aquí `AiUseCase.generate` solo reenvía la llamada. No rompe ningún criterio, por eso no bloquea, pero son 2 archivos y 2 entradas de `component.json` de más. |
| 6 | Baja | Eliminar la entrada `"ai-api-key"` en `EXCLUDED` (`architecture-001.md:390`, tarea 1.5). | Es código muerto: `parameter-properties.scriban:71-83` solo recorre property sources de **Parameter Store**, y `ai-api-key` viene de Secrets Manager (property source distinto, reconocido en el propio `parameter-properties.scriban:19-20`). La entrada nunca coincide y contradice "cambio mínimo". Si se conserva, que sea por el valor defensivo que el architect ya declara, no por efecto real. |
| 7 | Baja | Reutilizar el acceso existente a `API_BASE_URL` en lugar del 5º lookup inline (`architecture-001.md:310-318`). | Ya hay cuatro lecturas idénticas: `api_parameters_repository.dart.scriban:24-27`, `api_health_repository.dart.scriban:21-24`, `monetization_env.dart.scriban:41-45` y el test. Reutilizar `MonetizationEnv.apiBaseUrl` funciona, aunque semánticamente queda raro para IA; lo limpio es un `ApiEnv.baseUrl` en `lib/core/config/`. |
| 8 | Baja | Documentar dos limitaciones preexistentes que la arquitectura no menciona: (a) `cors-config.scriban:1` está dentro de `{{ if(Name == "security") }}`, luego **no hay CORS para `quizapi`** → el `POST` con `Content-Type: application/json` desde Flutter **web** (plataforma declarada en `com.quizsmart.app.json:7-14`) dispara preflight y falla; (b) `.env.dev.scriban:8` apunta a `API_BASE_URL=http://10.0.2.2:5000` mientras `quizapi` corre en `port: 8080` (`com.quizsmart.app.json:149`). | No son regresiones (afectan igual a `auth`, `health` y `parameters`), pero el criterio 5 no se puede verificar a mano en local/web y el developer perderá tiempo depurando lo que no rompió este objetivo. |
| 9 | Baja | Corregir la cita `terraform-secrets-manager.scriban:7` (`architecture-001.md:411`, y las mismas en `research-001.md:34` y `questions/resolved-questions/question-002.md:4`). | Ese archivo no existe: la plantilla es `generator/components/cloud/aws/templates/terraform-secrets.scriban` y la línea 7 es `source = "../modules/secrets-manager"`, no el nombre del secreto. El nombre real lo produce `up.ps1.scriban:252` (`"$Environment/{{ APPLICATION_ID }}"`), que es lo que el diseño usa. El resto de citas del documento sí son exactas (verificado). |

## Cobertura de los 10 criterios de aceptación

| # | Criterio | Cubierto | Nota |
|---|---|---|---|
| 1 | `POST /api/v1/ai/generate` | Sí | Ruta expuesta por `ANY /{proxy+}` (`terraform-apigateway-lambda.scriban:24-28`). Requiere el paso de despliegue de la obs. 4. |
| 2 | Puerto `IAProviderPort` + `OpenRouterAdapter` | Sí | Nombres exactos pedidos por el objetivo. `domain` no menciona OpenRouter → ArchUnit OK. |
| 3 | API key en Secret Manager | Sí | Clave `ai-api-key` del secreto existente, sembrada por `up.ps1.scriban:265-285,290`. El placeholder no es un secreto. |
| 4 | Parámetros públicos en SSM | Sí | Los 4 nacen de `environment_variables` (`terraform-ssm.scriban:3-9`) leyendo `environments[].variables`; sin tocar Terraform. |
| 5 | Frontend consume el backend | Sí | `backend_ai_api_client.dart` + `strategy_factory.dart.scriban:8,65`. Sin cambios en `IApiClient` (`i_api_client.dart.scriban:1-3`) ni en `RealAIStrategy`. |
| 6 | Sin `openrouter.ai` en el frontend | Sí | Las 8 plantillas a borrar son las únicas coincidencias (verificado con grep sobre todo el componente frontend). `postman-collection.scriban:127` es del componente **backend** y queda fuera del criterio. |
| 7 | `.env.*` sin API key | Sí | `.env.dev.scriban:11-13` y `.env.mock.scriban:20-22`. `API_BASE_URL` se conserva correctamente. |
| 8 | Plantillas en `component.json` | Sí | Backend +8 (todas las carpetas destino existen en `component.json:11-27`), frontend +1/−8 (las 8 plantillas existen en disco), cloud sin cambios (correcto: no hay plantilla nueva). |
| 9 | `dotnet build` | Sí | Incluido en §10 y tarea 5.1. |
| 10 | No se rompen endpoints existentes | Sí | El diff solo **añade** líneas en `application-properties`/`up.ps1`/`component.json` y **borra** 8 entradas, todas del cliente de IA. `AiController` no toca `auth`, `parameters`, `subscription`, `dynamodb`, `cognito`, `sns/sqs`. Bonus: el test de Postman que rechaza secretos (`postman-collection.scriban:105`, regex `/api-key|apikey|secret|password|credential/i`) **no** se dispara con los 4 parámetros nuevos, porque ninguno contiene esos literales. |

## Verificaciones de coherencia realizadas

- **ArchUnit** (`hexagonal-architecture-test.scriban:13-37`): `domain` (`AiGeneration`, `IAProviderPort`, `IAiServicePort`, `AiUseCase`) no importa `application` ni `infrastructure`; `application.dto.AiGenerateRequestDTO` no depende de nada; `infrastructure → {application, domain}` y `domain → {}` no forman ciclo entre slices. `reactor` y `java.util` son externos a los paquetes forbidden. **Respeta las reglas.**
- **`component.json`**: las 8 altas backend son claves únicas y sus carpetas destino existen; las 8 bajas frontend corresponden a plantillas que existen realmente en disco; el nombre de clase `OpenAiApiClient` duplicado entre `ai_api_client.dart.scriban:13` y `openai_api_client.dart.scriban:11` queda resuelto al borrar el primero (que era código muerto: nadie lo importaba).
- **`freezed` sigue en uso**: quedan 9 modelos (`auth_user`, `auth_tokens`, `question`, `quiz_generation_config`, `topic`, `history_item`, `log_entry`, `labeled_slider`) → `pubspec.yaml` correctly no se toca.
- **`AiEnv`**: `AiEnvValidator` solo usa `requiredKeys` (`ai_env_validator.dart.scriban:8`), y `allKeys` solo se usa para logueo (`env_config.dart.scriban:16`) → pasarlo a `[keyPrompt]` es el cambio correcto y necesario. `env_config.dart.scriban` **debe** conservar el import de `ai_env.dart` (usa `keyPrompt` en la línea 22); el diseño lo mantiene.
- **`strategy_factory.dart.scriban`**: conserva `ParametersInitializer` (líneas 16, 24) y `EnvConfig` (línea 46) tras el cambio; solo se sustituye el import de la línea 8. Correcto.
- **Config AWS**: `application-cloud-properties.scriban:1` importa `aws-parameterstore:` y `aws-secretsmanager:` → los 4 parámetros llegan como propiedades `AI_*` y la clave del secreto como `ai-api-key`, con exactamente el patrón ya probado de `application-properties.scriban:46-48`. IAM suficiente (`terraform-lambda.scriban:42-51`). Sin CMK propia → **0 USD**.
- **Sobreingeniería cloud**: ninguna. No tocar `terraform-*.scriban` es la decisión correcta y la más barata.
- **Dudas 001-005**: las 5 respuestas son coherentes con el diseño implementado y con el código real.

## Preguntas

Ninguna bloqueante. Las observaciones 1-5 (Media) conviene que el architect las confirme o las reescriba; si el architect prefiere el diseño tal cual, el developer puede aplicar 1, 2, 3, 4, 6, 7, 8 y 9 tal como están recomendadas sin ampliar el alcance.
