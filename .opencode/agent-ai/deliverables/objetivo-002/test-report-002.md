# Reporte de pruebas — Objetivo 002 (`common`)

**Versión 2** (re-test tras los arreglos del Developer). Fecha: 2026-10-03.
Entorno: PowerShell, Maven 3.9.9, JDK 17.0.12, Windows 10. Sin AWS.

## Changelog respecto a la v1

| Aspecto | v1 (FALLA_IMPLEMENTACION) | v2 |
| --- | --- | --- |
| Defecto 1 — prefijo S3 `buildspecs/*.yml` vs clave real en la raíz | **no cumple** | **corregido**: los 3 sitios coinciden en la raíz; 0 patrones huérfanos |
| Defecto 2 — `settings.xml` nunca creado y `CHANGE_ME` en `mvn deploy` | **no cumple** | **corregido**: `pre_build` crea el `settings.xml`, la URL viaja Terraform → CodeBuild → `-D` |
| IAM de logs y caché de CodeBuild | no existía | añadido (`iam.tf:90-103`), ver nota de alcance abajo |
| Artefactos S3 de CodePipeline (`artifact_store`) | no detectado | **defecto nuevo detectado** (ver abajo) |
| CA #1, #3, #4, #5, #11 | cumple | **siguen cumpliendo** (re-ejecutados) |
| CA #10 | pendiente del usuario | pendiente del usuario, **idéntico**: mismos 3 imports, sin cambios |

Ningún fichero de código, test o Terraform modificado por el agente. Sin commit ni push.

## Comandos ejecutados (v2)

| # | Comando | Resultado |
| --- | --- | --- |
| 1 | `mvn -B -ntp clean install` (en `common/`) | BUILD SUCCESS (7/7) |
| 2 | `mvn -pl samples/log-only-sample dependency:tree` | 0 coincidencias `common-web`/`webflux`/`reactor`/`spring-web` |
| 3 | `mvn -pl samples/log-only-sample spring-boot:run --debug` | arranca; 0 apariciones de `com.epc.common.web` |
| 4 | `web-sample` en 8098 + `curl /error` + informe de condiciones | 500 con el advice de la muestra; `globalExceptionHandler: Did not match` |
| 5 | `mvn -B -ntp -o clean compile` (en `quizapi`) | `Compiling 57 source files` → BUILD SUCCESS |
| 6 | `mvn -B -ntp -o clean test` (en `quizapi`) | **BUILD FAILURE en `testCompile`**: los mismos 3 imports |
| 7 | `terraform fmt -check -diff .` + `terraform validate` | `fmt-exit=0`; `Success! The configuration is valid.` |
| 8 | `ConvertFrom-Yaml` / `ConvertFrom-Json` (7 YAML de repo + buildspec renderizado + 2 JSON) | 10/10 válidos |
| 9 | Render del buildspec inline (`$${}`→`${}`) + `ConvertFrom-Yaml` | YAML válido; 4 comandos en `pre_build`, 1 en `build`; **0 `CHANGE_ME` ejecutable** |
| 10 | `settings.xml` extraído del render → parseo XML + `mvn -N help:effective-pom -s <fichero> -Depc.codeartifact.url=...` | XML válido; **BUILD SUCCESS**; `distributionManagement` efectivo → `id=codeartifact`, `url=https://epc-111122223333.d.codeartifact.us-east-1.amazonaws.com/maven/common/` (el `CHANGE_ME` sustituido) |
| 11 | `settings.xml` de los buildspecs compartidos con `<url>${CODEARTIFACT_URL}</url>` → `mvn help:effective-settings` | Maven **sí expande** la variable: el repositorio efectivo sale con la URL real |
| 12 | `grep` de `buildspecs/` y `CHANGE_ME` en `*.tf`, `*.sh`, `*.yml` | 0 patrones huérfanos; `CHANGE_ME` solo en comentarios y en la `description` de una variable |

## Criterio por criterio

