# platform

Un solo repositorio con la configuración compartida de CI. No es una aplicación: nadie lo compila.

```
buildspecs/          Buildspecs para CodePipeline (CodeBuild), publicados en s3://epc-buildspecs/
scripts/             Publicación de los buildspecs al bucket y de `common` a CodeArtifact
terraform/           Plataforma: CodeArtifact, bucket de buildspecs, ECR, IAM, pipeline de `common`
                     y los dos builds de automatización (declarativo, lo aplica el usuario)
```

## CodeArtifact: publicar `common`

`terraform/` crea el dominio `epc` y el repositorio maven `common`, con Maven Central como
upstream, y **el resto de la plataforma**: bucket `epc-buildspecs` (versionado, sin acceso
público, también artifact store), ECR `epc/common-base`, los roles IAM, el pipeline `common` con
sus dos CodeBuild y los dos builds de automatización. No hay CMK ni secretos en los `.tf`: los dos
secretos de Secrets Manager se **declaran vacíos** y los siembra el usuario.

```bash
cp terraform/terraform.example.tfvars terraform/terraform.tfvars   # ajustar los valores
pwsh scripts/publish-common.ps1
```

Qué hace el script, en orden:

1. `terraform init` y `terraform apply -auto-approve` (con `-SkipApply` usa el estado existente).
2. Lee el output `codeartifact_endpoint`.
3. Pide el token con `aws codeartifact get-authorization-token --domain epc`: vive solo en
   memoria y en la variable de entorno del proceso, nunca en disco ni en Secrets Manager.
4. `mvn deploy` del reactor `../common` con `-Depc.codeartifact.url=<endpoint>`.
   `common-parent` queda fuera del deploy (`maven.deploy.skip`, ADR-0020).
5. `aws codeartifact list-packages` para confirmar que `common-bom`, `common-log`,
   `common-error` y `common-web` están publicados.

El endpoint que devuelve Terraform es el que hay que copiar en `../common/settings.xml`
(sustituyendo `<cuenta>` y `<region>`) para que Maven resuelva `common` desde el host.

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

```bash
AWS_REGION=us-east-1 ./scripts/publish-buildspecs.sh
```

## Requisitos

- Bucket `epc-buildspecs` **en la misma región** que el proyecto CodeBuild (requisito del ARN).
  Lo crea `terraform/`, no hace falta hacerlo a mano.
- Repos de CodeCommit `common` y `platform` **antes** del primer build: los crea el usuario y
  Terraform solo compone su ARN (no se declaran como recursos).

## Renovate y versión del BOM (`common` es CodeCommit)

CodeCommit **no tiene soporte de PR en Renovate** (no existe `platform: awsCodeCommit`), así que
el trabajo se reparte en dos caminos, ambos en Terraform (`renovate.tf`):

| Camino | Qué hace | Disparador | Coste |
| --- | --- | --- | --- |
| **Renovate programado** | Actualiza las versiones de terceros de `common-bom` y deja ramas en `common` (`platform: local`) | Scheduler semanal → CodeBuild `common-renovate` (buildspec `renovate.yml`) | 4 invocaciones/mes, dentro de las 14 gratuitas |
| **Trigger por release** | Sube **una línea**: la `<version>` del `import` de `common-bom` en cada ms y abre el PR | EventBridge sobre el evento CodeCommit *Reference Change* (tag `v*`) → CodeBuild `common-bump-bom` (buildspec `bump-bom.yml`) | 0 (los service events de CodeCommit se ingieren gratis) |

### Scripts

- `scripts/open-codecommit-prs.py` — abre PRs **idempotentes**: si ya hay uno abierto desde esa
  rama, no hace nada. Reutilizable por cualquier disparador.
- `scripts/bump-bom-version.py` — lista los ms por prefijo de nombre (paginado), y en cada uno que
  ya importe `common-bom` sube esa versión y abre el PR. Idempotente: si ya está a la versión nueva,
  no hace nada. `--repo-prefix` es obligatorio y se configura en el proyecto CodeBuild según la
  convención de nombres de repos elegida para los microservicios generados; no se asume el piloto.
  Sin `--new-version` toma el último tag `v*` de `common`.

```bash
# Ensayo del trigger (necesita AWS porque toca CodeCommit)
python3 scripts/bump-bom-version.py --repo-prefix <prefijo-de-repos-generados> --dry-run
```

### Credenciales (las siembra el usuario, nunca están en el repo)

Dos secretos en Secrets Manager:

| Secreto | Claves | Para qué |
| --- | --- | --- |
| `epc/<env>/codecommit-git` | `username`, `password` | Git HTTPS de CodeCommit: `GIT_USERNAME` / `GIT_PASSWORD` de ambos builds |
| `epc/<env>/codeartifact` | `token` | `CODEARTIFACT_AUTH_TOKEN` del pipeline de `common` y `MAVEN_PASSWORD` del build de Renovate (con `RENOVATE_DETECT_HOST_RULES_FROM_ENV=true`, `MAVEN_USERNAME=aws`) |

Los dos secretos los **declara Terraform vacíos** (el valor va por `put-secret-value`):

```bash
aws secretsmanager put-secret-value --secret-id epc/develop/codeartifact --region us-east-1 \
  --secret-string "{\"token\":\"$(aws codeartifact get-authorization-token --domain epc --query token --output text)\"}"

aws secretsmanager put-secret-value --secret-id epc/develop/codecommit-git --region us-east-1 \
  --secret-string '{"username":"<usuario-git>","password":"<password-o-token-git>"}'
```

En los buildspecs, las credenciales de Git viajan con `GIT_ASKPASS` (en memoria): no se escriben en
`~/.gitconfig` ni en disco.
