# knowledge/architecture

Decisiones estructurales del workspace: capas del generador (.NET), arquitectura hexagonal en Spring, clean architecture + provider en Flutter, layout `cloud/terraform/<ms>/` con módulos reutilizables.

## Flujo de despliegue (backend Lambda)

1. **`up.ps1 -Fast` (raíz del proyecto generado)** — infraestructura (Terraform), build y push de la imagen Docker a ECR, y despliegue local. **No refresca la imagen `:latest` de la Lambda si solo cambió código**: Terraform no detecta cambio porque `image_uri` sigue igual.
2. **`backend/update-all.ps1`** (o `backend/<ms>/update-ms.ps1` por microservicio) — actualiza la Lambda sin `terraform apply`: ejecuta `aws lambda update-function-code` (refresco de la imagen `:latest`), `wait function-updated` y opcionalmente `publish-version`. Parámetros: `-Tag`, `-Environment`, `-Region`, `-PublishVersion`, `-SkipBuild`, `-WhatIf`, `-Exclude`, `-Parallel`.

**Regla:** tras cambiar código del backend y desplegar con `up.ps1 -Fast`, ejecutar `backend/update-all.ps1` para que la Lambda use la imagen nueva. Sin ese paso, la Lambda sigue sirviendo la imagen anterior (se verán los logs viejos). No hace falta hacer `update-function-code` manual.

También disponible: `backend/<ms>/update-ms.ps1` para un solo microservicio.

Referencia registrada en `.opencode/opencode.json` (alias `architecture`). Aquí van diagramas y ADRs extensos; decisiones puntuales → `.opencode/docs/decisions.md`.
