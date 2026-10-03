# ADR-0006: Estructura por capas del generador

- **Fecha:** 2026-09-25
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** —

## Contexto

`Services/` era un cajón de sastre con 19 ficheros: casos de uso, acceso a sistema de ficheros, renderizado y logging mezclados, sin ninguna frontera verificable.

## Decisión

El generador se organiza en `Application/` + `Domain/{Models,Validation,Messages}` + `Infrastructure/` + `Configuration/` (antes `Models/`, `Services/`, `Validation/` y `Messages/` planos), con los namespaces `Generator.Domain.*`, `Generator.Application` y `Generator.Infrastructure`. La dependencia es unidireccional **`Infrastructure → Application → Domain`**, con `GeneratorLogger` y `OutputRegistry` en `Application` (y no en `Infrastructure`) para no invertirla.

## Consecuencias

### Positivas

- `dotnet build` con 0 errores y una dirección de dependencias que se puede comprobar.
- La documentación del generador pasa a `generator/docs/` y la fuente de verdad de la estructura a `generator/AGENTS.md`.

### Negativas y riesgos

- Reubicar los 19 ficheros de `Services/` fue un cambio grande; cualquier resto sin migrar rompería el build.

### Coste

0 USD.
