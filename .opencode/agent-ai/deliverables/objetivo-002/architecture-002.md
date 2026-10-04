# Arquitectura — Objetivo 002

Componente reutilizable multi-módulo Maven (`common`) para microservicios Java: BOM de versiones, auto-configuración Spring granular por capacidad (`common-log`, `common-error`, `common-web`), publicación en CodeArtifact, imagen base en ECR, buildspecs en bucket S3 versionado y migración del piloto `quizapi`. CI y repos de microservicios: AWS CodePipeline/CodeBuild y CodeCommit (ADR-0018).

## Changelog (v2)

Revisión posterior a `DELIVERABLES/objetivo-002/plan-review-002.md` (veredicto: vuelve a Architect). Correcciones **aplicadas** al documento:

| # | Cambio | Por qué |
| --- | --- | --- |
| **B1** | §1.4 pasa a tener la **tabla completa de coordenadas** que el BOM gobierna (13 grupos que el piloto fijaba y ningún BOM importado cubría) + §1.4.2 explica qué queda en el ms porque **`dependencyManagement` no gobierna plugins**. F7.3 deja de decir "borra las 56 `<version>`" | El diseño anterior entregaba un `pom.xml` que no compilaba: borraba versiones que el BOM no sustituía y propiedades usadas por `<build><plugins>` |
| **B2** | **Fuera `${revision}`**: versión literal `1.0.0`; `flatten-maven-plugin` 1.8.0 con `flattenMode` por defecto (`oss`) + `updatePomFile=true` explícito; `${project.version}` en las entradas del BOM | La doc de MojoHaus dice que el POM aplanado solo se instala como POM del proyecto para `packaging != pom` salvo `updatePomFile=true`, y que `resolveCiFriendliesOnly` solo resuelve `revision`/`sha1`/`changelist`: con `resolveCiFriendliesOnly` el BOM publicado llevaba `${project.version}` literal y el consumidor externo fallaba |
| **B3** | **Un solo número: `1.0.0`** en todo el documento (ni `1.1.0-SNAPSHOT` ni `1.0.0-SNAPSHOT`) | El documento tenía tres números para la misma versión y `mvn install` no satisfacían el import del ms |
| **B4** | `renovate.json` **sin credenciales**: solo `registryUrls` + `enabledManagers`. El token llega al runner por `detectHostRulesFromEnv` (`MAVEN_USERNAME` / `MAVEN_PASSWORD`), documentado con cita | `hostRules[].password` es literal; no hay indirección por variable de entorno en el config del repo |
| **B5** | **Ruta fijada: `common/` y `platform/`** en la raíz del workspace (junto a `generator/`). Crear los repos remotos pasa a F3 (bootstrap del usuario) | Sin ruta el Developer no tiene dónde escribir y el flujo branch→PR no se puede ejecutar |
| **A1** | Las condiciones pasan a los **métodos `@Bean`** de `WebAutoConfiguration` (§1.3) | Los `@Conditional*` de una clase devuelta por `@Bean` no se evalúan: el `@ConditionalOnMissingBean` del advice no se cumplía |
| **A2** | **Una sola forma** del interruptor de `stackTrace`: se elimina la propiedad; el campo se conserva, nunca poblado, con `@JsonInclude(NON_NULL)` | Laproperty anterior estaba como `@ConditionalOnProperty` sobre el advice: desactivarla rompía el manejo de errores en lugar de ocultar el stack |
| **A3** | **Decisión v2 supersedida por ADR-0018**: los MS viven en CodeCommit; Renovate usa `platform: local` y scripts abren PRs | Se separó el mantenimiento de dependencias del trigger de release de `common` |
| **A4** | Cada fase marca **subtarea por subtarea** si es entregable del Developer o **"ejecuta el usuario"** (§5) | Varias subtareas (crear repo, `mvn deploy`, push a ECR, `renovate --dry-run`) requieren credenciales que el agente no tiene |
| **A5** | §1.7.2 mapea las plantillas Azure a los jobs reales del piloto (`Build`/`Static_Testing`/`Security`), añade `stages/security.yml` y declara `deploy.yml` sin consumidores | "Los mismos 3 jobs" era falso; además las plantillas deben ser YAML puro (Azure no ejecuta scripts del repo de plantillas) |
| **A6** | Contrato de `ApiResponse` **compatible** con el piloto: `timestamp` sigue siendo `LocalDateTime` (solo cambia la zona del reloj a UTC) y **no se toca Postman**; solo quedan 2 imports de test como tarea del usuario (§1.10, F7.5) | El agente no puede editar tests y cambiar el formato del JSON obligaba a tocar Postman + tests a la vez |
| M1–M8 | §1.4.3 reescribe el párrafo de `spring.cloud.aws.version` (precedencia, no colisión de propiedad); `settings-publish.xml`, `publish-artifacts.yml`, `gitignore.template`, `dockerignore.template` e `install-config.sh` **eliminados**; los 3 proyectos de prueba → **2 samples**; CA #3 reformulada a "verifica la regla inversa"; `.dockerignore` del piloto creado en F7; sin tag `:latest`; sin `ErrorMessages`; sin `epc.common.web.enabled` | Medias y bajas del review: eran piezas muertas o sobrecarga |
| Decisión del orchestrator | **Un solo repo `platform/`** (buildspecs + plantillas Azure) en lugar de dos repos; se registra como **desviación del objetivo** en `DECISIONS` y se actualizan las líneas afectadas de `OBJECTIVES/objetivo-002.md` | Menos repos, menos IAM, mismo resultado para los ms |

## Changelog (v3)

Actualización posterior conforme a ADR-0018 y al objetivo vigente: Azure DevOps queda descartado; los repos de microservicios usan CodeCommit y la CI usa exclusivamente CodePipeline/CodeBuild. Renovate semanal actualiza `common`; el trigger por tag `v*` bumpea el import de `common-bom` y crea PRs en CodeCommit. `common-parent` no se publica (ADR-0020). La sección v2 anterior se conserva como historial, no como diseño vigente.

---

## Contexto

Cada microservicio repite el mismo código de manejo de errores (`ApiResponse`, `ErrorApiResponse`, `GeneralException`, `GlobalExceptionHandler`) y declara ~56 versiones explícitas en su `pom.xml` (`projects/com.quizsmart.app/backend/quizapi/pom.xml`). Con ~100 ms y camino a 500, dos problemas escalan peor que el número de ms: código divergente y una vulnerabilidad que obliga a editar N poms.

Hechos verificados en la investigación (`DELIVERABLES/objetivo-002/research-002.md`) que condicionan el diseño:

1. El buildspec compartido **no** se puede referenciar desde otro repo con pin de commit (no existe `BuildspecSource`): solo YAML inline, ruta en `CODEBUILD_SRC_DIR` o **ARN de S3** → bucket `epc-buildspecs` versionado (`QUESTIONS_RESOLVED/question-002.md`).
2. `quizapi` es **Lambda + WebFlux + R2dbc**, no servlet/MVC → `common-web` es WebFlux (`question-003.md`). Los paquetes Dart quedan fuera (`question-004.md`).
3. `common-helpers`, MDC/request-id, `PageResponse` y `ErrorCode` **no existen en el piloto**: no hay código que extraer.

**Rutas** (decisión del orchestrator, cierra B5): el repo `common` vive en `common/` y el repo de plataforma en `platform/`, ambos en la raíz de este workspace junto a `generator/`. No van bajo `projects/` porque **no son aplicaciones generadas** — mismo criterio que el archetype, que vive fuera de `projects/`. Los Directorios `common/` y `platform/` todavía **no existen**: los crea el Developer en F0.

