# Errores obj-003 y prevención

- 2026-10-07 · El overload `Map` concatenaba al mensaje → el masking por path JSON no lo cubría.
  - Causa: el contrato no fijaba cómo el mapa se convertía a propiedades JSON enmascarables.
  - Prevención: definir en el ADR el flujo `Map → key-value → JSON → masking` y validar con `password`/`token`.

- 2026-10-07 · `logback.xml` no se regeneraba porque `logging.config` forzaba `logback-base.xml`.
  - Causa: el override saltaba el `<include>` y el tester no lo reprodujo en ejecución.
  - Prevención: revisar propiedades generadas y exigir una comprobación local de carga de Logback.

- 2026-10-07 · `logback-base.xml` tenía propiedades desconocidas en `LogstashFieldNames`.
  - `<loggerName>` y `<threadName>` ignorados; `<mask>` desconocido en el decorator.
  - Prevención: grep sobre la doc del encoder y validar el arranque real antes de desplegar.

- 2026-10-07 · `MaskingJsonGeneratorDecorator` no usa `<path>` suelto ni `<defaultMask>` solo.
  - Se necesitaba `<addPaths>` o `<pathMask>` con `<paths>`.
  - Prevención: incluir un ejemplo mínimo validado de la librería en el ADR.

- 2026-10-07 · La imagen `maven:3.9.6-eclipse-temurin-17` KVM crashó la JVM en Docker.
  - Causa: bug de Temurin 17.0.11 en ese entorno.
  - Prevención: fijar una imagen builder conocida y reproducir el build en Docker antes de aceptar.

- 2026-10-07 · CodeArtifact rechazó volver a publicar `common-bom:1.1.0` con 409.
  - Causa: la versión ya existía y se intentó redeploy con cambios.
  - Prevención: documentar que `common` 1.1.0 no se puede republicar; usar 1.1.1 o eliminar la versión si el repositorio lo permite.

## Etapa más temprana de prevención

| # | Error | Etapa más temprana | Cómo evitarlo ahí |
|---|-------|--------------------|-------------------|
| 1 | `Map` no enmascarable | Diseño | ADR con flujo `Map → JSON → masking`; criterio de aceptación con `password`/`token` |
| 2 | `logging.config` salta `<include>` | Diseño | ADR fija el mecanismo de carga de Logback; prohíbe override que omita el include |
| 3 | Propiedades desconocidas en encoder | Análisis | Researcher valida cada tag contra la doc/versión exacta de la librería |
| 4 | `MaskingJsonGeneratorDecorator` mal configurado | Análisis | Researcher entrega config mínima verificada; el ADR la copia |
| 5 | Imagen Temurin 17.0.11 crashea | Diseño | ADR fija imagen builder y versión; lista de imágenes probadas |
| 6 | 409 en CodeArtifact (1.1.0) | Análisis | Regla de versionado: versiones publicadas son inmutables; subir versión antes de publicar |

## Controles transversales por etapa

- Análisis
  - Toda config de librería externa se verifica contra su doc de la versión usada.
  - Checklist de restricciones del entorno: imágenes, registry, inmutabilidad de versiones.
- Diseño
  - El ADR incluye ejemplo mínimo ejecutado, no solo descrito.
  - Cada decisión lleva criterio de aceptación observable.
- Implementación
  - Smoke local: arrancar la app y revisar warnings de Logback (propiedades ignoradas).
  - Build en Docker con la imagen fijada, antes de entregar al tester.
- Pruebas
  - Última red: reproducir en ejecución real (log JSON con campos sensibles, regeneración de `logback.xml`).
  - Un hallazgo aquí se registra como fallo de las etapas anteriores y se agrega a su checklist.
