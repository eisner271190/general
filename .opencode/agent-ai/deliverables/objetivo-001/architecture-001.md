# Arquitectura — Objetivo 001

API de IA agnóstica al proveedor: endpoint Spring Boot `/api/v1/ai/generate` detrás de un puerto, cliente Flutter contra el backend (sin consumo directo de OpenRouter), API key en AWS Secret Manager y parámetros públicos en SSM Parameter Store.

## Contexto

Hoy el cliente Flutter (`openai_api_client.dart`) llama directo a `https://openrouter.ai/api/v1/chat/completions` con la API key disponible en el dispositivo. Se quiere:

1. **Backend**: un puerto `IAProviderPort` + adaptador `OpenRouterAdapter`, exponiendo `POST /api/v1/ai/generate`.
2. **Frontend**: sustituir el cliente que habla con el proveedor por uno que hable con el backend, **sin tocar `RealAIStrategy`**.
3. **Cloud**: la key en el secreto ya existente (`up.ps1` siembra claves fijas), los parámetros públicos en SSM vía `environment_variables`.

Reutilización del patrón ya validado en el repo: `ISubscriptionProviderPort` ← `RevenueCatAdapter` (puerto agnóstico en `domain/ports`, adaptador HTTP en `infrastructure/adapters`, config con `@Value`), `SubscriptionController` (envoltorio `ApiResponse`, `Mono<ResponseEntity<ApiResponse>>`) y `RevenueCatWebhookPayload` (record con `@JsonProperty` + traducción al dominio).

Rutas de código relativas a la raíz del repo. Las rutas de plantilla son **del generador** (`generator/components/**`), no del proyecto generado.

---

## 1. Decisión de diseño y alternativas descartadas

### 1.1 Decisión

**Capa IA en el backend con 5 piezas y reutilización literal del patrón de suscripción:**

```
AiController (infrastructure/controllers)
   └─> IAiServicePort (domain/servicePorts)
         └─> AiUseCase (domain/usecase)
               └─> IAProviderPort (domain/ports)          ← frontera agnóstica
                     └─> OpenRouterAdapter (infrastructure/adapters)
                           └─> WebClient → https://openrouter.ai/api/v1
```

**Frontend: renombrar, no crear desde cero.** `openai_api_client.dart` es el único cliente alcanzable (`strategy_factory.dart.scriban:8,65`); `ai_api_client.dart` es **código muerto** (nadie lo importa) y además duplica el nombre de clase `OpenAiApiClient` — dos clases distintas en el mismo feature. Se **renombra** el alcanzable a `backend_ai_api_client.dart` / `BackendAiApiClient` (se conserva la lógica de timeout, log y parseo ya escrita) y se **elimina** el muerto más sus 6 plantillas de payload Freezed huérfanas. Crear un tercer cliente habría dejado tres implementaciones de `IApiClient`.

### 1.2 Alternativas descartadas

| Alternativa | Por qué se descarta |
|---|---|
| Cliente Flutter nuevo + borrar el viejo | No es un borrado: `openai_payload`/`openai_message` (Freezed) solo los usa ese cliente y quedarían huérfanos. Renombrar conserva el trabajo ya hecho y cumple "misma interfaz" con menos diff. |
| `IAProviderPort` que devuelva el `Map` crudo del proveedor | El puerto quedaría con la forma de OpenAI: cualquier proveedor nuevo tendría que imitar `choices[].message.content`. El puerto devuelve `AiGeneration` (modelo + content + payload opaco), que sí es agnóstico. |
| Solo texto en `ApiResponse.data` (`{"content": ...}`) | Obliga a reescribir el parseo de `real_ai_strategy.dart.scriban:46-53` → fuera de alcance ("mantener la misma interfaz"). Se mantiene el passthrough del cuerpo del proveedor. |
| Spring AI (`ChatClient`) como abstracción | Cambio de dependencias, sin patrón equivalente en el repo, riesgo en Lambda/GraalVM; el objetivo pide cambio mínimo y la interfaz ya la da el puerto propio. |
| Integrar en el microservicio `security` (donde vive Cognito) | Empareja IA con seguridad y crea dependencia entre microservicios; el objetivo limita el alcance al microservicio actual. |
| `@Valid` + `jakarta.validation` en el DTO | `spring-boot-starter-validation` **no está** en `pom.scriban` (líneas 84-251). Los controladores que sí usan `@Valid` están envueltos en `{{ if(Name == "security") }}` y nunca se generan hoy. Validación manual en el controlador. |
| CMK propia en Secrets Manager / secretos nuevos en Terraform | +1 USD/mes. El secreto único por app ya existe y su valor se siembra fuera de Terraform. **Coste incremental: 0 USD.** |

---

## 2. Diseño por capa

### 2.1 Contratos backend (contenido clave de cada archivo nuevo)

**`domain/model/AiGeneration.java`** — record inmutable, sin dependencias externas (ArchUnit: `domain` no depende de nada):

```java
package {{ PACKAGE }}.domain.model;

import java.util.Map;

/**
 * Resultado de una generación de IA ya traducido al contrato agnóstico.
 *
 * @param model           modelo que respondió el proveedor (informativo)
 * @param content         texto plano generado
 * @param providerPayload cuerpo crudo del proveedor. Se reenvía tal cual en la
 *                        respuesta HTTP para que el cliente no dependa del
 *                        proveedor; acoplamiento deliberado y documentado.
 */
public record AiGeneration(String model, String content, Map<String, Object> providerPayload) {}
```

**`domain/ports/IAProviderPort.java`** — la frontera agnóstica (réplica de `isubscription-provider-port.scriban:13-17`):