---

## 1. Decisiones de diseño

### 1.1 Estructura del repo `common` y por qué existe cada módulo

```
common/                                   repo Maven (CodeCommit) -> CodeArtifact
├── pom.xml                               parent: propiedades + pluginManagement (packaging=pom)
├── renovate.json                         sin credenciales (ver §1.8)
├── .gitignore .dockerignore
├── common-bom/pom.xml                    packaging=pom, SOLO <dependencyManagement> (§1.4)
├── common-log/                           Java + SLF4J, sin Spring, sin web
│   └── src/main/java/com/epc/common/log/MdcCorrelation.java
├── common-error/                         contrato de error, sin web
│   └── src/main/java/com/epc/common/error/{ApiResponse,ErrorApiResponse,CommonException}.java
├── common-web/                           ÚNICA capa reactiva; auto-configuración
│   ├── src/main/java/com/epc/common/web/{WebAutoConfiguration,GlobalExceptionHandler,RequestCorrelationFilter}.java
│   └── src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
├── samples/                              2 apps mínimas que verifican CA #3 y CA #4
│   ├── log-only-sample/                  importa SOLO common-log (+ common-bom)
│   └── web-sample/                       importa common-web, con advice propio que gana
├── docker/{Dockerfile,publish-base-image.sh}      imagen base ECR (runtime)
├── settings.xml                          <server> de CodeArtifact + <repository> (plantilla)
└── docs/{como-usar.md,como-versionar.md,como-migrar-un-ms.md}
```

| Elemento | Valor | Motivo |
| --- | --- | --- |
| `groupId` | `com.epc.common` | Namespace propio, separado de `com.quizsmart`: `common` no debe poder importar clases de cliente por accidente (dominio sin framework) |
| `artifactId` raíz | `common-parent` | Un `pom` sin nombre no se puede parentar ni excluir |
| `version` | **`1.0.0` literal**, sin `${revision}` (§1.4.1) | Un único número en todo el sistema (B3). Se bumpea editando **un** fichero al publicar |
| Dependencias entre módulos | `${project.version}` (nunca `${revision}`) | `${revision}` ya no existe; `${project.version}` sí lo resuelve el POM aplanado |
| `maven.compiler.release` | `17` | Igual que el piloto y el resto de la flota |

**`common-helpers` NO se crea** en este objetivo. No hay un solo helper de fecha, string o colección en `quizapi` (verificado: el único uso de tiempo es `LocalDateTime.now()` dentro de `ApiResponse` y un `Instant.parse` en `RevenueCatAdapter`), no hay consumidor, y crearlo sería especulación. Se crea cuando el segundo microservicio tenga algo real que extraer; ese día su dependencia natural será `common-error → common-helpers`. `common-error` no depende de nada de `common` hoy.

**`common-log` sí se crea**, con una responsabilidad: MDC/correlación sin dependencia de web. Tiene un consumidor real en este mismo release (el filtro de `common-web`) y una frontera real para los ms no-web. Contenido: `MdcCorrelation` (`put`/`clear` de `requestId`, clave como constante), Java + `slf4j-api`. **Su API pública se congela en `1.0.0`** (M8).

Alternativa descartada: fusionar `common-log` dentro de `common-web`. Ahorra un módulo, pero deja a los ms no-web (consumidores SQS/SNS, batch) sin correlacionar y hace imposible verificar la frontera.

### 1.2 Grafo de dependencias y aislamiento

```
common-bom   (pom, sin dependencias)
common-log   → org.slf4j:slf4j-api (compile)
common-error → com.fasterxml.jackson.core:jackson-annotations (provided, optional=true)
common-web   → common-log, common-error, spring-boot-autoconfigure, spring-webflux
               (spring-* y reactor: provided + optional=true)
samples/log-only-sample → common-bom, common-log
samples/web-sample      → common-bom, common-web, spring-boot-starter-webflux
```

Reglas duras (verificables en revisión):

1. Solo `common-web` depende de `common-log` y `common-error`. **Nunca la inversa**, ni con `runtime`, ni con `test`.
2. `common-web` no declara `spring-boot-starter-webflux` (arrastraría reactor-netty y ~15 MB en el cold start de Lambda): declara `spring-webflux` y `spring-boot-autoconfigure` como `provided`+`optional`. El ms aporta su starter.
3. `common-bom` no lo importa ningún módulo de `common` (evita ciclos de `dependencyManagement`); solo lo importan los ms y los samples.

**Mecanismo real del aislamiento**: el artefacto `common-web` no llega al classpath de un ms que solo importa `common-log`, porque `common-log` no lo declara en su `pom.xml`. Si no está en el classpath, su `AutoConfiguration.imports` no existe y Spring no puede registrar nada. **`@AutoConfigureBefore/After` no participa**: el orden solo afecta al orden de *definición* de beans entre auto-configuraciones ya presentes en el classpath.

**Qué verifica de verdad la CA #3** (M8): el criterio "un ms que importa solo `common-log` no carga `common-web`" es vacuamente cierto por definición de POM. La prueba útil es la **regla inversa**: (a) `mvn dependency:tree` de `common-log` **no** muestra `common-web` ni `spring-webflux`; (b) arrancando `log-only-sample`, el log de arranque (`--debug`) no registra ninguna clase `com.epc.common.web`; (c) `common-log` **no** tiene archivo `AutoConfiguration.imports` (si lo tuviera, sería la única vía por la que algo de web pudiera colarse). Esas tres comprobaciones son las que se ejecutan en F2.3.

Coste: sin aislamiento, un ms que solo quiere logging cargaría reactor-netty y ~15 MB en el cold start de Lambda. Con aislamiento, 0.

### 1.3 Auto-configuración

Un único archivo `common-web/src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`, una línea:

```
com.epc.common.web.WebAutoConfiguration
```

| Elemento | Anotaciones | Nota |
| --- | --- | --- |
| `WebAutoConfiguration` (clase) | `@AutoConfiguration`<br>`@ConditionalOnWebApplication(type = REACTIVE)`<br>`@ConditionalOnClass({WebFilter.class, ApiResponse.class})` | Aquí las condiciones **sí** valen: es una auto-configuración, no una clase devuelta por `@Bean` |
| `WebAutoConfiguration#globalExceptionHandler()` (método `@Bean`) | **`@ConditionalOnMissingBean(GlobalExceptionHandler.class)`** | A1: la condición va en el **método**. Devuelve un `@RestControllerAdvice` reactivo con 2 handlers: `CommonException` → 500 + `ErrorApiResponse` (registrando el stack con `log.error`), `Exception` → 500 + `ApiResponse` |
| `WebAutoConfiguration#requestCorrelationFilter()` (método `@Bean`) | `@ConditionalOnMissingBean(name = "requestCorrelationFilter")` | Devuelve el `WebFilter` de orden `HIGHEST_PRECEDENCE`: lee `X-Request-Id` o genera UUID, `MdcCorrelation.put(...)` en el `filter()` y `clear()` en el `blockFinally` |

Razones: `GlobalExceptionHandler` **no** es `@Component` sino un bean de auto-configuración, porque Spring documenta que `@ConditionalOnMissingBean` solo es fiable en auto-configuración (se procesa después de las definiciones del usuario). Los `@Conditional*` de la **clase** devuelta por `@Bean` no se evalúan (A1): por eso el método lleva el `@ConditionalOnMissingBean` y la clase solo lleva condiciones de contexto. No hay ninguna propiedad `epc.common.web.enabled`: `question-012` la aplaza (sin cliente en el alcance; el propio `@ConditionalOnMissingBean` ya cubre el caso del advice propio). Si algún día un ms necesita desactivar el filtro, se añade entonces.

