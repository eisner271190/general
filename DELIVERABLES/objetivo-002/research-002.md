# Research 002 — CodePipeline (CodeCommit) y credential-helper para Renovate

Fecha: 2026-10-04
Alcance: investigación documental. Sin commit/push.

## Resumen

- `trigger` / `pathFilters` **no existen** para source CodeCommit en Terraform AWS.
  Solo aplican a `CodeStarSourceConnection` y exigen `pipeline_type = "V2"`.
- `platform: local` de Renovate **no soporta creación de ramas**. El supuesto del
  proyecto (empujar ramas + abrir PR) es inválido con `local`.
- Renovate tiene plataforma **`codecommit`** nativa, que sí crea ramas y PRs.

---

## Tema 1 — Filtros de ruta en CodePipeline con source CodeCommit

### F-1 · CRÍTICO · `trigger` no aplica a CodeCommit

`DELIVERABLES/objetivo-002/research-002.md:29`

Terraform, provider `hashicorp/aws`, recurso `aws_codepipeline`:

> `trigger` - (Optional) A trigger block. **Valid only when `pipeline_type` is `V2`**.
> ...

> `provider_type` - (Required) The source provider for the event.
> **Possible value is: `CodeStarSourceConnection`.**

> `provider` = `CodeStarSourceConnection` (único ejemplo del bloque `action` de ejemplo)

Fuente: https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/codepipeline.html.markdown

No hay ningún `pathFilters`. El bloque se llama `file_paths` con `includes`/`excludes`,
anidado bajo `push` o `pull_request`, y siempre dentro de `git_configuration`
de un `trigger`. Es decir: **no existe un atributo `pathFilters`**; el nombre correcto
es `trigger` → `git_configuration` → `push`/`pull_request` → `file_paths`.

### F-2 · CRÍTICO · AWS limita los triggers a conexiones, no a CodeCommit

`DELIVERABLES/objetivo-002/research-002.md:31`

> Triggers are configurable for source actions with connections that use the
> **CodeStarSourceConnection** action in CodePipeline, **such as GitHub, Bitbucket,
> and GitLab**.
>
> Source actions, such as **CodeCommit and S3**, use **automated change detection**
> to start pipelines when a change is made.

Fuente: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-triggers.html

Y la página específica de CodeCommit:

> The change detection method defaults to starting the pipeline by polling the source.
> You should disable periodic checks and create the change detection rule manually.

Fuente: https://docs.aws.amazon.com/codepipeline/latest/userguide/triggering.html

### F-3 · ALTO · ¿Los filtros aplican a PR?

Sí aplican a `pull_request` (`OPEN`, `UPDATED`, `CLOSED`) **pero solo en
CodeStarSourceConnection**:

> Pull request — Valid filter combinations are: branches (include/exclude),
> branches + file paths (include/exclude)

Fuente: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-triggers.html

Para CodeCommit **no hay evento de PR en EventBridge**, por tanto no hay forma de
filtrar por ruta en PR. CodeCommit tiene PRs como función, pero CodePipeline no se
suscribe a ellos con triggers.

### F-4 · ALTO · Mecanismos reales de filtrado con CodeCommit

Para `com.quizsmart.app` monorepo, las opciones son:

1. **EventBridge con `referenceType`/`referenceName`** — único filtro nativo.
   Filtra por **branch o tag**, nunca por ruta:

   ```json
   {"source":["aws.codecommit"],
    "detail-type":["CodeCommit Repository State Change"],
    "resources":["<repo-ARN>"],
    "detail":{"referenceType":["branch"],"referenceName":["main"]}}
   ```

   Además `PutRule` acepta `EventPattern` con `resources`, así que **una regla por
   repositorio**, pero el `detail` de `CodeCommit Repository State Change` **no incluye
   la lista de archivos modificados**. Confirmado: el payload es referenceType /
   referenceName / commitId / old / new. No hay campo de paths.

   Fuente: https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-trigger-source-repo-changes-cli.html

   Consecuencia: **no se puede disparar por ruta con CodeCommit + EventBridge.**
   Este es el punto que cierra el tema 1.

2. **Ramas por componente** — `backend/quizapi` → rama `backend/quizapi`,
   `frontend` → `frontend`. EventBridge filtra `referenceName`. Costo: disciplina de
   nombres de rama, sin garantía técnica.