```java
package {{ PACKAGE }}.domain.ports;

import {{ PACKAGE }}.domain.model.AiGeneration;
import reactor.core.publisher.Mono;

public interface IAProviderPort {
    /** Genera texto con el proveedor configurado. */
    Mono<AiGeneration> generate(String prompt);
}
```

**`domain/servicePorts/IAiServicePort.java`** — puerto de servicio (réplica de `isubscription-service-port.scriban:6-9`):

```java
package {{ PACKAGE }}.domain.servicePorts;

import {{ PACKAGE }}.domain.model.AiGeneration;
import reactor.core.publisher.Mono;

public interface IAiServicePort {
    Mono<AiGeneration> generate(String prompt);
}
```

**`domain/usecase/AiUseCase.java`** — caso de uso; punto de extensión para guardarraíles de prompt, registro y rate limiting futuros:

```java
@Service
public class AiUseCase implements IAiServicePort {
    private final IAProviderPort aiProvider;
    public AiUseCase(IAProviderPort aiProvider) { this.aiProvider = aiProvider; }
    @Override
    public Mono<AiGeneration> generate(String prompt) { return aiProvider.generate(prompt); }
}
```

**`application/dto/AiGenerateRequestDTO.java`** — POJO plano con getter/setter (Jackson necesita setter; estilo `change-password-request-dto.scriban`), **sin** anotaciones de validación:

```java
package {{ PACKAGE }}.application.dto;

public class AiGenerateRequestDTO {
    private String prompt;
    public AiGenerateRequestDTO() {}
    public AiGenerateRequestDTO(String prompt) { this.prompt = prompt; }
    public String getPrompt() { return prompt; }
    public void setPrompt(String prompt) { this.prompt = prompt; }
}
```

**`infrastructure/adapters/OpenRouterChatRequest.java`** — record del payload de salida (réplica de `revenuecat-subscriber-response.scriban`). `temperature`/`maxTokens` son nulables para poder omitirlos:

```java
package {{ PACKAGE }}.infrastructure.adapters;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record OpenRouterChatRequest(
    @JsonProperty("model") String model,
    @JsonProperty("messages") List<Message> messages,
    @JsonProperty("temperature") Double temperature,
    @JsonProperty("max_tokens") Integer maxTokens
) {
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Message(
        @JsonProperty("role") String role,
        @JsonProperty("content") String content
    ) {}
}
```

**`infrastructure/adapters/OpenRouterAdapter.java`** — `@Component`, implementa `IAProviderPort`. Inyecta con `@Value` como `RevenueCatAdapter` (`revenuecat-adapter.scriban:32-38`):

```java
@Component
public class OpenRouterAdapter implements IAProviderPort {

    private static final String ROLE_USER = "user";

    private final WebClient webClient;
    private final String apiKey;
    private final String model;
    private final Double temperature;
    private final Integer maxTokens;

    public OpenRouterAdapter(
            WebClient.Builder webClientBuilder,
            @Value("${ai.api-key}") String apiKey,
            @Value("${ai.api-base-url}") String apiBaseUrl,
            @Value("${ai.model}") String model,
            @Value("${ai.temperature}") Double temperature,
            @Value("${ai.max-tokens}") Integer maxTokens) {
        this.webClient = webClientBuilder.baseUrl(apiBaseUrl).build();
        this.apiKey = apiKey;
        this.model = model;
        this.temperature = temperature;
        this.maxTokens = maxTokens;
        if (apiKey == null || apiKey.isBlank()) {
            LoggerFactory.getLogger(OpenRouterAdapter.class)
                .warn("ai.api-key vacio: /api/v1/ai/generate respondera error hasta sembrar el secreto");
        }
    }

    @Override
    public Mono<AiGeneration> generate(String prompt) {
        if (apiKey == null || apiKey.isBlank()) {
            return Mono.error(new IllegalStateException(
                "Falta la API key del proveedor de IA (ai.api-key)"));
        }
        OpenRouterChatRequest request = new OpenRouterChatRequest(
                model,
                List.of(new OpenRouterChatRequest.Message(ROLE_USER, prompt)),
                temperature,
                maxTokens);
        return webClient.post()
                .uri("/chat/completions")
                .header("Authorization", "Bearer " + apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(request)
                .retrieve()
                .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
                .map(payload -> new AiGeneration(model, extractContent(payload), payload));
    }

    /** choices[0].message.content; null si la respuesta no trae contenido usable. */
    private String extractContent(Map<String, Object> payload) { /* instanceof sobre List/Map */ }
}
```

Notas de diseño del adaptador:
- Se parsea **una sola vez** a `Map<String, Object>`: de ahí sale el `content` (para el dominio) y el `providerPayload` (passthrough fiel, sin pérdida de campos).
- `extractContent` navega con `instanceof` (nunca `ClassCastException`); devuelve `null` si la forma no es la esperada.
- Errores del proveedor (401 por key placeholder, 429, 5xx) los captura `GlobalExceptionHandler` (`global-exception-handler.scriban:28-32`) → 500 `ApiResponse`. No se re-lanza nada en la capa de aplicación.

**`infrastructure/controllers/AiController.java`** — control de entrada y **validación en la frontera HTTP**:

