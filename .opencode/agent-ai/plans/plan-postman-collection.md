# Plan: Colección Postman por microservicio generada por el componente backend

**Tarea del TODO:** N/A — solicitado directamente (rama `feature/postman-collection`)
**Fecha:** 2026-09-26

## 1. Descripción
El componente `spring-boot-3.5.16` no expone los endpoints de los microservicios generados en un formato ejecutable. Se pide una colección Postman **por microservicio** con todos los endpoints de todas las APIs, que quede en la carpeta backend del proyecto generado.

## 2. Objetivo
Que cada microservicio generado incluya `<MICROSERVICE_NAME>/postman/<MICROSERVICE_NAME>.postman_collection.json` (formato Collection v2.1) con una carpeta por dominio/controller, requests completos (headers, auth, bodies de ejemplo, scripts) y `baseUrl` apuntando a la **URL del API Gateway** obtenida con `terraform output http_api_url`.

## 3. Estado actual vs. nuevo
```text
generator/components/backend/spring-boot-3.5.16/
├── component.json                  # lista "files" (fuente de verdad)
└── templates/                      # 9 controllers con endpoints, SIN postman
---
generator/components/backend/spring-boot-3.5.16/
├── component.json                  # + 1 entrada: {{MICROSERVICE_NAME}}/postman/...
└── templates/
    └── postman-collection.scriban   # NUEVO: Collection v2.1 renderizada
```
Salida generada: `<proyecto>/<MICROSERVICE_NAME>/postman/<MICROSERVICE_NAME>.postman_collection.json`

## 4. Referencias web
| Referencia | Aporte |
|---|---|
| https://learning.postman.com/docs/use/use-collections/collections-schemas | Esquema oficial Collection v2.1 (`info`, `item`, `request`, `response`). |
| https://learning.postman.com/docs/writing-scripts/script-references/variables/ | `baseUrl` como variable de colección; ambientes separados. |
| https://community.postman.com/t/setting-baseurl-when-generating-a-collection-from-an-openapi-spec/35168 | Patrón de una sola variable `baseUrl` en la raíz. |
| https://javascript.plainenglish.io/how-to-set-up-postman-collections-in-your-codebase-a-developers-guide-5c8f0ec5f78d | Versionar la colección en el repo junto al código. |
| Scriban: escaping de literales (`{{ "{{" }}`) | Evita que `{{baseUrl}}` se interprete como placeholder. |
| `generator/components/cloud/aws/templates/terraform-apigateway.scriban` (output `http_api_url`) | Fuente real de la URL del API Gateway stage `$default`. |

## 5. Tareas de implementación

### Tarea 1 — Inventario de endpoints y bodies (fuente de verdad: `templates/*.scriban`)
Leer cada controller y su(s) DTO(s) de request para extraer método, path, path-variables, headers y body de ejemplo:
- `hola-mundo-controller` → `GET /{{Name}}/hello`, `GET /{{Name}}/error`
- `sns-controller` → `POST /sns/publish`
- `sqs-controller` → `POST /sqs/send`, `GET /sqs/consume` (solo si `ConsumedEvents.size > 0`)
- Solo si `Name == "security"`: `auth-controller` (`/api/v1/auth/token`, `/exchange`), `user-controller` (10 endpoints), `registration-controller` (3), `admin-user-controller` (3), `password-controller` (3)
- DTOs: `token-request-dto`, `exchange-request-dto`, `register-user-request-dto`, `confirm-user-*-dto`, `change-password-request-dto`, `recover-password-request-dto`, `force-password-reset-request-dto`, `auth-request-dto`.
- **Hallazgo:** `controller.scriban` (CRUD por entidad) **no está** en `component.json` → no se genera; se excluye de la colección.

### Tarea 2 — Crear `templates/postman-collection.scriban`
Collection v2.1 con:
- `info.name` = `{{ MicroserviceName }}` / `{{MICROSERVICE_NAME}}`, `schema` = `https://schema.getpostman.com/json/collection/v2.1.0/collection.json`.
- Variables de colección: `baseUrl` (valor por defecto documentado; se llena con `terraform output http_api_url`), `token`, `username`.
- **URL del API Gateway:** en `info.description` de la colección dejar el procedimiento:
  `cd cloud/terraform/<microservicio> && terraform output http_api_url` → pegar el valor en la variable `baseUrl`. Salida esperada: `https://{api_id}.execute-api.{region}.amazonaws.com` (stage `$default`, sin prefijo). **Actualizado (2026-09-27):** `cloud/up.ps1` lo hace solo tras el `terraform apply` (escribe `baseUrl` en la colección); el procedimiento manual queda como alternativa.