3. **Un solo pipeline + buildspec parametrizado (recomendado)** — el buildspec
   compartido en S3 (ADR-0016) ya recibe variables. Se pasa `COMPONENT` como variable
   del pipeline y el buildspec decide qué construir. Un push a `main` dispara siempre;
   el desperdicio está en el arranque, no en la lógica.

4. **Filtro por ruta dentro del pipeline** — la Source stage descarga el repo entero,
   luego un CodeBuild de "routing" hace
   `git diff --name-only $PREV_COMMIT..$CODEBUILD_RESOLVED_SOURCE_VERSION` y decide.
   Coste: 1 build extra. Requiere `CODEBUILD_RESOLVED_SOURCE_VERSION` (ya existe para
   CodeCommit, disponible tras `DOWNLOAD_SOURCE`).

   Fuente: https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html

   Nota: `CODEBUILD_RESOLVED_SOURCE_VERSION` solo existe si la fase `DOWNLOAD_SOURCE`
   corrió; con source CodePipeline desde S3 **no se setea**. Relevante para buildspecs
   en S3.

5. **Migrar a CodeConnections (GitHub)** — habilita `pathFilters` nativas. No es
   opción realista: el proyecto está en CodeCommit.

---

## Tema 2 — Credential-helper de CodeCommit con Renovate

### F-6 · CRÍTICO · `platform: local` no crea ramas

`DELIVERABLES/objetivo-002/research-002.md:40`

> In this mode, Renovate defaults to `dryRun=lookup`.
> Other `dryRun` values (such as `full`) are not supported on the local platform and
> fall back to `lookup`.
>
> Limitations:
> - `baseBranchPatterns` are ignored
> - **Branch creation is not supported**

Fuente: https://docs.renovatebot.com/modules/platform/local/

Consecuencia directa: con `platform: local`, `dryRun` queda forzado a `lookup`,
no hay `commit` ni `branch`. **Renovate no empuja nada.** Cualquier buildspec que
dependa de que Renovate cree la rama `renovate/...` y luego la empuje con `git push`
no puede funcionar. Esas ramas hay que crearlas a mano antes, y aun así `lookup`
no escribe archivos.

### F-7 · ALTO · Existe plataforma `codecommit` nativa

`DELIVERABLES/objetivo-002/research-002.md:43`

> Set `platform: 'codecommit'`
> Set `repositories: ['...']`

Permisos mínimos según la doc de Renovate:

```json
{
  "Sid": "RenovatePolicy",
  "Effect": "Allow",
  "Action": [
    "codecommit:GitPull", "codecommit:GitPush",
    "codecommit:CreatePullRequest", "codecommit:GetPullRequest",
    "codecommit:ListPullRequests", "codecommit:GetCommentsForPullRequest",
    "codecommit:UpdateComment", "codecommit:DeleteCommentContent",
    "codecommit:UpdatePullRequestTitle", "codecommit:UpdatePullRequestDescription",
    "codecommit:UpdatePullRequestStatus",
    "codecommit:GetFile", "codecommit:GetRepository", "codecommit:ListRepositories"
  ],
  "Resource": "*"
}
```

Buildspec de ejemplo oficial:

```yaml
version: 0.2
env:
  shell: bash
  git-credential-helper: yes
  variables:
    RENOVATE_PLATFORM: 'codecommit'
    RENOVATE_REPOSITORIES: '["com.quizsmart.app"]'
    AWS_REGION: 'us-east-1'
```

Fuente: https://docs.renovatebot.com/modules/platform/codecommit/

Advertencias relevantes al proyecto:

- **No hay nuevas features.** "The Renovate maintainers have decided that we will not
  add any new features unless a company is willing to contribute feature(s)".
- **No soporta `automerge`** → los PRs de `common-bom` se abrirán pero no se
  auto-mergearán. Requiere merge manual o acción en el trigger de tag `v*`.
- **No soporta `rebaseLabel`.**
- Feature freeze de CodeCommit desde julio 2024; AWS lo reinstating en GA en
  noviembre 2025 pero el freeze continúa.

### F-8 · MEDIO · `git-credential-helper: yes` es de CodeBuild, no un paquete

`DELIVERABLES/objetivo-002/research-002.md:52`

