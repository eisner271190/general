# Plan: Endpoint backend de parámetros para el frontend

**Tarea del TODO:** `.opencode/agent-ai/docs/todo.md` → "El backend debe exponer un endpoint para consultar los parametros y secret que necesita el frontend"
**Fecha:** 2026-09-29
**Branch:** `feature/plan-endpoint-config-frontend`
**Alcance confirmado por el usuario:** plantillas del generador (fuente de verdad) · sólo parámetros públicos · flujo "Trabajar" · rename `frontend` → `parameter` · refactor bajo `epc-clean-code` · collection Postman · ruta catch-all en el API Gateway · cierre de actuator a `health` · compilación y tests autorizados.

## 1. Descripción
El frontend (Flutter) hoy lee su configuración de `assets/.env` con `EnvHelper.getEnv()`. El backlog pide que el backend exponga un endpoint desde donde el frontend consulte los parámetros que necesita. Este plan cubre **sólo el lado backend**: crear el endpoint en las plantillas del generador, de forma que todo microservicio generado lo obtenga.

Los valores sensibles (p. ej. `API_KEY` de OpenAI) **no se exponen**: el endpoint sólo lee un prefijo de configuración reservado a lo público.

## 2. Objetivo
`GET /api/v1/parameters` devuelva un `ApiResponse` cuyo `data` sea el mapa de claves públicas definidas bajo `parameter.public-config.*`, omitiendo y registrando en log cualquier clave con apariencia sensible, y ser alcanzable vía `baseUrl` del API Gateway.

## 3. Estado actual vs. nuevo
```text
templates/
├── hola-mundo-controller.scriban      (demo, no sirve parámetros)
├── application-properties.scriban     (sin prefijo de parámetros)
├── postman-collection.scriban         (sin carpeta Parameters)
├── component.json                     (sin plantillas de parámetros)
cloud/aws/templates/
└── terraform-apigateway-lambda.scriban  (sólo /<ms>/{proxy+} y /actuator/health)
---
templates/
├── parameter-properties.scriban          NUEVO  @ConfigurationProperties("parameter") → public-config
├── parameter-controller.scriban          NUEVO  GET /api/v1/parameters
├── parameter-controller-test.scriban     NUEVO  3 tests
├── application-properties.scriban        MOD    bloque comentado de ejemplo
├── postman-collection.scriban            MOD    carpeta Parameters + descripción
├── component.json                        MOD    +3 entradas en files
cloud/aws/templates/
└── terraform-apigateway-lambda.scriban    MOD    + ruta `ANY /{proxy+}`
```

Ejemplo de respuesta:
```json
{
  "data": { "api-url": "https://api.openrouter.ai/api/v1/chat/completions", "model": "gpt-4o-mini" },
  "message": "Parameters retrieved successfully",
  "status": 200,
  "timestamp": "2026-09-29T10:00:00"
}
```