```java
@RestController
@RequestMapping("/api/v1/ai")
public class AiController {

    private static final int MAX_PROMPT_LENGTH = 8000;

    private final IAiServicePort aiService;

    public AiController(IAiServicePort aiService) { this.aiService = aiService; }

    /** Cuerpo: {"prompt":"..."} -> ApiResponse con data = cuerpo crudo del proveedor. */
    @PostMapping("/generate")
    public Mono<ResponseEntity<ApiResponse>> generate(
            @RequestBody(required = false) AiGenerateRequestDTO request) {
        String prompt = request == null ? null : request.getPrompt();
        if (prompt == null || prompt.isBlank() || prompt.length() > MAX_PROMPT_LENGTH) {
            Map<String, Object> noData = null;
            return Mono.just(ResponseEntity.badRequest().body(new ApiResponse(
                    noData, "prompt is required and must be at most 8000 characters", 400)));
        }
        return aiService.generate(prompt)
                .map(generation -> ResponseEntity.ok(new ApiResponse(
                        generation.providerPayload(), "Text generated", 200)));
    }
}
```

Se usa una variable `Map<String, Object>` para el `null` porque `ApiResponse` tiene sobrecargas `ApiResponse(Map,…)` y `ApiResponse(Object,…)` (`api-response.scriban:17,24`): la variable tipada desambigua sinipsis y hace explícito que `data` va nulo, no envuelto.

**Contrato del endpoint**

| Aspecto | Valor |
|---|---|
| Ruta | `POST /api/v1/ai/generate` (prefijo ya enrutado por `ANY /{proxy+}`, `terraform-apigateway-lambda.scriban:24-28`: **no hay cambios en Terraform**) |
| Auth | Ninguna (ver §Dudas, `question-003`) |
| Request | `{"prompt": "<texto>", "model": "<opcional, ignorado>", "temperature": <opcional, ignorado>, "max_tokens": <opcional, ignorado>}` — el modelo/temperatura/max_tokens los decide el backend desde SSM |
| Respuesta 200 | `ApiResponse` con `data` = **cuerpo crudo de OpenRouter** (mapa completo), `message: "Text generated"`, `status: 200`, `timestamp` |
| Respuesta 400 | `ApiResponse` con `data: null`, `message: "prompt is required and must be at most 8000 characters"`, `status: 400` |
| Respuesta 500 | `ApiResponse` vía `GlobalExceptionHandler` (key ausente, error del proveedor) |

**Propiedades Spring** (`application-properties.scriban`, bloque nuevo al final, siguiendo el bloque `subscription.*`):

```properties
# IA generativa (proveedor actual: OpenRouter). Claves genericas para poder
# cambiar de proveedor sin tocar el codigo. La API key NUNCA va aqui en claro.
ai.api-key=${AI_API_KEY:${ai-api-key:}}
ai.api-base-url=${AI_API_BASE_URL:https://openrouter.ai/api/v1}
ai.model=${AI_MODEL:gpt-4o-mini}
ai.temperature=${AI_TEMPERATURE:0.7}
ai.max-tokens=${AI_MAX_TOKENS:1000}
```

### 2.2 Contratos frontend

**`lib/features/quiz/data/backend_ai_api_client.dart`** (nuevo, renombrando `openai_api_client.dart`):

```dart
/// Cliente del endpoint de IA del backend (POST /api/v1/ai/generate).
///
/// Agnóstico al proveedor: modelo, temperatura y credenciales los resuelve el
/// backend. Devuelve `data` del ApiResponse (cuerpo crudo del proveedor) para
/// que RealAIStrategy siga leyendo choices[0].message.content sin cambios.
class BackendAiApiClient implements IApiClient {
  static const String _generatePath = '/api/v1/ai/generate';
  static const int _apiTimeoutSeconds = 30;

  final IHttpClient _httpClient;
  final Validator _validator = Validator();

  BackendAiApiClient({IHttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClientImpl();

  @override
  Future<Map<String, dynamic>> callApi(String prompt) async {
    _validator.notEmptyAndNotNull(prompt, 'Prompt cannot be empty');
    final url = '${_baseUrl()}$_generatePath';
    try {
      final response = await _httpClient
          .post(url,
              headers: {'Content-Type': 'application/json'},
              body: {'prompt': prompt})
          .timeout(Duration(seconds: _apiTimeoutSeconds),
              onTimeout: () => throw TimeoutException(
                  'Backend AI request timed out after $_apiTimeoutSeconds seconds'));
      return _parseResponse(response);
    } on TimeoutException catch (e) {
      Logger.error('[AI] Timeout calling backend AI', error: e);
      rethrow;
    } catch (e) {
      Logger.error('[AI] Unexpected error calling backend AI', error: e);
      rethrow;
    }
  }

  /// API_BASE_URL llega por GET /api/v1/parameters (ya existe; up.ps1 la escribe).
  String _baseUrl() {
    final base = ParametersInitializer.instance!
        .getParameterOrDefault('API_BASE_URL', '');
    if (base.isEmpty) {
      throw Exception('API_BASE_URL no configurada (GET /api/v1/parameters)');
    }
    return base;
  }

  Map<String, dynamic> _parseResponse(HttpResponse response) {
    if (response.statusCode != 200) {
      Logger.error('[AI] Error en llamada al backend de IA',
          data: {'statusCode': response.statusCode, 'body': response.body});
      throw Exception('Error en la API de IA: ${response.statusCode}');
    }
    final body = json.decode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('La respuesta del backend de IA no contiene data');
    }
    return data;
  }
}
```

Contrato: implementa `IApiClient` **sin cambios** (`i_api_client.dart.scriban:1-3`), así que `RealAIStrategy` y `MockAIStrategy` siguen intactos.

**`strategy_factory.dart`**: import `backend_ai_api_client.dart` (en lugar de `openai_api_client.dart`) y condición de selección:

```dart
if (mode == ServiceMode.real) {
  _logUsingRealStrategy();
  return RealAIStrategy(BackendAiApiClient(), config.promptTemplate);
}
```

Se conserva el `if (mode == ServiceMode.mock)` y el *fallback* final a mock para el modo `none`. Mensaje de log actualizado a `(real mode via backend)`.

