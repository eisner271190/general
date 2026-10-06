# Tareas pendientes

Filas con identificador estable: sincronizadas por `taskkeeper`. Filas sin identificador: manuales; el agente las conserva.

## Objetivo 002

- [x] [002-C2] [usuario] Publicar `common` en CodeArtifact y comprobar que un proyecto externo resuelve el BOM.
- [ ] [002-C7] [usuario] Publicar `epc/common-base` en ECR y probar el Dockerfile del piloto. El repo ECR
  existe pero sin imágenes: la construye el stage Publish del pipeline de `common`, que necesita un commit
  nuevo en `main` para re-dispararse tras el arreglo de IAM (ver Notas de alcance).
- [x] [002-C8] [usuario] Aplicar Terraform y ejecutar el pipeline que usa el buildspec del bucket S3.
  Cerrada: `up.ps1 -Fast` de `projects/com.quizsmart.app` terminó con `exit=0` el 2026-10-05 18:12:06
  (inicio 18:00:56, 11 min 10 s). Plataforma aplicada (26 recursos) y los 3 pasos previos funcionan
  (0 plataforma 37 s, 0b publish-common 23 s, 0c publish-buildspecs 11 s).
- [ ] [002-C9] [usuario] Verificar en AWS el trigger de release y los PRs de actualización de BOM.
  El bloqueo ya NO es el repo vacío (resuelto) ni el tag `v1.0.1` (creado): es que `platform-bump-bom`
  no arranca. Ver Notas de alcance.
- [x] [002-C10] [usuario] Actualizar los imports de tests del piloto y ejecutar la suite para cerrar la migración.
- [x] [002-C11] [usuario] Declarar en Terraform los dos repos de plataforma `common` y `platform` (CodeCommit).
- [x] [002-C12] [usuario] Trabajar sin secretos: token de CodeArtifact pedir por rol IAM y Git con credential-helper.
- [ ] [002-C13] [usuario] Emitir un único PR por release de `common` en `com.quizsmart.app`.
  El bloqueo ya NO es el repo vacío (resuelto) ni el tag `v1.0.1` (creado): es que `platform-bump-bom`
  no arranca. El criterio sigue siendo un único PR por release. Ver Notas de alcance.
- [x] [002-C14] [usuario] Entregar los scripts de despliegue en PowerShell: `platform/scripts/up.ps1`, `publish-common.ps1` (sin apply) y `publish-buildspecs.ps1`.
- [x] [002-C15] [usuario] Generador: plantilla Terraform del repo en el componente cloud y `up.ps1` que crea el repo, añade el remoto y empuja.
- [x] [002-C17] [usuario] Conectar los remotos de `common` y `platform` en git: automatizado en
  `library/platform/scripts/seed-repos.ps1`, que copia `library/common` y `library/platform` a carpetas
  temporales, hace `git init`, un commit y push a los repos CodeCommit `common` y `platform`. No toca el
  índice del monorepo `general`. Idempotente, con `-DryRun` y `-KeepTemp`.
- [x] [002-C16] [usuario] Añadir `environment` y `application_repository` al `terraform.tfvars` local de
  `library/platform/terraform/`: hecho con `environment = "develop"` y
  `application_repository = "com.quizsmart.app"` (fichero local, gitignored). Apply correcto con
  `library/platform/scripts/up.ps1 -AutoApprove`.

## Notas de alcance

- `[002-C6]` retirada: Renovate queda fuera del objetivo (ADR-0025). La actualización del BOM dentro de
  `common` la hace una persona, por aviso de seguridad; su propagación la hace el trigger por tag.
- Renovate, su CodeBuild programado y su Scheduler semanal se han borrado. No tienen tarea asociada.
- `OBJECTIVES/objetivo-002.md` ya no cita Renovate: contexto, alcance, criterios y fuera del alcance
  están alineados con ADR-0022, ADR-0024 y ADR-0025.
- El criterio de aceptación vigente es **un único PR** por release de `common` en
  `com.quizsmart.app`, no uno por repositorio de microservicio. Lo cubren `[002-C13]` y `[002-C9]`.
- El detalle de fase y los pendientes separados entre agente y usuario están en `STATUS/status.md`,
  que se recreó en 2026-10-05 tras perderse del versionado.
- `[002-C12]`, `[002-C14]` y `[002-C15]` cerradas: código entregado y verificado (`fmt`, `validate`,
  `plan` a 25 recursos, AST y parser de PowerShell, YAML de los 3 buildspecs, dry-run de los scripts).
  Cero secretos: ningún `aws_secretsmanager_secret`, token por rol, sin git push en los builds.
