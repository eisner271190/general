# Estado

Handover entre sesiones. Se reescribe al cerrar cada fase del flujo.

- Actualizado: 2026-10-05 00:05
- Objetivo en curso: **002** (`objectives/objetivo-002.md`)
- Rama: `objetivo-002-common`

## Fase actual del flujo

**Documentación y decisiones** — cerrada.

| Fase | Estado |
|------|--------|
| Definición del objetivo | Cerrada (`objetivo-002.md`) |
| Arquitectura | Cerrada (`architecture-002.md`, v3) |
| Plan review | Cerrada (`plan-review-002.md`) |
| Investigación | Cerrada (`research-002.md`) |
| Implementación | Cerrada (`implementation-002.md`, Trabajo 4) |
| Pruebas | Cerrada (`test-report-002.md`) |
| **Documentación y decisiones** | **Cerrada** (ADR-0022 revisada, ADR-0024 y ADR-0025 nuevas) |
| Despliegue AWS | **Pendiente del usuario** |

## Entregables del objetivo 002

Todos en `deliverables/objetivo-002/`:

- `research-002.md` — investigación y mediciones previas
- `plan-review-002.md` — revisión del plan con `grill-me`
- `architecture-002.md` — arquitectura v3 (v2 conservada como historial)
- `implementation-002.md` — implementación, con los 4 trabajos y sus evidencias
- `test-report-002.md` — reporte de pruebas

## Decisiones en vigor

| ADR | Decisión | Estado |
|-----|----------|--------|
| ADR-0016 | `common`: buildspec en S3, `common-web` WebFlux, sin Dart | Aceptada |
| ADR-0018 | Azure DevOps eliminado; CI solo CodePipeline + CodeBuild, ms en CodeCommit | Aceptada — su reparto de dependencias queda sustituido por ADR-0024 y ADR-0025 |
| ADR-0019 | El generador deja de emitir el código de `common` | Aceptada |
| ADR-0020 | `common-parent` no se publica en CodeArtifact | Aceptada |
| ADR-0022 | IAM de CodeArtifact por rol, token bajo demanda, **cero secretos de plataforma** | Aceptada (revisada 2026-10-04) |
| ADR-0023 | Un único secreto JSON por aplicación, decidido por coste | Aceptada |
| ADR-0024 | Dos repos de plataforma, `common` y `platform`, con un pipeline cada uno | Aceptada |
| ADR-0025 | Renovate retirado; el BOM se actualiza a mano y el trigger por tag hace un único PR | Aceptada |

Índice y cadena de sustituciones: `docs/adr/README.md`.

## Pendientes

### Del agente

- Ninguno. No hay código ni documentación que falte en este objetivo.

### Del usuario

| # | Qué | Comando |
|---|-----|---------|
| 1 | Desplegar la plataforma: bucket `epc-buildspecs`, repos CodeCommit `common` y `platform`, ECR `epc/common-base`, roles IAM, pipeline de `common` y trigger del BOM. **25 recursos por crear.** | `cd library/platform` → copiar `terraform.example.tfvars` a `terraform.tfvars`, ajustar `environment` → `pwsh scripts/up.ps1 -AutoApprove` |
| 2 | Publicar los 3 buildspecs en la raíz del bucket | `pwsh scripts/publish-buildspecs.ps1 -Region us-east-1` |
| 3 | Publicar `common` 1.0.0 en CodeArtifact | `pwsh scripts/publish-common.ps1` |
| 4 | Conectar los remotos de `common` y `platform` en git | No hay script para esto; es el único paso manual que queda |
| 5 | Verificar en AWS | `aws s3 ls s3://epc-buildspecs/`, `aws codecommit list-repositories`, `aws codebuild start-build --project-name platform-bump-bom --region us-east-1` |
| 6 | Limpiar y regenerar la salida del generador, y ejecutar la suite del piloto | El agente no ejecuta tests |

Nada que sembrar: **cero secretos de plataforma** (ADR-0022).

Detalle de los pendientes 1-3: `deliverables/objetivo-002/implementation-002.md` §Trabajo 4
§Tareas del usuario.

## Notas

- El criterio 6 (actualizar el BOM automáticamente y propagar PRs por microservicio) queda
  **fuera de alcance** por ADR-0025. Su equivalente vigente es el criterio reescrito del objetivo:
  un único PR por release en el repositorio de la aplicación.
- `tasks.md` mantiene el detalle fila a fila. Las notas de alcance de ese fichero quedaron
  actualizadas con la retirada de Renovate.
- No hay commit ni push hecho. No se ha tocado ningún test ni ninguna colección de Postman.