---

## 3. Archivos a crear

### Frontend

- `generator/components/frontend/flutter3.47.2/templates/lib/features/quiz/data/backend_ai_api_client.dart.scriban` — cliente `IApiClient` contra `POST $API_BASE_URL/api/v1/ai/generate`. Destino: `frontend/{{ FRONTEND_NAME }}/lib/features/quiz/data/backend_ai_api_client.dart`.

### Backend

Todos en `generator/components/backend/spring-boot-3.5.16/templates/`, destino `{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/…`:

- `ai-generation.scriban` → `domain/model/AiGeneration.java` — record de dominio (§2.1).
- `ia-provider-port.scriban` → `domain/ports/IAProviderPort.java` — puerto agnóstico `Mono<AiGeneration> generate(String)`.
- `iai-service-port.scriban` → `domain/servicePorts/IAiServicePort.java` — puerto de servicio.
- `ai-usecase.scriban` → `domain/usecase/AiUseCase.java` — `@Service`, delega en el puerto.
- `ai-generate-request-dto.scriban` → `application/dto/AiGenerateRequestDTO.java` — POJO `prompt`.
- `openrouter-adapter.scriban` → `infrastructure/adapters/OpenRouterAdapter.java` — `WebClient` + traducción.
- `openrouter-chat-request.scriban` → `infrastructure/adapters/OpenRouterChatRequest.java` — record JSON de salida.
- `ai-controller.scriban` → `infrastructure/controllers/AiController.java` — endpoint + validación.

### Cloud

- Ninguna plantilla nueva. `terraform-*.scriban` **no se toca** (ver §6): el secreto ya existe y los parámetros públicos salen de `environment_variables`.

---

## 4. Archivos a modificar

### Frontend

- `…/templates/lib/features/quiz/application/strategy_factory.dart.scriban` — import del cliente nuevo; condición `mode == real` sin `apiKey`; texto del log.
- `…/templates/lib/features/quiz/application/strategy_config.dart.scriban` — eliminar el campo `apiKey` y el `import` de `parameters_initializer.dart`; queda `StrategyConfig({required this.promptTemplate})`.
- `…/templates/lib/features/quiz/config/ai_env.dart.scriban` — eliminar `keyApiKey`, `keyApiUrl`, `keyModel`, `defaultApiUrl`, `defaultModel`; `allKeys` pasa a `[keyPrompt]` (`requiredKeys` ya era `[keyPrompt]`, no cambia).
- `…/templates/lib/shared/env/env_config.dart.scriban` — eliminar los getters `apiKey`, `apiUrl` y `model` (solo los usaba el cliente eliminado); se conservan `promptTemplate` y `themeStyle`.
- `…/templates/assets/.env.dev.scriban` — borrar las líneas `API_KEY=…`, `API_URL=…`, `MODEL=…`. `API_BASE_URL` **se queda**.
- `…/templates/assets/.env.mock.scriban` — borrar `API_URL=…`, `API_KEY=mock-api-key`, `MODEL=mock-model`.

### Backend

- `…/templates/application-properties.scriban` — añadir el bloque `ai.*` (§2.1) al final.
- `…/templates/parameter-properties.scriban` — añadir `"ai-api-key"` a `EXCLUDED` (defensa en profundidad: hoy la clave vive en Secrets Manager y nunca se publica, pero si alguien la moviera a Parameter Store `getPublicParameters()` la filtraría a `GET /api/v1/parameters`). Una línea, sin cambio de comportamiento.

### Cloud

- `generator/components/cloud/aws/templates/up.ps1.scriban`:
  - `New-ApplicationSecretDefault`: nuevo caso `if ($Key -eq 'ai-api-key') { return 'AI_API_KEY_PLACEHOLDER' }`.
  - `Get-MissingApplicationSecretKey`: `$seededKeys` pasa a `@('jwt-secret','api-key','subscription-secret-key','subscription-webhook-secret','ai-api-key')`.
  - Nada más: `$script:PostApplyParameters` no cambia (los parámetros de IA son valores estáticos del JSON, no outputs de Terraform).

### Opcional (documentación, no bloquea)

- `…/templates/postman-collection.scriban:127` — el ejemplo de `GET /api/v1/parameters` sigue mostrando `{"api-url":"https://api.openrouter.ai/…","model":"gpt-4o-mini"}`. Si el developer lo actualiza a `{"ai-model":"gpt-4o-mini", …}` es cosmético; si no, queda como está. **No afecta a ningún criterio de aceptación.**

---

## 5. Configuración: nombres exactos de claves

### 5.1 AWS Secret Manager — una clave nueva

| Elemento | Valor |
|---|---|
| Secreto | `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}` (el ya existente; el contenedor en `terraform-secrets.scriban:6-13` y el nombre real lo produce `up.ps1.scriban:252`) |
| Clave JSON nueva | `ai-api-key` |
| Valor por defecto en `up.ps1` | `AI_API_KEY_PLACEHOLDER` |
| Propiedad Spring | `ai-api-key` (Spring Cloud AWS aplana cada clave JSON del secreto) |
| Formato en `application.properties` | `ai.api-key=${AI_API_KEY:${ai-api-key:}}` |

Orden de resolución: variable de entorno `AI_API_KEY` (desarrollo local) → clave `ai-api-key` del secreto (AWS) → cadena vacía.
**Nunca** se escribe en `application.properties`, en `.env.*`, en el `component.json` ni en el estado de Terraform.

### 5.2 AWS SSM Parameter Store — cuatro parámetros públicos

