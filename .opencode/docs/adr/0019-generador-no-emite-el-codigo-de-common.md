# ADR-0019: El generador deja de emitir el código que vive en `common`

- **Fecha:** 2026-10-03
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; `question-009.md`

## Contexto

`generator/components/backend/spring-boot-3.5.16/templates/` seguía produciendo `api-response.scriban`, `general-exception.scriban`, `global-exception-handler.scriban` y un `pom.scriban` con ~56 versiones explícitas. Es decir, el generador regeneraba exactamente el código que la migración a `common` borra: riesgo de regresión detectado en `question-009.md`.

## Decisión

El usuario decide: si el código está en `common`, no debe existir en los microservicios. Por tanto:

- Se eliminan del componente backend las plantillas que producen `ApiResponse`, `ErrorApiResponse`, la excepción base y el `GlobalExceptionHandler`, y quedan dadas de baja en `component.json`.
- `pom.scriban` pasa a importar `common-bom` y a declarar `common-web` / `common-log` / `common-error` **solo si el microservicio generado las necesita**.
- `logback.xml` **se mantiene** en el microservicio: cada uno define su formato de log; `common-log` solo aporta MDC y correlación de `request-id`.

## Consecuencias

### Positiva

- El generador deja de ser una segunda fuente de verdad del código que se acaba de centralizar.

### Negativas y riesgos

- Los microservicios ya generados **no se regeneran** en este objetivo: `quizapi` se migró a mano. El resto sigue con el código duplicado hasta que se migren uno a uno.

### Coste

0 USD.
