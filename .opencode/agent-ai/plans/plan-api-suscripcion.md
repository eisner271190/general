# Plan: API Suscripción — Mover RevenueCat del Frontend al Backend

**Tarea del TODO:** API Suscripción (línea 36-37 de `.opencode/agent-ai/docs/todo.md`)
**Fecha:** 2026-09-29

## 1. Descripción

Actualmente la suscripción con RevenueCat está implementada 100% en el frontend Flutter. Esto expone la API key pública y permite que el cliente manipule el estado de suscripción sin verificación en servidor. Se necesita extraer el consumo de RevenueCat al backend Spring Boot, de modo que:

- La API key **secret** de RevenueCat viva solo en el backend (AWS Secrets Manager)
- El backend reciba webhooks de RevenueCat con los eventos asíncronos (renovaciones, cancelaciones, reembolsos)
- El backend verifique el estado de suscripción vía REST API de RevenueCat bajo demanda
- El frontend consulte su estado de suscripción al backend (no directamente a RevenueCat)
- **Sync-on-Purchase:** tras una compra exitosa, el frontend fuerza una sincronización inmediata vía `POST /api/v1/subscriptions/sync` para evitar race conditions con webhooks

## 2. Objetivo

1. **Eliminar la API key secreta del frontend** — el frontend solo necesita la key pública para iniciar el SDK de RevenueCat (necesaria para el flujo de compra nativo), pero la verificación de suscripción se hace en el backend.
2. **Backend como fuente de verdad** — el backend mantiene el estado de suscripción del usuario sincronizado con RevenueCat.
3. **Frontend consulta al backend** — el frontend verifica su suscripción llamando `GET /api/v1/subscriptions/status` en lugar de confiar en el SDK local.
4. **Sync-on-Purchase** — tras una compra exitosa, el frontend llama `POST /api/v1/subscriptions/sync` para forzar la sincronización inmediata vía REST API de RevenueCat, evitando race conditions con webhooks.
5. **Webhooks para eventos asíncronos** — el backend recibe eventos de renovación, cancelación, reembolso y expiración (no de compra inicial, que se maneja con sync-on-purchase).

## 3. Estado actual vs. nuevo

### Actual (frontend-only)
```text
┌─────────────────────────────────────────────────────┐
│  Frontend (Flutter)                                 │
│  ┌───────────────────────────────────────────────┐  │
│  │ RevenueCatProvider                            │  │
│  │  - Purchases.configure(publicKey)             │  │
│  │  - Purchases.getOfferings()                   │  │
│  │  - Purchases.getCustomerInfo()                │  │
│  │  - StreamController<bool>                     │  │
│  │  - SharedPreferences cache                    │  │
│  └───────────────────────────────────────────────┘  │
│  PaywallWidget ← escucha stream local              │
└─────────────────────────────────────────────────────┘
         │
         ▼
   RevenueCat Cloud
```

### Nuevo (backend-verificado)
```text
┌─────────────────────────────────────────────────────┐
│  Frontend (Flutter)                                 │
│  ┌───────────────────────────────────────────────┐  │
│  │ RevenueCatProvider (simplificado)             │  │
│  │  - Purchases.configure(publicKey)             │  │
│  │  - Purchases.purchasePackage()                │  │
│  │  - POST /api/v1/subscriptions/sync (tras pay)  │  │
│  │  - GET /api/v1/subscriptions/status           │  │
│  └───────────────────────────────────────────────┘  │
│  PaywallWidget ← escucha respuesta backend         │
└─────────────────────────────────────────────────────┘
         │                           ▲
         │ purchase                  │ status
         ▼                           │
┌─────────────────────────────────────────────────────┐
│  Backend (Spring Boot)                              │
│  ┌───────────────────────────────────────────────┐  │
│  │ SubscriptionController                        │  │
│  │  POST /api/v1/subscriptions/webhook           │  │
│  │  GET  /api/v1/subscriptions/status            │  │
│  └───────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────┐  │
│  │ RevenueCatService                             │  │
│  │  - verifyWebhookSignature()                   │  │
│  │  - handleWebhookEvent()                       │  │
│  │  - fetchCustomerInfo() → RC REST API          │  │
│  └───────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────┐  │
│  │ SubscriptionRepository (DynamoDB)             │  │
│  │  - saveSubscription()                          │  │
│  │  - findActiveSubscription()                    │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
         │
         ▼
   RevenueCat Cloud (webhooks + REST API)
```

