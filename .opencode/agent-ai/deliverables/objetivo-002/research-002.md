# Investigación — Objetivo 002

## Problema

Diseñar `common`: proyecto Maven multi-módulo reutilizable (dependencia por capacidad), BOM de versiones, publicación en CodeArtifact, buildspecs compartidos en CodeCommit, plantillas Azure DevOps, imagen base en ECR, paquetes Dart, y migración piloto de `quizapi`. La investigación cubre: (a) mecanismos técnicos verificables en documentación oficial y (b) inventario real del microservicio piloto.

## Estado actual del código

### Microservicio piloto `projects/com.quizsmart.app/backend/quizapi`

Estructura: **proyecto Maven de un solo módulo** (no multi-módulo), `groupId=com.quizsmart`, `artifactId=quizapi`, `version=1.0`.

- Parent: `org.springframework.boot:spring-boot-starter-parent:3.4.0`, `java.version=17`.
- Stack: WebFlux (reactivo) + R2dbc/H2 + Spring Cloud AWS 3.3.1 (parameter-store, secrets-manager) + AWS SDK v2 2.31.73 + DynamoDB + SNS + `aws-serverless-java-container` 2.1.4 (Lambda + Spring Boot 3). Ya trae `graalvm/native-maven-plugin`, `jacoco`, `pitest`, `sonar`, `archunit`, `karate`, `mapstruct`, `lombok`, `jjwt`.
- `dependencyManagement` propio con `software.amazon.awssdk:bom` importado.
- **56 dependencias con `<version>` explícita** (líneas 13–35 y 47–263 del `pom.xml`): es exactamente el problema que el BOM viene a eliminar.

Código a extraer (rutas exactas):

| Archivo | Qué hace | Destino en `common` |
| --- | --- | --- |
| `src/main/java/com/quizsmart/app/infrastructure/configuration/GlobalExceptionHandler.java` | `@ControllerAdvice` con 2 handlers (`GeneralException`, `Exception`), devuelve `ResponseEntity<ApiResponse>` | `common-web` |
| `src/main/java/com/quizsmart/app/infrastructure/configuration/GeneralException.java` | Excepción checked con `Map<String,Object> data` + `addData` | `common-error` |
| `src/main/java/com/quizsmart/app/infrastructure/rest/response/ApiResponse.java` | Envoltorio `{data, message, status, timestamp, environment}` con `LocalDateTime.now()` y sobrecarga `(Object,...)` que envuelve en `{"data": x}` | `common-error` |
| `src/main/java/com/quizsmart/app/infrastructure/rest/response/ErrorApiResponse.java` | Subclase que añade `stackTrace` (expuesto al cliente) | `common-error` |

**Hallazgo relevante: NO existen en `quizapi`** (verificado por grep sobre `src/`):

- `PageResponse` — no existe.
- `ErrorCode` — no existe.
- Helpers de fecha — no existen (único uso de tiempo: `LocalDateTime.now()` dentro de `ApiResponse` y `Instant.parse(...).toEpochMilli()` en `infrastructure/adapters/RevenueCatAdapter.java:108`).
- MDC / `request-id` / correlación de logs — no existe. `src/main/resources/logback.xml` es un `ConsoleAppender` con patrón `%d{yyyy-MM-dd HH:mm:ss} %-5level %logger{36} - %msg%n`, sin `logging.pattern` con MDC.
- Perfil de log por entorno — no existe.
- `.dockerignore` — no existe (el `.gitignore` es genérico y enorme, plantilla VisualStudio + Java; línea 385 ignora `*.dockerfile`).
- `Dockerfile`: 10 líneas, multi-stage `maven:3.9.6-eclipse-temurin-17` → `public.ecr.aws/lambda/java:17`, `CMD ["com.quizsmart.app.LambdaHandler::handleRequest"]`. Ya es compatible con la idea de imagen base.
- Pipelines del ms: solo `azure-build.yml` (Azure DevOps, jobs `Build` / `Static_Testing` / `Security`, sin `resources.repositories`, sin plantilla compartida). **No hay buildspec de CodePipeline para el ms**; el único buildspec es `cloud/terraform/modules/pipeline/buildspec-plan.yml` / `buildspec-apply.yml`, que son de Terraform, no de Java.
- Terraform Lambda: `package_type = "Image"`, `memory_size = 512`, `image_uri = <ecr>/quizapi:latest` (`cloud/terraform/quizapi/lambda.tf:59-62`).
- **Fuga de secreto existente**: `azure-build.yml:16` tiene `NVD_API_KEY: 'dbe68886-...'` en claro; `sonar-scanner.properties:12-13` tiene `sonar.login=admin` / `sonar.password=admin`. No es parte de este objetivo, pero conviene señalarlo.

