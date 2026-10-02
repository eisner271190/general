# Reporte de pruebas — Objetivo 001

> **Alcance de la verificación:** estática / por inspección. El objetivo (`objetivo-001.md:21`) prohíbe
> ejecutar tests (`mvn test`, `flutter test`, cualquier runner). Solo se ejecutó `dotnet build` del
> generador. Los criterios marcados APTO lo están **por inspección del código de las plantillas**; el
> comportamiento en runtime (AWS, arranque de la Lambda, suite Java/Dart) es **NO VERIFICABLE** aquí y
> queda pendiente de que el usuario lance sus propios comandos.

## Comando ejecutado

```bash
dotnet build          # workdir: generator/
```

## Salida

```
  Determinando los proyectos que se van a restaurar...
  Todos los proyectos están actualizados para la restauración.
  Generator -> C:\epc\general\generator\bin\Debug\net9.0\Generator.dll

Compilación correcta.
    0 Advertencia(s)
    0 Errores

Tiempo transcurrido 00:00:01.41
```

Consultas de solo lectura usadas para la inspección: `git status --porcelain`, `git diff -- <component.json,
application-properties, parameter-properties, up.ps1, target json, componente flutter>`, `Select-String`
recursivo sobre `generator/components` y lectura directa de las plantillas.

## Resultado

**Pasan** (10/10 criterios APTO por inspección estática; 0 NO APTO; 0 NO VERIFICABLE como criterio de
aceptación — el runtime de AWS sigue sin verificar, ver "Pendientes").

## Verificación criterio por criterio

| # | Criterio de aceptación | Veredicto | Evidencia (`ruta:línea`) |
|---|---|---|---|
| 1 | `POST /api/v1/ai/generate` recibe prompt y devuelve la respuesta | **APTO** | `ai-controller.scriban:27` (`@RequestMapping("/api/v1/ai")`), `:50` (`@PostMapping("/generate")`), `:52` (`@RequestBody AiGenerateRequestDTO`), `:58-60` (devuelve `ApiResponse` con `data` = payload del proveedor) |
| 2 | Agnóstico: puerto `IAProviderPort` + adaptador `OpenRouterAdapter` | **APTO** | `ia-provider-port.scriban:14,17`; `openrouter-adapter.scriban:28` (`implements IAProviderPort`); el dominio no conoce el proveedor: `ia-provider-port.scriban:3` importa solo `domain.model.AiGeneration`; `iai-service-port.scriban:10`, `ai-usecase.scriban:16-25` |
| 3 | API key en Secret Manager, no en código ni en variables del frontend | **APTO** | `application-properties.scriban:52` solo referencia `${AI_API_KEY:${ai-api-key:}}` (sin valor); siembra en `up.ps1.scriban:284-286` y `:294`; `AI_API_KEY_PLACEHOLDER` aparece **solo** en `up.ps1.scriban:285`; import verificado en `application-cloud-properties.scriban:1` (`aws-secretsmanager:{{ ENVIRONMENT }}/{{ APPLICATION_ID }}`) |
| 4 | Parámetros públicos del proveedor en SSM Parameter Store | **APTO** | `com.quizsmart.app.json:37-40` (`AI_API_BASE_URL`, `AI_MODEL`, `AI_TEMPERATURE`, `AI_MAX_TOKENS`) → `terraform-ssm.scriban:4-8` (`for_each = var.environment_variables`, nombre `/ENV/APP/MS/CLAVE`) → `application-properties.scriban:53-56` (`ai.api-base-url`, `ai.model`, `ai.temperature`, `ai.max-tokens`) |
| 5 | El frontend consume el endpoint del backend, no OpenRouter | **APTO** | `backend_ai_api_client.dart.scriban:15,16,26,33,35`; `strategy_factory.dart.scriban:8,62-64` |
| 6 | Sin `openrouter.ai` en el frontend | **APTO** | `Select-String -Recurse` sobre `generator/components/frontend` con `openai\|openrouter` (case-insensitive) → **0 coincidencias**. `openrouter.ai` solo permanece en el backend (`application-properties.scriban:53`) y en el target JSON (clave de SSM, correcta) |
| 7 | Los `.env.*` del frontend no contienen la API key | **APTO** | `.env.dev.scriban` y `.env.mock.scriban`: 0 coincidencias de `API_KEY`/`API_URL`/`MODEL` (verificado sobre ambos ficheros); `ai_env.dart.scriban` solo conserva `keyPrompt`; `env_config.dart.scriban:19-24` sin `apiKey`/`apiUrl`/`model` |
| 8 | Plantillas nuevas registradas en `component.json` | **APTO** | Backend +8: `component.json:205-212`. Flutter +2: `api_env.dart` (línea 252-254 del diff) y `backend_ai_api_client.dart` (línea 868-869); −8 borradas. Chequeo automático `component.json` ↔ disco: **0 huérfanos y 0 "falta en disco"** en `frontend` y `cloud`; en backend los 52 "huérfanos" son las plantillas genéricas/librería preexistentes (`service.scriban`, `terraform-*.scriban`, …) y ninguna de las 8 nuevas de IA |
| 9 | El generador compila | **APTO** | `dotnet build` → 0 errores, 0 advertencias (salida arriba) |
| 10 | No se rompen auth, parameters, subscription, health ni la lógica de quiz | **APTO** (por inspección del diff) | `git status`: los únicos `.scriban` backend tocados son `application-properties` (8 líneas **añadidas** al final) y `parameter-properties` (6 claves añadidas a `EXCLUDED` + un comentario). `auth-*`, `subscription-*`, `health-*`, `parameter-controller`, `dynamo*`, `cognito*` **intactos**. Lógica de quiz intacta: `PROMPT` sin cambios (`com.quizsmart.app.json:34`), `real_ai_strategy.dart.scriban:26-32,46-53` sigue construyendo el mismo prompt y leyendo `choices[0].message.content`; `mock_ai_strategy` intacto |

