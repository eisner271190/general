# Revisión de arquitectura — Objetivo 002

Revisada con `grill-me` / `grilling`: supuestos, casos límite, seguridad, coste AWS, riesgos y alternativas descartadas.
Entradas: `objectives/objetivo-002.md`, `DELIVERABLES/objetivo-002/research-002.md`, `DELIVERABLES/objetivo-002/architecture-002.md`, `questions/006..010`, `questions/resolved-questions/002..004`, `AGENTS.md` y el código real del piloto.

## Veredicto

**Con observaciones — vuelve a Architect.**

5 hallazgos bloqueantes y 6 altos. Dos de ellos (B1, B2) rompen la fase F7 tal como está escrita: el `pom.xml` del piloto no compila después de la migración y el BOM publicado no es consumible por un tercero. Ninguno es cosmético: son el núcleo del objetivo.

---

## Observaciones

### Bloqueantes

| # | Severidad | Qué cambiar | Por qué |
|---|---|---|---|
| B1 | **bloqueante** | `architecture-002.md:106` y `:237` — no borrar las 56 `<version>` del piloto indiscriminadamente: `common-bom` (`:100-102`) solo importa `spring-boot-dependencies`, `aws-sdk-bom` y `spring-cloud-aws-dependencies`, y **no gobiernan** estas coordenadas que el piloto fija: `aws-lambda-java-runtime-interface-client:2.8.3` (`pom.xml:72`), `springdoc-openapi-starter-webflux-ui:2.8.3` (`:84`), `gson:2.13.1` (`:131`), `jjwt-api/impl/jackson:0.12.6` (`:162-176`), `mapstruct`+processor (`:185,191`), `micrometer-registry-prometheus:1.14.3` (`:197`), `archunit-junit5:1.3.0` (`:201`), `janino:3.1.12` (`:206`), `karate-junit5:1.4.1` (`:216`), `pitest-junit5-plugin:1.2.1` (`:233`), `r2dbc-h2` (`:251`), `aws-serverless-java-container-*:2.1.4` (`:256,261`). Además `architecture-002.md:106` manda borrar `maven.compiler.plugin.version`, `maven.shade.plugin.version`, `jacoco`, `sonar`, `mapstruct`, `lombok`, que **se usan dentro de `<build><plugins>`** (`pom.xml:273,285,288,321,344,369`) → build roto, no solo versiones sin gestionar. | El diseño promete un `pom.xml` sin versiones y entrega un `pom.xml` que no compila. F7.3 (“`mvn compile` verde”) es imposible. |
| B2 | **bloqueante** | `architecture-002.md:47`, `:99`, `:350` — `flatten-maven-plugin` con `flattenMode=resolveCiFriendliesOnly` **no** resuelve `${project.version}` dentro de `<dependencyManagement>`: la doc de MojoHaus dice literalmente *“Only resolves variables revision, sha1 and changelist”*, y para `packaging=pom` el `updatePomFile` por defecto es `false`. Con `common-bom` declarando `common-log/common-error/common-web` como `${project.version}` (§1.4 punto 1) el POM publicado lleva la variable literal y el consumidor externo (CA #2) falla con *“version is missing”*. La afirmación de `research-002.md:66` (“`resolveCiFriendliesOnly` es obligatorio”) es incorrecta para un BOM. | Corregir a: **quitar `${revision}`**, versión literal en el parent (`1.0.0`), `${project.version}` en las entradas del BOM y `flatten-maven-plugin` con `flattenMode` por defecto (`oss`) + `updatePomFile=true` explícito (obligatorio para `packaging=pom`). Verificable en F4.1 con `mvn dependency:get`. Menos piezas y correcto. |
| B3 | **bloqueante** | `architecture-002.md:47` (`1.0.0-SNAPSHOT` en develop) vs `:135` (`develop` = `1.1.0-SNAPSHOT`) vs `:242` (el ms importa `common-bom:1.0.0`) vs `:374` (F7.1 “`mvn install` para que el ms resuelva sin CodeArtifact”). | `mvn install` instala `1.x-SNAPSHOT`; el ms pide `1.0.0` → no resuelve y F7 se cae. Además `§6.4` dice que la release inicial es `1.0.0` mientras la propiedad `revision` dice otra cosa: tres números distintos para la misma versión. Un solo número por defecto (`1.0.0`), bumpeado explícitamente al publicar. |
| B4 | **bloqueante** | `architecture-002.md:197-204` — `"password": "CODEARTIFACT_AUTH_TOKEN"` en `renovate.json`. | En Renovate, `hostRules[].password` es la credencial **literal**; no hay indirección por variable de entorno (la config self-hosted tiene `secrets`, `detectHostRulesFromEnv` y `config.js`, pero eso es del runner, no del repo). Renovate mandaría la cadena `CODEARTIFACT_AUTH_TOKEN` como contraseña y CodeArtifact devolvería 401 en cada ejecución. Además, aunque funcionara, sería una credencial en un fichero del repo (`AGENTS.md`: sin secretos en ficheros). |
| B5 | **bloqueante** | `architecture-002.md:15`, `:270`, `:284`, `:289`, `:349` — no hay ruta en este workspace para `common`, `platform-buildspecs` ni `azure-pipelines`, y F0.1 pide “crear el repo CodeCommit”, que el agente no puede hacer (ni `apply`, ni commits sin autorización, `AGENTS.md`). | Sin ruta, `WORKFLOW` (branch → plan → implementar → PR) no se puede ejecutar y el Developer no tiene dónde escribir. Hay que fijar la ruta dentro de este repo (p. ej. `projects/epc.platform/backend/common`, siguiendo `projects/<id>/backend/<ms>`) y mover la creación de los repos remotos a F3 como paso de bootstrap del usuario. |

### Altas

| # | Severidad | Qué cambiar | Por qué |
|---|---|---|---|
| A1 | alta | `architecture-002.md:88-89` — mover `@ConditionalOnMissingBean` y `@ConditionalOnProperty` de las **clases** a los **métodos `@Bean`** de `WebAutoConfiguration`. | Las clases se registran con `@Bean` desde la auto-configuración (§1.3 dice “no es `@Component` sino un bean”). Los metadatos `@Conditional*` de una clase devuelta por un método `@Bean` no se evalúan: el `@ConditionalOnMissingBean` de la CA #4 no se cumpliría. |
| A2 | alta | `architecture-002.md:88` vs `:254` — contradicción del interruptor `include-stack-trace`. | §1.3 lo pone como `@ConditionalOnProperty` **sobre el advice**: si se desactiva, `CommonException` deja de tener handler y cae en el handler genérico, perdiendo `data` y `ErrorApiResponse` — no es “no filtrar el stack trace”, es romper el manejo de errores. §1.10 lo describe como serialización condicional del campo. Dejar **solo** lo segundo (`@JsonInclude(NON_NULL)` + valor `null` por defecto). |
| A3 | alta | `architecture-002.md:220`, `:398` — la CA #6 depende de `question-006`, que sigue abierta. | Si los repos de ms viven en CodeCommit, Renovate no tiene plataforma: `platform: azureDevOps` no puede abrir PRs ahí. F8.2 no es verificable ni bajo la asunción actual ni bajo la alternativa. O se resuelve 006 antes de F8, o la CA se reformula a “rama/commit”. |
| A4 | alta | `architecture-002.md:349,362-365,367,372,377,380` — marcar subtarea por subtarea qué es **bootstrap del usuario** y qué entrega el Developer. Solo F3 lo está. | F0.1 (crear repo), F4.1 (`mvn deploy` con token de 12 h), F6.1 (publicar en ECR), F7.4 (`docker build` tras `aws ecr get-login-password`), F8.2 (`renovate --dry-run`) **no son ejecutables por el agente**: requieren credenciales AWS que el agente no tiene y que `AGENTS.md` no le permite sembrar. Si no se marca, el Developer los intentará y se bloqueará. |
| A5 | alta | `architecture-002.md:291`, `:379` — las 3 plantillas son `build/test/deploy`, pero los jobs actuales del piloto son `Build/Static_Testing/Security` (`research-002.md:36`): no hay mapping y “los mismos 3 jobs” es falso. | Sin mapping no hay forma de comprobar F8.1. Además: (a) `deploy` es alcance nuevo para un ms que despliega por Terraform/CodePipeline, no por Azure; (b) Azure DevOps resuelve el repo de plantillas una sola vez y **no puede ejecutar scripts del repo de plantillas** (`research-002.md:126`) — las plantillas deben ser YAML puro; (c) `ref: refs/tags/v1.0.0` exige que el usuario cree ese tag antes. |
| A6 | alta | `architecture-002.md:235` — el criterio “`quizapi` compila y sus pruebas existentes pasan” (objetivo:64) **no lo puede cerrar el agente**: `HolaMundoControllerTest.java:3,4` y `ParameterControllerTest.java:4` importan `ApiResponse`/`ErrorApiResponse` del paquete borrado, y `AGENTS.md` prohíbe crear o modificar tests. | La arquitectura lo anota, pero no lo convierte en paso de traspaso con responsable. Además `HolaMundoControllerTest.java:4` importa `ErrorApiResponse` sin usarlo (import muerto que sobrevive por el cambio de paquete). Dejar explícito: F7 termina en “verde hasta donde el agente puede llegar” y el cierre de la CA #10 es del usuario. |

### Medias

| # | Severidad | Qué cambiar | Por qué |
|---|---|---|---|
| M1 | media | `architecture-002.md:106` — la explicación del conflicto `spring.cloud.aws.version` mezcla dos cosas. | Los POM **importados** resuelven sus propias propiedades dentro de su propio modelo; no hay colisión de `spring.cloud.aws.version` entre el POM del ms y `spring-cloud-aws-dependencies` (que usa `spring-cloud-aws.version`). Lo que sí importa es la **precedencia** de `dependencyManagement` (una entrada propia gana al `import`), que es lo que mide F1.2. Reescribir el párrafo con esa distinción o la CA #11 queda sin fundamento. |
| M2 | media | `architecture-002.md:112` y `:418` — la CA #5 (“no requiere modificar ningún `pom.xml` de ms”) es **falsa tal como está escrita** en el objetivo, y la arquitectura lo admite pero no lo resuelve. | Hay que modificar `objectives/objetivo-002.md` con la redacción honesta que propone §1.4, o registrar la CA reformulada en `DECISIONS`. Mientras el objetivo diga eso, la revisión de aceptación fallará. Igual con la CA #6 (§1.8). Registrado como duda 014. |
| M3 | media | `architecture-002.md:293-295`, `:354`, `:360` — tres proyectos de prueba: `samples/log-only-sample`, el “proyecto de prueba” de F1.2 y el “ms WebFlux mínimo” de F2.4. | Tres módulos desechables para tres mediciones. Consolidar en `samples/` con dos módulos (`log-only-sample` y `web-sample`) y reutilizar `log-only-sample` para medir la precedencia de F1.2 (es un proyecto que importa el BOM). |
| M4 | media | `architecture-002.md` no menciona `src/test/java/com/quizsmart/app/HexagonalArchitectureTest.java` (verificado: existe, con `@ArchTest` y `slices`). | Si define reglas por paquete (`..rest..`, `..configuration..`), borrar `infrastructure.rest.response` y `GlobalExceptionHandler` puede romper una regla de slices. El Developer debe comprobarlo y avisar; el test lo ajusta el usuario. |
| M5 | media | `architecture-002.md:132` vs `:280` — `templates/settings-publish.xml` se crea, pero §1.5 dice que el método preferido es `distributionManagement` en el POM raíz. | Fichero muerto. Con `distributionManagement` solo hace falta el `<server>` de `settings.xml`. |
| M6 | media | `architecture-002.md:286` — `buildspecs/publish-artifacts.yml` no lo usa ninguna fase (F5.1 solo crea `java-ci.yml` y `docker-build.yml`; la publicación está en un stage con `mvn deploy`). | Artefacto muerto en el repo de origen de verdad. |
| M7 | media | `architecture-002.md:280` — `templates/{gitignore,dockerignore}.template` + `install-config.sh` son 4 ficheros para una copia manual de un solo uso, y el objetivo:75 declara la sincronización de `.gitignore`/`.dockerignore` **fuera de alcance**. | Sobrecarga. Dejar el snippet en `docs/como-migrar-un-ms.md` y borrar los tres ficheros de plantilla + el script. |
| M8 | media | `architecture-002.md:53`, `:387` — la propia arquitectura admite que `common-log` nace “para que el criterio de aislamiento sea demostrable”. | El criterio es vacuamente cierto: `common-log` no arrastra `common-web` por definición de su POM. Se acepta el módulo (tiene un consumidor real, el filtro de `common-web`, y una frontera real para los ms no-web), pero la arquitectura debe decir que la CA #3 verifica **la regla inversa** (`common-log` no declara `common-web`) y que la API pública de `MdcCorrelation` se congela en 1.0.0. Si no, el criterio no prueba nada sobre el diseño. |

### Bajas

| # | Severidad | Qué cambiar | Por qué |
|---|---|---|---|
| B-1 | baja | `architecture-002.md:275` — `ErrorMessages` (y el `ErrorCode` que el objetivo menciona) no los exige ningún criterio ni el piloto. | Rung 1 de la escalera: no crear clases para dos literales. Se admite si `epc-clean-code` R11 lo exige; si no, constantes privadas en el advice. |
| B-2 | baja | `architecture-002.md:91` — `epc.common.web.enabled` no tiene consumidor. | Propiedad sin cliente (YAGNI). Se puede dejar, pero debe anotarse como “interruptor para el primer ms que necesite desactivarlo todo”, no como parte del diseño actual. |
| B-3 | baja | `architecture-002.md:152` y `install-config.sh` — el piloto **no tiene `.dockerignore`** (verificado) y sin él el contexto de `docker build` manda `.git`. | Hay que crear el `.dockerignore` del piloto como copia de una vez (con `target/` **no** excluido, según §1.6) y decirlo explícitamente en F7.4. |
| B-4 | baja | `architecture-002.md:158`, `:160` — publicar `:latest` en cada versión duplica punteros de tag por cada release de `common`. | 2× tags (no capas). Menor. El resto del coste está bien estimado: `< 2 USD/mes` y CodeArtifact variable a 500 ms ≈ 4 USD/mes (`:441`), dentro del techo de 10. |
| B-5 | baja | `architecture-002.md:152` — la imagen base añade “usuario no-root” sobre `public.ecr.aws/lambda/java:17`; el `Dockerfile` del ms hace `COPY` como root. | Legible (644), pero conviene decirlo en `docs/como-usar.md` para que nadie asuma lo contrario. |

---

## Cobertura de los 12 criterios de aceptación

| CA | ¿Se cumple? | Nota |
|---|---|---|
| 1. `mvn install` compila todos los módulos | Sí, condicionado a B2 | Con el flatten corregido. |
| 2. Publica en CodeArtifact y un proyecto externo resuelve importando `common-bom` | **No tal cual** | B2: el POM publicado lleva `${project.version}` literal. |
| 3. Un ms que importa solo `common-log` no carga `common-web` | Sí, pero vacuamente (M8) | El mecanismo (dependencia transitiva) es el correcto; la prueba no dice nada del diseño. |
| 4. `GlobalExceptionHandler` solo si el ms no define el suyo | **No tal cual** | A1: el `@ConditionalOnMissingBean` sobre la clase no se evalúa. Y con el piloto migrado no hay ms que lo demuestre (F2.4). |
| 5. Cambiar una versión no requiere editar ningún pom de ms | **Falsa tal como está redactada** | M2. El diseño es correcto; la CA hay que reescribirla. |
| 6. Renovate abre PR en un ms | **No tal cual** | Además de M2, B4 (credencial literal) y A3 (plataforma sin resolver). |
| 7. `epc/common-base` en ECR + `Dockerfile` ≤5 líneas | Sí | Opción B bien resuelta; el `Dockerfile` de 4 líneas encaja con el actual de 10 (`Dockerfile:1-11`) y conserva `CMD`. |
| 8. Buildspec por ARN de S3 sin editar el pipeline | Sí | Correcto y coherente con `question-002.md`. Riesgo de supply-chain mitigado con claves por versión (`architecture-002.md:422`). |
| 9. El pipeline extiende una plantilla de Azure DevOps | Sí en diseño, con huecos | A5 (mapping de jobs, scripts no disponibles, tag previo). |
| 10. `quizapi` compila y sus pruebas pasan | **No sin intervención del usuario** | A6, y B1 rompe la compilación. |
| 11. El pom de `quizapi` no declara versiones presentes en `common-bom` | Sí, por construcción | Se cumple solo si B1 no rompe el build. |

## Orden de fases

El orden F0→F9 es correcto en lo esencial. Tres ajustes:

1. **F7 depende de F4** (o de un `mvn install` con la versión exacta): hoy F7.1 promete “`mvn install` para que el ms resuelva sin CodeArtifact” con una versión que no coincide (B3).
2. **F5 y F6 dependen de F3**, y F8.1 depende de que el usuario cree el repo de plantillas y el tag `v1.0.0`. Marcarlo como prerrequisito en F3 (A4, A5).
3. **F1.2/F1.3 miden con un artefacto que aún no existe**: el BOM se construye en F1.1 y se instala en el repo local; la medición no necesita CodeArtifact si el proyecto de prueba es un módulo del reactor (M3).

## Reglas duras del workspace

- **Identificadores en inglés**: correcto en todo el diseño (`MdcCorrelation`, `CommonException`, `epc.*`).
- **`terraform apply` denegado**: respetado — `architecture-002.md:118`, `:180`, `:299`, `:362` lo marcan como paso del usuario. Sin observaciones.
- **No crear ni modificar tests**: respetado en la intención, pero A6 exige que la CA #10 quede explícitamente como traspaso al usuario, no como entregable del Developer.
- **Sin secretos en ficheros**: correcto en Maven/CI (`${env.CODEARTIFACT_AUTH_TOKEN}`); **incumple en Renovate** (B4).
- **Sin commit ni push**: correcto; pero B5 (no hay ruta) impide cumplir el flujo de PR.

## Lista mínima para que vuelva a pasar

1. B1 — completar `common-bom` con las ~13 coordenadas que el piloto fija y no están gobernadas; no borrar propiedades usadas por plugins.
2. B2 — quitar `${revision}`; `flattenMode` por defecto + `updatePomFile=true`; verificar con `dependency:get`.
3. B3 — un único número de versión por defecto (`1.0.0`).
4. B4 — credenciales de Renovate en la config self-hosted del runner; el `renovate.json` del repo solo lleva `registryUrls`/`matchHost`.
5. B5 — fijar la ruta de los tres repos nuevos dentro de este workspace y separar “entregable del Developer” de “bootstrap del usuario”.
6. A1 + A2 — condiciones en los métodos `@Bean`; el interruptor de `stackTrace` solo como serialización condicional.
7. A3 — resolver `question-006` o reformular la CA #6.
8. A6 — la CA #10 queda como traspaso al usuario.
9. M2 — reescribir las CA #5 y #6 en `objetivo-002.md` (o en `DECISIONS`).

A3 y M2 requieren una decisión del usuario; el resto son correcciones acotadas de diseño.

## Preguntas

Ninguna bloqueante para esta revisión. Dudas no bloqueantes registradas en `QUESTIONS_OPEN`: `question-011.md` (publicar o no `common-parent`), `question-012.md` (mantener `epc.common.web.enabled`), `question-013.md` (`.dockerignore` del piloto como copia de una vez), `question-014.md` (reescritura de las CA #5 y #6 en el objetivo).