- **Escapado obligatorio:** toda variable Postman se escribe como `{{ "{{" }}baseUrl{{ "}}" }}` (el renderer usa `StrictVariables = true`; sin escapar → error `GEN011 UnresolvedPlaceholder`).
- Carpetas por dominio, replicando las mismas condiciones de los controllers (`{{ if(Name == "security") }}...{{ end }}`) para que la colección coincida con lo realmente generado.
- Por request: `method`, `url` (`{{baseUrl}}` + path), `header` (`Content-Type: application/json`, `Authorization: Bearer {{token}}` donde aplique), `body.raw` con JSON de ejemplo y `response` de ejemplo.
- Scripts: `event` a nivel colección con test de status y extracción de token en `/auth/token` (y `/users/token`).

### Tarea 3 — Registrar la plantilla en `component.json`
Agregar la entrada en `files`:
`{ "key": "{{MICROSERVICE_NAME}}/postman/{{MICROSERVICE_NAME}}.postman_collection.json", "value": "templates/postman-collection.scriban" }`
y `{{MICROSERVICE_NAME}}/postman` en `directories` si el plan de generación exige la carpeta declarada.

### Tarea 4 — Verificación
- Buscar placeholders `{{ ... }}` sin resolver de Postman en la plantilla (grep de `{{[a-z]` escapados).
- Validar JSON resultante (render manual de muestra con `jq` / `python -m json.tool`).
- `dotnet build` y `dotnet run --project Generator.csproj` → **requieren autorización explícita**.

## 6. Flujo de datos
1. `templates/*.scriban` (controllers + DTOs) → inventario de endpoints.
2. `templates/postman-collection.scriban` → render con variables `Name`, `Company`, `MicroserviceName`, `Port`, `MICROSERVICE_NAME`, `Entity`, `EntityCapital`.
3. `component.json` (`files`) → `GenerationPlanBuilder` → `PlanExecutor` copia/renderiza.
4. Salida: `<MICROSERVICE_NAME>/postman/<MICROSERVICE_NAME>.postman_collection.json`.

## 7. Archivos a crear
| Archivo | Propósito |
|---|---|
| `generator/components/backend/spring-boot-3.5.16/templates/postman-collection.scriban` | Colección Postman v2.1 del microservicio |

## 8. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `generator/components/backend/spring-boot-3.5.16/component.json` | Registrar la plantilla en `files` (+ `directories` si aplica) |

## 9. Preguntas y recomendaciones
1. Compilar para verificar (`dotnet build` / `dotnet run`) → *Recomendación:* pedir autorización antes de ejecutar (regla del workspace).

## 10. Decisiones tomadas
1. Una colección por microservicio (carpetas internas por controller/dominio).
2. Destino: plantilla en el componente → se genera en `<MICROSERVICE_NAME>/postman/`.
3. Nivel de detalle completo: headers, auth, body de ejemplo, respuestas de ejemplo y scripts.
4. Alcance: solo componente `spring-boot-3.5.16`.
5. Replicar las condiciones `{{ if(Name == "security") }}` de los controllers en la colección.
6. No incluir los endpoints declarados en `epc.json` (`ENDPOINTS_JSON`); fase 2.
7. Nombre del archivo: `<MICROSERVICE_NAME>/postman/<MICROSERVICE_NAME>.postman_collection.json`.
8. `baseUrl` sale de **`terraform output http_api_url`** (output de `cloud/terraform/<microservicio>/apigateway.tf`); no se usa `API_URL` de `epc.json`.

## 11. Costos
- Infraestructura: **$0** (sin servicios nuevos; solo archivos en repo).
- Esfuerzo: **2 archivos** (plantilla `postman-collection.scriban` = 1009 líneas + registro en `component.json`), **1 sesión**, 1 rama/PR.
- Contexto/tokens: **medio-alto** en la fase de lectura (≈20 plantillas: 9 controllers + DTOs + `component.json`); medio en la escritura.
- Verificación: **`dotnet build` OK (0 errores/0 warnings)** y **`dotnet run` real** en copia aislada (`/tmp/opencode`, sin tocar el repo) → `OK=2`: colección generada y validada con `json.tool` (quizapi: 3 requests / security: 26 requests), sin placeholders sin resolver.

## 12. Fuera de alcance
- Colecciones para el componente `dotnet9`.
- Colección por ambiente (archivos de entorno Postman `dev/qa/prod`).
- Generación de colecciones desde OpenAPI/Swagger (no existe spec en el repo).
- Ejecución con Newman en pipeline.
- Endpoints declarados en `epc.json` (`ENDPOINTS_JSON`).
- Tomar `baseUrl` de `API_URL` en `epc.json` (descartado: se usa `terraform output http_api_url`).
