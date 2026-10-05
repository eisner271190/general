# ADR-0022: IAM de CodeArtifact por rol, token bajo demanda y cero secretos

- **Fecha:** 2026-10-03 (revisado 2026-10-04)
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; `question-008.md`, `question-010.md`

## Contexto

CodeArtifact no usa usuario ni contraseña: el login de Maven es un **token temporal de 12 h**
emitido por AWS a partir de la identidad de quien lo pide. Por tanto **el rol IAM es la frontera de
seguridad**: si el rol puede publicar, el token puede publicar. El objetivo exigía que el token
viviera en la variable de entorno `CODEARTIFACT_AUTH_TOKEN`.

## Decisión

La autenticación es **por rol**: cada build pide su propio token con la identidad que CodeBuild ya
le da, y **no hay ningún secreto de plataforma sembrado**.

| Pieza | Dónde vive | Por qué |
|-------|-------------|---------|
| `codeartifact:GetAuthorizationToken` | `terraform/iam.tf:224-228`, rol `epc-codebuild` | La API la exige sobre `*` y solo entrega un token de 12 h |
| Token en el build | `get-authorization-token` en `pre_build` (`terraform/pipeline/main.tf:32-35`) | Bajo demanda: nace y muere con el build |
| `CODEARTIFACT_AUTH_TOKEN` | Variable local del build; `unset` tras escribir el `settings.xml` | No se persiste |
| `settings.xml` | Efímero en `~/.m2`, borrado en `finally` | No queda en ninguna capa de Docker ni en el disco del runner |

**Cero secretos de plataforma**: no existe ningún `aws_secretsmanager_secret` de CodeArtifact ni de
Git en `library/platform/terraform/`, ni ninguna variable `SECRETS_MANAGER` en los buildspecs.
**El usuario no siembra nada.**

### Matriz de roles

| Rol | Permisos CodeArtifact / CodeCommit | Quién lo usa |
|-----|-------------------------------------|--------------|
| `epc-common-publisher` | `GetAuthorizationToken` + `ReadFromRepository` + `PublishPackageVersion` + `GetPackageVersion` sobre el ARN del repositorio | El pipeline de `common` en el bootstrap local |
| `epc-common-reader` | `GetAuthorizationToken` + `ReadFromRepository` | Builds de ms que solo consumen el BOM |
| `epc-codebuild` | `GetAuthorizationToken` (`*`, lo exige la API) + `GitPull`/`GitPush` sobre `platform` + las acciones de la API de CodeCommit (`GetFolder`, `PutFile`, `CreatePullRequest`, `GetPullRequest`, `ListPullRequests`) acotadas al repo de la aplicación + `ListReferences` acotada a `common` | Los proyectos CodeBuild: publicación de `common` y trigger del bump del BOM |
| `epc-buildspecs-publisher` | Sin CodeArtifact: `ListBucket`, `GetBucketVersioning` y `PutObject` sobre el bucket de buildspecs | `scripts/publish-buildspecs.ps1` |
| `epc-common-pipeline` | Sin CodeArtifact: artifact store a nivel de bucket + `ReadCommonRepository` + `StartPipeline` + `RunBuildProjects` | El CodePipeline de `common` |
| `epc-bump-trigger` | Sin CodeArtifact: `StartBuild` sobre el proyecto de bump + `PassBuildRole` | La regla EventBridge del tag `v*` |

- **`kms:Decrypt` no hace falta**: el repositorio no usa CMK propia (decisión de coste).
- El token se emite con `get-authorization-token` en el momento y viaja **siempre por variable de
  entorno**, nunca en un fichero. En el build local el `Dockerfile` lo monta con
  `RUN --mount=type=secret` y genera el `settings.xml` en el mismo `RUN`, de modo que no queda en
  ninguna capa.
- En **build local** el token sale de las credenciales del propio usuario de AWS: no hay nada previo
  que sembrar.

### Por qué ningún build empuja con `git`

Verificado: el script `bump-bom-version.py` escribe con la **API de CodeCommit** (boto3), que
autentica con el rol del propio proyecto CodeBuild: no necesita usuario ni contraseña.
de una aplicación lo hace `up.ps1` **en local**, leyendo `codecommit_clone_url` del output de su
propio Terraform. No hay ningún buildspec que ejecute `git push`.

`git-credential-helper: yes` es un **ajuste del buildspec de CodeBuild**, no un atributo de
Terraform: el provider `aws` v6.67.0 no expone `git_credential_helper` en `aws_codebuild_project`.
Hoy es **innecesario** porque ningún build empuja con `git`; si algún día hiciera falta, la imagen
estándar de CodeBuild ya trae el credential helper nativo de CodeCommit, autenticado con el rol.

## Consecuencias

### Positivas

- Radio de exposición mínimo: si se filtra el rol de un ms, el daño máximo es **leer**, no publicar.
- **Cero superficie de secretos**: nada que sembrar, nada que rotar, nada que auditar en Secrets
  Manager. Eliminado el coste de los secretos de plataforma (ADR-0023 deja un único secreto por
  aplicación para runtime, no para la plataforma).
- No hay CMK propia: se evita el coste mensual de la clave.
- El token no puede quedar obsoleto: se pide en cada build, no se almacena.

### Negativas y riesgos

- No hay alternativa al secreto: un repositorio Maven privado exige autenticación HTTPS. Lo que se
  reduce es el radio de exposición, no la necesidad.
- Si `pre_build` no consigue el token, el build falla pronto y con mensaje explícito, en lugar de
  fallar en `mvn` con un 401 opaco.
- El token **no se persiste en Secrets Manager**: dura 12 h, así que guardar un valor es guardar
  algo ya expirado. En el bootstrap local sale de las credenciales del propio usuario.
- Los dos roles de CodeArtifact (`epc-common-publisher`, `epc-common-reader`) siguen vigentes para
  uso local y para los proyectos CodeBuild de ms que se declaren.
- **Corrección de una versión anterior**: este ADR afirmaba que había que sembrar
  `epc/<env>/codeartifact` porque CodeBuild no tiene identidad de usuario. Es falso —CodeBuild sí
  tiene identidad: el rol que le asigna su proyecto—, y queda desmentido por
  `terraform/iam.tf:224-228` y `terraform/pipeline/main.tf:32-35`.

### Coste

**0 USD**. Sin CMK propia se evita **+1 USD/mes**, y sin secretos de plataforma se evita
**+0,40 USD/mes** por secreto y su rotación.