- `[002-C13]` se queda abierta como **entrega de código** cerrada a medias: lo único que falta es la
  ejecución real en AWS, que es `[002-C9]`. Lo cubre el trigger por tag con destino único.
- `[002-C16]` nueva: `application_repository` y `environment` ya no tienen valor por defecto en Terraform
  (ADR-0024), así que el `terraform.tfvars` local es obligatorio antes de cualquier `plan`/`apply`.
- Endurecimiento de calidad de los cinco scripts con `clean-code` y `epc-clean-code`; en el camino se
  corrigieron dos bugs reales.
- Correcciones entregadas hoy sin tarea propia (notas, sin identificador nuevo):
  - Bug real de API de CodeBuild: `source { type = "CODEPIPELINE" }` exige
    `artifacts { type = "CODEPIPELINE" }`. Con `artifacts.type = "S3"` los 3 proyectos CodeBuild fallaban
    con `InvalidInputException` y el `apply` se caía. Corregido en
    `library/platform/terraform/pipeline/main.tf` y `library/platform/terraform/bump_bom.tf`.
    `terraform validate` no lo detecta: solo valida esquema, no reglas del API de AWS.
  - El Credential Manager de Windows (`credential.helper = manager`, en el config de sistema de Git) se
    ejecutaba antes que el helper de CodeCommit y abría un diálogo de usuario/contraseña. Resuelto en
    `seed-repos.ps1` con `-c credential.helper=` y `$env:GIT_TERMINAL_PROMPT='0'`.
  - `delete-all-services-aws.ps1`: ahora borra plataforma y app por defecto (20 recursos), consulta y quita
    los targets de EventBridge antes de `delete-rule` (el id lo autogenera Terraform, no se puede
    hardcodear) y borra también `com.quizsmart.app` vía `-ApplicationRepositories`. Sigue pidiendo
    confirmación `SI` o `-Force`.
  - `up.ps1` de la aplicación y su plantilla Scriban
    (`generator/components/root/workspace/templates/up.ps1.scriban`) sincronizados con tres pasos previos
    idempotentes: paso 0 `library/platform/scripts/up.ps1` (crea el dominio de CodeArtifact; sin él,
    `docker build` falla con `ResourceNotFoundException`), paso 0b `publish-common.ps1` (sin los paquetes
    Maven, el `pom.xml` no resuelve el `common-bom` y `docker build` falla), paso 0c
    `publish-buildspecs.ps1` (los buildspecs se referencian por ARN; sin ellos el pipeline no arranca).
    Parámetros nuevos: `-PlatformRoot` (por defecto `../../library/platform`) y `-SkipPlatform`.
- Resuelto antes del tag: `com.quizsmart.app` ya tiene commits y `backend/quizapi/pom.xml`, así que
  `POM_GLOB = "backend/*/pom.xml"` encuentra el pom.
- Histórico 2026-10-05: el apply de `[002-C16]` creó 26 recursos (antes 25 en el plan). La cuenta quedó
  vacía a las 17:49 por un borrado externo, lo que obligo a un segundo despliegue completo a las 18:00.
  La nota queda como registro de por que hubo dos despliegues; el estado vigente esta en la nota
  "Despliegue de la tarde OK".
- **Despliegue de la tarde OK**: `up.ps1 -Fast` de `projects/com.quizsmart.app` terminó con `exit=0` el
  2026-10-05 18:12:06 (inicio 18:00:56, 11 min 10 s). Verificado con `get-services-aws.ps1`: ECR 2
  (`epc/common-base`, `quizapi`), Lambda 1, API Gateway 1, SNS 1, SQS 1, Cognito 1, SSM 37 parámetros,
  Secrets 1, IAM 2 roles + 1 policy, DynamoDB 2. Con esto `[002-C8]` queda cerrada.

### Bug del paso 3b de `up.ps1`: CORREGIDO (2026-10-05 noche)

- El bug que bloqueaba `[002-C9]` y `[002-C13]` (`codecommit_clone_url vacio (se omite el remoto)`, aviso sin
  `throw`, repo `com.quizsmart.app` vacío) está **corregido**. `up.ps1 -Fast` volvió a terminar con `exit=0`.
- El repo CodeCommit `com.quizsmart.app` quedó sembrado con el layout correcto: subcarpetas `backend`, `cloud`,
  `frontend` y ficheros `down.ps1`, `up.ps1`, `generation-plan.json`. Commit
  `de3ba449e64361490de6e17c569b5408047026b2`. El `POM_GLOB` `backend/*/pom.xml` ya encuentra
  `backend/quizapi/pom.xml`.
