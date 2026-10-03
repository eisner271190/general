# ADRs — Architecture Decision Records

Un archivo por decisión. Convención: `NNNN-slug.md`, donde `NNNN` es el ID secuencial y va primero para que el listado salga en orden cronológico y las referencias por ID (`ADR-NNNN`) aguanten aunque cambie el slug.

- **Plantilla:** `TEMPLATES/adr.md` (`ADR_TEMPLATE`)
- **Registrar una decisión relevante:** en `AGENTS.md`
- **Símbolos de rutas:** `workspace-map.md`

## Estados

| Estado | Significado |
|--------|-------------|
| `Propuesta` | Redactada, pendiente de decisión del usuario |
| `Aceptada` | En vigor |
| `Rechazada` | Se estudió y no se adoptó |
| `Obsoleta` | Sustituida por otra; ver `Sustituida por` |

## Índice

| ID | Fecha | Decisión | Estado |
|----|-------|----------|--------|
| [ADR-0001](0001-terraform-en-cloud.md) | 2026-09-21 | Terraform vive en `cloud/terraform/<microservicio>/` | Aceptada |
| [ADR-0002](0002-flujo-trabajar.md) | 2026-09-23 | Flujo "Trabajar" con `todo.md`, branch y PR | Obsoleta → ADR-0015 |
| [ADR-0003](0003-criterio-tarea-grande.md) | 2026-09-23 | Criterio de "tarea grande" | Aceptada |
| [ADR-0004](0004-estructura-del-agent-workspace.md) | 2026-09-23 | Estructura del agent workspace | Aceptada |
| [ADR-0005](0005-sobrescritura-de-salida.md) | 2026-09-24 | El generador sobrescribe la salida sin comprobación previa | Aceptada |
| [ADR-0006](0006-estructura-por-capas-del-generador.md) | 2026-09-25 | Estructura por capas del generador | Aceptada |
| [ADR-0007](0007-auto-approve-por-defecto.md) | 2026-09-27 | `up.ps1` y `down.ps1` con auto-approve por defecto | Aceptada |
| [ADR-0008](0008-postman-baseurl-tras-apply.md) | 2026-09-27 | `cloud/up.ps1` rellena el `baseUrl` de Postman | Aceptada |
| [ADR-0009](0009-cmd-lambda-clase-cualificada.md) | 2026-09-27 | El `CMD` del `Dockerfile` usa la clase cualificada | Aceptada |
| [ADR-0010](0010-un-secreto-por-aplicacion.md) | 2026-09-28 | Un único secreto por aplicación en Secrets Manager | Aceptada |
| [ADR-0011](0011-ciclo-de-vida-de-secretos.md) | 2026-09-28 | Ciclo de vida de secretos y `up.ps1 -Fast` | Aceptada |
| [ADR-0012](0012-spring-cloud-aws-en-perfil-cloud.md) | 2026-09-28 | T06 — `spring-cloud-aws` 3.3.1 en el perfil `cloud` | Aceptada |
| [ADR-0013](0013-endpoint-publico-de-parametros.md) | 2026-09-29 | Endpoint público de parámetros, catch-all y actuator reducido | Aceptada |
| [ADR-0014](0014-workspace-map-como-fuente-unica.md) | 2026-10-01 | `workspace-map.md` como fuente única de rutas | Aceptada |
| [ADR-0015](0015-flujo-de-trabajo-con-roles.md) | 2026-10-01 | Flujo de trabajo con roles y entregables | Aceptada |
| [ADR-0016](0016-common-buildspec-s3-webflux-sin-dart.md) | 2026-10-02 | `common`: buildspec en S3, `common-web` WebFlux, sin Dart | Aceptada |
| [ADR-0017](0017-objetivo-002-v2.md) | 2026-10-02 | Objetivo 002 (`common`), v2 tras `plan-review-002` | Obsoleta → ADR-0018 |
| [ADR-0018](0018-azure-devops-eliminado.md) | 2026-10-03 | Azure DevOps eliminado; ms en CodeCommit | Aceptada |
| [ADR-0019](0019-generador-no-emite-el-codigo-de-common.md) | 2026-10-03 | El generador deja de emitir el código de `common` | Aceptada |
| [ADR-0020](0020-common-parent-no-se-publica.md) | 2026-10-03 | `common-parent` no se publica en CodeArtifact | Aceptada |
| [ADR-0021](0021-precedencia-maven-common-bom.md) | 2026-10-03 | Precedencia Maven: una entrada explícita gana a un `import` | Aceptada |
| [ADR-0022](0022-iam-codeartifact-dos-roles.md) | 2026-10-03 | IAM de CodeArtifact en dos roles y token por variable de entorno | Aceptada |

## Cadena de sustitución

```
ADR-0002 (flujo "Trabajar", todo.md)
   └─> ADR-0015 (flujo con roles, objetivos/objetivo-NNN.md)

ADR-0012 (actuator en health,info,prometheus)
   └─> ADR-0013 (actuator reducido a health + catch-all)

ADR-0016 (common v1)
   └─> ADR-0017 (common v2)
          └─> ADR-0018 (Azure DevOps eliminado)
```

## Relación con las dudas

Las dudas (`QUESTIONS_OPEN`) se resuelven con una respuesta, no con un ADR. Pero **cuando la respuesta es una decisión con consecuencias, esa decisión se registra aquí como ADR** y la duda se referencia por `Origen:`. No dupliques el texto: el ADR es la fuente, la duda es el hilo donde se discutió.