`common-log` no tiene auto-configuración (no tiene nada que registrar); su ausencia de `imports` es parte del aislamiento (§1.2).

Constantes de mensajes: **no** hay clase `ErrorMessages` (B-1): son dos literales privados dentro del advice (rung 1 de la escalera; R11 se aplica con constantes privadas, no con una clase pública sin consumidor).

### 1.4 BOM: cobertura, estrategia de versión y precedencia

#### 1.4.1 Versión única y `flatten-maven-plugin` (B2, B3)

Estrategia elegida, verificada contra la documentación oficial ([MojoHaus Flatten Maven Plugin — Usage](https://www.mojohaus.org/flatten-maven-plugin/usage.html)):

- **Sin `${revision}`**. Versión literal `1.0.0` en `common/pom.xml`; los hijos heredan `<parent><version>1.0.0</version>`. Publicar una release = cambiar ese número en **un** fichero.
- **`flatten-maven-plugin` 1.8.0** con `flattenMode` **por defecto** (`oss`) y **`updatePomFile=true` explícito**, goal `flatten` en `process-resources` y `clean` en `clean`.
- Motivo (texto de la doc): *"The generated flattened POM will be set as POM file to the current project only for projects with packaging other than pom. You may want to also do this for pom packaging projects by setting the parameter updatePomFile to true."* → sin `updatePomFile=true`, `common-bom` (`packaging=pom`) instalaría su POM **original**, con `${project.version}` literal en las entradas de los módulos propios, y el consumidor externo fallaría con *version is missing* (CA #2 rota).
- `flattenMode=resolveCiFriendliesOnly` **queda descartado**: según la misma doc *"To keep all additional POM elements and flatten only to a bare minimum use 'resolveCiFriendliesOnly'"*, es decir solo resuelve `revision`/`sha1`/`changelist` — no resolvería `${project.version}`. Con el modo por defecto (`oss`) el POM aplanado **sí** resuelve sus variables (*"Its variables are resolved"*), que es lo que necesita el BOM.
- `distributionManagement` se declara **una sola vez** en `common-parent` (heredado por los 4 módulos). Consecuencia asumida: **`common-parent` también se publica** (~4 KB, sin consumidores). Es más barato que duplicar `distributionManagement` en 4 módulos o pelear con `maven.deploy.skip`, que **se hereda** a los hijos y los saltaría a todos. This resolves `question-011` differently than proposed, with this reason.
- Verificación en F4.1: `mvn dependency:get -Dartifact=com.epc.common:common-bom:1.0.0:pom` y, sobre el POM descargado, comprobar que las entradas de los módulos llevan `1.0.0` literal y no `${project.version}`.

#### 1.4.2 Qué gobierna el BOM (B1)

`common-bom/pom.xml` (`packaging=pom`, sin `src/`) lleva, en este orden: (1) los módulos propios con `${project.version}`; (2) `org.springframework.boot:spring-boot-dependencies:3.4.0` (import); (3) `software.amazon.awssdk:bom:2.31.73` (import); (4) `io.awspring.cloud:spring-cloud-aws-dependencies:3.3.1` (import); (5) las coordenadas que ningún BOM importado cubre, con propiedades `epc.*`.

**Tabla completa de terceros que fija hoy `quizapi/pom.xml`:**

| Coordenada | Versión actual (línea del piloto) | Destino | Propiedad / acción |
| --- | --- | --- | --- |
| `software.amazon.awssdk:{s3,dynamodb,dynamodb-enhanced,sns,sqs,cognitoidentityprovider}` | `2.31.73` vía `${aws.java.sdk.version}` (31, 65, 70, 134, 139, 143) | `aws-sdk-bom` | **Borrar** propiedad y versiones |
| `org.springframework.boot:spring-boot-starter{, -actuator, -webflux, -data-r2dbc}` | `3.4.0` vía `${springboot}` (19, 92, 100, 105) | `spring-boot-dependencies` | **Borrar** propiedad y versiones |
| `org.slf4j:slf4j-api` | `2.0.9` (94) | `spring-boot-dependencies` | **Borrar** versión (sube a la gestionada por Boot) |
| `org.mapstruct:mapstruct` + `mapstruct-processor` | `1.6.3` (23, 187, 193) | `spring-boot-dependencies` (`mapstruct.version`) | **Borrar** versión; `annotationProcessorPaths` según §1.4.4 |
| `io.micrometer:micrometer-registry-prometheus` | `1.14.3` (24, 200) | `spring-boot-dependencies` | **Borrar** versión |
| `org.projectlombok:lombok` | `1.18.36` (27, 220) | `spring-boot-dependencies` | **Borrar** versión; `annotationProcessorPaths` según §1.4.4 |
| `org.junit.jupiter:junit-jupiter` | `5.11.3` (28, 229) | `spring-boot-dependencies` | **Borrar** versión |
| `org.codehaus.janino:janino` | `3.1.12` (207) | `spring-boot-dependencies` (propiedad `janino.version`) | **Borrar** versión · *verificar en F1.2* |
| `com.amazonaws:aws-lambda-java-core` | `1.2.3` vía `${aws.lambda.java.version}` (32, 80) | **BOM propio** | `epc.aws-lambda-java-core.version=1.2.3` |
| `com.amazonaws:aws-lambda-java-runtime-interface-client` | `2.8.3` (73) | **BOM propio** | `epc.aws-lambda-java-runtime.version=2.8.3` (propiedad aparte: las versiones actuales difieren) |
| `org.springdoc:springdoc-openapi-starter-webflux-ui` | `2.8.3` (21, 85) | **BOM propio** | `epc.springdoc.version=2.8.3` |
| `com.google.code.gson:gson` | `2.13.1` (133) | **BOM propio** | `epc.gson.version=2.13.1` |
| `io.jsonwebtoken:jjwt-{api,impl,jackson}` | `0.12.6` (25, 165, 172, 179) | **BOM propio** | `epc.jjwt.version=0.12.6` |
| `com.intuit.karate:karate-junit5` | `1.4.1` (26, 217) | **BOM propio** | `epc.karate.version=1.4.1` |
| `com.tngtech.archunit:archunit-junit5` | `1.3.0` (202) | **BOM propio** | `epc.archunit.version=1.3.0` |
| `org.pitest:pitest-junit5-plugin` (declarado como `dependency`) | `1.2.1` (29, 235) | **BOM propio** | `epc.pitest.version=1.2.1` |
| `io.r2dbc:r2dbc-h2` | `1.0.0.RELEASE` (30, 252) | **BOM propio** (el `r2dbc-bom` que importa Boot no lo cubre de forma fiable) | `epc.r2dbc-h2.version=1.0.0.RELEASE` · *verificar en F1.2; si Boot lo cubriera, se borra* |
| `com.amazonaws.serverless:aws-serverless-java-container-{core,springboot3}` | `2.1.4` vía `${com.amazonaws.serverless.version}` (33, 257, 261) | **BOM propio** | `epc.serverless-java-container.version=2.1.4` |
| `org.mockito:mockito-junit-jupiter` | `4.11.0` (247) | `spring-boot-dependencies` | **Borrar** versión → **sube de 4.11.0 (Mockito 4) a la gestionada (Mockito 5)**: salto de major en dependencia **de test**. Queda como punto de decisión del usuario (`QUESTIONS_OPEN/question-015.md`); si se quiere fijar, se añade `epc.mockito.version` |
| `com.fasterxml.jackson.core:jackson-databind`, `io.projectreactor:reactor-test`, `org.mockito:mockito-core` | ya sin versión (182, 244, 249) | `spring-boot-dependencies` | Sin cambios |

Resultado: el `pom.xml` del piloto pasa de 56 `<version>` explícitas a **0** de terceros, y las únicas propiedades que quedan son las de §1.4.4.

#### 1.4.3 El conflicto de `spring.cloud.aws.version`, bien entendido (M1)

`quizapi/pom.xml:34` declara `<spring.cloud.aws.version>3.3.1</spring.cloud.aws.version>` y la usa en los dos starters (líneas 151, 158). Lo que ocurre no es una **colisión de nombres de propiedad**: los POM **importados** resuelven sus propias propiedades dentro de su propio modelo, y `spring-cloud-aws-dependencies` usa `spring-cloud-aws.version` (no `spring.cloud.aws.version`). Lo que sí decide el resultado es la **precedencia de `dependencyManagement`**: una entrada declarada en el `dependencyManagement` **del propio POM del ms** gana al `import` (nearest-wins). Por eso la migración **borra** del piloto la propiedad y las 2 versiones de los starters, y a partir de ahí la versión la fija el BOM. La medición de esa precedencia es F1.2 (`mvn help:effective-pom` + `dependency:tree`), y su resultado es el criterio de salida de la fase.

#### 1.4.4 Lo que el BOM **no** puede gobernar (B1, segunda mitad)

Un `import` de BOM solo aporta `dependencyManagement`. **No aporta `pluginManagement`**, así que **las versiones de plugins siguen viviendo en el `pom.xml` del microservicio**. Es una limitación de Maven, no del diseño: un ms solo puede tener un `<parent>`, y ya lo tiene (`spring-boot-starter-parent`).

| Elemento del piloto | Versión (línea) | Qué se hace |
| --- | --- | --- |
| `maven-compiler-plugin` | `3.14.0` (18, 274) | **Se queda en el ms.** El parent de Boot gestiona `maven-compiler-plugin`, pero el piloto fija `3.14.0` a propósito (properties + `-parameters`). *Verificar en F1.2:* si el `effective-pom` muestra la del parent, se puede borrar la propiedad `maven.compiler.plugin.version` y sus 3 usos |
| `maven-dependency-plugin` | `3.8.1` (309) | **Se queda** (lo usa el `copy-dependencies` de la imagen) |
| `jacoco-maven-plugin` | `0.8.12` (31→321, 344) | **Se queda.** El parent de Boot gestiona jacoco; *verificar en F1.2* si basta con borrar la propiedad `jacoco` |
| `org.pitest:pitest-maven` | `1.17.2` (344) | **Se queda** (plugin, distinto del `pitest-junit5-plugin` que sí es dependencia) |
| `sonar-maven-plugin` | `5.0.0.4389` (28, 369) | **Se queda** |
| `native-maven-plugin` | `0.10.2` (374) | **Se queda** |
| `maven-shade-plugin` | propiedad `maven.shade.plugin.version` (19) | **Se borra la propiedad**: el plugin **no está** en `<build>` (verificado) → está muerta |
| `annotationProcessorPaths` (`mapstruct-processor`, `lombok`) | 1.6.3 / 1.18.36 (281, 286) | **Se deja la versión explícita** siguiendo la propiedad, porque la resolución de `annotationProcessorPaths` a través de `dependencyManagement` no es fiable entre versiones de `maven-compiler-plugin`. *Verificar en F1.2:* si el `effective-pom` lo resuelve, se borran también estas dos versiones. Es la **única excepción documentada** a la CA #11, y solo para processors |
| `java.version`, `maven.compiler.source/target`, `skipTests`, `spring.aot.enabled` | (15-17, 391-393) | **Se quedan**: no son versiones de dependencias |

Por tanto, la CA #11 se cumple con una excepción acotada y declarada: el `pom.xml` de `quizapi` no declara versiones de **dependencias** presentes en `common-bom`; las versiones de **plugins** y de `annotationProcessorPaths` quedan en el ms porque Maven no ofrece un BOM para elas.

#### 1.4.5 Propiedades y mecanismo de propagación, sin adornos (M2)

Propiedades del BOM, prefijadas con `epc.` (`epc.spring-boot.version`, `epc.aws-sdk.version`, `epc.spring-cloud-aws.version`, `epc.springdoc.version`, `epc.jjwt.version`, `epc.karate.version`, `epc.archunit.version`, `epc.gson.version`, `epc.pitest.version`, `epc.r2dbc-h2.version`, `epc.serverless-java-container.version`, `epc.aws-lambda-java-core.version`, `epc.aws-lambda-java-runtime.version`): nunca colisionan con las `spring.*`/`aws.*` del ms, y sustituirlas es una operación de un solo fichero.

Cómo mantiene el ms su parent y cómo se propaga una versión:

- El ms conserva `<parent>spring-boot-starter-parent:3.4.0</parent>` y **añade** `<dependencyManagement>` con el `import` de `com.epc.common:common-bom:1.0.0`. El `dependencyManagement` del propio POM del ms (incluidos sus `import`) tiene precedencia sobre el heredado del parent; `spring-boot-maven-plugin` y el resto de plugins siguen viniendo del parent (§1.4.4). *Precedencia no documentada por Spring: la mide F1.2 con `mvn help:effective-pom` antes de migrar nada.*
- El ms declara `<dependency>` **sin `<version>`**; la resolución sale del `dependencyManagement` efectivo.
- **Mecanismo de propagación, dicho sin trampa**: cuando `common-bom` cambia una versión y se publica `1.0.1`, el `pom.xml` del ms **no se edita para propagar la definición** — no queda ninguna versión de third-party en él. Lo único que hay que subir en el ms es la `<version>` del propio `import` (`1.0.0 → 1.0.1`), **una línea**, y es exactamente lo que automatiza Renovate (§1.8). Decir "no hay que tocar nada" sería falso; decir "la definición vive en un solo fichero y el consumo se actualiza con una línea" es lo correcto. Por eso la CA #5 del objetivo se reescribe con esa redacción (§3, `OBJECTIVES/objetivo-002.md`).

### 1.5 CodeArtifact

Recursos declarados en Terraform en `projects/com.quizsmart.app/cloud/terraform/platform/` (**el agente no aplica**):

- Dominio CodeArtifact `epc` (KMS gestionada de AWS; sin CMK propia: +1 USD/mes evitado).
- Repositorio `common`, formato `maven`, upstream `maven-central`.
- Rol IAM de publicación (`common-publisher`) y de lectura (`common-reader`), con mínimo privilegio: `codeartifact:GetAuthorizationToken` sobre `*` (lo exige la API) + `ReadFromRepository` / `GetPackageVersion` / `PublishPackageVersion` sobre el ARN del paquete. `kms:Decrypt` solo si algún día hay CMK (`question-006`).
- Bucket S3 `epc-buildspecs` en la **misma región que el proyecto CodeBuild** (requisito para el ARN de buildspec), con versionado habilitado y acceso restringido al rol del pipeline (Zero Trust: nada público).
- Repositorio ECR `epc/common-base`.
- Secretos (valor sembrado por el usuario, nunca en Terraform): `epc/<env>/codeartifact`.

Configuración Maven — **un solo fichero**, `common/settings.xml` (plantilla para el desarrollador y para el CI):

```xml
<settings>
  <servers>
    <server>
      <id>codeartifact</id>
      <username>aws</username>
      <password>${env.CODEARTIFACT_AUTH_TOKEN}</password>
    </server>
  </servers>
  <profiles>
    <profile>
      <id>codeartifact</id>
      <repositories>
        <repository>
          <id>codeartifact</id>
          <url>https://epc-<cuenta>.d.codeartifact.<region>.amazonaws.com/maven/common/</url>
        </repository>
      </repositories>
    </profile>
  </profiles>
  <activeProfiles><activeProfile>codeartifact</activeProfile></activeProfiles>
</settings>
```

- El **`id` debe coincidir** entre `<server>` y `<repository>` (requisito explícito de la doc). El endpoint se obtiene con `aws codeartifact get-repository-endpoint --domain epc --repository common --format maven`; `<cuenta>`/`<region>` se parametrizan en el bootstrap, no se hardcodean.
- **No** hay `settings-publish.xml` (M5): la publicación sale del `<distributionManagement>` del POM raíz (§1.4.1).
- **Sin `<mirrors>`**: un mirror de Central haría que cada build de cada ms descargase de la cuenta (0,09 USD/GB) sin necesidad.
- El token se obtiene con `aws codeartifact get-authorization-token` (**12 h** de validez, suficiente para una build) y viaja como variable de entorno `CODEARTIFACT_AUTH_TOKEN`, inyectada por CodeBuild desde Secrets Manager (`env.secrets-manager`). Nunca en el repositorio.

Versionado: una sola línea de versiones. `1.0.0` es el primer y único número; se bumpea en `common/pom.xml` (`1.0.1`, `1.1.0`, `2.0.0`) **antes** de publicar. Sin `-SNAPSHOT` ni propiedad `revision`: con un solo número, `mvn install` en el repo local y lo publicado por CodeArtifact son las mismas coordenadas y el ms resuelve sin sorpresas (B3).

### 1.6 Imagen base ECR: **imagen de runtime** + compilación en el buildspec

El criterio de aceptación (`Dockerfile` del ms de ≤5 líneas) y el hecho de que el piloto compile Maven dentro de `docker build` (`Dockerfile:1-11`) son incompatibles (research §7). Resolución: **Opción B** — `epc/common-base` es imagen de **runtime** y la compilación vive en el buildspec compartido `docker-build.yml`.

`common/docker/Dockerfile` (imagen base): `FROM public.ecr.aws/lambda/java:17` + `ENV TZ=UTC`. **No** fija `USER` (B-5): el `COPY` del `Dockerfile` del ms corre como root y produce ficheros legibles; documentado en `docs/como-usar.md`.

`projects/com.quizsmart.app/backend/quizapi/Dockerfile` tras migrar (4 líneas):

```dockerfile
FROM <cuenta>.dkr.ecr.<region>.amazonaws.com/epc/common-base:1.0.0
COPY target/classes ${LAMBDA_TASK_ROOT}
COPY target/dependency/* ${LAMBDA_TASK_ROOT}/lib/
CMD [ "com.quizsmart.app.LambdaHandler::handleRequest" ]
```

`docker-build.yml` compila **fuera** de Docker (`mvn -B dependency:copy-dependencies -DincludeScope=runtime compile`) y luego `docker build`. El `.dockerignore` del piloto (que **no existe**, B-3 / `question-013`) se crea en F7.4 con contenido mínimo (`.git`, `logs`, `postman`, `.idea`, `bootstrap`) y **sin** `target/`: el contexto necesita `target/classes` y `target/dependency/`.

| | Opción A (imagen de build) | **Opción B (elegida)** |
| --- | --- | --- |
| `Dockerfile` del ms | 6-7 líneas | **4 líneas** |
| `docker build` | ~90 s (compila Maven) | **~10 s** (solo `COPY`) |
| Imagen del ms | ~700 MB | capa de runtime compartida (~250 MB, cacheada) |
| CA #7 | incumplido | **cumplido** |
| Coste | — | compilación fuera de Docker: quien construya a mano ejecuta antes `mvn compile dependency:copy-dependencies` (documentado) |

Publicación: `common/docker/publish-base-image.sh` (lo ejecuta el pipeline en cada release): `aws ecr get-login-password | docker login` → `docker build` → `docker push …:1.0.0`. **Sin tag `:latest`** (B-4: duplicaría punteros en cada release sin ganar nada). IAM: `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`, `ecr:PutImage`.

Divergencia Fargate: una imagen de runtime para Lambda **no** sirve para Fargate (entrypoint, `USER`, filesystem). Cuando exista el primer consumidor Fargate se publica `epc/common-base-fargate:1.0.0` desde el mismo repo. Coste: +0,01 USD/mes por imagen publicada una vez.

### 1.7 CI: AWS CodePipeline + CodeBuild

Los repos de `common`, `platform` y los microservicios viven en CodeCommit. Los buildspecs compartidos viven en `platform/buildspecs/` y se publican en la raíz del bucket S3 versionado `epc-buildspecs`; CodeBuild los consume mediante ARN, por ejemplo `arn:aws:s3:::epc-buildspecs/java-ci.yml`.

- `java-ci.yml`: compila/verifica Java y obtiene el token de CodeArtifact desde Secrets Manager.
- `docker-build.yml`: compila y construye la imagen del microservicio sobre la imagen base (§1.6).
- `renovate.yml` y `bump-bom.yml`: automatizaciones separadas de versionado (§1.8).
- `publish-buildspecs.sh` publica los cuatro buildspecs a la raíz del bucket.

El bucket conserva versiones anteriores, pero el ARN sin `object version` resuelve la versión actual del objeto: no equivale a un pin inmutable de commit. Se acepta esta limitación conforme a ADR-0016. Cada microservicio mantiene su propio pipeline/proyecto CodeBuild; no se crea un pipeline universal parametrizado.

### 1.8 Renovate

Conforme a ADR-0018, CodeCommit no tiene plataforma de PR nativa en Renovate. El flujo usa dos automatizaciones, ambas en CodeBuild:

1. **Renovate semanal para `common`**: EventBridge Scheduler ejecuta Renovate con `platform: local`; Renovate actualiza dependencias gobernadas por el BOM y deja ramas. `open-codecommit-prs.py` abre PRs idempotentes.
2. **Bump por release para cada MS**: el tag `v*` en `common` genera un evento de referencia de CodeCommit que inicia `platform-bump-bom`; `bump-bom-version.py` actualiza solo la versión del import `common-bom` y abre PRs en los repos CodeCommit.

`common/renovate.json` — **sin credenciales** (B4). `hostRules[].password` es un valor **literal**: no existe indirección por variable de entorno en la configuración del repo, y escribir el nombre de la variable ahí haría que Renovate mandara la cadena `CODEARTIFACT_AUTH_TOKEN` como contraseña (401 en cada ejecución) *y* sería una credencial en un fichero versionado.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended", ":dependencyDashboard", ":semanticCommits"],
  "enabledManagers": ["maven"],
  "registryUrls": ["https://epc-<cuenta>.d.codeartifact.<region>.amazonaws.com/maven/common/"],
  "packageRules": [
    { "matchDepTypes": ["import"], "groupName": "common bom" }
  ]
}
```

**Dónde vive la credencial** (verificado en [Renovate — Self-hosted configuration](https://docs.renovatebot.com/self-hosted-configuration/)): con `detectHostRulesFromEnv: true` (flag de CLI/env `RENOVATE_DETECT_HOST_RULES_FROM_ENV`, default `false`), Renovate construye `hostRules` desde variables de entorno con formato `RENOVATE_<datasource>_<matchHost>_<campo>`, y admite **omitir la parte del host** (*"You can skip the host part, and use only the datasource and credentials"* → ejemplo `DOCKER_USERNAME`/`DOCKER_PASSWORD`). Es decir: **el runner se autentica con su propia identidad**, sin tocar el repo:

```bash
export RENOVATE_DETECT_HOST_RULES_FROM_ENV=true
export MAVEN_USERNAME=aws
export MAVEN_PASSWORD="$(aws codeartifact get-authorization-token --domain epc --query token --output text)"
  renovate --platform=local --dry-run
```

El token se pide **fresco en cada ejecución** (caduca a las 12 h), lo que además elimina el problema de cacheo de credenciales. Alternativa si el runner no puede hablar con la API de AWS: `secrets` en el `config.js` del administrador + `{{ secrets.CODEARTIFACT_TOKEN }}` en el repo (documentada en la misma página). Ninguna de las dos escribe el secreto en el repositorio.

Qué criterio cumple y cuál no:

- **Cumple mediante el trigger**, no Renovate directamente: al publicar una versión nueva, el script sube una línea del import `common-bom` y abre el PR en cada MS.
- **No cumple, y no puede**: abrir PR en el ms por una vulnerabilidad de una dependencia transitiva gobernada por el BOM. Renovate no lee el POM del BOM para actualizar versiones que en el ms no existen. Eso se resuelve **en `common`** (Renovate corriendo sobre `common` abre el PR que sube `spring-boot-dependencies`, `aws-sdk-bom`, …) y luego el PR del ms llega por la vía anterior. La CA #6 del objetivo se reescribe con esta redacción honesta (§3).

### 1.9 Migración de `quizapi`, archivo por archivo

**Se borran (4):**

| Archivo | Va a |
| --- | --- |
| `src/main/java/com/quizsmart/app/infrastructure/configuration/GlobalExceptionHandler.java` | `common-web`, como bean de auto-configuración con `@ConditionalOnMissingBean` en el método `@Bean` |
| `src/main/java/com/quizsmart/app/infrastructure/configuration/GeneralException.java` | `common-error`, renombrada a `CommonException` (checked, con `Map data` + `addData`) |
| `src/main/java/com/quizsmart/app/infrastructure/rest/response/ApiResponse.java` | `common-error` |
| `src/main/java/com/quizsmart/app/infrastructure/rest/response/ErrorApiResponse.java` | `common-error` |

**Se modifican (main):** `HolaMundoController` (imports a `com.epc.common.error.*`; `GeneralException` → `CommonException`, con `addData` igual), `ParameterController`, `SubscriptionController`, `AiController` (solo el import de `ApiResponse`). Nada más cambia: mismo cuerpo, mismo status, mismo mensaje.

**Tests — tarea del usuario (A6):** `ParameterControllerTest.java:4` y `HolaMundoControllerTest.java:3-4` importan `ApiResponse`/`ErrorApiResponse` del paquete borrado → hay que cambiar esos imports a `com.epc.common.error.*`. El agente **no** edita tests (`AGENTS.md`); queda listado como paso de traspaso en `DELIVERABLES/objetivo-002/implementation-002.md` y como criterio de salida de F7. Detalle útil: el import de `ErrorApiResponse` en `HolaMundoControllerTest.java:4` **no se usa** (la línea 35 solo usa `ApiResponse.class`), así que basta con borrarlo o reescribirlo.

**`pom.xml`:** borrar las 56 `<version>` explícitas, las propiedades de §1.4.2 y el `<dependencyManagement>` que importa `software.amazon.awssdk:bom`; añadir el `import` de `com.epc.common:common-bom:1.0.0` y **una sola** dependencia `com.epc.common:common-web` sin versión (que ya arrastra `common-error` y `common-log`; declararlas además sería redundante). Se conservan `<parent>spring-boot-starter-parent</parent>`, `java.version`/`maven.compiler.*` y **todos** los plugins con su versión (§1.4.4).

**Verificación previa a los tests (F7.3):** con `mvn -o test-compile` el Developer comprueba que el código de test **compila** (los imports viejos fallen aquí). `HexagonalArchitectureTest` no se ve afectado por lectura de sus tres reglas (`domainIndependence`, `applicationNoInfrastructureDependency`, `noCircularDependencies`): ninguna exige que existan clases en `infrastructure.rest.response` ni restringe las dependencias **salientes** de `infrastructure`, y borrar clases no puede crear ciclos. El Developer lo re-comprueba en F7 y cualquier ajuste del test es tarea del usuario.

**No se toca** (inventario del research, verificado): `infrastructure/configuration/{AiProperties,AiConstants,AiMessages,GraalHints,MapperInfo,MapperClass,ParameterProperties}`, `infrastructure/configuration/cloud/aws/**`, `infrastructure/configuration/webfilters/RevenueCatWebhookFilter.java`, controladores restantes, `adapters/`, `persistence/`, `domain/`, `application/`, `LambdaHandler`, `Application`, `logback.xml`, `postman/`, `bootstrap`, `*.ps1`, `sonar-*.properties`, `.gitignore`.

### 1.10 Contrato de `ApiResponse` (A6: compatible con el piloto)

| Aspecto | Decisión | Criterio |
| --- | --- | --- |
| `timestamp` con `LocalDateTime.now()` (hora local del host) | **El tipo NO cambia** (`LocalDateTime`); solo cambia el reloj: `LocalDateTime.now(Clock.systemUTC())` | El contrato es el problema, no la zona: cambiar el tipo a `Instant` cambiaría el JSON (gana una `Z`), obligaría a tocar los 6 ejemplos de Postman y a revisar clientes, todo en un objetivo cuyo problema es el código duplicado. Con `Clock.systemUTC()` el **valor** es correcto (UTC) y el JSON es idéntico → **cero trabajo para el usuario**. Limitación consciente: el JSON sigue sin offset; se revisa solo si un consumidor necesita la zona |
| `environment` (siempre `null`) | **Se elimina del contrato** | Campo muerto: nadie lo setea (grep verificado), no lo lee el cliente y no aparece en los ejemplos de Postman. Eliminarlo **no cambia** ningún ejemplo (Jackson lo serializaba como `"environment":null`, que nadie consume). No hay campo nuevo que preservar |
| `stackTrace` al cliente (A2) | **Una sola forma, sin propiedad interruptora**: `ErrorApiResponse` conserva el campo, **nunca se puebla** en el advice (el stack se registra con `log.error(msg, ex)`), y la clase lleva `@JsonInclude(NON_NULL)` → la clave no aparece en el JSON | Mínimo privilegio / Zero Trust: no se filtra estructura interna por defecto. Se mantiene la clase y el campo para no romper a un cliente futuro, pero **no hay ninguna propiedad configurable**: la versión anterior (`@ConditionalOnProperty` sobre el advice) estaba mal porque desactivarla hacía que `CommonException` perdiera su handler y cayera en el genérico, es decir rompía el manejo de errores en lugar de ocultar el stack |
| Forma de la clase | Se conservan los **dos constructores** (`Map<String,Object>` y `Object`, este último envolviendo en `{"data": x}`), el constructor no-arg y los setters | `AiController.badRequest()` (líneas 72-78) depende del overload con `Map` para desambiguar un `null`, y los tests hacen `expectBody(ApiResponse.class)`, que exige no-arg + setters. `ApiResponse` sigue siendo clase mutable, no `record` |
| Nombres en el cliente | `getMessage()`, `getStatus()`, `getData()` intactos | Los tests (`HolaMundoControllerTest:37-41`, `ParameterControllerTest`) leen solo esos tres |

**Consecuencia: los 6 ejemplos de `timestamp` de `postman/quizapi.postman_collection.json` NO cambian** y **no hay tarea de usuario para Postman**. La colección solo se tocaría si se añadiera o eliminara un endpoint, y este objetivo no añade ninguno (regla de `AGENTS_ROOT` satisfied por no haber cambio de endpoint).

---

## 2. Archivos a crear

### Frontend

- Ninguno. Los paquetes Dart quedan fuera de alcance (`question-004.md`).

### Backend

`common/` (ruta en este workspace; el Developer trabaja aquí; el repo remoto lo crea el usuario en F3):

- `pom.xml` — parent: propiedades, `pluginManagement` (compiler, flatten, surefire), `flatten-maven-plugin` 1.8.0 (`flattenMode` por defecto + `updatePomFile=true`), `modules`, `distributionManagement`.
- `common-bom/pom.xml` — `dependencyManagement` completo de §1.4.2.
- `common-log/pom.xml`, `common-log/src/main/java/com/epc/common/log/MdcCorrelation.java`.
- `common-error/pom.xml`, `common-error/src/main/java/com/epc/common/error/{ApiResponse,ErrorApiResponse,CommonException}.java`.
- `common-web/pom.xml`, `common-web/src/main/java/com/epc/common/web/{WebAutoConfiguration,GlobalExceptionHandler,RequestCorrelationFilter}.java`, `common-web/src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`.
- `samples/log-only-sample/**`, `samples/web-sample/**` — 2 apps mínimas (M3); `log-only-sample` sirve además para medir la precedencia del BOM (F1.2).
- `docker/Dockerfile`, `docker/publish-base-image.sh`.
- `settings.xml` (plantilla), `renovate.json`, `README.md`.
- `docs/{como-usar.md,como-versionar.md,como-migrar-un-ms.md}` — `como-migrar-un-ms.md` lleva los snippets de `.gitignore`/`.dockerignore`/`settings.xml` (M7: sin ficheros de plantilla sueltos).
- `common-*/src/test/**` — los escribe el usuario.

`platform/` (repo único de plataforma, desviación del objetivo):

- `buildspecs/{java-ci.yml,docker-build.yml}`, `scripts/publish-buildspecs.sh`.
- `buildspecs/{renovate.yml,bump-bom.yml}`, scripts de PR para CodeCommit y `README.md`.
- `.gitignore`, `README.md`.

### Cloud

`platform/` (**el agente no hace `apply`**):

- Terraform de CodeArtifact, bucket `epc-buildspecs` versionado y restringido, ECR `epc/common-base`, roles IAM, CodePipeline de `common`, proyectos CodeBuild para Renovate y bump, Scheduler y regla de evento por tag.
- La aplicación en AWS la ejecuta el usuario. El agente valida localmente formato y sintaxis, sin `terraform apply`.

## 3. Archivos a modificar

### Frontend

- Ninguno.

### Backend

`projects/com.quizsmart.app/backend/quizapi/`:

- `pom.xml` — borrar las 56 `<version>` + propiedades según §1.4.2/§1.4.4; borrar el `dependencyManagement` de aws-sdk; importar `common-bom:1.0.0`; añadir `common-web` sin versión. **Único cambio de contrato**: ninguno.
- `Dockerfile` — 10 líneas → 4 sobre `epc/common-base:1.0.0`.
- `.dockerignore` — **nuevo** (no existía): `.git`, `logs`, `postman`, `.idea`, `bootstrap`; **sin** `target/`.
- `src/main/java/com/quizsmart/app/infrastructure/controllers/HolaMundoController.java` — imports a `com.epc.common.error.*`, `GeneralException` → `CommonException`.
- `.../ParameterController.java`, `.../SubscriptionController.java`, `.../AiController.java` — import de `ApiResponse`.
- **Borrar**: `.../configuration/GlobalExceptionHandler.java`, `.../configuration/GeneralException.java`, `.../rest/response/ApiResponse.java`, `.../rest/response/ErrorApiResponse.java`.
- El pipeline del microservicio debe ser CodePipeline/CodeBuild con el buildspec de S3 por ARN; la infraestructura específica del MS es pendiente de completar/verificar.
- **Tarea del usuario (A6), no la hace el agente**: `src/test/java/com/quizsmart/app/infrastructure/controllers/ParameterControllerTest.java:4` y `HolaMundoControllerTest.java:3-4` — imports de `ApiResponse`/`ErrorApiResponse`.
- `sonar-scanner.properties` / `sonar-project.properties` — credenciales en claro (señalado, fuera de alcance).

Sin cambios: `postman/quizapi.postman_collection.json` (el contrato no cambia de forma), `logback.xml`, `bootstrap`, `*.ps1`, `.gitignore`.

### Cloud

- `projects/com.quizsmart.app/cloud/terraform/quizapi/lambda.tf` — sin cambios (`package_type = "Image"` + `image_uri`; solo cambia el contenido de la imagen).
- `projects/com.quizsmart.app/cloud/terraform/platform/` — nuevo (§2 Cloud).

## 4. Flujo

**Consumo (ms → common):** `mvn` resuelve `common-bom:1.0.0` en CodeArtifact → versiones de terceros y de los módulos `common-*` → el ms compila. Sin copia de ficheros ni submódulos: `git clone` del ms + `settings.xml` con el token = build completo.

**Arranque del ms (web):** Spring lee el `AutoConfiguration.imports` de `common-web` → `WebAutoConfiguration` ve `WebFilter` en el classpath y el contexto REACTIVO → registra `RequestCorrelationFilter` (MDC `requestId`) y, si el ms no define su advice, `GlobalExceptionHandler` → una `CommonException` sale como 500 con `ErrorApiResponse` **sin `stackTrace`**, y el stack queda en el log. Con un ms no-web, `common-web` ni está en el classpath.

**Publicación de una versión:** se bumpea el número en `common/pom.xml` → tag `v1.0.1` → CodePipeline valida con `java-ci.yml` → `mvn deploy` a CodeArtifact → `docker/Dockerfile` se publica como `epc/common-base:1.0.1` → Renovate ve la release y abre PR en cada ms actualizando la versión del `import`.

**Build de imagen de un ms:** `docker-build.yml` → `mvn compile dependency:copy-dependencies` → `docker build` con el `Dockerfile` de 4 líneas → push al ECR del ms → Terraform Lambda referencia la imagen.

## 5. Lista de tareas y subtareas

El estado de ejecución vigente se mantiene en `DELIVERABLES/objetivo-002/implementation-002.md` y `STATUS/status.md`. Resumen v3:

- **Entregado localmente:** módulos de `common`, BOM, buildspecs/scripts/Terraform de `platform`, importación de `common-bom` en el generador y migración de código de producción de `quizapi` a `common`.
- **Pendiente de código/documentación:** completar el Terraform/CodeBuild específico de cada microservicio; alinear la documentación heredada con ADR-0018/0020; verificar el despliegue excluyendo solo `common-parent`; re-test de los arreglos y revisión final.
- **Pendiente del usuario:** limpiar y regenerar la salida del generador, actualizar los imports de tests y ejecutar la suite; aplicar Terraform, sembrar credenciales y verificar CodeArtifact/S3/CodeBuild/ECR/CodeCommit en AWS.

El agente no ejecuta `terraform apply`/`destroy`, no gestiona credenciales ni modifica tests.

## 6. Decisiones asumidas

1. **`common-helpers` no se crea** en este objetivo (nada que extraer, sin consumidores). Se crea cuando el segundo ms tenga algo real que extraer.
2. **`common-log` sí se crea**, con `MdcCorrelation` (MDC sin web) y API congelada en `1.0.0`. El filtro de correlación es web y vive en `common-web`.
3. **`groupId = com.epc.common`**, raíz `common-parent`.
4. **Versión única `1.0.0`**, literal, sin `${revision}` ni SNAPSHOT. Se bumpea en un fichero (B2, B3).
5. **`epc/common-base` es imagen de runtime**; la compilación vive en `docker-build.yml`; `Dockerfile` del ms de 4 líneas.
6. **Presupuesto de versiones del BOM = las del piloto**: Spring Boot 3.4.0, aws-sdk 2.31.73, spring-cloud-aws 3.3.1. No se sube a Boot 3.5.x (el componente del generador se llama `spring-boot-3.5.16` pero su `pom.scriban` fija 3.4.0: inconsistencia preexistente, fuera de alcance).
7. **Propiedades del BOM prefijadas con `epc.`** para no colisionar con `spring.*`/`aws.*` del ms.
8. **Versiones de plugins y de `annotationProcessorPaths` quedan en el ms**: un `import` de BOM no aporta `pluginManagement` y un ms solo puede tener un `<parent>`. Excepción declarada a la CA #11.
9. **Sin `<mirrors>`** en `settings.xml`; CodeArtifact como repositorio adicional.
10. **Un solo `settings.xml`** (plantilla) con `<server>` + perfil de repositorio; la publicación va en el POM raíz.
11. **Token de CodeArtifact** por variable de entorno sembrada por el usuario en Secrets Manager / variable group.
12. **Sin CMK propia** en CodeArtifact (+1 USD/mes evitado).
13. **Repo único `platform/` en CodeCommit** (registrado en ADR-0017/0018): contiene buildspecs, scripts y Terraform de plataforma.
14. **Renovate con `platform: local`** semanalmente; los PRs de CodeCommit los abre `open-codecommit-prs.py`. El bump por tag es un flujo separado (ADR-0018).
15. **`common-parent` no se publica** (ADR-0020); el `maven-deploy-plugin` omite solo el POM raíz y la configuración no se hereda a módulos.
16. **`epc.common.web.enabled` no existe**: se aplaza (resuelve `question-012`). Sin `ErrorMessages` (constantes privadas en el advice).
17. **No hay `.gitignore`/`.dockerignore` de plantilla ni `install-config.sh`**: snippets en `docs/como-migrar-un-ms.md` (resuelve `question-013` con el `.dockerignore` del piloto creado en F7.4).
18. **Sin tag `:latest`** en la imagen base.
19. **La CI común usa CodePipeline/CodeBuild** y los MS consumen buildspecs del bucket S3 por ARN; cada MS conserva su propio pipeline/proyecto.
20. **El generador importa `common`**: deja de emitir los contratos/excepciones/handler que ahora entrega `common`; `logback.xml` sigue en el MS.
21. **`logback.xml` del ms se queda** (el patrón con `%X{requestId}` es opcional y no bloqueante).
22. **CA #5 y #6 del objetivo se reescriben** con la redacción honesta, y se registra en `DECISIONS`.

## 7. Fuera del alcance

- Paquetes Dart (`common_log`, `common_error`, cliente HTTP, caché, colas, seguridad, feature flags, métricas, schedulers): solo Java (`question-004.md`).
- `common-web` para servlet/MVC: llega con el primer consumidor (`question-003.md`).
- Migrar más de un microservicio; solo `quizapi`.
- Imagen base para Fargate (imagen aparte cuando haya consumidor).
- Publicar un parent Maven compartido para `pluginManagement` (el MS conserva `spring-boot-starter-parent`; plugins siguen configurados por MS).
- Autenticación de CodeArtifact en los pipelines de ms que todavía no usan `common`.
- Gates de calidad nuevos, OpenTelemetry, caché, colas, rate limiting, CORS, security como parte de `common`.
- Credenciales preexistentes de `sonar-scanner.properties`: fuera del alcance de este objetivo; requieren rotación y gestión segura.
- Sincronización automática de `.gitignore`/`.dockerignore`.
- Pipeline único parametrizado; `BuildspecOverride` inline; `git submodule`.
- `CORS` y `SecurityConfig` en `common-web`.

## 8. Riesgos y coste

| Riesgo | Severidad | Mitigación / criterio de salida |
| --- | --- | --- |
| El BOM no cubre alguna coordenada que el piloto fijaba y el ms se queda sin versión | Alta (era B1) | Tabla exhaustiva §1.4.2 + F1.3 verifica los cuatro supuestos con `effective-pom`; F7.3 compila con `-o` |
| Precedencia `spring-boot-starter-parent` vs BOM importado sin verificar en la doc de Spring | Alta | Medida en F1.2 antes de migrar; si gana el parent, el BOM deja de importar `spring-boot-dependencies` |
| Mockito 4.11.0 → gestionada (major) al borrar su versión | Media | Dependencia **de test**; el Developer verifica `test-compile` y el usuario decide al ejecutar la suite (`question-015.md`) |
| Renovate sin soporte nativo de CodeCommit y token de 12 h | Media | Scheduler semanal con `platform: local`; scripts idempotentes crean PRs; token de CodeArtifact fresco por ejecución |
| Matriz IAM de CodeArtifact sin verificar | Media | Rol con los permisos mínimos documentados; lo valida el `apply` del usuario (`question-006`) |
| Pérdida del pin exacto del buildspec (CodeBuild toma la última versión del objeto) | Media (ya aceptada en `question-002.md`) | Versionado del bucket; claves por versión (`java-ci-1.0.0.yml`) si alguna vez hace falta reproducibilidad bit a bit |
| `Dockerfile` de 4 líneas rompe el build local de quien solo haga `docker build` | Baja | Documentado en `docs/como-usar.md`; el CI compila antes |
| Plantillas del generador reintroducen el código migrado | Media | Aceptado (§6.20) |
| `HexagonalArchitectureTest` o `pitest` configuran paquetes que desaparecen | Baja | Revisado por lectura: ninguna regla exige la existencia de esas clases (§1.9); el Developer lo re-verifica en F7 y el ajuste es del usuario |
| `include-stack-trace` no existe: si alguien quiere depurar en cliente, no puede | Baja | Aceptado (A2): el stack va al log con `log.error(msg, ex)` |

**Coste AWS mensual estimado (todo nuevo de este objetivo): < 2 USD/mes.**

| Recurso | Coste |
| --- | --- |
| Dominio + repo CodeArtifact (KMS gestionada) | ~0,05 USD/mes + 0,09 USD/GB descargado. `common` son unos pocos MB por ms → céntimos/mes |
| Bucket `epc-buildspecs` versionado | ~0 USD/mes (KB + `GetObject`) |
| ECR `epc/common-base` (1 imagen, una vez) | ~0,01 USD/mes de capas; 0 cómputo |
| CodeBuild de publicación | `BUILD_GENERAL1_SMALL` ~0,17 USD/min × unos minutos por release → ~1 USD/mes |
| Renovate self-hosted | 0 USD (runner del pipeline existente) |
| **F0-F2, F7 y F9 (todo el código, incluida la migración del piloto)** | **0 USD** |
| **Total** | **< 2 USD/mes**, por debajo del techo de 10 USD/mes |

A escala 500 ms el término variable es CodeArtifact: 500 ms × ~3 MB por build × 30 builds/mes ≈ 45 GB/mes ≈ **4 USD/mes**. Sigue dentro del techo; si algún día lo superara, la mitigación es empaquetar `common-*` en el artefacto que distributes en el buildspec en vez de resolverlo en cada build.