| # | Criterio | Estado v1 | Estado v2 | Evidencia |
| --- | --- | --- | --- | --- |
| 1 | `mvn install` en `common` compila todos los módulos | cumple | **cumple** | Cmd 1: los 7 módulos SUCCESS |
| 2 | Publica en CodeArtifact y un ms externo resuelve el BOM | no verificable sin AWS | **no verificable en local** | Requiere `terraform apply` (CodeArtifact + Secrets Manager), token sembrado y `mvn deploy`. Haría falta además corregir el defecto nuevo de IAM del pipeline (§Fallo 1) para que el stage `Publish` arranque |
| 3 | Un ms con solo `common-log` no carga `common-web` | cumple | **cumple** | Cmds 2 y 3: 0 coincidencias en el árbol y 0 en todo el arranque con `--debug` |
| 4 | `common-web` registra el advice solo si el ms no define el suyo | cumple | **cumple** | Cmd 4: `curl /error` → 500 con `"Manejado por el advice de la muestra"` y sin `stackTrace`; `WebAutoConfiguration#globalExceptionHandler: Did not match` |
| 5 | Versión en un solo fichero, consumo de una línea | cumple | **cumple** | Sin cambios en `quizapi/pom.xml` (única `import` de `common-bom` en la línea 35, 0 versiones de terceros) |
| 6 | Renovate actualiza el BOM y abre PR en cada ms | no verificable sin AWS | **no verificable en local** | JSON válido y sin credenciales. Haría falta `renovate --dry-run` con `MAVEN_USERNAME`/`MAVEN_PASSWORD` y el endpoint real |
| 7 | `epc/common-base` en ECR y `Dockerfile` ≤5 líneas | parcial | **cumple (local) / no verificable en local (publicación)** | `Dockerfile` del piloto: 4 líneas efectivas sobre `epc/common-base:1.0.0`; `common/docker/Dockerfile` sobre `public.ecr.aws/lambda/java:17`. La publicación requiere `terraform apply` + ECR + `docker build` |
| 8 | El pipeline resuelve el buildspec por ARN de S3 sin editar el ms | **no cumple** | **defecto corregido, pero sigue bloqueado por un defecto nuevo de IAM** | Coherencia de clave: `publish-buildspecs.sh:12` → `s3://${BUCKET}/`; `pipeline/main.tf:95` → `arn:aws:s3:::${var.buildspecs_bucket}/java-ci.yml`; `iam.tf:86` → `${bucket.arn}/*.yml`; `iam.tf:154` → `${bucket.arn}/*`; `iam.tf:100-101` → `logs/*`, `cache/*`. 0 huérfanos. La ejecución real sigue sin ser verificable sin AWS |
| 9 | Un pipeline extiende una plantilla de plataforma | no verificable sin Azure DevOps | **no verificable en local** | `azure-build.yml` con `resources.repositories` + `ref: refs/tags/v1.0.0` y 3 `template: …@platform`. Necesita el repo en Azure DevOps y el tag publicado |
| 10 | `quizapi` compila y sus pruebas pasan sin código duplicado | pendiente del usuario | **pendiente del usuario** | Cmd 5: producción compila (57 ficheros). Cmd 6: la suite no arranca por los 3 imports previstos. `infrastructure/rest/` sigue sin existir |
| 11 | `quizapi` sin versiones de terceros presentes en el BOM | cumple | **cumple** | Sin cambios: 9 `<version>`, todas justificadas (parent, propia, import del BOM, 6 de plugins) |

## Estado de los 2 defectos de la v1

### Defecto 1 (prefijo S3) — **CORREGIDO, causa raíz**

Lo que lo demuestra (los 3 sitios, leídos en los ficheros, no en el informe):

```
platform/scripts/publish-buildspecs.sh:12   aws s3 sync .../buildspecs  s3://${BUCKET}/
pipeline/main.tf:95                         buildspec = "arn:aws:s3:::${var.buildspecs_bucket}/java-ci.yml"
iam.tf:86                                   resources = ["${aws_s3_bucket.buildspecs.arn}/*.yml"]
iam.tf:154                                  Resource = [bucket.arn, "${bucket.arn}/*"]
```