- Tres bugs corregidos en `projects/com.quizsmart.app/up.ps1` y en su plantilla
  `generator/components/root/workspace/templates/up.ps1.scriban`:
  - `terraform -chdir=$terraformApp` sin comillas: PowerShell no expandía la variable y Terraform recibía el
    literal `$terraformApp`, `exit 1`, output vacío y remoto omitido en silencio. Ahora `"-chdir=$terraformApp"`.
  - `Copy-Item -Path $PSScriptRoot` copiaba la CARPETA dentro de `$seed` (repo con un nivel de más). Ahora
    `Copy-Item -Path (Join-Path $PSScriptRoot '*')` copia el contenido.
  - Faltaba `New-Item $seed` antes del `Copy-Item`: "No se puede copiar el contenedor en el elemento hoja
    existente".
  - Además: el output vacío ahora hace `throw` en vez de solo avisar, y el push usa `--force` (la copia es una
    foto, no un historial). El paso 3b siembra desde copia temporal a `main`, sin tocar el índice del monorepo,
    e invoca git con `-c credential.helper=` para que el Credential Manager de Windows no pida usuario/contraseña.

### Versionado de `common` a 1.0.1 y tag `v1.0.1`

- Se subió `library/common/pom.xml` y los 4 módulos (`common-bom`, `common-error`, `common-log`, `common-web`)
  de `1.0.0` a `1.0.1`, porque `1.0.0` ya estaba publicado en CodeArtifact y `mvn deploy` de una release
  existente falla.
- `seed-repos.ps1` ahora hace `push --force` siempre: antes solo sembraba si el remoto estaba vacío y se saltaba
  los cambios posteriores. Repo `common` actualizado, commit `07b6245b23479504cdbbd4d6df7ef09f5d643299`.
- El import de `common-bom` en `projects/com.quizsmart.app/backend/quizapi/pom.xml` se dejó en `1.0.0` a
  propósito: cambiarlo es lo que debe hacer el PR del BOM.
- Tag `v1.0.1` creado en el repo `common` con
  `aws codecommit create-branch --branch-name refs/tags/v1.0.1 --commit-id <sha>`, verificado en
  `list-branches`: `refs/tags/v1.0.1` y `main`.
- Ojo: `list-tags-for-resource` NO lista tags de referencia, solo etiquetas de Terraform. Para verificar refs
  usar `list-branches`, que devuelve un array de strings.

### BUG DE IAM REAL: `epc-codebuild` sin permisos de CloudWatch Logs

- El rol `epc-codebuild` no podía crear log streams de CloudWatch. Los builds de CodeBuild abortaban en fase
  QUEUED con ACCESS_DENIED: "does not allow AWS CodeBuild to create Amazon CloudWatch Logs log streams" y "no
  identity-based policy allows the logs:CreateLogStream action".
- Corregido añadiendo en `library/platform/terraform/iam.tf` una statement `BuildLogs` con `logs:CreateLogGroup`,
  `logs:CreateLogStream`, `logs:PutLogEvents` sobre `arn:aws:logs:*:*:log-group:/aws/codebuild/*`.
- Sin esto NINGÚN build puede arrancar, ni de `common` ni del bump. Ni `terraform validate` ni `plan` lo
  detectan: solo al ejecutar.

### BLOQUEO ABIERTO (nota, sin identificador): `platform-bump-bom` no arranca

Única vía pendiente para `[002-C7]`, `[002-C9]` y `[002-C13]`. Cadena de hallazgos:

- Con `source CODEPIPELINE` + `artifacts S3` el API lo rechaza (`InvalidInputException`): source CODEPIPELINE
  exige artifacts CODEPIPELINE. Corregido así para los 3 proyectos.
- Con `artifacts CODEPIPELINE`, EventBridge no puede arrancarlo: "Builds with CodePipeline artifacts should be
  triggered through CodePipeline" (start-build manual falla).
- `NO_ARTIFACTS` da "artifact type NO_ARTIFACTS should have null output name", y con `packaging = null` vuelve
  a pedir null output name. Es bug conocido del provider aws (cloudposse/terraform-aws-codebuild#63,
  StackOverflow 63477000): el remedio es DESTRUIR y RECREAR el proyecto.
- AWS bloquea la modificación: "This build project uses AWS CodeBuild... you must use the AWS console". Cada
  cambio exige `delete-project` + `state rm` + apply.
- Se recreó con `source CODECOMMIT location = var.platform_source_bucket`. El build ARRANCA (IAM OK) pero falla
  en DOWNLOAD_SOURCE con "repository not found for primary source and source version refs/heads/main". El repo
  `platform` SÍ existe. Probado con y sin `--source-version`.
