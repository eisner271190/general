# Plan: Bootstrap de CodeArtifact y publicación de `common`

- **Tarea del objetivo:** N/A - solicitado directamente
- **Fecha:** 2026-10-04

## 1. Descripción

- `up.ps1` falla en el paso 2/5 (`backend -Phase Build`).
- `docker build` de `quizapi` no resuelve `com.epc.common:common-bom:pom:1.0.0`.
- 22 errores de Maven en cascada: todos consecuencia del BOM sin resolver.
- Causa: `Dockerfile.scriban` hace `mvn` sin credenciales.
- El BOM solo existe en el `~/.m2` del host; el contenedor no lo ve.
- Es defecto de plantilla: `pom.scriban:28` importa el BOM en todo proyecto emitido.
- CodeArtifact no existe: `aws codeartifact list-domains` devuelve vacío.

## 2. Objetivo

- Publicar `common` en CodeArtifact.
- Que el build de todo ms generado resuelva el BOM.
- Ningún token persistido en imagen ni en Secrets Manager.

## 3. Estado actual vs. nuevo

```text
ACTUAL:
general/
  common/                    Maven multi-módulo, versión 1.0.0
  platform/                  buildspecs + scripts, SIN terraform
  generator/

NUEVO:
general/
  library/
    common/                  movido
    platform/                movido
      terraform/             NUEVO: domain epc + repo common
        provider.tf
        variables.tf
        codeartifact.tf
        outputs.tf
        terraform.example.tfvars
      scripts/
        publish-common.ps1   NUEVO: apply + mvn deploy
  generator/                 sin mover
```

## 4. Referencias web

- Ninguna externa. Todo sale del repo y de `get-authorization-token`.

## 5. Tareas de implementación

### Tarea 0 - Mover a `library/`

- `git mv common library/common`
- `git mv platform library/platform`
- Actualizar rutas en:
  - `library/common/renovate.json:6`
  - `library/platform/README.md:64`
  - scripts de `library/platform/scripts/`
- `.gitignore` de raíz ya cubre `.terraform/` y `*.tfstate`.

### Tarea 1 - Terraform de CodeArtifact

- `provider.tf`: `region = var.region`.
- `variables.tf`: solo `region` y `domain_name`.
  - Repo `common` fijo: lo referencian `settings.xml:25` y `pom.xml:52`.
- `codeartifact.tf`:
  - `aws_codeartifact_domain.epc`
  - `aws_codeartifact_repository.common` (format `maven`, upstream a Central)
  - Sin CMK (ADR-0022).
- `outputs.tf`: `codeartifact_endpoint` en formato maven.
- `terraform.example.tfvars`: región y dominio. `.gitignore` excluye `*.tfvars`.

### Tarea 2 - Script de publicación (lo ejecuta el usuario)

- `library/platform/scripts/publish-common.ps1`:
  1. `terraform -chdir=library/platform/terraform init`
  2. `terraform -chdir=library/platform/terraform apply -auto-approve`
  3. leer `codeartifact_endpoint`
  4. `aws codeartifact get-authorization-token --domain epc`
  5. `mvn -f library/common/pom.xml deploy -Depc.codeartifact.url="$endpoint"`
  6. `aws codeartifact list-packages` para confirmar
- Token se pide en el momento. No se persiste.
- `common-parent` fuera del deploy (`maven.deploy.skip`, ADR-0020).
- Actualizar `README.md` de scripts con el comando y qué verifica.

### Tarea 3 - Templates del generador

- `Dockerfile.scriban`:
  - `RUN --mount=type=secret,id=CODEARTIFACT_AUTH_TOKEN`
  - El `settings.xml` se genera en el mismo `RUN`.
  - No persiste en ninguna capa.
- `up.ps1.scriban:142`:
  - añadir `--secret id=CODEARTIFACT_AUTH_TOKEN,env=CODEARTIFACT_AUTH_TOKEN`
- `up.ps1.scriban`:
  - pedir token con `get-authorization-token` antes del build.
