# ADR-0017: Objetivo 002 (`common`), v2 tras `plan-review-002`

- **Fecha:** 2026-10-02
- **Estado:** `Obsoleta`
- **Sustituye a:** ADR-0016
- **Sustituida por:** ADR-0018
- **Alcance:** proyecto
- **Origen:** objetivo 002; `plan-review-002.md`; `question-012.md`, `question-013.md`, `question-014.md`

## Contexto

`plan-review-002.md` encontró bloqueantes y hallazgos que obligaban a corregir el diseño: `common-bom` no cubría todas las coordenadas del piloto (B1), dos criterios de aceptación eran verificablemente falsos tal como estaban escritos (M2, A3) y varias decisiones del diseño sobraban por YAGNI.

## Decisión

Versión 2 del diseño del objetivo 002, sobre lo ya decidido en ADR-0016:

- **a.** Se mantienen las decisiones ya registradas: buildspec en bucket S3 versionado, `common-web` WebFlux únicamente, paquetes Dart fuera de alcance.
- **b.** **Un único repo de plataforma `platform/`** (buildspecs + plantillas de CI) en lugar de dos repos, y el repo `common` en la raíz del workspace (`common/`, junto a `generator/`) porque no es una aplicación generada.
- **c.** **Versionado único `1.0.0` literal, sin `${revision}` ni SNAPSHOT**, con `flatten-maven-plugin` 1.8.0 en modo por defecto y `updatePomFile=true` (obligatorio para `packaging=pom`, según la doc de MojoHaus).
- **d.** `common-bom` gobierna **todas** las coordenadas de terceros que fijaba el piloto, incluidas las que ningún BOM importado cubría (springdoc, gson, jjwt, karate, archunit, pitest, r2dbc-h2, aws-lambda-\*, aws-serverless-java-container). Las **versiones de plugins y `annotationProcessorPaths` siguen en el ms**, porque un `import` de BOM no aporta `pluginManagement`.
- **e.** Contrato de `ApiResponse` **compatible** con el piloto: `timestamp` sigue siendo `LocalDateTime` pero con reloj UTC, y `environment` se elimina (nunca se seteaba). `stackTrace` se conserva pero nunca se puebla.
- **f.** Renovate sin credenciales en el repo: token por `detectHostRulesFromEnv` en el runner.

## Consecuencias

### Positivas

- Se reescriben las líneas de Alcance y los criterios #3, #5, #6 y #10 del objetivo con la redacción honesta.
- `common-helpers` se pospone: no hay nada que extraer.

### Negativas y riesgos

- `ErrorMessages` y `epc.common.web.enabled` se eliminan por YAGNI: sin microservicio que necesite el interruptor, el advice se desactiva definiendo un bean propio (decisión 16 de `architecture-002.md`).
- Las plantillas de un solo uso se sustituyen por snippets en la documentación.
- El cierre de las pruebas del piloto y toda la fase de bootstrap AWS (Terraform, publicación en CodeArtifact/ECR, token) son **pasos del usuario**, no del agente.
- La parte (f) sobre la plataforma de CI quedó obsoleta al día siguiente: ADR-0018 descarta Azure DevOps.

### Coste

**< 2 USD/mes** (< 4 USD/mes a 500 ms de microservicios por el ancho de banda de CodeArtifact), dentro del techo de 10 USD/mes del workspace.