Divergencias piloto vs.Fleet vs. Spring Cloud AWS:

- **Lambda, no Fargate**: el objetivo menciona Fargate como uno de los casos; `quizapi` es Lambda con `aws-serverless-java-container`. La imagen base `epc/common-base` debe servir para runtime Java gestionado por Lambda; una imagen Fargate NO puede ser la misma (entrypoint, user, filesystem de `/var/task`).
- **WebFlux, no MVC**: `GlobalExceptionHandler` es WebFlux. `common-web` no puede asumir `spring-boot-starter-web` (Tomcat). Un `GlobalExceptionHandler` compartido debe funcionar en ambos o declararse solo para reactivo.
- **Spring Cloud AWS 3.3.1 ya está en el ms**: si `common-bom` importa `spring-cloud-aws-dependencies` como BOM y el ms además fija la versión, hay conflicto de propiedad (`spring.cloud.aws.version`). Verificar antes.
- `spring-boot-dependencies` 3.4.0 ya gobierna las versiones Boot vía parent; `common-bom` importándolo cambiaría la precedencia. Criterio de aceptación "el pom de quizapi no declara versiones presentes en common-bom" es alcanzable, pero el orden `spring-boot-starter-parent` + `common-bom` importado **no** es un orden documentado por Spring: el BOM importado gana al parent, sí, pero el `spring-boot-maven-plugin` sigue viniendo del parent. Verificar con un proyecto de prueba.

### Findings de investigación web

#### 1. Spring Boot 3.4 / Java 17 — auto-configuración

