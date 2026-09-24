---
name: Terraform Clean
description: Buenas prácticas Terraform/AWS al escribir o revisar HCL, módulos y pipelines (fmt, validate, seguridad, estructura)
---

## Verificación obligatoria
1. `terraform fmt -check` 2. `terraform validate` 3. `tflint` 4. `checkov`/`trivy` si están instalados.
5. `terraform plan` solo con autorización. `apply`/`destroy` DENEGADOS para el agente.

## Estructura
- Un directorio de Terraform por servicio + módulos reutilizables en `modules/`.
- Un recurso principal por archivo, coherente con el nombre (`ecr.tf` → recurso ECR); sin placeholders en nombres de archivo.
- Las plantillas Terraform se registran SOLO en el componente cloud.

## Módulos y variables
- `variables.tf` con `type` + `description` siempre; `outputs` explícitos; snake_case.
- Inputs con `validation` blocks; sin valores de entorno hardcodeados; módulos externos con versión `~>`.
- Estado remoto por backend/variables; nunca state en git.

## Seguridad
- Sin secrets en HCL: módulo dedicado de secretos o inyección del pipeline.
- IAM mínimo necesario; `tags` consistentes (Name, Environment, Project).

## Plantillas
- Los placeholders `{{ ... }}` deben resolverse al generar; verificar tras editar cualquier plantilla.
- Actualizar el registro del componente al agregar/renombrar plantillas.

## Referencias
- developer.hashicorp.com/terraform/style · github.com/antonbabenko/terraform-skill