## 4. Referencias web
| Referencia | Aporte |
|---|---|
| [Spring Boot Endpoints (3.5)](https://docs.spring.io/spring-boot/3.5/reference/actuator/endpoints.html) | `/actuator/env` y `/configprops` son sensibles y se sanearán; exponer configuración propia explícita en vez de actuator. |
| [Spring Boot Actuator Security](https://www.joptimize.io/blog/spring-boot-actuator-security-hardening) | `/actuator/env` filtra API keys y credenciales; nunca usarlo como API de configuración pública. |
| [JetBrains — Spring Boot Configuration Management Best Practices](https://blog.jetbrains.com/idea/2026/08/spring-boot-configuration-management-best-practices/) | `@ConfigurationProperties` tipado + valores fuera del código + secretos en gestor de secretos. |
| [Guide to @ConfigurationProperties (Baeldung)](https://www.baeldung.com/configuration-properties-in-spring-boot) | Bind de familias de propiedades y de `Map<String,String>` bajo un prefijo. |
| [AWS — Create routes for HTTP APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-routes.html) | Selección por coincidencia **más específica**: ruta estática > `{proxy+}` > `$default`. Justifica convivir `ANY /<ms>/{proxy+}` con `ANY /{proxy+}`. |

## 5. Tareas de implementación

### Tarea 1 — `ParameterProperties`
Plantilla `parameter-properties.scriban` → `infrastructure/configuration/ParameterProperties.java`:
- `@Component` + `@ConfigurationProperties(prefix = "parameter")`.
- Único campo: `Map<String, String> publicConfig` (bind de `parameter.public-config.*`). **No existe ningún campo para secretos**: la clase no puede leerlos por diseño.
  - Nota de diseño: con `@ConfigurationProperties` el campo `Map` añade su propio nivel, por eso el prefijo es `parameter.public-config.*` y no `parameter.config.public.*` (que exigiría un nivel `values` extra o bindear un bean `Map`).
- API: `getPublicConfig()`/`setPublicConfig()` (binding) y `getPublicParameters()`, que filtra y devuelve sólo lo publicable.
- Filtro de claves sensibles con `Pattern` (`secret|password|passwd|token|credential|api-key|apikey|private-key|auth`, case-insensitive); cada clave omitida se registra con `log.warn`.

### Tarea 2 — `ParameterController`
Plantilla `parameter-controller.scriban` → `infrastructure/controllers/ParameterController.java`:
- `@RestController` + `@RequestMapping("/api/v1/parameters")`.
- `@GetMapping` → `ResponseEntity<ApiResponse>` con mensaje `"Parameters retrieved successfully"`.
- Inyecta `ParameterProperties` por constructor (mismo patrón que `{{ EntityCapital }}Controller`).

### Tarea 3 — Test del controller
Plantilla `parameter-controller-test.scriban` → test en `infrastructure/controllers`:
- `WebTestClient.bindToController(...)` (mismo estilo que `HolaMundoControllerTest`).
- Test 1: devuelve 200 y las claves públicas definidas.
- Test 2: `parameter.public-config.api-key` y `jwt-secret` **no** aparecen en la respuesta.
- Test 3: sin claves configuradas → 200 y mapa vacío.

### Tarea 4 — `application-properties.scriban`: ejemplo y cierre de actuator
- Bloque comentado al final:
  ```properties
  # parameter.public-config.api-url=https://api.openrouter.ai/api/v1/chat/completions
  # parameter.public-config.model=gpt-4o-mini
  # parameter.public-config.admob-banner-id=ca-app-pub-0000000000000000/0000000000
  ```
- **Cierre de actuator** (decisión 8): `management.endpoints.web.exposure.include=health,info,prometheus` → `health`.
  - Contexto: la ruta catch-all haría públicos `/actuator/prometheus` e `/actuator/info` vía `baseUrl`.
  - Continúa la decisión T06 de `decisions.md`, que ya bajó `include=*` a `health,info,prometheus` porque `/actuator/env` era una fuga con los secretos en el `Environment`.
  - Ojo: `management.server.port={{ Port }}` y `server.port={{ Port }}` son el mismo puerto en la plantilla, así que actuator y API comparten listener en local/Lambda.

### Tarea 5 — `component.json`
- Sumar las 3 plantillas nuevas a `files` (orden alfabético, tras `mapper-info`).
- Sin `directories` nuevos: `infrastructure/configuration`, `infrastructure/controllers` y el de tests ya existen.

### Tarea 6 — Collection Postman (`postman-collection.scriban`)
- Nueva carpeta **Parameters** (entre *Hola Mundo* y *Actuator*) con la petición `GET {{baseUrl}}/api/v1/parameters`.
- Tests: `Status 2xx` y `Sin secretos` (assert de que la respuesta no contiene `api-key|apikey|secret|password|credential`).
- Ejemplo de respuesta 200 en `response`.
- Descripción de la collection actualizada: rutas públicas = `/api/v1/users/**`, `/api/v1/parameters` y `/actuator/health`.
- Al ser plantilla, el fichero generado `postman/quizapi.postman_collection.json` se actualiza en la próxima generación (no se edita: es salida).

### Tarea 7 — Ruta catch-all en el API Gateway (`terraform-apigateway-lambda.scriban`, componente cloud)
- Añadir `aws_apigatewayv2_route "<ms>_proxy"` con `route_key = "ANY /{proxy+}"`.
- Motivo: sólo existían `ANY /<ms>/{proxy+}` y `GET /actuator/health`, por lo que `/api/v1/**` y `/sns/**` devolvían `{"message":"Not Found"}` desde `baseUrl`.
- Sin ambigüedad: AWS selecciona la coincidencia más específica, así que `/quizapi/hello` sigue yendo a la ruta con prefijo y `/actuator/health` a la ruta estática.

### Tarea 8 — Verificación — ✅ ejecutada
- Placeholders `{{ ... }}` sin resolver en las plantillas nuevas: ninguno (sólo `Company` y `Name`, ambos definidos por el generador).
- Longitud de línea ≤100 (Google Java Style) en las 3 plantillas Java.
- `component.json` → JSON válido.
- `postman-collection.scriban` → JSON válido tras simular el render (con y sin bloques `ConsumedEvents`/`security`).
- **`mvn compile` → exit 0** y **`ParameterControllerTest` 3/3** (`Tests run: 3, Failures: 0, Errors: 0`) en copia temporal (`%TEMP%\opencode\verify-parameters-*`) con las clases renderizadas (`Company=quizsmart`, `Name=quizapi`); el log confirma el filtro: `Parametro publico 'api-key' ... omitido` y lo mismo para `jwt-secret`. `ApplicationContextTest` arranca el contexto en verde con el nuevo bean.
- **Suite completa: 10 tests, 2 fallos — preexistentes y ajenos.** `HexagonalArchitectureTest` falla porque `domain/` y `application/` están **vacías** (0 clases) en el proyecto generado y ArchUnit exige `allowEmptyShould`. *Prueba A/B:* una copia base **sin** mis clases reproduce exactamente los mismos 2 fallos (`Tests run: 3, Failures: 2`). No se toca: fuera de alcance.
- **`terraform fmt -check`:** mi bloque aislado → **exit 0 (conforme)**. El `.tf` ya generado y la plantilla de origen → exit 3 **antes** de mi cambio (alineación de `=` en el bloque `aws_apigatewayv2_integration` y BOM `EF BB BF` en la plantilla, que el generador elimina al renderizar). Hallazgos preexistentes.
- `terraform validate` completo pendiente: exige renderizar el directorio entero (ejecutar el generador, requiere autorización aparte); `fmt` ya parsea el HCL y valida la sintaxis del bloque nuevo.

## 6. Flujo de datos
1. Terraform/SSM define `parameter.public-config.<clave>` bajo el prefijo del microservicio (o `application.properties` en local).
2. `spring.config.import` (perfil `cloud`) trae esas claves al `Environment` de Spring.
3. `@ConfigurationProperties(prefix = "parameter")` bindea `parameter.public-config.*` a `ParameterProperties.publicConfig`.
4. `GET /api/v1/parameters` → `getPublicParameters()` filtra claves sensibles → `ApiResponse.data`.
5. El API Gateway enruta `ANY /{proxy+}` → Lambda → el mismo path en Spring.
6. El frontend (tarea pendiente del backlog) consume el endpoint y puebla su `EnvConfig`.

## 7. Archivos a crear
| Archivo | Propósito |
|---|---|
| `generator/components/backend/spring-boot-3.5.16/templates/parameter-properties.scriban` | Binding tipado de `parameter.public-config.*` + filtro de claves sensibles |
| `.../templates/parameter-controller.scriban` | `GET /api/v1/parameters` |
| `.../templates/parameter-controller-test.scriban` | Tests del endpoint |

## 8. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `.../spring-boot-3.5.16/component.json` | Registrar las 3 plantillas nuevas en `files` |
| `.../templates/application-properties.scriban` | Bloque de ejemplo de `parameter.public-config.*` + `management.endpoints.web.exposure.include=health` |
| `.../templates/postman-collection.scriban` | Carpeta **Parameters** + descripción de rutas públicas |
| `generator/components/cloud/aws/templates/terraform-apigateway-lambda.scriban` | Ruta `ANY /{proxy+}` |

## 9. Preguntas y recomendaciones
1. ¿La ruta `/api/v1/parameters`? → *Respuesta:* sí, elegida por el usuario (los controllers de entidad ya usan `/api/v1`).
2. ¿Nombre de las clases/archivos `Parameter*` en lugar de `FrontendConfig*`? → *Respuesta:* sí, rename pedido por el usuario. Las 2 menciones restantes a "frontend" en los Javadoc son el **consumidor**, no el nombre del endpoint.
3. ¿El gateway no enruta `/api/v1/**`? → *Respuesta:* añadir ruta catch-all (elegida por el usuario). **Riesgo:** ver §11.1, mitigado por la Tarea 4.
4. ¿Quién aporta los valores concretos de cada proyecto? → *Recomendación:* fuera de este plan: terraform/SSM (T17) y el consumidor Flutter (tarea del backlog).
5. ¿Añadir `Cache-Control` al endpoint? → *Recomendación:* no en esta fase; el frontend lo llamará una vez al arrancar.

## 10. Decisiones tomadas
1. **Sólo parámetros públicos** (decisión del usuario): no se leen secretos; el binding se limita a `parameter.public-config.*`.
2. Secure-by-construction: `ParameterProperties` no tiene campo alguno para secretos, por lo que no puede filtrarlos aunque se intente.
3. Claves expuestas **tal cual** están en configuración (kebab-case), sin transformación, para que el emparejamiento frontend↔backend sea predecible.
4. Se aplica a las **plantillas del generador**, no al proyecto generado (`projects/` es salida).
5. `@Component` + `@ConfigurationProperties` (sin `@EnableConfigurationProperties`): `@SpringBootApplication` escanea el package raíz.
6. **`epc-clean-code` aplicado:** R1 (métodos < 20 líneas), R2 (lógica de bucle/condición extraída a `copyIfPublishable`/`logSensitiveOmission`/`isSensitiveKey`), R7 (máx. 2 parámetros: se eliminó el antiguo `putIfNotSensitive(map, key, value)` de 3), R8 (creaciones encapsuladas en `createPublishableMap`/`buildParametersData`/`buildResponse`), R9 (el controller orquesta y delega; no se añade una Facade adicional por ser una sola operación — YAGNI).
7. Filtro de secretos con `Pattern` en constante en lugar de array + bucle: elimina el `for`/`if` del flujo y deja la condición autoexplicativa (`isSensitiveKey`).
8. **Cierre de actuator a `health`** (decisión del usuario): la ruta catch-all amplía la superficie pública, así que se recorta `include` a `health`. Refuerza —no contradice— la decisión T06 ya registrada en `decisions.md`.
9. **Verificación por compilación autorizada**: se ejecuta en una copia temporal del microservicio con las clases renderizadas a mano; no se regenera `projects/` ni se ensucia el árbol.
10. **Nombres de plan y rama sin renombrar** (`plan-endpoint-config-frontend` / `feature/plan-endpoint-config-frontend`), decisión del usuario; el rename `frontend` → `parameter` aplica sólo a clases, plantillas y rutas.

## 11. Riesgos
1. **Catch-all expone más superficie** (§5.7): con `ANY /{proxy+}` quedan accesibles vía `baseUrl` rutas que antes no lo estaban: `/actuator/prometheus`, `/actuator/info`, `/h2-console` (`spring.h2.console.enabled=true`) y cualquier controlador futuro. → **Mitigado** con la Tarea 4 (`include=health`) y decisión 8. *Pendiente residual:* `/h2-console` sigue en `application.properties`; no aplica en Lambda (no hay H2 remoto) pero conviene desactivarlo fuera de local en un plan de seguridad.
2. **Colisión de `route_key`** si un proyecto genera ≥2 microservicios: cada uno renderizaría `ANY /{proxy+}`. Ya existía el mismo problema con `aws_apigatewayv2_api.http_api` (recurso idéntico en cada carpeta), así que multi-microservicio no está soportado de facto. Fuera de alcance.
3. El `terraform.tf` generado requiere `terraform apply` para surtir efecto; el agente no puede ejecutarlo (denegado).

## 12. Costos
- **AWS:** $0 incremental. La ruta catch-all no tiene coste; los parámetros SSM estándar son gratis hasta 10.000. Sin nuevos recursos ni instancias.
- **Esfuerzo:** 7 archivos (3 nuevos + 4 modificados), ~330 líneas, 1 sesión.
- **Contexto/tokens:** plan ~5k; implementación ~20-25k con verificación.

## 13. Fuera de alcance
- Consumidor Flutter del endpoint (tarea del backlog: "El frontend debe obtener los parametros consumiendo un servicio del backend").
- Parámetros SSM del frontend en terraform (T17: prefijo `/frontend/quizsmart/`).
- Exposición de secretos reales y autenticación (Cognito/JWT) — descartado por decisión del usuario.
- Restricción de `/h2-console` fuera de perfil local (riesgo §11.1, residual) — plan de seguridad aparte.
- `Cache-Control`, versionado de la respuesta y CORS específico para el nuevo path.
- Regenerar el proyecto `projects/com.quizsmart.app` y aplicar terraform (ambos al fusionar).
- **Hallazgos fuera de alcance (verificados como preexistentes, reproduccidos sin mis clases):**
  - `HexagonalArchitectureTest` falla siempre porque `domain/` y `application/` están vacíos en el proyecto generado; hay que añadir `allowEmptyShould(true)` en `hexagonal-architecture-test.scriban`.
  - `terraform fmt -check` ya fallaba sobre el `.tf` generado: desalineación de `=` en `aws_apigatewayv2_integration` (`terraform-apigateway-lambda.scriban`).
  - La plantilla `terraform-apigateway-lambda.scriban` empieza por BOM `EF BB BF` (el generador lo elimina al renderizar, pero rompe `fmt` si se trabaja sobre la plantilla).
  - `ClassTooLargeException` de JaCoCo al instrumentar `DefaultSsmClient` (ruido en el log, no falla el build).
  - Las plantillas declaran `package com.{{ Company }}.{{ Name }}...` (= `com.quizsmart.quizapi`) pero escriben en `src/main/java/{{APPLICATION_PACKAGE}}/...` (= `com/quizsmart/app`). Package y directorio no coinciden en el proyecto generado. El escaneo de componentes funciona igual (Spring usa el package de los `.class`), pero conviene corregirlo en un plan propio.