Fuente: [Creating Your Own Auto-configuration](https://docs.spring.io/spring-boot/reference/features/developing-auto-configuration.html) y [Auto-configuration](https://docs.spring.io/spring-boot/reference/using/auto-configuration.html) (la URL canónica redirige a la versión 4.1.1; el mecanismo es idéntico en 3.4).

- Registro: archivo `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`, un FQCN por línea, comentarios con `#`. **Solo se cargan las clases nombradas ahí**; deben estar en un espacio de paquetes propio y nunca ser objetivo de component scan; no deben activar component scan.
- `@AutoConfiguration` es meta-anotada con `@Configuration`. Combinarla con `@ConditionalOnClass` / `@ConditionalOnMissingBean`.
- Orden: atributos `before` / `beforeName` / `after` / `afterName` en `@AutoConfiguration`, o `@AutoConfigureBefore` / `@AutoConfigureAfter`. El orden solo afecta al **orden de definición** de beans, no al de instanciación.
- `@ConditionalOnMissingBean` funciona solo en auto-configuración: la doc recomienda usarlo **únicamente** en clases de auto-configuración, porque se garantiza que se cargan después de las definiciones del usuario.
- Aislamiento de `common-log` vs `common-web` (criterio de aceptación): se consigue por **dependencia transitiva**, no por orden. Si `common-log` no declara `common-web` en su `pom.xml` (ni con `runtime`/`compile`), el artefacto `common-web` no llega al classpath y su `AutoConfiguration.imports` no existe. `@AutoConfigureAfter/Before` solo ordena lo que ya está en el classpath. Regla: `common-web` es el único módulo que depende de `common-log` y `common-error`; dependencia inversa nunca. Verificación: `mvn dependency:tree` + el report de `--debug`.
- Testing de auto-configuración: `ApplicationContextRunner` + `AutoConfigurations.of(...)`; no funciona en imagen nativa (relevante: `quizapi` tiene plugin GraalVM).

#### 2. Maven multi-módulo + BOM

Fuentes: [Maven CI Friendly Versions](https://maven.apache.org/maven-ci-friendly.html), [Using Modules (Maven 3)](https://maven.apache.org/guides/mini/guide-multiple-modules.html), [Flatten Maven Plugin](https://www.mojohaus.org/flatten-maven-plugin/).

- `${revision}` / `${sha1}` / `${changelist}` **solo** funcionan con esos tres nombres. `1.0.0-${buildNumber}-SNAPSHOT` no funciona.
- Multi-módulo: el padre usa `<version>${revision}</version>` + `<properties><revision>…</revision></properties>`; los hijos heredan `<parent><version>${revision}</version>`. Dependencias entre módulos: **`${project.version}`, nunca `${revision}`** (usar `${revision}` falla).
- **`flatten-maven-plugin` es obligatorio** para instalar/desplegar con CI-friendly: sin él se publican artefactos no consumibles por Maven. Configuración canónica: `updatePomFile=true`, `flattenMode=resolveCiFriendliesOnly`, goal `flatten` en `process-resources` y `clean` en `clean`.
- El BOM de `common` es un módulo más con `packaging=pom` y solo `dependencyManagement`, importando `spring-boot-dependencies`, `software.amazon.awssdk:bom` y `io.awspring.cloud:spring-cloud-aws-dependencies` (verificado en Maven Central: 3.3.1 = 2025-05-22, 3.4.2 = 2025-11-30; la propiedad del ms es `spring.cloud.aws.version`).
- Precedencia: en un `dependencyManagement`, el `import` de un BOM tiene **menor** precedencia que una entrada `dependencyManagement` explícita del propio POM (nearest-wins). Por eso el ms debe **borrar** sus `<version>` explícitas, no solo añadir el import.

#### 3. CodeArtifact (Maven)

Fuente: [Use CodeArtifact with mvn](https://docs.aws.amazon.com/codeartifact/latest/ug/maven-mvn.html), [Create a domain](https://docs.aws.amazon.com/codeartifact/latest/ug/domain-create.html).

- Endpoint por región/dominio/cuenta: `aws codeartifact get-repository-endpoint --domain D --repository R --format maven` → `https://D-<cuenta>.d.codeartifact.<region>.amazonaws.com/maven/R/`. Dualstack: `codeartifact.<region>.on.aws`.
- Consumo: `<server>` en `settings.xml` con `id=codeartifact`, `username=aws`, `password=${env.CODEARTIFACT_AUTH_TOKEN}` + `<repository>` (o `<mirror>` si se quiere forzar todo por CodeArtifact; si se usa `<mirrors>` hay que añadir `<pluginRepository>`).
- **El `id` debe coincidir entre `<server>` y `<repository>`** (requisito explícito de la doc).
- Publicación: `<distributionManagement><repository>` con el mismo `id` + `mvn deploy`.
- El token se genera con `aws codeartifact get-authorization-token` y va **siempre** en variable de entorno (`CODEARTIFACT_AUTH_TOKEN`), nunca en el repo.
- El dominio se crea con KMS (gestionada o del cliente); para CMK hace falta key policy con `kms:ViaService=codeartifact.<region>.amazonaws.com` + `kms:CallerAccount`.
- Permisos IAM mínimos del pipeline: `codeartifact:GetAuthorizationToken` (resource `*`), `codeartifact:ReadFromRepository`, y para publicar `codeartifact:PublishPackageVersion` (`codeartifact:GetPackageVersion` / `GetAuthorizationToken`). **No verificado en esta investigación la página exacta de la matriz de permisos** — a confirmar en la doc de IAM antes de escribir el rol.

#### 4. CodePipeline / CodeBuild buildspec compartido — **hallazgo crítico**

Fuentes: [Build specification reference for CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html#build-spec-ref-name-storage), [ProjectSource (API)](https://docs.aws.amazon.com/codebuild/latest/APIReference/API_ProjectSource.html), [AWS::CodeBuild::Project Source (CFN)](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-codebuild-project-source.html), [CodeBuild build and test action reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html), [Environment variables in build environments](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html).

**Lo que el objetivo plantea (`BuildspecSource` con `Location` + `repo/path@sha1:<sha>`) NO EXISTE en la documentación oficial.** Se buscó en: API `ProjectSource` (propiedades: `type`, `location`, `buildspec`, `sourceIdentifier`, `gitCloneDepth`, `gitSubmodulesConfig`, `auth`, `buildStatusConfig`, `insecureSsl`, `reportBuildStatus`), CFN `Source`, CLI `create-project`, y la acción `Build` de CodePipeline. No hay ningún campo `buildspecSource` ni sintaxis `@sha1:`.

Opciones **verificadas** para un buildspec compartido:

1. **S3 (única con pin real)**: `buildspec` acepta `arn:aws:s3:::bucket/buildspec.yml`, y el bucket debe estar en la misma región que el proyecto. Con **versioning habilitado** el objeto se puede versionar → el pin se logra por `versionId`… **pero `buildspec` es un string y la doc no documenta un sufijo `?versionId=`** → sin verificar.
2. **Ruta relativa a `CODEBUILD_SRC_DIR`** del primary source (`create-project --buildspec`, CFN `BuildSpec`, o `start-build --buildspecOverride`). Solo dentro del repo del ms.
3. **`BuildspecOverride`** en la acción `Build` de CodePipeline: acepta buildspec inline, ruta relativa a `CODEBUILD_SRC_DIR`, o ARN de S3 en la misma región. La doc advierte explícitamente de riesgo de supply-chain: *"we encourage that you use a trustworthy buildspec location"*.
4. **Fuentes secundarias** (`SecondarySources`, hasta 12; `sourceIdentifier` alfanumérico + `_`, <128 chars): cada fuente secundaria se clona a `$CODEBUILD_SRC_DIR_<sourceIdentifier>`. Sirve para tener el repo de buildspecs **disponible**, pero **el buildspec en sí se resuelve en `CODEBUILD_SRC_DIR`**, no en el directorio de la fuente secundaria. Además el buildspec **no tiene mecanismo de include**: no puede "importar" otro YAML.
5. Acciones `Source` múltiples en el stage `Source` de CodePipeline (el `Build` acepta 1–5 input artifacts, con `PrimarySource`). Cada artifact se extrae en su propio `$CODEBUILD_SRC_DIR_<name>`. Mismo límite del punto 4.

Limitaciones relevantes:

- El buildspec **sí** soporta variables: `env.variables`, `env.parameter-store`, `env.secrets-manager`, `env.exported-variables`. Por tanto la afirmación "no variables custom" del enunciado es **incorrecta**; lo que no hay es **interpolación de plantillas** (no es Jinja/njk).
- Con `type: CODEPIPELINE`, `location` **no se debe especificar** (CodePipeline lo ignora).
- `env.exported-variables` no puede exportar secretos de Parameter Store/Secrets Manager ni variables `AWS_*`.
- El buildspec solo puede ser YAML inline o un archivo; **un buildspec compartido no puede componerse**.

#### 5. Azure DevOps — plantillas entre repos

Fuente: [How to use YAML templates for reusable and secure pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates?view=azure-devops).

Sintaxis verificada:

```yaml
resources:
  repositories:
    - repository: platform      # alias
      type: git                 # Azure Repos
      name: Project/Repo
      ref: refs/tags/v1.0       # opcional
      # endpoint: myServiceConnection  # solo si el repo está en otra organización
stages:
  - template: stages/build.yml@platform
```

- Tipos: `type: git` → Azure Repos, `name` = `<project>/<repo>`; `type: github` → `name` = `<identity>/<repo>`.
- `@alias` referencia; también existe `@self`.
- **Pin**: `ref` acepta `refs/heads/<name>` o `refs/tags/<name>`, **o un SHA de 40 caracteres** (`ref: 1234567890abcdef…`). La doc recomienda: para fijar un commit concreto, crear antes un tag que lo apunte y pinear al tag.
- **Si no se especifica `ref`, el pipeline usa `refs/heads/main` por defecto.**
- Límites: máximo **100 ficheros YAML** incluidos (directa o indirectamente), **100 niveles** de anidamiento, **20 MB** de memoria de parseo.
- **Los repos se resuelven una sola vez al arrancar el pipeline.** Después de la expansión, "el pipeline final se ejecuta como si estuviera definido enteramente en el repo de origen" → **no se pueden usar scripts del repo de plantillas**. Solo los ficheros de plantilla se usan.
- `extends` (plantilla que define esquema) vs `template` (inclusión de contenido). Para stages/jobs/steps de un repo compartido: `template: …@platform`.
- Plantillas deben existir en el filesystem al inicio del run; no se pueden referenciar desde artifacts.

#### 6. Renovate

Fuentes: [Renovate — Maven manager](https://docs.renovatebot.com/modules/manager/maven/), [Renovate — Maven datasource](https://docs.renovatebot.com/modules/datasource/maven/).

- El manager `maven` detecta por defecto `/(^|/|\.)pom\.xml$/` y **`/^(((\.mvn)|(\.m2))/)?settings\.xml$/`**. No necesita `managerFileMatch` ni `matchManagers`: ya viene por defecto.
- `depType` incluye **`import`** (BOM importado) y **`parent`**. `parent-root` se promueve durante la resolución multi-módulo.
- **Limitación crítica para el criterio de aceptación**: el manager extrae y actualiza la **versión del propio BOM** (`<version>` de `common-bom` con `scope=import`). **No resuelve ni actualiza las versiones transitivas que el BOM gobierna dentro del ms** (no lee el POM del BOM para actualizar `spring-boot`, aws-sdk, etc. en el ms). Por tanto:
  - Lo que Renovate **sí** hace: abrir PR en el ms para subir la versión de `common-bom` cuando hay una nueva publicada. Eso cumple el criterio "abrir PR de actualización cuando se publica una versión nueva del BOM".
  - Lo que **no** hace: abrir un PR en el ms por una vulnerabilidad de una dependencia gobernada por el BOM. Para eso hay que actualizar en `common-bom` (Renovate corriendo **sobre `common`**).
- Datasource `maven`: soporta registry personalizada (`registryUrls`) y `scm` en el POM para changelogs. **No existe `registryCodeArtifact`**: no hay soporte nativo de CodeArtifact. Habría que usar `hostRules` con `username: aws` / `password: <CODEARTIFACT_AUTH_TOKEN>` y `registryUrls` con el endpoint de CodeArtifact. **No verificado** que Renovate negocie correctamente el token de CodeArtifact (que expira a 12 h) — es el punto frágil.

Alternativas más lazies si el soporte es frágil: (a) correr Renovate **solo sobre `common`** (datasource `maven` público: no necesita CodeArtifact para leer Maven Central, solo para publicar), y (b) openshift… no: (b) un job de Dependabot no aplica a CodeCommit. (c) Notificación por CodeBuild → aviso, sin PR.

#### 7. ECR imagen base

Fuente: [Create a Lambda function using a container image](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html), [CodeBuild build environment reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html).

- `FROM <cuenta>.dkr.ecr.<region>.amazonaws.com/epc/common-base:<version>` funciona: CodeBuild puede usar imágenes de ECR propias como build image (`image: <registry>/<repository>:<tag>` o `@sha256:<digest>`). Para `FROM` dentro de un Dockerfile el daemon de Docker del build necesita `ecr:GetAuthorizationToken` + `ecr:BatchGetImage` + `ecr:GetDownloadUrlForLayer` y haber hecho `aws ecr get-login-password | docker login`.
- Restricciones Lambda: solo imágenes Linux, **una sola arquitectura**, filesystem **read-only** con `/tmp` escribible, tamaño descomprimido ≤10 GB, manifest <25 400 bytes. El usuario Lambda por defecto debe poder leer los ficheros.
- La imagen base debe contener el runtime + `lib/` con las dependencias. `quizapi` compila **dentro** del build de Docker (`mvn compile dependency:copy-dependencies`). Si `common-base` lleva un JRE y solo los jars, el `Dockerfile` del ms no puede ser de 5 líneas **y** compilar Maven dentro. Trade-off a decidir:
  - Opción A: `common-base` = imagen de build (Maven + JDK). `Dockerfile` del ms = `FROM …:vX` + `COPY` + `RUN mvn …` + `COPY` → ~6-7 líneas.
  - Opción B: el buildspec compartido compila (`mvn package`) y `docker build`; `Dockerfile` del ms = `FROM …:vX` + 3 `COPY` (artefactos ya en el contexto) → 4-5 líneas. Requiere `.gitignore`/`context` bien resueltos y que el buildspec colocado el `target/` antes del `docker build`.

#### 8. Pub / paquetes Dart

Fuente: [Publishing packages](https://dart.dev/tools/pub/publishing), [Custom package repositories](https://dart.dev/tools/pub/custom-package-repositories), [Pubspec file](https://dart.dev/tools/pub/pubspec).

- Un paquete = un directorio con `pubspec.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE` (recomendado BSD-3), `lib/` (+ `test/`). `dart pub publish --dry-run` valida convenciones.
- **Restricción dura de pub**: *"Have your package depend only on hosted dependencies from the default pub package server and SDK dependencies"*. Un paquete publicado en pub.dev **no puede depender de un paquete alojado en un repo git/privado**.
- `publish_to: none` en `pubspec.yaml` impide publicar en cualquier sitio.
- Versionado: semver; `1.2.3` para estable, prerelease con sufijo (`2.0.0-dev.1`). `dart pub publish` es **permanente**: no se puede despublicar (solo retractar 7 días o marcar discontinued). **Publicar en pub.dev un paquete interno es irreversible.**
- Pub no tiene BOM ni "importar" una tabla de versiones compartida. El equivalente a `common-bom` en Dart es… **no existe**; la actualización de versiones va en el `pubspec.yaml` de cada app (Renovate tiene manager `pub`).
- Alternativa de distribución privada: hosted git repo / repositorio personalizado (`dependency_overrides` con `git:` o `path:`), que es exactamente el mecanismo de desarrollo local que el objetivo menciona.
- `dependency_overrides` solo debe usarse para desarrollo: no se propaga a los consumidores.

## Restricciones

- No commits ni push; solo research.
- No escribir código de producción.
- No inventar: citar URL y marcar lo no verificado.
- No tocar `.env` ni credenciales.

## Alternativas

### A. Distribución del buildspec compartido

| Alternativa | Ventajas | Desventajas |
|---|---|---|
| S3 versionado + `buildspec: arn:aws:s3:::…` | Es la única vía oficial con versionado/pin potencial; region-local; sobrevive a la.Source action | Publicar a S3 es un paso extra y **el pin por `versionId` no está documentado** (no verificado); sin inmutabilidad real si se sobrescribe la clave |
| Segundo repo como `Source` action en el stage Source | Clonación nativa por CodePipeline, sin pasos extra | **El buildspec se resuelve en `CODEBUILD_SRC_DIR` del primary source**; el buildspec no tiene `include` → no sirve tal cual |
| Fuentes secundarias (`SecondarySources`) | Clona el repo de buildspecs a `$CODEBUILD_SRC_DIR_<id>` | Mismo límite del punto anterior |
| `BuildspecOverride` inline en la acción Build | Simple | Convierte el pipeline en el lugar del buildspec; contradice "cambiar el buildspec no obliga a editar el pipeline" |
| Copiar el buildspec al repo del ms | Funciona hoy | Contradice explícitamente el objetivo |

### B. Versionado del BOM y Renovate

| Alternativa | Ventajas | Desventajas |
|---|---|---|
| Renovate sobre `common` (datasource `maven` público) | Simple, sin CodeArtifact; abre PRs donde están las versiones reales | No abre PR en el ms (el ms no contiene la versión) |
| Renovate sobre `common` + `common-bom` en cada ms | Renovate sube el `common-bom` en el ms automáticamente | Requiere `registryUrls` + `hostRules` apuntando a CodeArtifact con token de 12 h (**no verificado**) |
| Dependabot | — | No soporta CodeCommit (no verificado en esta investigación; GitHub/Azure DevOps/GitLab sí) |

### C. Imagen base ECR

| Alternativa | Ventajas | Desventajas |
|---|---|---|
| `common-base` como imagen de build (Maven+JDK) | Compila dentro del `Dockerfile`; simple | `Dockerfile` del ms queda en 6-7 líneas, no ≤5 |
| `common-base` como imagen de runtime + compilación en el buildspec | `Dockerfile` del ms de 4-5 líneas | Acopla el ms a que el buildspec compile; el contexto de build necesita artefactos ya generados |

## Riesgos

- **Riesgo alto**: el criterio de aceptación "buildspec compartido con `Location` + `repo/path@sha1:<sha>` pin" **no tiene soporte en la API documentada de CodeBuild**. Tal como está escrito, no es implementable. Hay que redefinir el criterio (S3 versionado, o tag en el repo de buildspecs + `Source` action con `BranchName` = tag) o aceptarlo como no cumplible.
- **Riesgo alto**: la precedencia de `common-bom` (import) frente a `spring-boot-starter-parent` no está documentada por Spring; el resultado real hay que medirlo con un proyecto de prueba antes de comprometerse en el criterio de aceptación.
- **Riesgo medio**: `quizapi` es **WebFlux**, no MVC. Un `GlobalExceptionHandler` en `common-web` que asuma `spring-web` (servlet) rompería el piloto o forzaría una dependencia incorrecta.
- **Riesgo medio**: el `pom.xml` de `quizapi` fija `spring.cloud.aws.version` como propiedad con el mismo nombre que usa el BOM de Spring Cloud AWS; si `common-bom` importa ese BOM, la propiedad local gana y se pierde el gobierno centralizado para esas dependencias.
- **Riesgo medio**: `ApiResponse` expone `stackTrace` al cliente (`ErrorApiResponse`) y usa `LocalDateTime.now()` (hora local, no UTC). Extraerlo a `common` fija ese contrato para todos los ms; cambiarlo después es compatible pero rompe clientes.
- **Riesgo medio**: `Environment` está en `ApiResponse` pero nunca se setea → siempre `null` en el JSON. Decide si entra en el contrato o se elimina.
- **Riesgo bajo**: publicar paquetes Dart internos en pub.dev es **irreversible** y no admite dependencias privadas. Usar `publish_to: none` + `dependency_overrides` con git hasta que exista un hosted repo.
- **Riesgo bajo**: CodeArtifact cobra por GB almacenado; un `mirrors` de Maven Central hace que cada ms descargue de CodeArtifact (más rápido, pero consume cuota de la cuenta).
- **Riesgo bajo (fuera de objetivo, señalado)**: `azure-build.yml:16` y `sonar-scanner.properties:12-13` tienen credenciales en claro.

## Coste estimado

- Dominio + repositorio CodeArtifact (formato Maven): **~0.05 USD/mes** por dominio + almacenamiento. La parte relevante es el ancho de banda: **0.09 USD por GB descargado**. Un `common` pequeño (varios MB) descargado por ~100 ms una vez por build ≈ **céntimos al mes**.
- Pipeline de publicación: CodeBuild `BUILD_GENERAL1_SMALL` (~0.17 USD/min), unos pocos minutos por release → **~1 USD/mes**.
- Bucket S3 para el buildspec compartido (si se usa la opción A): **~0 USD** (KB).
- Imagen base ECR: almacenamiento de capas, **~0.01 USD/mes**; sin cómputo (se publica una vez por versión).
- Renovate self-hosted: coste del runner, **~0 USD** si corre en el pipeline existente.
- **Total estimado: < 2 USD/mes.** Sin coste nuevo relevante. CodeArtifact es el único con coste variable (crece con el nº de ms × tamaño de `common`).

## Puntos no verificados (marcar antes de diseñar)

1. Sintaxis `BuildspecSource` / `repo/path@sha1:<sha>` — **no existe** en API, CFN ni CLI documentados.
2. Pin por `versionId` en `buildspec` con ARN de S3 — no documentado.
3. Matriz exacta de permisos IAM para publicar en CodeArtifact (página de IAM policy references no consultada).
4. Precedencia `spring-boot-starter-parent` vs. `common-bom` importado.
5. Compatibilidad exacta `spring-cloud-aws-dependencies:3.3.1` + `spring-boot-dependencies:3.4.0`.
6. Si Renovate negocia correctamente un token de CodeArtifact vía `hostRules` (expiración de 12 h).
7. Si `common` publica en un hosted repo privado de pub, o sólo vía `dependency_overrides`/git.

## Inventario de extracción (resumen accionable)

**Se extrae a `common`:**

- `common-error`: `infrastructure/rest/response/ApiResponse.java`, `infrastructure/rest/response/ErrorApiResponse.java`, `infrastructure/configuration/GeneralException.java`.
- `common-web`: `infrastructure/configuration/GlobalExceptionHandler.java` (como auto-configuración con `@ConditionalOnMissingBean`, no como `@Component`).
- `common-helpers`: **nada** — no hay helpers de fecha ni de string en `quizapi`. Módulo a crear sin origen de extracción.
- `common-log`: **nada** — no hay MDC ni request-id. Módulo a crear desde cero; el `logback.xml` actual no aporta nada reutilizable.

**Se queda atrás en `quizapi`:**

- `infrastructure/configuration/`: `AiProperties`, `AiConstants`, `AiMessages`, `GraalHints`, `MapperInfo`, `MapperClass`, `ParameterProperties`.
- `infrastructure/configuration/cloud/aws/`: `DynamoDBConfig`, `SnsConfig`, `SnsEventPublisher`.
- `infrastructure/configuration/webfilters/RevenueCatWebhookFilter.java` (HMAC de RevenueCat; específico del dominio).
- Todo `infrastructure/controllers/`, `adapters/`, `persistence/`, `domain/`, `application/`.
- `LambdaHandler.java`, `Application.java` (el `CMD` del Dockerfile apunta a `LambdaHandler`).
- `Dockerfile`, `.gitignore`, `postman/`, `sonar-*.properties`, `bootstrap` (nativo), `up.ps1`/`down.ps1`/`update-ms.ps1`.

**Cambios mínimos en el ms tras la migración:**

- Borrar los 4 archivos de la tabla y actualizar 5 imports en `HolaMundoController`, `ParameterController`, `SubscriptionController`, `AiController` (+ 2 tests que importan `ApiResponse`).
- `pom.xml`: borrar 56 `<version>` explícitas, añadir `<dependencyManagement>` importando `common-bom`, añadir las deps `common-*`.
