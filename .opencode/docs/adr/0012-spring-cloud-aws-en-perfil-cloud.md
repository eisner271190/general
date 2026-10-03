# ADR-0012: T06 — `spring-cloud-aws` 3.3.1 en el perfil `cloud`

- **Fecha:** 2026-09-28
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** plan `plan-t06-config-microservicios.md` §5

## Contexto

Los microservicios necesitaban leer parámetros y secretos al arrancar. El plan justifica por qué no el SDK a mano, ni Spring Cloud Config Server, ni AppConfig, ni la extensión de AWS para Lambda. El `pom` es Spring Boot 3.4.0, así que **3.3.x** es la rama compatible de `spring-cloud-aws`.

## Decisión

`spring-cloud-aws` **3.3.1** (starters `parameter-store` + `secrets-manager`) para leer parámetros y secretos al iniciar, solo con el perfil `cloud` (Lambda), vía `spring.config.import` de la config data API de Boot 3.4.

- SSM **con** barra final (`/develop/com.quizsmart.app/quizapi/`, la misma de `terraform-ssm` y `up.ps1`); secreto **sin** barra inicial (`develop/com.quizsmart.app`).
- `import` **requerido** en el perfil `cloud`: fail-fast si falta IAM o T04/T05.
- `SPRING_PROFILES_ACTIVE=cloud` inyectado en la Lambda por `merge(...)` en `terraform-lambda.scriban` + permiso IAM `ssm:GetParametersByPath` (`secretsmanager:GetSecretValue` ya existía).
- Plantillas nuevas `application-cloud-properties.scriban` y `application-context-test.scriban`, registradas en `component.json`.
- En local, **0 llamadas a AWS**: el `import` vive solo en el perfil `cloud`.
- Al subir a Boot 3.5.x hay que subir SCA a 3.4.x.

## Consecuencias

### Positivas

- Configuración declarativa y una sola ruta de lectura para parámetros y secretos.
- Verificado: `dotnet run` regenera sin errores, `mvn dependency:tree` con **una única versión de AWS SDK (2.31.73)** y `ApplicationContextTest` 3/3 en verde.

### Negativas y riesgos

- El `actuator` pasó de `include=*` a `health,info,prometheus` (con secretos en el `Environment`, `/actuator/env` era una fuga); se borraron las líneas `cloud.aws.credentials.*` (prefijo erróneo para SCA 3.x). Este ajuste se llevaría más lejos en ADR-0013.
- **Riesgo aceptado:** el secreto único por app aporta sus claves a todos los ms.
- Hallazgos preexistentes al correr `mvn test`: `HexagonalArchitectureTest` falla 2/3 porque `domain`/`application` se generan vacíos, y JaCoCo no puede instrumentar `DefaultSsmClient` (no fatal).
- Queda pendiente solo el despliegue en nube.

### Coste

**0 USD**: 1 `GetParametersByPath` + 1 `GetSecretValue` por ciclo frío, dentro del nivel gratuito. Penaliza +50-150 ms de arranque (sin caché en SCA 3.3.1).
