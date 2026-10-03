# ADR-0013: Endpoint público de parámetros, ruta catch-all y actuator reducido

- **Fecha:** 2026-09-29
- **Estado:** `Aceptada`
- **Sustituye a:** ADR-0012
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** plan `plan-endpoint-config-frontend.md`

## Contexto

El frontend necesitaba consultar los parámetros que el backend expone al inicio, pero el backend no tenía endpoint para ello. El API Gateway solo declaraba `ANY /<ms>/{proxy+}` y `GET /actuator/health`, de modo que `/api/v1/**` y `/sns/**` devolvían `Not Found` vía `baseUrl`.

## Decisión

Endpoint `GET /api/v1/parameters` con **solo parámetros públicos** (`parameter.public-config.*`), ruta catch-all **`ANY /{proxy+}`** en el API Gateway y `actuator` reducido a **`health`**.

Decisiones del usuario que loendidos: las plantillas del generador son la fuente de verdad, **nunca secretos**, rename del diseño de `frontend` a `parameter`, refactor bajo `epc-clean-code` y añadir el endpoint a la colección Postman.

- Plantillas nuevas: `parameter-properties.scriban` (`@ConfigurationProperties(prefix="parameter")`, único campo `publicConfig`, filtro de claves sensibles con `Pattern` y `log.warn` al omitir) y `parameter-controller{,-test}.scriban`, las 3 registradas en `component.json`.
- Carpeta **Parameters** en `postman-collection.scriban` con el test "Sin secretos" y descripción de las rutas públicas.
- El gateway gana `aws_apigatewayv2_route "<ms>_proxy"` = `ANY /{proxy+}`: AWS elige la coincidencia más específica, así que no pisa las rutas existentes.
- `management.endpoints.web.exposure.include` baja de `health,info,prometheus` a **`health`**, porque con el catch-all `prometheus` e `info` quedarían públicos.

## Consecuencias

### Positivas

- Verificado: `mvn compile` exit 0, `ParameterControllerTest` 3/3, `ApplicationContextTest` en verde (copia en `%TEMP%`, sin tocar el repo), JSON de `component.json` y de la colección válidos con y sin bloques condicionales, bloque de Terraform `fmt -check` exit 0 (la desalineación de `aws_apigatewayv2_integration` y el BOM de la plantilla son preexistentes).

### Negativas y riesgos

- Los 2 fallos de `HexagonalArchitectureTest` son **preexistentes**: reproducidos en una copia base sin los cambios (`domain/` y `application/` vacíos).
- Queda pendiente decidir `h2-console`.

### Coste

**0 USD**: sin recursos nuevos; la ruta no tiene coste y los SSM estándar son gratis hasta 10.000.