- `component.json`:
  - registrar `.dockerignore` si la plantilla lo introduce.
  - Regla dura: plantilla no listada no se genera.

### Tarea 4 - Verificar

- `dotnet run` (regenera) + `pwsh up.ps1`: el paso 2/5 pasa.
- `docker history quizapi`: sin token en ARG ni en capas.

### Tarea 5 - Documentar

- `DECISIONS/0022`: actualizar línea 24.
  - Token emitido con `get-authorization-token`, no persistido.
  - Línea 37: sin secreto para build local.
  - Los dos roles IAM siguen vivos para CodeBuild.
- `DECISIONS`: ADR nuevo del secreto único por app.
  - Solo runtime: `jwt-secret`, `api-key`, `subscription-*`, `ai-api-key`.
  - Sin mencionar CodeArtifact.

## 6. Flujo de datos

- Credenciales AWS del usuario -> `get-authorization-token` -> variable de entorno.
- Variable de entorno -> `docker build --secret` -> `settings.xml` efímero.
- `settings.xml` -> Maven resuelve `common-bom` en el builder.
- Token de app -> Terraform crea el contenedor vacío -> `cloud/up.ps1` lo siembra.

## 7. Archivos a crear

| Archivo | Propósito |
|---------|-----------|
| `library/platform/terraform/codeartifact.tf` | domain + repo maven |
| `library/platform/terraform/provider.tf` | provider aws |
| `library/platform/terraform/variables.tf` | `region`, `domain_name` |
| `library/platform/terraform/outputs.tf` | endpoint maven |
| `library/platform/terraform/terraform.example.tfvars` | valores de ejemplo |
| `library/platform/scripts/publish-common.ps1` | apply + deploy + verify |

## 8. Archivos a modificar

| Archivo | Cambio |
|---------|--------|
| `generator/.../templates/Dockerfile.scriban` | `RUN --mount=type=secret` |
| `generator/.../templates/up.ps1.scriban` | `--secret` + token |
| `generator/.../templates/component.json` | registrar `.dockerignore` |
| `library/common/renovate.json` | rutas |
| `library/platform/README.md` | rutas y comando |
| `.opencode/docs/adr/0022-...md` | token efímero |
| `.opencode/docs/adr/README.md` | índice del ADR nuevo |

## 9. Preguntas y recomendaciones

- ¿Mover el plan a `PLANS`? → Sí: el mapa exige `plans/plan-*.md`.
- ¿Dónde va `publish-common.ps1`, en `library/platform/scripts/`?
  → Sí: junto a los otros scripts de plataforma.
- ¿Falta símbolo en `workspace-map.md`?
  → No: `DECISIONS`, `PLANS` y `TASKS` ya existen.

## 10. Decisiones tomadas

1. Carpeta `library/` agrupa `common/` y `platform/`.
   - Motivo: nombra el propósito; separa lo transversal del generador.
2. Terraform en `library/platform/terraform/`.
   - Motivo: transversal. No en `projects/`: está en `.gitignore` y se regenera.
3. Sin secreto en Secrets Manager.
   - Motivo: el token dura 12 h; persistirlo es guardar algo expirado.
4. Sin roles IAM en esta fase.
   - Motivo: el token sale de las credenciales del usuario.
5. Sin CMK en el repositorio.
   - Motivo: decisión de coste ya tomada (ADR-0022).
6. Sin orquestador de Terraform.
   - Motivo: se añade cuando exista CodeBuild, que es cuando aparecen los dos.

## 11. Costos

- CodeArtifact: de pago. Bajo el techo de 2 USD/mes con 1 ms. No es cero.
- Esfuerzo: 6 tareas, 1 sesión.
- Impacto: 7 archivos nuevos, 7 modificados.

## 12. Fuera de alcance

- IAM y CodeBuild del pipeline de `common`.
- Bucket S3 de buildspecs y referencia por ARN.
- Renovate programado y trigger por tag.
- `Dockerfile-graalvm.scriban` (no está en `component.json`).
- Migrar más de un microservicio a `common`.