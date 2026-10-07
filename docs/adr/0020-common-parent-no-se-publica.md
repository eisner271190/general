# ADR-0020: `common-parent` no se publica en CodeArtifact

- **Fecha:** 2026-10-03
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; `question-011.md`; hallazgo B2 de `plan-review-002.md`

## Contexto

Con `flatten-maven-plugin` en modo por defecto y `updatePomFile=true`, el POM publicado de `common-bom` ya no referencia a su `<parent>`: lo deja inlined. Ningún consumidor necesita por tanto el artefacto `common-parent`.

## Decisión

**No se publica `common-parent`.** El registro de CodeArtifact contiene solo `common-bom`, `common-log`, `common-error` y `common-web`. Se marca `maven.deploy.skip` en el POM padre y se documenta en `common/docs/como-versionar.md` que `common-parent` existe solo para `pluginManagement` y propiedades del build.

Corrige la decisión 15 de `architecture-002.md`.

## Consecuencias

### Positivas

- Sin artefacto sin consumidores en el registro, y sin la pregunta permanente de "quién lo consume".

### Negativas y riesgos

- Ninguna: el POM interno sigue disponible para el repo `common`.

### Coste

0 USD (ahorra ~4 KB en el registro).
