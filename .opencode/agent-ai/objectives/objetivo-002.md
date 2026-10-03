# Objetivo 002

## Objetivo

Crear el proyecto `common`, un componente reutilizable e independiente que se importe en cada microservicio, para eliminar el código repetido (manejo de errores, logging, helpers, fechas, contratos de API) y centralizar el gobierno de versiones de dependencias en un único punto. La migración de los microservicios existentes se hace de forma incremental, un microservicio a la vez.

## Contexto

- Los microservicios actuales usan Spring Boot 3.4, Java 17, Maven, arquitectura hexagonal y AWS (Lambda, Spring Cloud AWS). Microservicio de referencia: `projects/com.quizsmart.app/backend/quizapi`.
- Cada microservicio vive en su propio repositorio dentro de la misma cuenta AWS (CodeCommit). No hay monorepo compartido.
- Se parte de un ecosistema que pasó de 1 a 500 microservicios; hoy hay ~1-100. El problema de código repetido y de versiones dispersas escala peor que el número de microservicios.
- Necesidad concreta: ante una vulnerabilidad en una dependencia, cambiar la versión debe requerir modificar un solo archivo.
- Insumos ya conversados y decididos:
  - Proyecto Maven multi-módulo, granular por capacidad: un ms que solo necesita logging no debe arrastrar manejo de errores.
  - `BOM` (pom de solo `dependencyManagement`) para versiones de terceros y de los propios módulos de `common`. El ms conserva su parent `spring-boot-starter-parent`.
  - Los archivos de configuración compartidos (`.gitignore`, `.dockerignore`, `codepipeline`/`buildspec`) no se comparten por dependencia de Maven; se resuelven con el repo de plataforma y los buildspecs en S3.
  - CI: **solo AWS CodePipeline + CodeBuild**, con buildspecs compartidos en el bucket `s3://epc-buildspecs/`. Los repos de los microservicios viven en **CodeCommit**; **Azure DevOps queda descartado por completo** (decisión del usuario, `DECISIONS` 2026-10-03).
  - AWS CodePipeline: el buildspec **no se puede referenciar desde otro repo con pin de commit** (CodeBuild solo acepta YAML inline, ruta en el primary source o ARN de S3; ver ADR-0016). Solución: buildspec centralizado en el bucket `s3://epc-buildspecs/` (versionado), referenciado por ARN de S3 desde cada microservicio. El repo de buildspecs en CodeCommit es la fuente de verdad de la que se publica al bucket.
  - `Dockerfile`: no se comparte como archivo, se comparte como imagen base en ECR (`epc/common-base:<version>`).
  - Dart: paquetes pub independientes (`common_log`, `common_error`) en su propio repositorio, mismo objetivo.

## Restricciones

- No crear ni modificar tests: los escribe y gestiona el usuario.
- No hacer commit ni push sin autorización explícita.
- No editar `.env` ni credenciales; los secretos de CodeArtifact y ECR viven en el CI como credenciales, nunca en el repositorio.
- Sin secretos, tokens ni credenciales en código.
- Idioma de identificadores: inglés.
- No crear un pipeline único parametrizado para todos los microservicios: los ms divergen (Fargate, Lambda, App Service) y un pipeline central choca con esa diverencia.
- No apuntar los buildspec compartidos a una rama en movimiento (`main` sin pin): rompe la reproducibilidad de un despliegue.
- No usar `git submodule` para distribuir `common`: cada repositorio autónomo debe poder compilar con `git clone` simple.
- Respetar `WORKFLOW`; registrar dudas según `WORKFLOW` §Dudas; registrar decisiones en `DECISIONS`.

## Alcance

- Repositorio `common` (CodeCommit; en este workspace en `common/`, junto a `generator/`, porque no es una aplicación generada) con estructura multi-módulo y una sola versión (`1.0.0` literal, sin `${revision}` ni SNAPSHOT):
  - `pom.xml` parent (propiedades y `pluginManagement`, sin código de negocio).
  - `common-bom/`: solo `dependencyManagement`. Importa `spring-boot-dependencies`, `aws-sdk-bom`, `spring-cloud-aws` y las versiones de los módulos propios.
  - `common-helpers/`: **pospuesto**; no hay código que extraer del piloto ni consumidores, así que no se crea en este objetivo (YAGNI; decisión en `architecture-002.md` §6).
  - `common-log/`: MDC, `request-id`, correlación de logs. Sin dependencia de web.
  - `common-error/`: `ApiResponse`, `ErrorApiResponse`, excepciones base. (`PageResponse` y `ErrorCode` no existen en el piloto: solo se crean si un ms los necesita.)
  - `common-web/`: `GlobalExceptionHandler` (`@ConditionalOnMissingBean`), filtro de correlación, configuración **WebFlux** (el piloto es Lambda + WebFlux; decisión en ADR-0016). Única capa que toca web; depende de `common-log` y `common-error`.
  - Auto-configuración mediante `AutoConfiguration.imports`.
  - `docker/Dockerfile` de imagen base + script de publicación a ECR (`epc/common-base:<version>`).
  - `docs/` con guía de uso, versionado y migración de un microservicio (incluye los snippets de `.gitignore`, `.dockerignore` y `settings.xml`).
