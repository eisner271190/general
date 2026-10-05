# platform

Este repositorio, junto a `common` (`library/common/`), es uno de los **dos repositorios de
plataforma** (ADR-0024): `common` cambia en cada release, `platform` muy poco, y cada uno tiene su
pipeline. No es una aplicación: nadie lo compila.

```
buildspecs/          Buildspecs para CodePipeline (CodeBuild), publicados en s3://epc-buildspecs/
scripts/             up.ps1 (Terraform), publicación de buildspecs y de `common` a CodeArtifact,
                     y el script del trigger de bump del BOM
terraform/           Plataforma: CodeArtifact, CodeCommit, bucket de buildspecs, ECR, IAM y
                     pipeline de `common` (declarativo, lo aplica el usuario)
```

## Scripts (nunca comandos sueltos)

| Script | Qué hace |
| --- | --- |
| `scripts/up.ps1` | `init -> plan -> apply` de `terraform/`. `-WhatIf` = solo plan, `-AutoApprove` = sin preguntar. |
| `scripts/publish-buildspecs.ps1` | Sube `buildspecs/*.yml` al bucket. **Idempotente**: compara el MD5 local con el ETag remoto y solo sube lo que cambió (`-DryRun` para ver qué subiría). |
| `scripts/publish-common.ps1` | `mvn deploy` de `../common` en CodeArtifact y confirmación de paquetes. `-DryRun` solo comprueba endpoint y token. |
| `scripts/bump-bom-version.py` | Sube **una línea** por pom (la `<version>` del `import` de `common-bom`) en el repo de la aplicación y abre un único PR. Idempotente. |
| `scripts/open-codecommit-prs.py` | Abre PRs idempotentes en CodeCommit. Lo usa el script anterior. |

```powershell
pwsh scripts/up.ps1 -WhatIf
pwsh scripts/publish-buildspecs.ps1 -Region us-east-1
pwsh scripts/publish-common.ps1
$env:APPLICATION_REPOSITORY = "<repo-de-la-aplicacion>"
python scripts/bump-bom-version.py --dry-run
```

El destino del bump **no está escrito en el script**: es la variable `APPLICATION_REPOSITORY`, que
Terraform inyecta en el proyecto CodeBuild (`application_repository`). `--repository` lo sustituye
para una ejecución manual.

## Terraform

`terraform/` declara: dominio y repositorio maven `common` en CodeArtifact, los **repos de
CodeCommit `common` y `platform`**, el bucket `epc-buildspecs` (versionado, sin acceso público,
también artifact store), el ECR `epc/common-base`, los roles IAM y el pipeline `common` con sus
dos CodeBuild y el CodeBuild del trigger de bump. Sin CMK y **sin secretos**: el token de
CodeArtifact lo pide cada build con la identidad del rol de CodeBuild (ADR-0022), así que no hay
nada que sembrar en Secrets Manager.

El repositorio de la aplicación **no** se declara aquí: lo declara su propio Terraform
(`cloud/terraform/app/codecommit.tf` del proyecto generado). `application_repository` solo da su
nombre, para componer el ARN del IAM del trigger.

```powershell
cp terraform/terraform.example.tfvars terraform/terraform.tfvars   # ajustar los valores
pwsh scripts/up.ps1 -WhatIf
pwsh scripts/up.ps1 -AutoApprove
```

El endpoint maven que devuelve el output `codeartifact_endpoint` es el que hay que copiar en
`../common/settings.xml` (sustituyendo `<cuenta>` y `<region>`) para que Maven resuelva `common`
desde el host.

## Buildspecs (CodePipeline / CodeBuild)

Un buildspec **no se puede referenciar desde otro repo con pin de commit** (CodeBuild solo acepta
YAML inline, una ruta en `CODEBUILD_SRC_DIR` o un ARN de S3). Por eso viven en un bucket versionado:

```yaml
source:
  type       = CODEPIPELINE
  buildspec = "arn:aws:s3:::epc-buildspecs/java-ci.yml"
```

Consecuencia: publicar un buildspec nuevo **no obliga a editar el pipeline del microservicio**. El
bucket tiene versionado, así que siempre se puede recuperar la versión que ejecutó un build.

| Buildspec | Para qué |
| --- | --- |
| `java-ci.yml` | Valida un microservicio Java (`mvn verify`). |
| `docker-build.yml` | Compila fuera de Docker y construye la imagen del microservicio. |
| `bump-bom.yml` | Trigger de release de `common` (ver abajo). |

El bucket debe estar **en la misma región** que el proyecto CodeBuild (requisito del ARN); lo crea
`terraform/`.

## Versión del BOM (`common` es CodeCommit)

CodeCommit no tiene plataforma de PR en Renovate, así que **no hay Renovate** (ADR-0025): la
actualización del BOM la hace una persona (criterio 6 del objetivo, fuera de alcance) y su
propagación a las aplicaciones la hace el trigger de release:

```
Tag v* en `common` (CodeCommit Reference Change, ingesta gratuita)
  -> CodeBuild platform-bump-bom   [buildspecs/bump-bom.yml]
      -> python3 scripts/bump-bom-version.py
          -> un repo (APPLICATION_REPOSITORY, de application_repository), poms por ruta
          -> sube UNA línea por pom, una sola rama, un único PR idempotente
```

- 0,00 USD: repos y pipelines por evento.

### Sin credenciales de Git

No hay secreto de Git sembrado ni `GIT_ASKPASS`. El script usa la **API de CodeCommit** (boto3),
que autentica con el rol del propio proyecto CodeBuild; de ahí que el rol tenga `codecommit:GitPull`,
`GitPush` y las acciones de la API acotadas al repositorio de la aplicación. Si algún build
necesitara clonar o empujar con `git`, la imagen estándar de CodeBuild ya trae el credential helper
nativo de CodeCommit, autenticado con ese mismo rol.

### Permisos que necesitan los proyectos CodeBuild de los microservicios

Además de los del bucket, el proyecto de cada microservicio necesita
`codeartifact:GetAuthorizationToken` (lo exige la API) sobre `*`: `java-ci.yml` y `docker-build.yml`
piden ahí el token, igual que hace el pipeline de `common`.

## Verificación

```bash
cd terraform && terraform fmt -check -recursive . && terraform validate && terraform plan
python scripts/bump-bom-version.py --help
python scripts/open-codecommit-prs.py --help
```