Se crean solos: `aws_ssm_parameter.environment` itera `var.environment_variables` (`terraform-ssm.scriban:3-9`) y las variables vienen de `environments[].variables` del JSON target. No hay que tocar Terraform.

| Clave SSM | Valor | Propiedad Spring | Default (local sin SSM) |
|---|---|---|---|
| `AI_API_BASE_URL` | `https://openrouter.ai/api/v1` | `ai.api-base-url` | mismo valor |
| `AI_MODEL` | `gpt-4o-mini` | `ai.model` | `gpt-4o-mini` |
| `AI_TEMPERATURE` | `0.7` | `ai.temperature` | `0.7` |
| `AI_MAX_TOKENS` | `1000` | `ai.max-tokens` | `1000` |

Estos cuatro sí se publican en `GET /api/v1/parameters` (son públicos por definición). La key **no**.

### 5.3 Local / mock sin API key

- **Local sin nada configurado**: los cuatro parámetros caen a sus defaults (arranca bien), `ai.api-key` queda `""` → `OpenRouterAdapter` responde `Mono.error(IllegalStateException("Falta la API key…"))` → 500. Log `warn` en el constructor al arrancar.
- **Mock** (`SERVICE_MODE=MOCK` / `AI_SERVICE_MODE=MOCK`, `.env.mock`): `StrategyFactory` devuelve `MockAIStrategy` y **nunca** llama al endpoint. El backend ni se consulta.
- **Develop real**: hay que sustituir `AI_API_KEY_PLACEHOLDER` por la key real en el secreto (lo hace el usuario en AWS; `up.ps1` solo siembra el placeholder y **no pisa valores existentes**, `up.ps1.scriban:403-419`).

---

## 6. Cambios en Terraform

**Ninguno.** Es deliberado y es la decisión de menor coste:

- **Secret Manager**: el contenedor ya existe (`module "secrets"`, `terraform-secrets.scriban:6-13`) y el módulo no modela claves, solo el `aws_secretsmanager_secret`. Añadir la clave es Sembrarla con `up.ps1`, que ya tiene el bucle `seededKeys` + `put-secret-value`. Sin CMK propia → **0 USD**.
- **SSM**: los parámetros nacen de `environment_variables`; añadir claves al JSON target es suficiente. **0 USD** (Parameter Store tiene 10 000 parámetros estándar gratis; aquí hay ~25).
- **Lambda IAM**: `terraform-lambda.scriban:44-50` ya concede `secretsmanager:GetSecretValue` sobre `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}-*` y `ssm:GetParametersByPath` sobre la ruta del microservicio. No hace falta ninguna política nueva → **0 USD** en IAM.
- **API Gateway**: ruta catch-all `ANY /{proxy+}` → el endpoint queda expuesto sin tocar rutas.
- **Coste AWS total del objetivo: 0 USD incrementales.** Lo único que ya existía y sigue costando: invocaciones de Lambda y tokens del proveedor.

## 7. Cambios en `up.ps1` para sembrar

Dos ediciones, en `generator/components/cloud/aws/templates/up.ps1.scriban`:

```powershell
# en New-ApplicationSecretDefault (antes del throw final)
if ($Key -eq 'ai-api-key') {
    return 'AI_API_KEY_PLACEHOLDER'
}
```

```powershell
# en Get-MissingApplicationSecretKey
$seededKeys = @('jwt-secret', 'api-key', 'subscription-secret-key', 'subscription-webhook-secret', 'ai-api-key')
```

Los parámetros públicos **no** los siembra `up.ps1`: los crea Terraform desde el JSON target (§5.2). `Update-PostApplyParameters` queda intacto.

---

## 8. Cambios en los `component.json`

### 8.1 `generator/components/backend/spring-boot-3.5.16/component.json`

Añadir 8 entradas a `files` (después de la línea 204, manteniendo el estilo de las existentes):

```json
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/domain/model/AiGeneration.java", "value": "templates/ai-generation.scriban" },
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/domain/ports/IAProviderPort.java", "value": "templates/ia-provider-port.scriban" },
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/domain/servicePorts/IAiServicePort.java", "value": "templates/iai-service-port.scriban" },
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/domain/usecase/AiUseCase.java", "value": "templates/ai-usecase.scriban" },
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/application/dto/AiGenerateRequestDTO.java", "value": "templates/ai-generate-request-dto.scriban" },
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/infrastructure/adapters/OpenRouterAdapter.java", "value": "templates/openrouter-adapter.scriban" },
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/infrastructure/adapters/OpenRouterChatRequest.java", "value": "templates/openrouter-chat-request.scriban" },
{ "key": "{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/infrastructure/controllers/AiController.java", "value": "templates/ai-controller.scriban" }
```

Sin entradas en `directories`: las carpetas destino (`domain/model`, `domain/ports`, `domain/servicePorts`, `domain/usecase`, `application/dto`, `infrastructure/adapters`, `infrastructure/controllers`) ya existen (`component.json:12-27`).
**Sin bloque `{{ if }}`**: se registran sin condición, igual que `SubscriptionController` (`component.json:204`) — ver §Dudas `question-001`.

### 8.2 `generator/components/frontend/flutter3.47.2/component.json`

- **Añadir** (mismo formato de las vecinas, `component.json:863-866`):

```json
{
    "key":  "frontend/{{ FRONTEND_NAME }}/lib/features/quiz/data/backend_ai_api_client.dart",
    "value":  "templates/lib/features/quiz/data/backend_ai_api_client.dart.scriban"
},
```