- Registro CodeArtifact en la cuenta AWS: repositorio Maven, rol IAM de publicación, pipeline que publica en cada tag con versionado semver.
- Repositorio único de plataforma `platform/` (CodeCommit), sustituyendo a los dos repos separados: `buildspecs/{java-ci,docker-build,renovate,bump-bom}.yml` publicados al bucket S3 `epc-buildspecs` (versionado) y referenciados por ARN de S3 desde cada microservicio, más los scripts que abren los pull requests en CodeCommit.
- Terraform declarativo de `platform` en `projects/com.quizsmart.app/cloud/terraform/platform/` (CodeArtifact, bucket, ECR, roles, pipeline, CodeBuild de Renovate, Scheduler semanal, regla EventBridge). **Lo aplica el usuario**: el agente no ejecuta `terraform apply`.
- Migración de `quizapi` como primer consumidor: extraer a `common` el manejo de errores, el contrato de respuesta y el logging con correlación; borrar el código duplicado; dejar el `pom.xml` del ms importando `common-bom` y solo las dependencias que usa.
- **Generador**: quitar del componente backend las plantillas que emiten el código que ahora vive en `common` (`ApiResponse`, `ErrorApiResponse`, la excepción base y el `GlobalExceptionHandler`) y hacer que `pom.scriban` importe `common-bom` y declare los módulos de `common` que el ms generado necesite. `logback.xml` se queda en el ms.
- Renovate configurado en `common` leyendo el BOM, para abrir PRs de actualización en cada microservicio.

## Criterios de aceptación

- [ ] `mvn install` en la raíz de `common` compila todos los módulos.
- [ ] `common` publica sus artefactos en CodeArtifact y un proyecto externo los resuelve importando `common-bom`.
- [ ] Un microservicio de prueba que importa solo `common-log` no carga ni arranca ninguna clase de `common-web`: el BOM de `common-log` no declara `common-web` ni `spring-webflux`, `common-log` no tiene `AutoConfiguration.imports`, y el arranque (`--debug`) no registra ninguna clase `com.epc.common.web`.
- [ ] `common-web` registra `GlobalExceptionHandler` solo si el microservicio no define el suyo.
- [ ] La definición de la versión de una dependencia vive en un solo fichero (`common-bom/pom.xml`) y el consumo se actualiza subiendo **una línea**: la `<version>` del `import` del BOM en el `pom.xml` del ms, sin tocar ninguna otra declaración de versión de ese `pom.xml`.
- [ ] Renovate mantiene actualizado el BOM en `common` y abre en cada ms el PR que sube la versión de `common-bom` cuando hay una release nueva. (No abre PR en el ms por dependencias transitivas gobernadas por el BOM: eso se actualiza en `common`.)
- [ ] La imagen `epc/common-base:<version>` está publicada en ECR y un microservicio construye su imagen con un `Dockerfile` de máximo cinco líneas.
- [ ] Un pipeline de un microservicio resuelve un `buildspec` desde el bucket compartido `s3://epc-buildspecs/` por ARN de S3, y publicar un buildspec nuevo no obliga a editar el pipeline del microservicio.
- [ ] Al publicar una release de `common` (tag `v*`), un trigger bumpea la `<version>` del `import` de `common-bom` y abre un pull request en cada repositorio de microservicio (CodeCommit), sin intervención manual.
- [ ] `quizapi` compila y sus pruebas existentes pasan después de la migración, sin `GlobalExceptionHandler`, `ApiResponse`, `PageResponse` ni helpers de fecha propios. — **El cierre de este criterio es del usuario**: el agente cambia el código de producción y los 2 imports de test que quedan, que no puede editar.
- [ ] El `pom.xml` de `quizapi` no declara versiones de dependencias de terceros presentes en `common-bom` (excepción declarada: las versiones de plugins y de `annotationProcessorPaths` se quedan en el ms, porque un `import` de BOM no aporta `pluginManagement`).

## Fuera del alcance

- Paquetes Dart `common_log` y `common_error`: por el momento **solo Java** (ADR-0016). Cualquier paquete Dart (los dos anteriores y cliente HTTP, caché, colas, seguridad, feature flags, métricas, schedulers) queda para objetivos futuros.
- `common-web` para servlet/MVC: `common-web` es WebFlux; el soporte servlet llega cuando exista el primer consumidor.
- Migrar más de un microservicio a `common`: solo `quizapi` como piloto. El resto se migra en objetivos posteriores.
- Cualquier paquete Dart más allá de `common_log` y `common_error` (cliente HTTP, caché, colas, seguridad, feature flags, métricas, schedulers). Quedan para objetivos futuros.
- Goviarar dependencias que no están en el BOM: solo se centraliza lo que se decide centralizar.
- Un pipeline único parametrizado para todos los microservicios.
- Plantillas de `.gitignore` y `.dockerignore` de un solo uso: los snippets viven en `common/docs/como-migrar-un-ms.md` (`templates/` y su script de instalación, fuera).
- La fase de bootstrap en AWS (aplicar Terraform, crear los repos remotos, `mvn deploy` a CodeArtifact, publicar imagen en ECR, sembrar el token, `renovate --dry-run`): **la ejecuta el usuario**; el agente entrega los ficheros y el comando exacto en `implementation-002.md`.
- Las versiones de plugins y `annotationProcessorPaths` de cada microservicio: un `import` de BOM no aporta `pluginManagement`.
- Habilitar la autenticación de CodeArtifact en los pipelines existentes de microservicios que todavía no usan `common`.
- Gates de calidad nuevos, observabilidad distribuida (OpenTelemetry), caché, colas, rate limiting y seguridad como parte de `common`.
- Proveedor de registro distinto a CodeArtifact y plataforma de CI distinta a AWS CodePipeline + CodeBuild.
- **Azure DevOps**: eliminado de todo el proyecto (ficheros, plantillas del generador, objetivos, planes y documentación). Si algún día hace falta, es otro objetivo.
- Renovate (actualización de terceros dentro del propio `common`): sigue dentro, pero es **programado** (Scheduler semanal), no por evento: un push en `common` no depende de que exista una versión nueva publicada.