> `git-credential-helper` - Optional mapping. Used to indicate if CodeBuild uses its
> **Git credential helper** to provide Git credentials. `yes` if it is used.
> `git-credential-helper` is not supported for builds that are triggered by a webhook
> for a public Git repository.

Fuente: https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html

Es la vía **oficial y soportada**: CodeBuild inyecta el helper que firma SigV4 con el
rol del proyecto. No requiere instalar `aws-codecommit-credential-helper` ni guardar
secretos.

### F-9 · MEDIO · El paquete oficial y su configuración manual

Si se opta por install manual, AWS provee
`aws-codecommit-credential-helper` (PyPI/GitHub, repo oficial
`aws/aws-codecommit-credential-helper`, parte del AWS CLI). Configuración exacta:

```
git config --global credential.helper '!aws codecommit credential-helper $@'
git config --global credential.UseHttpPath true
```

> The credential helper uses the **default AWS credential profile or the Amazon EC2
> instance role**.

Fuente: https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-unixes.html

En CodeBuild **no funciona** el fallback a EC2 instance role porque CodeBuild no es
EC2: el rol llega vía metadata de STS. Por eso AWS recomienda `git-remote-codecommit`
en vez del credential-helper:

> the recommended method is to install and use the **git-remote-codecommit** utility

Fuente: misma URL

Y la doc de Renovate para CodeCommit pide `aws-cli` instalado + credential helper
configurado. Con `git-credential-helper: yes` de CodeBuild esto ya viene resuelto.

### F-10 · MEDIO · IAM mínimo en el rol de CodeBuild

```json
{
  "Effect": "Allow",
  "Action": ["codecommit:GitPull", "codecommit:GitPush"],
  "Resource": "arn:aws:codecommit:<region>:<account>:com.quizsmart.app"
}
```

- `GitPull` obligatorio para clonar/actualizar.
- `GitPush` obligatorio para subir ramas y commits.
- **Nada más** es necesario para la capa Git pura.
- Si se abre PR con `git push` a una rama + API `CreatePullRequest`, añadir
  `codecommit:CreatePullRequest` y `codecommit:GetPullRequest`.
- **No** usar `AWSCodeCommitPowerUser`: incluye `codecommit:*` de Create/Delete,
  `events:*`, `sns:*`, `iam:ListAccessKeys` — exceso de superficie para un job de CI.

Fuente (acciones y alcance de las managed policies):
https://docs.aws.amazon.com/codecommit/latest/userguide/security-iam-awsmanpol.html

### F-11 · BAJO · ¿Usa Renovate el cliente Git del contenedor?

Con `platform: codecommit`, **no**: Renovate usa su propia capa HTTP (el `username`/
`password`/`endpoint` de la doc), no el binario `git`. Por eso el `git-credential-helper`
de CodeBuild es irrelevante para la API de Renovate — pero **sí** es necesario si un
step separado del buildspec hace `git push`.

Con `platform: local` + `manager: maven`, el manager maven solo parsea `pom.xml`, no
invoca `git`. El `git` del contenedor lo invoca la **plataforma** (local), y como F-6
demuestra, local no escribe.

El manager maven no necesita opción alguna de credenciales:
https://docs.renovatebot.com/modules/manager/maven/ — extrae de `pom.xml`,
`pom.template.xml`, `settings.xml`, `.mvn/extensions.xml`. Cubre
`<scope>import</scope>` (BOM) vía `depType: import`.

### F-12 · BAJO · Limitaciones

- **Git LFS**: CodeCommit soporta LFS, pero requiere el helper y ancho de banda
  dedicated. No aplica a este repo Java. Sin fuente oficial adicional encontrada.
- **Force push**: CodeCommit bloquea force-push por defecto en branches
  protegidas. Renovate regenera commits en `renovate/*`; si la rama está protegida,
  el push falla. Recomendación de Renovate: `prConcurrentLimit` + `"enabled": false`
  en `packageRules` para no recrear PRs cerrados.
- **Windows/CodeBuild**: la doc de Renovate para CodeCommit tiene paths separados
  EC2/Linux y Windows. El buildspec oficial usa `shell: bash` → entorno Linux. En
  CodeBuild Windows `git-credential-helper: yes` no aplica de la misma forma.