Además `iam.tf:90-103` añade `BucketLogsAndCache` (`logs/*`, `cache/*` con `GetObject`, `GetObjectVersion`, `PutObject`, `DeleteObject`), que cubre los logs y la caché de CodeBuild en el mismo bucket. Grep de `buildspecs/` y `/buildspecs/` sobre `*.tf`, `*.sh` y `*.yml`: **0 patrones huérfanos** (los dos `buildspecs/` que aparecen son el directorio del repo y el nombre del bucket, correctos).

### Defecto 2 (`settings.xml` inexistente + `CHANGE_ME`) — **CORREGIDO, causa raíz**

Cadena verificada de extremo a extremo:

1. `main_pipeline.tf:10` compone el endpoint → `local.codeartifact_url`.
2. `main_pipeline.tf:22` lo pasa al módulo → `pipeline/variables.tf:32` (`codeartifact_url`).
3. `pipeline/main.tf:123-124` lo expone como variable de entorno de CodeBuild **`CODEARTIFACT_URL`** (valor plano, no secreto).
4. El buildspec inline (`pipeline/main.tf:13-45`) en `pre_build` **crea** `~/.m2/settings.xml` con `<id>codeartifact</id>` y `<password>${env.CODEARTIFACT_AUTH_TOKEN}</password>`, y en `build` ejecuta `mvn -B -ntp deploy -Depc.codeartifact.url="${CODEARTIFACT_URL}"`.
5. `finally` hace `rm -f`.

Render real (simulando el `$${}`→`${}` de Terraform) y prueba funcional con Maven (Cmd 9 y 10): YAML válido, el `<password>` llega intacto como `${env.CODEARTIFACT_AUTH_TOKEN}` (el heredoc `<<'SETTINGS'` impide que lo expanda el shell), y **`-D` sustituye el `CHANGE_ME`**: el `distributionManagement` efectivo resuelve a la URL real. `BUILD SUCCESS`.

Además el arreglo se extendió a los buildspecs compartidos (`java-ci.yml`, `docker-build.yml`), que crean el mismo `settings.xml` **guardado** con `if [ -n "${CODEARTIFACT_URL:-}" ]` (necesario: el build de `common` compila su propio reactor sin repo remoto).

Nota: sospeché que `<url>${CODEARTIFACT_URL}</url>` quedaría literal sin expandir por el heredoc entre comillas; **lo refuté con una prueba** (Cmd 11): Maven lo expande y el repositorio efectivo sale con la URL real. No es un defecto.

Ningún secreto ni `CHANGE_ME` en el flujo ejecutable: el token va por Secrets Manager (`pipeline/main.tf:72-73`, `116-117`) y `CHANGE_ME` solo aparece en comentarios y en la `description` de una variable. Sin commit ni push.

## Fallo que persiste en v2 (nuevo, misma clase que el defecto 1)

### `iam.tf` — el rol del CodePipeline no puede usar su propio `artifact_store`

`pipeline/main.tf:155-162`:

```hcl
resource "aws_codepipeline" "common" {
  name     = "common"
  role_arn = var.publisher_role_arn      # = common-publisher
  artifact_store { location = var.buildspecs_bucket, type = "S3" }
}
```

`grep` de todo `iam.tf`: **no existe ni un solo** `s3:GetBucketVersioning`, `s3:GetBucketLocation`, `s3:GetBucketAcl`, `s3:PutBucketAcl` ni `s3:ListBucket`. El rol `common-publisher` solo tiene `s3:GetObject`/`s3:GetObjectVersion` sobre `${bucket.arn}/*.yml` (`iam.tf:79-87`) y `PutObject`/`DeleteObject` sobre `logs/*` y `cache/*` (`iam.tf:90-103`).

