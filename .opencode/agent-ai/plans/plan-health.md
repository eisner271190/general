# Plan: consumir `/health` desde el frontend + indicador (punto verde/rojo)

Basado en `generator/` (fuente de verdad). No implementado.

## 1. Referencias web
- **Health check UI**: indicador con `StreamBuilder`/polling periódico (15-60 s); verde = `status == "UP"`, rojo = error/timeout/`DOWN`.
- **Spring Boot Actuator** expone `/actuator/health` (ya incluido en `pom.scriban`); debe quedar en `COMMON_PATHS` para que JWT no lo bloquee.
- **Flutter**: usar el `IHttpClient` existente (`lib/shared/consume/`), sin agregar dio; ViewModel en `AsyncNotifier` o `Stream.periodic`.

## 2. Objetivo y estado actual
**Objetivo**: al abrir la app se consulta `GET {API_BASE_URL}/actuator/health` y se muestra un punto 🟢 si está disponible, 🔴 si no.

**Estado actual**:
- Backend: `spring-boot-starter-actuator` presente y `management.endpoints.web.exposure.include=*` → `/actuator/health` YA existe; `path-constants.scriban` lo marca público. ❌ No hay controller `/health` propio.
- Frontend: existe `IHttpClient`/`HttpClientImpl`, `EnvHelper.getEnv()`, `ServiceFactory` (modos MOCK/REAL). ❌ No hay feature health ni variable `API_BASE_URL`.

## 3. Tareas
1. **Backend**: verificar que `/actuator/health` responde 200 `{"status":"UP"}` (si se quiere path limpio, crear `HealthController` con `@GetMapping("/health")`).
2. **Frontend - config**: agregar `API_BASE_URL` a `assets/.env.dev` y `.env.mock` (origen: output de Terraform `api_base_url` o `http://10.0.2.2:5000` para emulador local).
3. **Frontend - dominio**: `HealthStatus` model (enum `available|unavailable`) + `IHealthRepository`.
4. **Frontend - data**: `ApiHealthRepository` (GET vía `IHttpClient`, timeout 3 s, 200+`UP` → available) y `MockHealthRepository` (simula estados).
5. **Frontend - aplicación**: `HealthViewModel` con polling `Timer.periodic(30 s)` y método `refresh()`.
6. **Frontend - UI**: widget `HealthStatusDot` (circle 10-12 px, verde `Colors.green` / rojo `Colors.red`, tooltip con estado); insertar en home/app bar.
7. **Wire-up**: clave `HEALTH_SERVICE_MODE` en `ServiceEnv` + `ServiceFactory.createHealthRepository()`.
8. **Tests**: repository con `IHttpClient` mockeado (200/500/timeout) y widget test (rojo→verde).
9. **Registrar** archivos nuevos en `component.json` y directorios en `directories`.

## 4. Flujo (origen de cada dato)
```
HealthStatusDot → HealthViewModel (Timer 30s)
  → IHealthRepository
    → IHttpClient.get(EnvHelper.getEnv('API_BASE_URL') + '/actuator/health')
      → [MOCK: MockHealthRepository] o [REAL: API Gateway → Lambda/Spring → Actuator]
← status UP/error → color del punto (verde/rojo)
```
- `API_BASE_URL`: `.env.*` (cargado por `flutter_dotenv`, leído con `EnvHelper.getEnv`).
- Modo: `SERVICE_MODE`/`HEALTH_SERVICE_MODE` (MOCK/REAL) vía `ServiceFactory`.

## 5. Archivos a crear (generator/components/frontend/flutter3.47.2/templates/)
| Archivo | Propósito |
|---|---|
| `lib/features/health/domain/health_status.dart.scriban` | Modelo/enum de estado |
| `lib/features/health/domain/i_health_repository.scriban` | Interfaz (ISP) |
| `lib/features/health/data/api_health_repository.scriban` | Consumo real vía IHttpClient |
| `lib/features/health/data/mock_health_repository.scriban` | Modo mock |
| `lib/features/health/application/health_view_model.scriban` | Polling + estado expuesto |
| `lib/features/health/presentation/health_status_dot.scriban` | Widget punto verde/rojo |
| `backend/.../infrastructure/controllers/HealthController.java.scriban` | (opcional) `/health` propio |

## 6. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `templates/assets/.env.dev.scriban` y `.env.mock.scriban` | Agregar `API_BASE_URL` |
| `templates/lib/core/service_env.dart.scriban` | `keyHealthMode` + allKeys |
| `templates/lib/core/service_factory.dart.scriban` | `createHealthRepository()` |
| `templates/lib/ui/my_app.dart.scriban` (o home) | Insertar `HealthStatusDot` |
| `component.json` (frontend) | Registrar archivos y directorios `lib/features/health/**` |
| `backend path-constants.scriban` | Incluir `/health` si se crea controller propio |

## 7. Preguntas
1. ¿Endpoint `/actuator/health` o controller propio `/health`?
2. ¿Dónde se muestra el punto: home, app bar, splash?
3. ¿Polling automático (¿cada cuántos segundos?) o solo al iniciar/pull-to-refresh?
4. ¿Criterio verde solo `status=="UP"` o también HTTP 200?
5. ¿Local usa backend corriendo en `localhost:5000` (`10.0.2.2` en emulador Android)?

## 8. Costos
- Sin recursos AWS nuevos; usa Actuator ya existente.
- Si `API_BASE_URL` apunta a API Gateway: < $0.01/mes con 1 req/30 s (~86K req/mes ≈ $0.09).
- Esfuerzo: ~7 archivos nuevos + 5 modificados.

## 9. DoD
- [ ] Punto 🟢 con backend arriba; 🔴 con backend apagado o URL inválida.
- [ ] Modo MOCK funciona sin backend.
- [ ] `flutter test` pasa (repository + widget).
