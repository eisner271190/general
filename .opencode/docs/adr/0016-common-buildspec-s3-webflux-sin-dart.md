# ADR-0016: `common` — buildspec en S3, `common-web` WebFlux y Dart fuera de alcance

- **Fecha:** 2026-10-02
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** ADR-0017
- **Alcance:** proyecto
- **Origen:** objetivo 002; `question-002.md`, `question-003.md`, `question-004.md`

## Contexto

El objetivo 002 pedía un buildspec compartido desde otro repo de CodeCommit con pin de commit, `common-web` como "configuración MVC" y paquetes Dart (`common_log`, `common_error`) en su repositorio. La investigación (`deliverables/objetivo-002/research-002.md`) verificó que:

- `BuildspecSource` + `repo/path@sha1:<sha>` **no existe** en la API, CloudFormation ni CLI de CodeBuild. `buildspec` solo acepta YAML inline, ruta relativa a `CODEBUILD_SRC_DIR` o ARN de S3. Un segundo repo se puede clonar como `Source` action o `SecondarySources`, pero el buildspec se resuelve en `CODEBUILD_SRC_DIR` y no tiene mecanismo de `include`.
- El piloto `quizapi` es Lambda + WebFlux + R2dbc **sin ningún consumidor servlet**.
- Pub no tiene hosted repo privado: `dart pub publish` es irreversible y solo se puede retractar en 7 días.

## Decisión

1. El buildspec compartido vive en un **bucket S3 versionado** (`s3://epc-buildspecs/`, referenciado por ARN), **no** en un repo de CodeCommit con pin de commit.
2. `common-web` es **WebFlux** (reactivo), no MVC: depende de `spring-webflux`, el `GlobalExceptionHandler` es un `@RestControllerAdvice` reactivo y el filtro de correlación es un `WebFilter`.
3. Los **paquetes Dart quedan fuera de alcance** (solo Java).

## Consecuencias

### Positivas

- Publicar una versión nueva del buildspec **no** obliga a editar el pipeline del microservicio: cumple el criterio de aceptación tal como estaba escrito.
- Cero piezas de Dart que mantener sin consumidor.

### Negativas y riesgos

- Se pierde el pin exacto por commit (CodeBuild resuelve la última versión del objeto); el despliegue no es reproducible bit a bit si el objeto cambió. Se mitiga con el historial de versiones de S3.
- Aparece más adelante un `common-web-servlet` como módulo aparte cuando exista el primer consumidor servlet/Fargate.
- Distribución futura de los paquetes Dart, si aparece un consumidor Flutter: `publish_to: none` + git por tag como primera opción.
- Se reescriben el criterio de aceptación del buildspec y las líneas de Contexto/Alcance/Fuera del alcance de `objectives/objetivo-002.md`.
- El repo de buildspecs en CodeCommit queda como **fuente de verdad de la publicación** al bucket.

### Coste

**~0 USD/mes**: bucket S3 versionado en la región del proyecto (importe ridículo en storage + peticiones `GetObject`). CodeArtifact, ECR y CodeBuild ya se usan: no hay recursos de cómputo nuevos.
