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
  - Los archivos de configuración compartidos (`.gitignore`, `.dockerignore`, `codepipeline`/`buildspec`, `azure-pipelines`) no se comparten por dependencia de Maven; se resuelven con repos de plataformas y plantillas.
  - Azure DevOps: repo de plantillas referenciado con `@platform` desde cada pipeline (herencia real entre repos).
  - AWS CodePipeline: `buildspec.yml` centralizado en un repo CodeCommit y referenciado por `Location` + pin de commit (`repo/path@<sha>`), no copias por microservicio.
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

- Repositorio `common` (CodeCommit) con estructura multi-módulo:
  - `pom.xml` parent (propiedades y `pluginManagement`, sin código de negocio).
  - `common-bom/`: solo `dependencyManagement`. Importa `spring-boot-dependencies`, `aws-sdk-bom`, `spring-cloud-aws` y las versiones de los módulos propios.
  - `common-helpers/`: Java puro, sin Spring (fechas UTC, strings, colecciones).
  - `common-log/`: MDC, `request-id`, correlación de logs. Sin dependencia de web.
  - `common-error/`: `ApiResponse`, `PageResponse`, `ErrorCode`, excepciones base. Depende de `common-helpers`.
  - `common-web/`: `GlobalExceptionHandler` (`@ConditionalOnMissingBean`), filtro de correlación, configuración MVC. Única capa que toca web; depende de `common-log` y `common-error`.
  - Auto-configuración mediante `AutoConfiguration.imports`.
  - `docker/Dockerfile` de imagen base + script de publicación a ECR (`epc/common-base:<version>`).
  - `templates/` con `.gitignore`, `.dockerignore` y script de instalación para ms nuevos.
  - `docs/` con guía de uso, versionado y migración de un microservicio.
- Registro CodeArtifact en la cuenta AWS: repositorio Maven, rol IAM de publicación, pipeline que publica en cada tag con versionado semver.
- Repositorio de buildspecs en CodeCommit (`buildspecs/java-ci.yml`, `buildspecs/docker-build.yml`) para CodePipeline.
- Repo de plantillas Azure DevOps (`stages/build.yml`, `test.yml`, `deploy.yml`) referenciado con `resources.repositories` desde cada pipeline.
- Migración de `quizapi` como primer consumidor: extraer a `common` el manejo de errores, el contrato de respuesta, el logging con correlación y los helpers de fechas; borrar el código duplicado; dejar el `pom.xml` del ms importando `common-bom` y solo las dependencias que usa.
- Renovate configurado en `common` leyendo el BOM, para abrir PRs de actualización en cada microservicio.
- Paquetes Dart `common_log` y `common_error` en su repositorio, como equivalente del lado Flutter.

## Criterios de aceptación

- [ ] `mvn install` en la raíz de `common` compila todos los módulos.
- [ ] `common` publica sus artefactos en CodeArtifact y un proyecto externo los resuelve importando `common-bom`.
- [ ] Un microservicio de prueba que importa solo `common-log` no carga ni arranca ninguna clase de `common-web`.
- [ ] `common-web` registra `GlobalExceptionHandler` solo si el microservicio no define el suyo.
- [ ] Cambiar una versión de una dependencia en `common-bom/pom.xml` y publicar una versión nueva no requiere modificar ningún `pom.xml` de microservicio para propagar la definición.
- [ ] Renovate abre PR de actualización en un microservicio que declara esa dependencia cuando se publica una versión nueva del BOM.
- [ ] La imagen `epc/common-base:<version>` está publicada en ECR y un microservicio construye su imagen con un `Dockerfile` de máximo cinco líneas.
- [ ] Un pipeline de un microservicio resuelve un `buildspec` desde el repositorio compartido con pin de commit, y cambiar el buildspec compartido no obliga a editar el pipeline del microservicio para adoptar el comportamiento.
- [ ] Un pipeline de un microservicio extiende una plantilla del repositorio de plataformas de Azure DevOps.
- [ ] `quizapi` compila y sus pruebas existentes pasan después de la migración, sin `GlobalExceptionHandler`, `ApiResponse`, `PageResponse` ni helpers de fecha propios.
- [ ] El `pom.xml` de `quizapi` no declara versiones de dependencias de terceros presentes en `common-bom`.
- [ ] Los paquetes Dart `common_log` y `common_error` son instalables de forma independiente.

## Fuera del alcance

- Migrar más de un microservicio a `common`: solo `quizapi` como piloto. El resto se migra en objetivos posteriores.
- Cualquier paquete Dart más allá de `common_log` y `common_error` (cliente HTTP, caché, colas, seguridad, feature flags, métricas, schedulers). Quedan para objetivos futuros.
- Goviarar dependencias que no están en el BOM: solo se centraliza lo que se decide centralizar.
- Un pipeline único parametrizado para todos los microservicios.
- Sincronización automática de `.gitignore` y `.dockerignore` en microservicios existentes: es una copia de un solo uso por repositorio, no un problema recurrente.
- Habilitar la autenticación de CodeArtifact en los pipelines existentes de microservicios que todavía no usan `common`.
- Gates de calidad nuevos, observabilidad distribuida (OpenTelemetry), caché, colas, rate limiting y seguridad como parte de `common`.
- Proveedor de registro distinto a CodeArtifact y plataforma de CI distinta a Azure DevOps y AWS CodePipeline.