- **Eliminar 8 entradas**: `ai_api_client.dart` (línea 864), `openai_api_client.dart` (876), `openai_message.dart` (880), `openai_message.freezed.dart` (884), `openai_message.g.dart` (888), `openai_payload.dart` (892), `openai_payload.freezed.dart` (896), `openai_payload.g.dart` (900).
- **Borrar del disco** esas 8 plantillas `.scriban`. `i_api_client.dart` (868) **se conserva**: es el contrato.
- `pubspec.yaml` **no se toca**: `freezed` sigue usándose (`auth_tokens`, `question`, `quiz_generation_config`, `topic`, `history_item`, `log_entry`, `labeled_slider`).

### 8.3 `generator/components/cloud/aws/component.json`

**Sin cambios** (no hay plantilla nueva de cloud).

---

## 9. Estructura de JSON — `generator/target/com.quizsmart.app/com.quizsmart.app.json`

Único cambio: el bloque `environments[0].variables` (líneas 23-51).

- **Eliminar** `"API_URL": "https://openrouter.ai/api/v1/chat/completions"` (línea 31) — el backend ya no la necesita y el frontend tampoco.
- **Renombrar** `"MODEL": "gpt-4o-mini"` (línea 36) → `"AI_MODEL": "gpt-4o-mini"`. Se renombra en vez de duplicar para que exista **una sola fuente** del modelo (la consume el backend). Eliminar `MODEL` hace que Terraform lo borre de SSM en el siguiente apply; sin coste.
- **Añadir** tres claves junto a `SUBSCRIPTION_API_BASE_URL` (línea 38):

```json
"AI_API_BASE_URL": "https://openrouter.ai/api/v1",
"AI_MODEL": "gpt-4o-mini",
"AI_TEMPERATURE": "0.7",
"AI_MAX_TOKENS": "1000",
```

- **Se conservan** sin cambios: `SERVICE_MODE`, `AI_SERVICE_MODE`, `PROMPT`, `SUBSCRIPTION_API_BASE_URL`, el resto.
- **No se añade ninguna clave con la API key.** No hay bloque nuevo, no cambian `microservices`, `endpoints` ni `entities`.

```json
"variables": {
  "SERVICE_MODE": "REAL",
  "AI_SERVICE_MODE": "REAL",
  "PROMPT": "<sin cambios>",
  "AI_API_BASE_URL": "https://openrouter.ai/api/v1",
  "AI_MODEL": "gpt-4o-mini",
  "AI_TEMPERATURE": "0.7",
  "AI_MAX_TOKENS": "1000",
  "SUBSCRIPTION_API_BASE_URL": "https://api.revenuecat.com",
  "… resto sin cambios …"
}
```

---

## 10. Verificación prevista (sin ejecutar tests)

| # | Criterio de aceptación | Cómo se comprueba |
|---|---|---|
| 1 | `POST /api/v1/ai/generate` recibe prompt y devuelve la generación | `dotnet build` (generador) + inspección del diff de `ai-controller.scriban` contra `subscription-controller.scriban`. Si el usuario autoriza `dotnet run --project Generator.csproj` contra un target de prueba, se comprueba que el endpoint aparece en el proyecto generado. **Sin pruebas unitarias.** |
| 2 | Agnóstico: existe puerto y adaptador | `rg "interface IAProviderPort" generator/components/backend` → 1; `rg "implements IAProviderPort" → 1` (`OpenRouterAdapter`); `rg "openrouter" generator/components/backend/.../domain` → **0** (el dominio no conoce el proveedor). ArchUnit (`hexagonal-architecture-test.scriban:13-37`) valida esto cuando el usuario lance los tests. |
| 3 | La key está en Secret Manager, no en código ni en el frontend | `rg -i "api.?key" generator/components/frontend/flutter3.47.2/templates/assets` → **0**; `rg "OPENROUTER_API_KEY_PLACEHOLDER\|AI_API_KEY_PLACEHOLDER" generator/` → solo `up.ps1.scriban`; el valor real nunca está en el repo. Revisión manual de `application-properties.scriban`: solo `${AI_API_KEY:${ai-api-key:}}`. |
| 4 | Parámetros públicos en SSM | `rg "AI_API_BASE_URL\|AI_MODEL\|AI_TEMPERATURE\|AI_MAX_TOKENS" generator/target/com.quizsmart.app/com.quizsmart.app.json` → 4; cada una mapea a una propiedad `ai.*` en `application-properties.scriban`. No se puede verificar el `terraform plan` sin autorización (no se ejecuta). |
| 5 | El frontend consume el backend, no OpenRouter | `rg -i "openrouter\|openai" generator/components/frontend` → **0 coincidencias** (los 8 archivos eliminados eran las únicas). `strategy_factory.dart.scriban` importa `backend_ai_api_client.dart`. |
| 6 | Sin `openrouter.ai` en el frontend | covered por el punto 5 (`rg -i "openrouter"` sobre `generator/components/frontend`). |
| 7 | `.env.*` sin la API key | `rg "API_KEY" generator/components/frontend/flutter3.47.2/templates/assets` → **0**. |
| 8 | Plantillas registradas en `component.json` | Para cada clave nueva: `Test-Path` de la plantilla + `rg` de la clave en el `component.json` correspondiente → 1. Para cada clave eliminada: `rg` → 0 y `Test-Path` de la plantilla → `False`. `Test-Path` de todas las carpetas destino contra `directories` (ya existen). |
| 9 | El generador compila | `dotnet build` en `generator/` (permitido; no es un test). |
| 10 | No se rompen los endpoints existentes | Revisión del diff: solo se **añaden** entradas en los `component.json` (no se modifica ninguna clave existente salvo las 8 eliminadas, todas del cliente de IA); `application.properties` solo añade líneas `ai.*`; `parameter-properties` solo añade una entrada a `EXCLUDED`; `up.ps1` solo añade un caso y una clave a un array. `git diff --stat` no debe tocar `auth`, `subscription`, `parameters`, `dynamodb`, `cognito`, `sns/sqs`. |
| Extra | Placeholders Scriban resueltos | `rg "\{\{" <cada plantilla nueva o modificada>` → sin placeholders sin sustituir (solo `{{ PACKAGE }}`, que sí se sustituye). El propio generador falla antes de escribir si queda alguno (`generator/AGENTS.md`). |
| Extra | PowerShell válido | Inspección del diff de `up.ps1.scriban` (2 líneas lógicas). `up.ps1` generado no se ejecuta. |
| Extra | JSON válido | `python -m json.tool generator/target/com.quizsmart.app/com.quizsmart.app.json` y los tres `component.json`. |