CodePipeline necesita, como mínimo, para su artifact store: `s3:GetBucketVersioning` y `s3:GetBucketLocation`/`GetBucketAcl`/`PutBucketAcl` **sobre el bucket**, y `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject` sobre `bucket/*`. Además el Source stage no define `OutputArtifactName` (`pipeline/main.tf:174-178`), así que su artefacto es `CodeCommitSource` y su clave `CodeCommitSource/<uuid>` **no** termina en `.yml` → sin permiso de lectura aunque existiera.

El bucket tiene versionado activo (`main.tf:34-40`), lo que hace `s3:GetBucketVersioning` obligatorio.

Consecuencia: el stage `Source` falla con `AccessDenied` en cuanto se arranca el pipeline → CA #8 y CA #2 no se pueden cumplir aunque el usuario aplique el Terraform. Es exactamente la misma clase de defecto que el que se corrigió ("el rol no puede hacer lo que el pipeline necesita") y también es detectable sin AWS.

**Fix mínimo**: al `common_publisher` (o a un rol de pipeline dedicado) añadir el statement del artifact store —
`s3:GetBucketVersioning`, `s3:GetBucketLocation`, `s3:GetBucketAcl`, `s3:PutBucketAcl` sobre `aws_s3_bucket.buildspecs.arn`, y `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject`, `s3:GetBucketAcl` sobre `"${arn}/*"`.

### Observación (no bloqueante, no verificable sin AWS)

`logs/*` y `cache/*` (`iam.tf:100-101`): CodeBuild recibe solo el **nombre** del bucket (`pipeline/main.tf:89`, `145`), y sus claves reales cuelgan del nombre del proyecto (`<bucket>/<project>/<build-id>/...` para los logs) y del hash de la clave de caché, no literalmente de `logs/` y `cache/`. El statement puede no ser efectivo. No lo clasifico como fallo porque no es comprobable localmente; queda cubierto por la tarea de verificación con `--debug` que ya dejó el Developer. Si se confirma, el arreglo mínimo es ampliar el comodín de S3 del rol, no cambiar el bucket.

## Resultado de la suite de `quizapi`

```
> mvn -B -ntp -o clean test
[ERROR] HolaMundoControllerTest.java:[3,54] package com.quizsmart.app.infrastructure.rest.response does not exist
[ERROR] HolaMundoControllerTest.java:[4,54] package com.quizsmart.app.infrastructure.rest.response does not exist
[ERROR] ParameterControllerTest.java:[4,54]  package com.quizsmart.app.infrastructure.rest.response does not exist
[INFO] 3 errors
[INFO] BUILD FAILURE
```

**0 tests ejecutados**: la suite no arranca. Idéntico a la v1, sin cambios en los tests por parte del Developer. Los 3 imports siguen siendo tarea del usuario (F7.5); `AGENTS.md` lo prohíbe al agente. La producción compila (`Compiling 57 source files` → `BUILD SUCCESS`).

## Veredicto

**FALLA_IMPLEMENTACION** (v2)

- Los 2 defectos de la v1 están **corregidos en su causa raíz**, no parchados: lo demuestra la coherencia de los 3 sitios de la clave S3 y la prueba funcional del `settings.xml` generado con `-D` sustituyendo el `CHANGE_ME`.
- Los criterios #1, #3, #4, #5 y #11 se re-verificaron y siguen en verde: nada se ha roto.
- #2, #6, #7 (publicación), #8 (ejecución) y #9 son **no verificables en local**.
- #10 sigue **pendiente del usuario** (3 imports de test), sin cambios.
- **Bloquea el cierre**: `iam.tf` no da al rol del CodePipeline los permisos de su propio `artifact_store` (`GetBucketVersioning`, `GetBucketAcl`, `PutBucketAcl`, `GetBucketLocation`, `GetObject`/`PutObject` fuera de `*.yml`). El Source stage dará `AccessDenied` al arrancar el pipeline, con lo que CA #8 y CA #2 no se pueden cumplir. Vuelve a Developer.

No he creado ni modificado ningún test, ni ningún fichero del objetivo. No he hecho commit ni push. No ha hecho falta registrar ninguna duda nueva (question-019 sin uso).