## 4. Referencias web

| Referencia | Aporte |
|---|---|
| [Backend Architecture - RevenueCat](https://www.revenuecat.com/guides/revenuecat-android-sdk/backend-architecture) | El backend es el servidor de verificación; webhooks + REST API |
| [Webhooks - RevenueCat Docs](https://www.revenuecat.com/docs/integrations/webhooks) | Eventos de suscripción, HMAC signing, idempotencia, retries |
| [Event Types and Fields](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields) | Tipos de eventos: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION |
| [Webhook Signature Verification (HMAC)](https://www.revenuecat.com/docs/integrations/webhooks#webhook-signature-verification-hmac) | Verificación HMAC-SHA256 del webhook |
| [Syncing Subscription Status](https://community.revenuecat.com/sdks-51/should-i-rely-on-both-webhooks-and-the-api-for-latest-purchases-7051) | Llamar GET /subscribers tras recibir webhook para sync |
| [Common Webhook Flows](https://www.revenuecat.com/docs/integrations/webhooks/event-flows) | Flujos de eventos: cancelación, billing issue, expiración |

## 5. Estructuras JSON

### 5.1 — Webhook payload (RevenueCat → Backend)

JSON que RevenueCat envía al backend vía `POST /api/v1/subscriptions/webhook`:

```json
{
  "api_version": "1.0",
  "event": {
    "id": "evt_abc123",
    "type": "INITIAL_PURCHASE",
    "app_user_id": "user_42",
    "product_id": "premium_monthly",
    "period_type": "NORMAL",
    "purchased_at_ms": 1727600000000,
    "expiration_at_ms": 1730278400000,
    "store": "PLAY_STORE",
    "environment": "PRODUCTION",
    "entitlement_ids": ["premium"],
    "transaction_id": "GPA.1234-5678-9012-34567",
    "event_timestamp_ms": 1727600000000
  }
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `api_version` | String | Versión del formato de webhook (siempre `"1.0"`) |
| `event` | Object | Contenedor del evento |
| `event.id` | String | ID único del evento. Se usa como clave de idempotencia |
| `event.type` | String | Tipo de evento: `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`, `BILLING_ISSUE`, `UNCANCELLATION` |
| `event.app_user_id` | String | ID del usuario en RevenueCat (coincide con el `userId` del JWT) |
| `event.product_id` | String | ID del producto comprado (ej: `"premium_monthly"`) |
| `event.period_type` | String | Tipo de período: `TRIAL`, `INTRO`, `NORMAL`, `PROMOTIONAL` |
| `event.purchased_at_ms` | Long | Timestamp de compra en milisegundos |
| `event.expiration_at_ms` | Long | Timestamp de expiración en milisegundos |
| `event.store` | String | Tienda: `PLAY_STORE`, `APP_STORE`, `STRIPE` |
| `event.environment` | String | Ambiente: `PRODUCTION` o `SANDBOX` |
| `event.entitlement_ids` | Array | IDs de entitlements activados (no se usan en esta implementación simplificada) |
| `event.transaction_id` | String | ID de la transacción en la tienda |
| `event.event_timestamp_ms` | Long | Timestamp del evento en milisegundos |

### 5.2 — DTO de respuesta (Backend → Frontend)

JSON que el backend retorna en `GET /api/v1/subscriptions/status`:

```json
{
  "data": {
    "isActive": true,
    "productId": "premium_monthly",
    "expirationDate": "2026-10-29T00:00:00Z"
  },
  "message": "Subscription status retrieved successfully",
  "statusCode": 200
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `data` | Object | Contenedor de la respuesta |
| `data.isActive` | Boolean | `true` si el usuario tiene suscripción activa |
| `data.productId` | String | ID del producto de la suscripción |
| `data.expirationDate` | String (ISO 8601) | Fecha de expiración de la suscripción |
| `message` | String | Mensaje descriptivo del resultado |
| `statusCode` | Integer | Código de estado HTTP |

### 5.3 — DTO de webhook (interno)

JSON que el backend usa internamente para procesar el webhook:

```json
{
  "eventId": "evt_abc123",
  "eventType": "INITIAL_PURCHASE",
  "userId": "user_42",
  "productId": "premium_monthly",
  "status": "ACTIVE",
  "purchasedAtMs": 1727600000000,
  "expirationAtMs": 1730278400000
}
```

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `eventId` | String | ID único del evento (idempotencia) |
| `eventType` | String | Tipo de evento mapeado al strategy |
| `userId` | String | ID del usuario (del JWT o de RevenueCat) |
| `productId` | String | ID del producto comprado |
| `status` | String | Estado calculado: `ACTIVE`, `CANCELLED`, `EXPIRED`, `GRACE_PERIOD` |
| `purchasedAtMs` | Long | Timestamp de compra |
| `expirationAtMs` | Long | Timestamp de expiración |

## 6. Tareas de implementación

### Tarea 1 — Entidad de suscripción en DynamoDB

Crear plantilla de entidad de persistencia para almacenar el estado de suscripción del usuario.

**Archivo a crear:** `infrastructure/persistence/entities/subscription-entity.scriban`

```java
@DynamoDbBean
public class SubscriptionEntity {
    @DynamoDbPartitionKey
    private String userId;              // app_user_id de RevenueCat (PK: USER#123)
    private String productId;           // ej: "premium_monthly"
    private String status;              // ACTIVE, CANCELLED, EXPIRED, GRACE_PERIOD, INACTIVE
    private String store;               // PLAY_STORE, APP_STORE, STRIPE
    private String originalTransactionId; // ID de transacción para conciliación
    private Long purchasedAtMs;
    private Long expirationAtMs;
    private Long expirationTTL;         // TTL de DynamoDB para limpieza automática
    private Long updatedAtMs;
    // getters/setters
}
```

**Archivo a crear:** `infrastructure/persistence/dynamos/tableschema/subscription-table-schema.scriban`

Tabla DynamoDB: `{{ Name }}Subscription` con partition key `userId` (String).

**Nota:** Solo un nivel de suscripción (premium). No se usa `entitlementId` — el estado se maneja como flag booleano `isActive` derivado del `status`.

**Idempotencia:** Crear tabla separada `{{ Name }}WebhookEvent` con PK: `EVENT#{eventId}` y TTL de 24h para evitar mezclar registros de usuario con eventos procesados.

---

### Tarea 2 — Puertos de dominio y servicios de aplicación

**Archivo a crear:** `domain/ports/subscription-port.scriban`

```java
public interface SubscriptionPort {
    Mono<Subscription> findActiveSubscription(String userId);
    Mono<Subscription> saveSubscription(Subscription subscription);
    Mono<Subscription> updateStatus(String userId, String status);
}
```

**Archivo a crear:** `domain/servicePorts/isubscription-service-port.scriban`

```java
public interface ISubscriptionServicePort {
    Mono<SubscriptionStatusResponse> getStatus(String userId);
}
```

**Archivo a crear:** `domain/servicePorts/iwebhook-service-port.scriban`

```java
public interface IWebhookServicePort {
    Mono<Void> processWebhook(WebhookEvent event);
}
```

**Archivo a crear:** `domain/usecase/subscription-usecase.scriban`

Caso de uso que implementa `ISubscriptionServicePort`:
- `getStatus(userId)` → consulta DynamoDB. Si no existe, llama a RevenueCat REST API. Si RevenueCat devuelve sin suscripción, **guarda en DynamoDB con status INACTIVE y TTL corto** para evitar saturar la API.
- `syncFromRevenueCat(userId)` → fuerza sincronización: llama RevenueCat REST API, actualiza DynamoDB, retorna estado actual. Usado tras compra exitosa.

**Archivo a crear:** `domain/usecase/webhook-usecase.scriban`

Caso de uso que implementa `IWebhookServicePort`:
- `processWebhook(event)` → delega al `WebhookFacade` (R9)

---

### Tarea 3 — Adaptador RevenueCat (REST API + Webhook)

**Archivo a crear:** `infrastructure/adapters/revenuecat-adapter.scriban`

```java
@Component
public class RevenueCatAdapter {
    private final WebClient webClient;
    private final String secretApiKey;  // desde AWS Secrets Manager

    public Mono<CustomerInfo> fetchCustomerInfo(String appUserId) {
        return webClient.get()
            .uri("/v1/subscribers/{appUserId}", appUserId)
            .header("Authorization", "Bearer " + secretApiKey)
            .retrieve()
            .bodyToMono(CustomerInfo.class);
    }
}
```

**Configuración en `application.properties.scriban`:**
```properties
revenuecat.secret-key=${REVENUECAT_SECRET_KEY:}
revenuecat.webhook-secret=${REVENUECAT_WEBHOOK_SECRET:}
revenuecat.api-base-url=https://api.revenuecat.com
```

**Nota:** `REVENUECAT_SECRET_KEY` y `REVENUECAT_WEBHOOK_SECRET` se almacenan en **AWS Secrets Manager** como una única secret por app (ej: `quizsmart/revenuecat`). Se añaden a la lista `EXCLUDED` de `parameter-properties.scriban` (ya están excluidos por el patrón `REVENUECAT_*`).

---

### Tarea 4 — Controlador REST de suscripción

**Archivo a crear:** `infrastructure/controllers/subscription-controller.scriban`

```java
@RestController
@RequestMapping("/api/v1/subscriptions")
public class SubscriptionController {

    // Webhook de RevenueCat (público, protegido por HMAC WebFilter)
    @PostMapping("/webhook")
    public Mono<ResponseEntity<ApiResponse>> handleWebhook(@RequestBody WebhookEvent event) {
        // El WebFilter ya verificó el HMAC. Solo delegar al servicio.
        return webhookService.processWebhook(event)
            .thenReturn(ApiResponse.ok("Webhook processed"));
    }

    // Estado de suscripción del usuario autenticado
    @GetMapping("/status")
    public Mono<ResponseEntity<ApiResponse>> getStatus(@AuthenticationPrincipal Jwt jwt) {
        String userId = extractUserId(jwt);
        return subscriptionService.getStatus(userId)
            .map(ApiResponse::ok);
    }

    // Sync-on-Purchase: forzar sincronización tras compra exitosa
    @PostMapping("/sync")
    public Mono<ResponseEntity<ApiResponse>> sync(@AuthenticationPrincipal Jwt jwt) {
        String userId = extractUserId(jwt);
        return subscriptionService.syncFromRevenueCat(userId)
            .map(ApiResponse::ok);
    }

    private String extractUserId(Jwt jwt) {
        return jwt.getSubject();
    }
}
```

---

### Tarea 5 — DTOs y mappers

**Archivos a crear:**
- `application/dto/subscription-status-response-dto.scriban` — respuesta con `isActive`, `productId`, `expirationDate`
- `application/dto/webhook-event-dto.scriban` — payload del webhook de RevenueCat
- `application/mappers/subscription-status-mapper-dto.scriban` — mapper MapStruct

---

### Tarea 6 — Simplificación del frontend

**Archivos a modificar:**
- `lib/providers/revenuecat/revenuecat_provider.dart.scriban` — eliminar `getCustomerInfo()`, `getOfferings()`, cache en SharedPreferences. Mantener solo `configure()` y `purchasePackage()`.
- `lib/core/monetization_initializer.dart.scriban` — tras purchase, llamar `GET /api/v1/subscriptions/status` al backend.
- `lib/ui/paywall_widget.dart.scriban` — consultar estado al backend en lugar del stream local.

---

### Tarea 7 — Verificación HMAC del webhook (WebFilter)

**Problema:** En Spring WebFlux, el body es un `Flux<DataBuffer>`. Leerlo como `String` en el Controller puede causar discrepancias por re-serialización JSON.

**Solución:** Usar un `WebFilter` que intercepte el `DataBuffer` crudo antes del de-serializer JSON.

**Archivo a crear:** `infrastructure/configuration/webfilters/revenuecat-webhook-filter.scriban`

```java
@Component
public class RevenueCatWebhookFilter implements WebFilter {
    private final String webhookSecret;

    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        if (!isWebhookRequest(exchange)) {
            return chain.filter(exchange);
        }
        return readRawBody(exchange)
            .flatMap(rawBody -> verifyHmac(rawBody, exchange))
            .flatMap(isValid -> isValid 
                ? chain.filter(exchange) 
                : unauthorized(exchange));
    }

    private boolean isWebhookRequest(ServerWebExchange exchange) {
        return exchange.getRequest().getPath().value().contains("/subscriptions/webhook");
    }

    private Mono<String> readRawBody(ServerWebExchange exchange) {
        // Leer DataBuffer crudo sin serializar
    }

    private Mono<Boolean> verifyHmac(String rawBody, ServerWebExchange exchange) {
        // 1. Parsear "t=<timestamp>,v1=<hmac>" del header
        // 2. Calcular HMAC-SHA256 de "{timestamp}.{rawBody}"
        // 3. Comparar en tiempo constante
        // 4. Rechazar si |now - timestamp| > 5 minutos
    }
}
```

---

### Tarea 8 — Manejo de eventos webhook (Strategy + Facade)

**R4 (Strategy):** cada tipo de evento tiene su propia implementación.

**Archivo a crear:** `domain/usecase/webhook-strategy.scriban`

```java
public interface IWebhookStrategy {
    String eventType();
    Mono<Void> handle(WebhookEvent event);
}
```

**Archivos a crear (una implementación por evento):**
- `domain/usecase/strategies/renewal-strategy.scriban` → Actualiza `expirationAtMs`, status ACTIVE
- `domain/usecase/strategies/cancellation-strategy.scriban` → Status CANCELLED
- `domain/usecase/strategies/expiration-strategy.scriban` → Status EXPIRED
- `domain/usecase/strategies/billing-issue-strategy.scriban` → Status GRACE_PERIOD
- `domain/usecase/strategies/uncancellation-strategy.scriban` → Restaura status ACTIVE

**Nota:** `INITIAL_PURCHASE` no tiene strategy — se maneja con `POST /api/v1/subscriptions/sync` (sync-on-purchase).

**R9 (Facade):** el `WebhookUseCase` delega al strategy correspondiente.

**Archivo a crear:** `domain/usecase/webhook-usecase.scriban`

```java
@Component
public class WebhookUseCase implements IWebhookServicePort {
    private final Map<String, IWebhookStrategy> strategies;

    public Mono<Void> processWebhook(WebhookEvent event) {
        return findStrategy(event.getType())
            .handle(event);
    }

    private IWebhookStrategy findStrategy(String eventType) {
        return strategies.getOrDefault(eventType, new UnknownEventStrategy());
    }
}
```

**Idempotencia:** usar `event.id` como clave de deduplicación (guardar en DynamoDB con TTL).

## 7. Flujo de datos

1. **Compra en el app (Sync-on-Purchase):**
   - Frontend llama `Purchases.purchasePackage()` con la key pública
   - RevenueCat procesa el pago
   - Frontend llama `POST /api/v1/subscriptions/sync` con JWT
   - Backend llama `GET /v1/subscribers/{userId}` a RevenueCat REST API
   - Backend actualiza DynamoDB con el estado real
   - Backend responde con el estado actualizado inmediatamente

2. **Consulta de estado:**
   - Frontend llama `GET /api/v1/subscriptions/status` con JWT
   - Backend extrae `userId` del JWT → consulta DynamoDB → retorna estado
   - Si no hay registro en DynamoDB, backend llama RevenueCat REST API como fallback
   - Si RevenueCat devuelve sin suscripción, **guarda en DynamoDB con status INACTIVE y TTL corto** para evitar saturar la API

3. **Eventos asíncronos (webhooks):**
   - RevenueCat → webhook → backend → actualiza DynamoDB
   - Solo para: renovaciones, cancelaciones, reembolsos, expiraciones
   - No para compra inicial (se maneja con sync-on-purchase)

4. **Modo offline (frontend):**
   - Frontend guarda último estado del backend en almacenamiento seguro (`flutter_secure_storage`)
   - Si no hay conexión, usa el estado cacheado con timestamp
   - Al volver a conexión, consulta al backend para actualizar

## 8. Archivos a crear

| Archivo | Propósito |
|---------|-----------|
| `infrastructure/persistence/entities/subscription-entity.scriban` | Entidad DynamoDB de suscripción |
| `infrastructure/persistence/entities/webhook-event-entity.scriban` | Entidad DynamoDB para idempotencia de webhooks |
| `infrastructure/persistence/dynamos/tableschema/subscription-table-schema.scriban` | Esquema de tabla DynamoDB |
| `infrastructure/persistence/dynamos/tableschema/webhook-event-table-schema.scriban` | Esquema de tabla para eventos procesados |
| `domain/ports/subscription-port.scriban` | Puerto de dominio para persistencia |
| `domain/servicePorts/isubscription-service-port.scriban` | Puerto de servicio para consulta/sync |
| `domain/servicePorts/iwebhook-service-port.scriban` | Puerto de servicio para webhooks |
| `domain/usecase/subscription-usecase.scriban` | Caso de uso: consulta de estado + sync |
| `domain/usecase/webhook-usecase.scriban` | Caso de uso: procesamiento de webhooks (Facade R9) |
| `domain/usecase/webhook-strategy.scriban` | Interfaz Strategy para eventos (R4) |
| `domain/usecase/strategies/renewal-strategy.scriban` | Strategy: RENEWAL |
| `domain/usecase/strategies/cancellation-strategy.scriban` | Strategy: CANCELLATION |
| `domain/usecase/strategies/expiration-strategy.scriban` | Strategy: EXPIRATION |
| `domain/usecase/strategies/billing-issue-strategy.scriban` | Strategy: BILLING_ISSUE |
| `domain/usecase/strategies/uncancellation-strategy.scriban` | Strategy: UNCANCELLATION |
| `domain/usecase/strategies/unknown-event-strategy.scriban` | Strategy: eventos desconocidos (fallback) |
| `infrastructure/adapters/revenuecat-adapter.scriban` | Cliente REST API de RevenueCat |
| `infrastructure/configuration/webfilters/revenuecat-webhook-filter.scriban` | WebFilter para verificación HMAC |
| `infrastructure/controllers/subscription-controller.scriban` | Controlador REST |
| `application/dto/subscription-status-response-dto.scriban` | DTO de respuesta |
| `application/dto/webhook-event-dto.scriban` | DTO de webhook |
| `application/mappers/subscription-status-mapper-dto.scriban` | Mapper MapStruct |

## 9. Archivos a modificar

| Archivo | Cambio |
|---------|--------|
| `application.properties.scriban` | Añadir `revenuecat.secret-key`, `revenuecat.webhook-secret`, `revenuecat.api-base-url` |
| `parameter-properties.scriban` | Verificar que `REVENUECAT_SECRET_KEY` y `REVENUECAT_WEBHOOK_SECRET` estén en lista EXCLUDED |
| `lib/providers/revenuecat/revenuecat_provider.dart.scriban` | Eliminar lógica de CustomerInfo, cache local; mantener solo purchase + sync |
| `lib/core/monetization_initializer.dart.scriban` | Llamar `POST /api/v1/subscriptions/sync` tras purchase |
| `lib/ui/paywall_widget.dart.scriban` | Consultar estado al backend + fallback offline con `flutter_secure_storage` |
| `pubspec.yaml.scriban` | Añadir dependencia `flutter_secure_storage` para cache offline |

## 10. Preguntas y recomendaciones

1. **¿El frontend necesita la key pública de RevenueCat?**
   → *Sí*, para iniciar el SDK y procesar el pago nativo. La key pública no es secreta (se incrusta en el app). Lo que **no** debe estar en el frontend es la **key secreta** (REST API) ni el **webhook secret**.

2. **¿Qué pasa si el webhook falla o se retrasa?**
   → *Recomendación:* El frontend siempre consulta al backend. Si el webhook no ha llegado, el backend puede hacer fallback a `GET /v1/subscribers/{userId}` de RevenueCat bajo demanda.

3. **¿DynamoDB o R2DBC para persistencia?**
   → *Recomendación:* DynamoDB, porque el backend ya lo usa y es serverless-friendly (bajo costo, sin gestión de conexiones).

4. **¿Cómo manejar la idempotencia de webhooks?**
   → *Recomendación:* Guardar `event.id` en DynamoDB con TTL de 24h. Si ya existe, retornar 200 sin reprocesar.

5. **¿El endpoint `/status` requiere autenticación?**
   → *Sí*, debe requerir JWT. El `userId` se extrae del token, no del body.

6. **¿Qué pasa con los usuarios que ya tienen suscripción activa en el frontend?**
   → *Recomendación:* En el primer login tras el deploy, el backend no tendrá registro. El fallback a RevenueCat REST API cubre este caso. Opcional: script de migración que consulte RevenueCat para usuarios existentes.

7. **¿Cómo evitar la race condition tras la compra?**
   → *Recomendación:* Implementar `POST /api/v1/subscriptions/sync` (sync-on-purchase). El frontend lo llama inmediatamente tras una compra exitosa. El backend consulta RevenueCat REST API sincrónicamente y responde con el estado real.

8. **¿Cómo verificar el HMAC en Spring WebFlux?**
   → *Recomendación:* Usar un `WebFilter` que intercepte el `DataBuffer` crudo antes del de-serializer JSON. No usar `@RequestBody String` porque el body en WebFlux es un `Flux<DataBuffer>` y puede haber discrepancias por re-serialización.

9. **¿Cómo evitar saturar la REST API de RevenueCat con usuarios free?**
   → *Recomendación:* Cuando RevenueCat devuelve sin suscripción, guardar en DynamoDB con status `INACTIVE` y TTL corto (ej: 24h). Así no se consulta a RevenueCat en cada llamada a `/status`.

10. **¿Cómo manejar el modo offline en el frontend?**
    → *Recomendación:* Guardar el último estado del backend en `flutter_secure_storage` con timestamp. Si no hay conexión, usar el estado cacheado. Al volver a conexión, consultar al backend.

## 11. Decisiones tomadas

1. **Sync-on-Purchase + Webhooks** — `POST /sync` para compra inmediata (evita race condition), webhooks solo para eventos asíncronos (renovaciones, cancelaciones, reembolsos).
2. **DynamoDB para persistencia** — consistente con la arquitectura actual del backend. Tabla separada para idempotencia de webhooks.
3. **Frontend conserva la key pública** — necesaria para el flujo de compra nativo; la key secreta va al backend (AWS Secrets Manager).
4. **Verificación HMAC con WebFilter** — interceptar `DataBuffer` crudo antes del de-serializer JSON para evitar discrepancias.
5. **Idempotencia por event.id** — tabla separada `WebhookEvent` con PK `EVENT#{eventId}` y TTL 24h.
6. **JWT para autenticar /status y /sync** — el userId viene del token, no del cliente.
7. **Un solo nivel de suscripción** — no se usa `entitlementId`; el estado es un flag booleano `isActive` derivado del `status`.
8. **SRP (Clean Code)** — separar `SubscriptionUseCase` (consulta/sync) de `WebhookUseCase` (procesamiento).
9. **R4 Strategy (EPC)** — cada tipo de evento webhook asíncrono tiene su propia implementación Strategy.
10. **R9 Facade (EPC)** — `WebhookUseCase` actúa como Facade que delega al strategy correspondiente.
11. **R1 (EPC)** — métodos pequeños (<20 líneas), delegando a métodos auxiliares.
12. **Fallback INACTIVE** — si RevenueCat devuelve sin suscripción, guardar en DynamoDB con status INACTIVE y TTL corto para evitar saturar la API.
13. **TTL en DynamoDB** — campo `expirationTTL` para limpieza automática de registros expirados.
14. **Modo offline** — frontend guarda último estado en `flutter_secure_storage` con timestamp como fallback.

## 12. Costos

| Concepto | Costo |
|----------|-------|
| **Infraestructura AWS** | ~$0 — DynamoDB on-demand (pocos registros), sin recursos adicionales |
| **Esfuerzo de implementación** | ~20 archivos nuevos + 5 modificados. Estimado: 3-4 sesiones de trabajo |
| **Impacto de contexto/tokens** | Medio — plantillas Scriban + código Java + Dart |
| **RevenueCat** | **Gratis hasta $2,500 MTR** (Monthly Tracked Revenue), luego 1% de MTR. Webhooks incluidos en todos los planes |

## 13. Fuera de alcance

- Migración de usuarios existentes con suscripción activa (se cubre con fallback al REST API)
- Gestión de planes/precios desde el backend (sigue en RevenueCat Dashboard)
- Integración con App Store / Google Play directo (RevenueCat lo gestiona)
- Notificaciones push de eventos de suscripción (tarea separada: API Notifications)
- Cache de CustomerInfo en ElastiCache (tarea separada: AWS ElastiCache)