---

## 11. Riesgos y plan de rollback

| Riesgo | Impacto | Mitigación / rollback |
|---|---|---|
| Endpoint de IA público sin auth ni rate limiting (aceptado en el objetivo): cualquiera que conozca la URL puede gastar tokens de OpenRouter. | Coste variable y presión de cuota. | Fuera de alcance por decisión explícita. Mitigación futura: authorizer en API Gateway o cuota por usuario. **No bloquea este objetivo.** |
| `up.ps1` no pisa valores existentes: si el secreto ya trae `ai-api-key` con un valor real, no se toca (correcto); si se cambia el nombre de la clave en el futuro, la vieja queda huérfana. | Bajo. | Hoy es clave nueva → se siembra placeholder. El usuario sustituye el valor en AWS. |
| Acoplamiento residual: `ApiResponse.data` es el cuerpo crudo del proveedor y el cliente sigue leyendo `choices[0].message.content`. | Cambiar de proveedor obligará a tocar `real_ai_strategy.dart`. | **Deliberado** (objetivo: "mantener la misma interfaz"). Punto de extensión: cuando se implemente un segundo proveedor, `IAProviderPort` + `AiGeneration.content` permiten responder `{"content": "..."}` y ajustar el parseo en un solo sitio. |
| `AiGeneration.providerPayload` filtra al cliente metadatos del proveedor (`id`, `model`, `usage`). | Bajo: no son secretos. | Si molesta, la Evolutionnatural es devolver solo `content`. |
| Eliminar las 6 plantillas Freezed de `openai_*` deja obsoletos esos ficheros en **proyectos ya generados** si se regenera sobre un árbol existente (el generador copia, no borra). | Ficheros huérfanos en el proyecto del usuario, no en el generador. | El developer debe avisar de que hay que borrar a mano `lib/features/quiz/data/openai_*.dart` y `ai_api_client.dart` del proyecto generado, o regenerar limpio. |
| Sin `spring-boot-starter-validation` no hay `@Valid`: la validación es manual en el controlador. | Si alguien añade campos al DTO sin validarlos, pasan sin control. | `MAX_PROMPT_LENGTH` y el blank check están centralizados en `AiController`; documentado en el propio archivo. |
| Compilación nativa GraalVM: `GraalHints` no registra los tipos nuevos. | Si `Graalvm` está activo, Jackson necesita hints para el record de salida (`OpenRouterChatRequest` solo se serializa; `AiGeneration` nunca se deserializa). Riesgo bajo. | `Graalvm` no está en el JSON target, así que la plantilla no se genera. Si algún objetivo lo activa, registrar hints. |
| Spring Boot devuelve 500 (no 502/503) cuando el proveedor falla. | Diagnóstico peor. | Consistente con el resto del microservicio (`GlobalExceptionHandler`). No se cambia el manejador global para no afectar a otros endpoints. |
| Quitar `MODEL` de SSM y `API_URL` hace que el `terraform plan` siguiente propague **borrados** de parámetros. | `terraform apply` los borra; sin coste, sin riesgo de datos. | Si molesta, se pueden dejar los parámetros huérfanos (no harm). `API_BASE_URL` no se toca. |

### Plan de rollback

1. **Generador (todo el cambio es de plantillas + JSON target, no de código generado):** `git checkout -- generator/` devuelve el generador a su estado previo; regenerar el proyecto. No hay estado en AWS que deshacer salvo los parámetros de SSM.
2. **SSM**: los cuatro parámetros nuevos se pueden borrar con `aws ssm delete-parameter` (o `terraform apply` tras revertir el JSON); el backend arranca igual porque todas las propiedades `ai.*` tienen default. El parámetro `MODEL` borrado se puede recrear con `aws ssm put-parameter`.
3. **Secreto**: `ai-api-key` es una clave más del JSON del secreto. Revertir `up.ps1` y quitar la clave del secreto (AWS CLI) deja el secreto como estaba; el backend ignora la clave sobrante.
4. **Frontend**: revertir las plantillas y el `component.json` restaura el cliente directo a OpenRouter (con su `API_KEY` en `.env.dev`); nada en el cliente depende del backend para arrancar.

---

## 12. Dudas resueltas

