# ADR-0009: El `CMD` del `Dockerfile` usa la clase cualificada del handler

- **Fecha:** 2026-09-27
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** —

## Contexto

El `CMD` era `{{ APPLICATION_ID }}.LambdaHandler`, pero todas las apps declaran el paquete `com.{{ Company }}.{{ Name }}`. El contenedor arrancaba sin encontrar la clase y API Gateway devolvía 500.

## Decisión

`Dockerfile.scriban` del backend pasa el handler a `com.{{ Company }}.{{ Name }}.LambdaHandler`.

## Consecuencias

### Positivas

- Despliegue funcional: la Lambda encuentra el handler.

### Negativas y riesgos

- Queda pendiente el desajuste entre la carpeta `src/main/java/{{APPLICATION_PACKAGE}}` (`com/quizsmart/app`) y el paquete declarado (`com/quizsmart/quizapi`).

### Coste

0 USD.
