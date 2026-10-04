# Implementación — Objetivo 003

## Qué cambió

- `common/` y `platform/` pasan a `library/`: una carpeta nombra lo transversal y lo separa del
  generador.
- Terraform declarativo en `library/platform/terraform/`: dominio `epc` y repositorio maven
  `common` con Maven Central como upstream. Sin CMK, sin secretos, sin roles (ADR-0022).
- `library/platform/scripts/publish-common.ps1`: apply + `mvn deploy` + confirmación. El token se
  pide en el momento y no se persiste.
- Plantilla `Dockerfile.scriban`: `RUN --mount=type=secret` y `settings.xml` efímero creado y
  borrado en el mismo `RUN`.
- Plantilla `up.ps1.scriban` (backend): pide endpoint y token a CodeArtifact y los pasa a
  `docker build` con `--build-arg` y `--secret`.
- ADR-0022 actualizado y ADR-0023 nuevo (el secreto único por aplicación solo guarda runtime).
- `component.json` **sin cambios**: no se introduce ninguna plantilla nueva, y sin `.dockerignore`
  no hay nada que registrar.

## Archivos

Creados:

- `library/platform/terraform/provider.tf` — provider aws con `required_version` y `~> 6.0`.
- `library/platform/terraform/variables.tf` — `region` y `domain_name` (con `validation`).
- `library/platform/terraform/codeartifact.tf` — `aws_codeartifact_domain.epc` y
  `aws_codeartifact_repository.common` (`upstream { repository_name = "central" }`).
- `library/platform/terraform/outputs.tf` — data source
  `aws_codeartifact_repository_endpoint` (formato `maven`) + output `codeartifact_endpoint`.
- `library/platform/terraform/terraform.example.tfvars` — región y dominio de ejemplo.
- `library/platform/scripts/publish-common.ps1` — init, apply, endpoint, token, deploy, list-packages.
- `.opencode/docs/adr/0023-secreto-unico-solo-runtime.md` — ADR nuevo.

Modificados:

- `library/common/*` y `library/platform/*` — movidos con `git mv` (contenido intacto).
- `library/platform/README.md` — sección de CodeArtifact: comando y qué verifica.
- `generator/components/backend/spring-boot-3.5.16/templates/Dockerfile.scriban` — secret mount.
- `generator/components/backend/spring-boot-3.5.16/templates/up.ps1.scriban` — endpoint, token,
  `--build-arg` y `--secret`.
- `.opencode/docs/adr/0022-iam-codeartifact-dos-roles.md` — token efímero; sin secreto en Secrets
  Manager en el bootstrap local; los dos roles siguen vivos para CodeBuild.
- `.opencode/docs/adr/README.md` — entrada de ADR-0023.

## Verificación ejecutada

| Cmd | Comprobación | Resultado |
|-----|---------------|-----------|
| 1 | `git mv common library/common` y `git mv platform library/platform` | `R` (rename) en `git status`: el historial se conserva |
| 2 | `terraform fmt -check -recursive` en `library/platform/terraform` | exit 0 |
| 3 | `terraform init -backend=false` + `terraform validate` | `Success! The configuration is valid.` |
| 4 | `terraform providers schema -json` → `aws_codeartifact_repository` | Sin atributo `format`: el repo no declara formato y el endpoint se resuelve con el data source. `upstream` es bloque, no atributo. Corregido antes de validar |
| 5 | `Parser::ParseFile` de `publish-common.ps1` | Sin errores de sintaxis |
| 6 | `ConvertFrom-Json` de `renovate.json` y `component.json` | Ambos válidos |
| 7 | `dotnet build` en `generator` | Compilación correcta, 0 errores |
| 8 | `dotnet run` (regenera `projects/com.quizsmart.app`) | `Resumen: OK=1` |
| 9 | `Dockerfile` y `up.ps1` renderizados: `Select-String '\{\{'` | Sin placeholders sin resolver |
| 10 | `Parser::ParseFile` del `up.ps1` generado | Sin errores de sintaxis |

## Verificación pendiente del usuario (Tarea 4 del plan)

Requiere `terraform apply` y credenciales de pago, así que **no se ha ejecutado**:

1. `cp library/platform/terraform/terraform.example.tfvars
   library/platform/terraform/terraform.tfvars` y ajustar `region` y `domain_name`.
2. `pwsh library/platform/scripts/publish-common.ps1`.
3. `pwsh projects/com.quizsmart.app/up.ps1 -Fast` (o `backend/quizapi/up.ps1 -Phase Build`):
   el paso 2/5 debe pasar.
4. `docker history quizapi --no-trunc`: ni el token en `ARG` ni en ninguna capa.
5. `aws codeartifact list-packages --domain epc --repository common --format maven`: deben
   aparecer `common-bom`, `common-log`, `common-error` y `common-web`; `common-parent` no
   (ADR-0020).

Sin el paso 1, `up.ps1 -Phase Build` para con el mensaje "No se pudo resolver el endpoint de
CodeArtifact", que es el comportamiento buscado: fallar antes de un `mvn` que no puede resolver
`common-bom`.

## Notas y desviaciones del plan

- `format = "maven"` y `upstreams = [...]` del plan no existen en el provider aws 6.67.0
  (comprobado con `providers schema`). Se usan el bloque `upstream` y el data source
  `aws_codeartifact_repository_endpoint`.
- La tarea de actualizar rutas en `library/common/renovate.json:6` y
  `library/platform/README.md:64` no aplica: ambas líneas son la URL del registro y el nombre del
  secreto, no rutas del workspace. Ninguna ruta del repo a `common/` o `platform/` quedaba
  colgada: las coincidencias son nombres de repositorio de CodeCommit.
- Sin `.dockerignore`: no se introduce la plantilla, luego `component.json` no se toca.

## Coste AWS

- CodeArtifact es de pago: almacenamiento + datos transferidos. Con 1 ms y 4 artefactos, muy por
  debajo del techo de 2 USD/mes asumido. **No es 0 USD.**
- Secrets Manager: 0 USD. El token de bootstrap no se persiste (ADR-0022); el secreto único por
  aplicación ya estaba presupuestado en ADR-0010.