## Coherencia entre capas

| Comprobación | Resultado |
|---|---|
| Clave que lee el backend ↔ clave que siembra `up.ps1` | **OK.** Backend resuelve `ai.api-key` ← propiedad `ai-api-key` del secreto `develop/com.quizsmart.app` (import en `application-cloud-properties.scriban:1`). `up.ps1.scriban:284,294` siembra exactamente `ai-api-key`. Mismo patrón ya usado por `jwt-secret` (`application-properties.scriban:30`) y `subscription-secret-key` (`:46`). IAM ya lo permite: `terraform-lambda.scriban:44-45` |
| Claves públicas de SSM ↔ publicadas por `GET /api/v1/parameters` | **OK.** Las 4 `AI_*` se excluyen de la publicación en `parameter-properties.scriban:29-34`; siguen existiendo en SSM y el backend las sigue leyendo. El nombre en `EXCLUDED` coincide con el nombre que Parameter Store da a la propiedad (la clave del JSON target, en mayúsculas) |
| ¿El frontend necesita alguna de ellas? | **NO.** Los 4 puntos de uso de la URL base leen solo `API_BASE_URL` vía `api_env.dart.scriban:11-15`; el prompt vía `env_config.dart.scriban:19-24` (`PROMPT`, que sí se publica). `ApiEnv` es el punto único de lectura, y `monetization_env.dart.scriban:41-42` delega en él sin romper a `revenuecat_provider` |
| `target JSON` ↔ variables que consumen las plantillas | **OK.** Las 4 `AI_*` del JSON tienen su propiedad `ai.*` con default (`application-properties.scriban:53-56`), así que la Lambda arranca aunque falten. `MODEL` y `API_URL` eliminados del JSON y **sin ninguna plantilla que los consuma** (grep de `\bAPI_URL\b|\bMODEL\b` en `.scriban`/`.json`: 0 referencias de plantilla; el resto de coincidencias son `domain.model` / `var model` de otros archivos) |
| Referencias a plantillas borradas | **OK.** 0 coincidencias de `OpenAiApiClient`, `ai_api_client`, `openai_` en todo `generator/components`. Las 8 plantillas borradas están ausentes del disco y de su `component.json` |
| JSON válidos | **OK.** `ConvertFrom-Json` sobre los 2 `component.json`, el target JSON y el de cloud: todos parsean |
| Placeholders Scriban | **OK.** Las 8 plantillas backend nuevas y las 2 frontend nuevas solo usan `{{ PACKAGE }}` / `{{ FRONTEND_NAME }}` |
| Arquitectura hexagonal / ArchUnit | **OK en diseño.** `domain` (`AiGeneration`, `IAProviderPort`, `IAiServicePort`, `AiUseCase`) no importa `application` ni `infrastructure`; `application.dto.AiGenerateRequestDTO` no depende de nada; `infrastructure` → `{application, domain}`. Compatible con `hexagonal-architecture-test.scriban:14-37` y con los `directories` declarados en el `component.json` backend (`domain/ports`, `domain/servicePorts`, `domain/usecase`, `application/dto`, `infrastructure/adapters`, `infrastructure/controllers`). **No ejecutado** (`mvn test` prohibido) |
| `ApiResponse` y el contrato cliente | **OK.** `api-response.scriban` no es genérico; la sobrecarga `(Map<String,Object>, String, int)` es la que se resuelve con `providerPayload()`, de modo que `data` es el cuerpo crudo del proveedor y el cliente lee `body['data']` (`backend_ai_api_client.dart.scriban:74-78`) → `choices[0].message.content` |
| Hallazgos Media 1-6 y Baja 9, 10, 12, 13 del code review | **Aplicados y verificados en el código actual**: `EXCLUDED` (`parameter-properties.scriban:31-34`), `toGeneration` lanza (`:101-107`), `ApiEnv` (`api_env.dart.scriban`), URL antes del `try` (`backend_ai_api_client.dart.scriban:29`), `LOG.warn` en los parseos (`openrouter-adapter.scriban:129,139`), `.timeout(20s)` (`:92-93`), `onErrorResume` propio (`ai-controller.scriban:61-68`), typo corregido (`iai-service-port.scriban:10`) |

## No roto (regresión)