| # | Decisión | Justificación |
|---|---|---|
| `question-001` — ¿condicionar las plantillas de IA a `quizapi`? | **No condicionar**: se registran sin `{{ if }}`, como `SubscriptionController`/`RevenueCatAdapter` (`component.json:199-204`). | El componente es compartido y hoy solo existe `quizapi`; envolverlo ahora es cambio especulativo. Además, como todas las propiedades `ai.*` tienen default, un microservicio sin los parámetros **arranca igual** (solo falla al invocar el endpoint). Si mañana aparece otro microservicio, envolver las 8 plantillas en `{{ if(Name == "quizapi") }}` es un cambio de una línea por plantilla. |
| `question-002` — ¿clave `openrouter-api-key` nueva o reutilizar `api-key`? | **Clave nueva `ai-api-key`** (no `openrouter-api-key` como proponía el research). | El objetivo es agnosticismo: nombrar la clave con el proveedor la ata a OpenRouter y obligaría a migrar el secreto al cambiar de proveedor. `ai-api-key` casa con las propiedades `ai.*` y con `AI_API_KEY` en local. `api-key` se reutiliza para otra cosa y hoy no la lee el backend (`application-properties.scriban:44-48`). |
| `question-003` — ¿endpoint autenticado o público? | **Público**, como el resto de la API actual. | API Gateway es HTTP API sin authorizer (`terraform-apigateway.scriban`) y el backend no tiene filtro de auth activo (`jwt-authentication-filter.scriban` no está registrado). Añadir auth sería cambio de alcance, tocaría el microservicio `security` y varios componentes. **Riesgo asumido y documentado** (§11): sin rate limiting, un endpoint público de IA es susceptible de abuso que sí genera coste. |
| `question-004` — ¿forma de la respuesta? | **`ApiResponse` con `data` = cuerpo crudo del proveedor** (usando el constructor `ApiResponse(Map,…)`, no el de `Object`). | `real_ai_strategy.dart.scriban:46-53` lee `body['choices'][0]['message']['content']`; el cliente nuevo devuelve `jsonDecode(body)['data']` y no se toca la estrategia. El constructor `ApiResponse(Object,…)` habría creado un nivel extra `{"data":{"data":…}}` — de ahí la variable `Map<String,Object>` tipada en el controlador. |
| `question-005` — ¿qué decide mock vs real sin `API_KEY`? | **`mode == real`**; `StrategyConfig` deja de leer `apiKey`. `AI_SERVICE_MODE` sigue siendo el interruptor. | El backend es ahora quien autentica al proveedor; la key no puede estar en el cliente. Efecto colateral aceptado: en `develop` (`AI_SERVICE_MODE=REAL`) antes caía a mock por falta de `API_KEY` y ahora **sí** intenta el endpoint real; con la key sin sembrar devuelve 500 y la app lo muestra como error de generación. Es el comportamiento correcto del objetivo (mock explícito con `AI_SERVICE_MODE=MOCK`). |

### Dudas que siguen abiertas

Ninguna bloqueante. Queda una **observación de futuro** (no bloquea, no se implementa aquí): con el endpoint público y sin rate limiting, un abuso genera coste real en el proveedor; mitigación recomendada en un objetivo posterior (authorizer en API Gateway o cuota por `X-User-Id`).

---

## 13. Lista de tareas y subtareas

- [ ] **Tarea 1 — Backend (componente `spring-boot-3.5.16`)**
  - [ ] 1.1: crear `ai-generation.scriban`, `ia-provider-port.scriban`, `iai-service-port.scriban`, `ai-usecase.scriban` (§2.1, contratos literales)
  - [ ] 1.2: crear `ai-generate-request-dto.scriban`, `openrouter-chat-request.scriban`
  - [ ] 1.3: crear `openrouter-adapter.scriban` (WebClient, `extractContent` defensivo, guarda de key vacía)
  - [ ] 1.4: crear `ai-controller.scriban` (validación `MAX_PROMPT_LENGTH`, `ApiResponse` con `data` tipado `Map`)
  - [ ] 1.5: modificar `application-properties.scriban` (bloque `ai.*`) y `parameter-properties.scriban` (`EXCLUDED += "ai-api-key"`)
  - [ ] 1.6: registrar las 8 plantillas en `component.json` (§8.1)
- [ ] **Tarea 2 — Frontend (componente `flutter3.47.2`)**
  - [ ] 2.1: crear `backend_ai_api_client.dart.scriban` (§2.2)
  - [ ] 2.2: modificar `strategy_factory.dart.scriban` y `strategy_config.dart.scriban`
  - [ ] 2.3: modificar `ai_env.dart.scriban` y `env_config.dart.scriban` (quitar `apiKey`/`apiUrl`/`model`)
  - [ ] 2.4: modificar `.env.dev.scriban` y `.env.mock.scriban` (quitar `API_KEY`, `API_URL`, `MODEL`)
  - [ ] 2.5: actualizar `component.json` (añadir 1, eliminar 8) y borrar las 8 plantillas huérfanas del disco
  - [ ] 2.6 (opcional): refrescar el ejemplo de `postman-collection.scriban:127`
- [ ] **Tarea 3 — Cloud (componente `aws`)**
  - [ ] 3.1: `up.ps1.scriban` → `New-ApplicationSecretDefault` (`ai-api-key`) + `$seededKeys`
  - [ ] 3.2: confirmar que **no** se toca ningún `terraform-*.scriban` (§6) y que `component.json` de cloud no cambia
- [ ] **Tarea 4 — Entrada del generador**
  - [ ] 4.1: `generator/target/com.quizsmart.app/com.quizsmart.app.json` → quitar `API_URL`, renombrar `MODEL` → `AI_MODEL`, añadir `AI_API_BASE_URL`, `AI_TEMPERATURE`, `AI_MAX_TOKENS` (§9)
- [ ] **Tarea 5 — Verificación (sin tests)**
  - [ ] 5.1: `dotnet build` en `generator/`
  - [ ] 5.2: `rg` de verificación de §10 (criterios 2, 3, 5, 6, 7, 8)
  - [ ] 5.3: validar los 4 JSON y revisar `git diff --stat` (criterio 10)
  - [ ] 5.4: `implementation-001.md` con archivos, verificación, coste AWS (0 USD) y los 2 puntos que requieren acción manual del usuario (sustituir el placeholder del secreto; borrar ficheros huérfanos en el proyecto ya generado)