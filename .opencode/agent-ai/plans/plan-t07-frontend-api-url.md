# Plan: T07 — El frontend obtiene la URL del API Gateway y consume `/actuator/health`

**Tarea del TODO:** `.opencode/agent-ai/docs/todo.md` → MVP `T07 — El frontend debe obtener la URL del API Gateway y consumir los servicios del backend /actuator/health`
**Fecha:** 2026-09-27

## 1. Descripción
El frontend ya tiene el código de salud (`ApiHealthRepository` → `GET {API_BASE_URL}/actuator/health`, punto con polling de 30 s), pero:
- `API_BASE_URL` está **hardcodeada** en `.env.dev` (`http://10.0.2.2:5000`, backend local).
- En el móvil **siempre se carga `.env.mock`**: `main.dart:11-19` sólo cambia de fichero si recibe `args[0]`, y `flutter run -d <móvil>` no pasa argumentos a `main` (comprobado en el log de la ejecución de hoy: `[ENV] Environment variables (assets/.env.mock)`).
- La URL del API Gateway (`output http_api_url`) sólo llega hoy a la colección de Postman (`cloud/up.ps1:300-306`).

## 2. Objetivo
- `flutter run`/`flutter build` del móvil usa `.env.dev` con `API_BASE_URL = https://{id}.execute-api.us-east-1.amazonaws.com` (stage `$default`, sin segmento de stage).
- La app, en modo `REAL`, marca el punto verde consumiendo `GET {url}/actuator/health` en el teléfono.

## 3. Estado actual vs. nuevo
```text
cloud/terraform/quizapi/apigateway.tf:12   output http_api_url  → solo Postman
assets/.env.dev:6                          API_BASE_URL=http://10.0.2.2:5000
assets/.env.dev:4                          HEALTH_SERVICE_MODE=REAL
lib/main.dart:11-19                        args[0] ⇒ en Android siempre .env.mock
lib/features/health/data/api_health_repository.dart:21-27   ya consume /actuator/health
---
cloud/up.ps1                               + Update-FlutterEnvBaseUrl (mismo patrón que Postman)
lib/main.dart                              + const String.fromEnvironment('ENV', defaultValue:'mock')
frontend/up.ps1                            + parámetro -Environment (mock|dev) → --dart-define=ENV
assets/.env.dev (salida)                   API_BASE_URL=<http_api_url>  (escrito por cloud/up.ps1)
```

## 4. Referencias web
| Referencia | Aporte |
|---|---|
| https://docs.flutter.dev/deployment/flavors | Selección de entorno en build/run; aquí se resuelve con `--dart-define` (más simple que flavors completos). |
| https://api.flutter.dev/dart-core/String/fromEnvironment.html | `String.fromEnvironment` = const a tiempo de compilación, sin `dart:io`. |
| https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html | `invoke_url` de la etapa `$default` (sin prefijo de stage). |
| `generator/components/cloud/aws/templates/up.ps1.scriban:149` | `Update-PostmanBaseUrl`: patrón existente de escritura de la URL en un artefacto — replicarlo. |
| `.opencode/agent-ai/plans/plan-health.md` | Trabajo previo del backend/UI de salud (ya implementado, no repetir). |

## 5. Tareas de implementación
### T7.1 Inyectar la URL del API Gateway en el entorno del frontend
- En `components/cloud/aws/templates/up.ps1.scriban`, junto a `Get-TerraformOutput`/`Update-PostmanBaseUrl` (`:123`, `:149`, `:300`), añadir `Update-FlutterEnvBaseUrl` que escriba `API_BASE_URL=<http_api_url>` en `frontend/{{ FRONTEND_NAME }}/assets/.env.dev` (sustituye la línea `API_BASE_URL=...` si existe; si no, la añade).
- Llamarlo en la misma fase que Postman, **tras el apply**. Si `frontend/` no existe en el plan (componente no incluido), omitir con log (como ya hace con Postman).
- Mantener `http://10.0.2.2:5000` en `.env.mock` (desarrollo sin nube).

### T7.2 Seleccionar el entorno en el móvil
- `components/frontend/.../templates/lib/main.dart.scriban`: resolver el nombre de entorno con
  ```dart
  const env = String.fromEnvironment('ENV', defaultValue: '');
  final name = env.isNotEmpty ? env : (args.isNotEmpty ? args[0] : 'mock');
  await dotenv.load(fileName: 'assets/.env.$name');
  ```
  (se conserva `args[0]` para escritorio/web).
- `components/frontend/.../templates/up.ps1.scriban`: parámetro `[ValidateSet('mock','dev')] [string]$Environment = 'mock'` y pasar `--dart-define=ENV=$Environment` a `Invoke-Flutter -Arguments @('run','--debug','-d',<id>,'--dart-define=ENV=...')`. Documentarlo en el bloque de ayuda (`.PARAMETER Environment` + `.EXAMPLE`).

### T7.3 Modo real en el entorno dev
- Verificar que `.env.dev` sigue con `HEALTH_SERVICE_MODE=REAL` y `SERVICE_MODE=REAL` (`:1,:4`); el `ServiceFactory` (`lib/core/service_factory.dart:63-77`) creará `ApiHealthRepository` en lugar del mock.