- **auth**: `auth-*` intactos; `jwt.secret` (`application-properties.scriban:30`) sin cambios.
- **parameters**: el único cambio es *añadir* 4 claves a `EXCLUDED` y un comentario. El resto de la lógica de `ParameterProperties` idéntico.
- **subscription**: `subscription.secret-key` / `webhook-secret` / `api-base-url` (`:46-48`) sin cambios.
- **health**: el cambio es mecánico (`ParametersInitializer.instance!.getParameterOrDefault('API_BASE_URL','')` → `ApiEnv.baseUrl`, misma clave y mismo default) en `api_health_repository.dart.scriban:4,21`.
- **parameters (frontend)**: mismo cambio mecánico en `api_parameters_repository.dart.scriban:5-6,24`.
- **lógica de quiz**: prompt, parseo de `questions`, `MockAIStrategy` y `IApiClient` sin cambios. La condición de la factory pasa de `real && apiKey no vacío` a `real` (`strategy_factory.dart.scriban:61-65`): en local `ParametersInitializer` sigue vacío → `mode = none` → `MockAIStrategy` (`:67-68`), luego **el comportamiento local no cambia**; en AWS es donde aplica.

## Pendiente de acción manual del usuario

1. **Tests desalineados (los gestiona el usuario, no se tocaron).** `parameter-controller-test.scriban:40,52,65,82` sigue afirmando que `model` y `api-url` son públicos; con las 4 `AI_*` ya no se publican, el test pasa pero no refleja la realidad. Recomendación del code review (Media 7).
2. **Ejemplo de Postman obsoleto.** `postman-collection.scriban:127` muestra `{"api-url":"https://api.openrouter.ai/...","model":"gpt-4o-mini"}` en `GET /api/v1/parameters`. No coincide con la respuesta real (hallazgo Baja 11, no aplicado por alcance).
3. **Sustituir el placeholder en AWS.** `up.ps1` siembra `AI_API_KEY_PLACEHOLDER` en el secreto `develop/com.quizsmart.app` y **no pisa valores existentes**: hay que editar la clave `ai-api-key` a mano. Hasta entonces `/api/v1/ai/generate` responde 500.
4. **`terraform apply`** (requiere autorización) para crear los 4 parámetros `AI_*` en SSM y borrar `MODEL` / `API_URL`. No ejecutado.
5. **Desplegar el código nuevo del backend.** `up.ps1 -Fast` no refresca la imagen `:latest` de la Lambda. Hace falta `<proyecto>/backend/update-ms.ps1` (solo `quizapi`) o `update-all.ps1`. Sin esto el endpoint no existe en AWS aunque el diff sea correcto.
6. **Higiene en proyectos ya generados.** El generador copia, no borra: hay que eliminar a mano `lib/features/quiz/data/openai_*.dart` y `ai_api_client.dart` del proyecto existente, o regenerar limpio.
7. **Compilar y testear el Java y el Dart.** Aquí no se pudo (`mvn`/`flutter` prohibidos por el objetivo). En particular falta la validación de ArchUnit y el arranque de la Lambda con `ai.temperature` / `ai.max-tokens` vacíos coming de SSM.
8. **Nit documental**: `up.ps1.scriban:18-20` sigue enumerando solo 4 claves sembradas; omite `ai-api-key`.
9. **Nit**: `ai_env.dart.scriban` queda sin newline final.
10. **Hallazgo Baja 14 no aplicado** (por decisión del usuario): el comentario de `parameter-properties.scriban:20` no matiza que las claves de Secrets Manager nunca pasan por esa lista de exclusión; puede inducir a "arreglarlo" con `ai-api-key`.

## Desajustes preexistentes (no introducidos aquí, no bloquean)

- **CORS**: API Gateway es catch-all y `cors-config.scriban` está dentro de `{{ if(Name == "security") }}` → no hay CORS en `quizapi`. Un `POST` con `Content-Type: application/json` desde Flutter **web** dispara preflight y falla. Afecta igual a `auth`, `health` y `parameters`.
- `.env.dev.scriban:8` → `API_BASE_URL=http://10.0.2.2:5000` mientras `quizapi` corre en `port: 8080`.
- Endpoint público de IA sin auth ni rate limiting: cualquiera que conozca la URL puede gastar tokens (decisión `question-003`, coste asumido). El timeout de 20 sadded en `openrouter-adapter.scriban:92-93` acota el gasto por petición.

## Veredicto

- [x] **Pasan** → el objetivo finaliza (el orchestrator mueve `objetivo-001.md` a `objectives/resolved-objectives/`).
- [ ] Falla por implementación → vuelve a Developer.
- [ ] Falla por arquitectura/requisito → vuelve al Architect.

**Motivo**: los 10 criterios de aceptación se cumplen por inspección del código de las plantillas, el
generador compila sin errores, `component.json` ↔ disco, target JSON ↔ plantillas y
`up.ps1` ↔ secreto están coherentes, y el diff no toca ningún endpoint existente ni la lógica de
generación. Lo que queda es acción manual del usuario (tests, despliegue, placeholder del secreto) y
verificación en runtime que este objetivo prohíbe ejecutar. Ninguna duda bloqueante.