- **`codepipeline-service`**: no es requisito. Ninguna doc de CodeBuild ni Renovate
  lo menciona como variable necesaria. Los buildspecs de origen S3 (ADR-0016)
  necesitan `CODEBUILD_SRC_DIR` para localizar los buildspecs, no
  `codepipeline-service`.
- **`AWS_REGION`**: sí requerido. Renovate lo lista como prerrequisito
  ("Set the environment variable `AWS_REGION`"), y el buildspec oficial lo fija
  explícitamente. CodeBuild ya lo exporta, pero declararlo lo hace determinista.

---

## Decisión

### Tema 1: no hay filtros de ruta en CodeCommit

`trigger` con `file_paths` es exclusivo de `CodeStarSourceConnection` (GitHub,
Bitbucket, GitLab) y exige `pipeline_type = "V2"`. CodeCommit solo ofrece
detección de cambios por EventBridge con filtro de **branch o tag**.

**Elegido:** opción 3, un solo pipeline con buildspec parametrizado (ya disponible
por ADR-0016) + filtro por ruta opcional (opción 4) si el desperdicio se vuelve
molesto.

Descartado: filtros de ruta en PR (no existen para CodeCommit), ramas por
componente (sin garantía técnica, disciplina de nombres), migrar a GitHub (fuera de
alcance).

Riesgo aceptado: cada push a `main` arranca el pipeline. Mitigación: buildspec
temprano que compare el diff y salga rápido si nada cambió.

### Tema 2: cambiar a `platform: codecommit`, no `local`

`platform: local` fuerza `dryRun=lookup` y **no soporta creación de ramas**.
El diseño actual (Renovate empuja ramas con el cliente Git) no puede funcionar.
Renovate tiene plataforma `codecommit` nativa que hace ramas, push y PR vía API.

**Elegido:** `platform: 'codecommit'` + `git-credential-helper: yes` +
`AWS_REGION` explícito + IAM de 2 acciones (`GitPull`, `GitPush`) ampliada con
`CreatePullRequest` y `GetPullRequest`.

Consecuencias a aceptar:
- **No hay automerge.** El PR de `common-bom` requiere merge manual o un paso en el
  trigger de tag `v*`.
- **No hay features nuevas.** Si falta algo, hay que contribuirlo o trabajar con
  workarounds (`prConcurrentLimit`, `packageRules` con `"enabled": false`).
- Se elimina la dependencia del cliente `git` para escribir. El
  `git-credential-helper` queda solo para steps manuales del buildspec.

---

## Referencias

- [Automate starting pipelines using triggers and filtering](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-triggers.html)
- [Add trigger with code push or pull request event types](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-filter.html)
- [CodeCommit source actions and EventBridge](https://docs.aws.amazon.com/codepipeline/latest/userguide/triggering.html)
- [Create an EventBridge rule for a CodeCommit source (CLI)](https://docs.aws.amazon.com/codepipeline/latest/userguide/pipelines-trigger-source-repo-changes-cli.html)
- [CodeCommit source action reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeCommit.html)
- [terraform-provider-aws: aws_codepipeline](https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/codepipeline.html.markdown)
- [Buildspec specification reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html)
- [Environment variables in build environments](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html)
- [Setup HTTPS with the AWS CLI credential helper](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up-https-unixes.html)
- [AWS managed policies for CodeCommit](https://docs.aws.amazon.com/codecommit/latest/userguide/security-iam-awsmanpol.html)
- [Renovate: platform local](https://docs.renovatebot.com/modules/platform/local/)
- [Renovate: platform AWS CodeCommit](https://docs.renovatebot.com/modules/platform/codecommit/)
- [Renovate: manager maven](https://docs.renovatebot.com/modules/manager/maven/)

## Dudas

- ¿Se va a mantener Renovate en CodeBuild o migrar a la plataforma `codecommit` de
  un self-hosted runner? Cambia la decisión de IAM y la superficie de mantenimiento.
- ¿La ausencia de automerge es aceptable para `common-bom`, o el trigger de tag `v*`
  debe cerrar el PR programáticamente?
- ¿Existe algún payload de EventBridge de CodeCommit con la lista de archivos
  modificados? La documentación pública solo muestra
  `referenceType`/`referenceName`. Si existiera, cambiaría F-4.4.

---

## Cambios

- 2026-10-04: creado `DELIVERABLES/objetivo-002/research-002.md` (sección Decisión
  incluida; no había contenido previo que preservar).