### T7.4 Comprobar la ruta en la nube
- `apigateway_lambda.tf:21-26` declara `GET /actuator/health` con `authorization_type = NONE`. Con stage `$default`, la URL final es `https://{id}.execute-api.{region}.amazonaws.com/actuator/health`.
- Verificar con `curl` antes de probar en el móvil (T7.5).

### T7.5 Verificación en el dispositivo
```powershell
./cloud/up.ps1 -Phase Apply                       # escribe API_BASE_URL en .env.dev (autorización)
curl https://{id}.execute-api.us-east-1.amazonaws.com/actuator/health     # {"status":"UP"}
./frontend/quizsmart/up.ps1 -DeviceId <id> -Environment dev -SkipBuild
```
En el móvil: log `[ENV] Environment variables (assets/.env.dev)`, `[SERVICE_FACTORY] Creating ApiHealthRepository` y punto verde en `initial_screen.dart:27`.
Tests: `flutter test` (test de `ApiHealthRepository` ya existe en `test/health_repository_test.dart`; extenderlo si cambia la lectura de `ENV`).

## 6. Flujo de datos
1. Terraform → `output http_api_url` (etapa `$default`).
2. `cloud/up.ps1` (tras apply) → escribe `API_BASE_URL` en `frontend/<ms>/assets/.env.dev`.
3. `flutter run --dart-define=ENV=dev -d <móvil>` → `main.dart` carga `.env.dev` → `EnvHelper.getEnv('API_BASE_URL')`.
4. `ApiHealthRepository` → `GET {API_BASE_URL}/actuator/health` → API Gateway (`GET /actuator/health`, sin auth) → Lambda → Spring Actuator → `{"status":"UP"}`.
5. `HealthViewModel` (polling 30 s) → `HealthStatusDot` (punto verde/rojo).

## 7. Archivos a crear
| Archivo | Propósito |
|---|---|
| — | Ninguno (todo son plantillas ya registradas). |

## 8. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `generator/components/cloud/aws/templates/up.ps1.scriban` | `Update-FlutterEnvBaseUrl` + invocación tras apply. |
| `generator/components/frontend/flutter3.47.2/templates/lib/main.dart.scriban` | Entorno por `--dart-define=ENV` con fallback a `args[0]`. |
| `generator/components/frontend/flutter3.47.2/templates/up.ps1.scriban` | Parámetro `-Environment` y `--dart-define` en `flutter run`. |
| `projects/com.quizsmart.app/...` (salidas: up.ps1 del root, `main.dart`, `up.ps1` front, `assets/.env.dev`) | Sincronizar (`.gitignore`). |
| `.opencode/agent-ai/docs/todo.md` | Marcar T07 al fusionar (flujo del backlog). |

## 9. Preguntas y recomendaciones
1. **¿Dominio personalizado del API Gateway en vez de URL de `execute-api`?** → *Recomendación:* **fase 2**. El dominio fijo elimina la necesidad de inyectar la URL, pero exige un certificado ACM/Route53 y toca infraestructura; con inyección en build ya funciona el MVP.
2. **¿Escribir en `.env.dev` (archivo generado) o crear un fichero nuevo no versionado?** → *Recomendación:* **reescribir `.env.dev`**, igual que ya se hace con `backend/<ms>/postman/<ms>.postman_collection.json`; es el patrón del proyecto y evita añadir otro loader.
3. **¿`--dart-define` o migrar a `--dart-define-from-file`?** → *Recomendación:* `--dart-define=ENV` (cambio mínimo, un solo entorno). La migración completa de dotenv queda fuera de alcance.
4. **¿Publicar también `AUTH_BACKEND_HOST` y el resto de `REPLACE_WITH_*` de `.env.dev`?** → *Recomendación:* **no** en este plan (T07 es sólo la URL del API Gateway + health); abrir tarea aparte para el resto de la configuración de auth.
5. **¿Exigir backend desplegado para probar el frontend?** → *Recomendación:* sí: T07 depende de T05 (parámetros) y del apply de cloud; encadenar el orden T05 → T07.

## 10. Decisiones tomadas
1. La URL se inyecta en build/run (no hay descubrimiento en runtime).
2. `.env.mock` sigue siendo el valor por defecto (cero regresión para quien no pase `-Environment`).
3. El punto de salud sigue usando el endpoint público `GET /actuator/health` ya declarado (no crear rutas nuevas).

## 11. Costos
- **Infra:** 0 USD (el API GW y la ruta ya existen).
- **Esfuerzo:** 4-5 archivos en 2 componentes (cloud + frontend) → **1-2 sesiones**; 1 `flutter run` de verificación (~4 min: 116 s de Gradle + 14 s de instalación, medido hoy).
- **Contexto/tokens:** bajo-medio.

## 12. Fuera de alcance
- Configuración de auth (`AUTH_*` con `REPLACE_WITH_*`).
- `app_bootstrapper.dart:18` carga `assets/.env` (fichero inexistente): residual, revisar aparte.
- Dominio personalizado/CDN del API Gateway.
- Otros consumos REST del backend (T02 del backlog).