- Candidatos a seguir, **NINGUNO APLICADO**: (A) `NO_SOURCE` con buildspec INLINE en el `.tf`, porque con
  NO_SOURCE el API no admite buildspec externo por ARN (documentación AWS: hay que pasar el buildspec como
  string YAML); (B) diagnosticar con CloudTrail del servicio codebuild; (C) dejarlo documentado.

### Impacto del bloqueo de bump-bom

- NO bloquea el despliegue de la app, que está desplegada y verificada (13 servicios).
- Bloquea solo el trigger automático del BOM, que solo hace falta al liberar una versión nueva de `common`.
- `common 1.0.1` ya está en el repo y Maven resuelve con el import en `1.0.0`, así que el sistema funciona.

### Pendientes de estado al cierre de la noche

- `[002-C7]` sigue abierta: el repo ECR `epc/common-base` existe pero SIN imágenes. La construye el stage
  Publish del pipeline de `common`, que necesita un commit nuevo en `main` para re-dispararse tras el
  arreglo de IAM.
- `[002-C9]` y `[002-C13]` siguen abiertas: su bloqueo ya no es el repo vacío (resuelto) ni el tag `v1.0.1`
  (creado), sino que `platform-bump-bom` no arranca.

### Rendimiento y desglose del `up.ps1 -Fast`

- **Rendimiento del `docker build`** (3 min 07 s de los 4 min 44 s del paso 2). Datos de
  `backend/quizapi/logs/2026-10-05-18-02-20.log`:
  - Maven `Total time: 02:54 min`, 996 artefactos descargados, ninguno reutilizado.
  - 688 servidos por CodeArtifact (round-trips de ~50 ms, a menudo 11-50 kB/s), 308 por Maven Central.
  - 678 son `.pom` y 318 `.jar`: Maven descarga el pom de cada artefacto para resolver el árbol y luego el jar.
  - ~174 artefactos son de plugins Maven (plexus/maven.shared/maven) que el build NO ejecuta
    (native-maven-plugin, jacoco, pitest, sonar, spring-boot-maven-plugin) y ~75 son dependencias solo-test
    (junit 32, archunit 10, mockito 7, assertj 4, karate, reactor-test, r2dbc-h2).
  - `dependency:copy-dependencies -DincludeScope=runtime -DskipTests` filtra DESPUÉS de resolver, así que se
    descargan y luego no se usan: ~25% de los downloads no llega a la imagen.
  - Causa raíz principal: `~/.m2` no se cachea entre builds porque el `RUN` de Maven es una capa y su
    repositorio local se descarta.
  - Fichero generado con los 996 artefactos:
    `projects/com.quizsmart.app/backend/quizapi/logs/2026-10-05-18-02-20.cache-list.txt`
    (formato `GAV | repo | tamaño | velocidad`).
  - Opciones identificadas, **ninguna aplicada todavía**: (A) `-Dmaven.test.skip=true` en vez de `-DskipTests`,
    ahorro ~75; (B) quitar del pom los plugins no usados en deploy, ahorro ~150; (C)
    `--mount=type=cache,target=/root/.m2/repository` en el Dockerfile, no cambia comportamiento y hace que el
    2º build no descargue nada. **Recomendada la C.** Los cambios irían en la plantilla del generador
    `generator/components/backend/spring-boot-3.5.16`, no en `projects/`.
- Desglose de los 11 min del `up.ps1 -Fast`: docker build 4:44 (43%), cloud apply 4:38 (42%, con plan quizapi
  1:24 y apply quizapi 2:12), plataforma 0:37, frontend 0:19, publish-common 0:23, buildspecs 0:11,
  ECR 0:13, docker run 0:05. Los pasos nuevos suman solo 71 s (11%).

### Código sin commitear (lo hace el usuario)

- `library/platform/terraform/iam.tf` (statement `BuildLogs`).
- `library/platform/terraform/bump_bom.tf` (source CODECOMMIT, artifacts NO_ARTIFACTS).
- `library/platform/terraform/pipeline/main.tf`.
- `library/platform/buildspecs/bump-bom.yml`.
- `library/platform/scripts/seed-repos.ps1` (push `--force`).
- `library/common/pom.xml` y los 4 módulos a `1.0.1`.
- `generator/components/root/workspace/templates/up.ps1.scriban` y `projects/com.quizsmart.app/up.ps1`
  (pasos 0/0b/0c y arreglo del 3b).
- `.opencode/scripts/delete-all-services-aws.ps1`.
- `library/platform/terraform/terraform.tfvars` (local, gitignored).
