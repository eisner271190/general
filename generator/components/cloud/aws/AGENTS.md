# Plantillas cloud — Terraform AWS

## Qué es aquí
Plantillas Scriban → `<proyecto>/cloud/terraform/<microservicio>/*.tf` y módulos en `cloud/terraform/modules/{secrets-manager,pipeline}`. Registrado en `component.json` (solo la lista `files` se copia).

## Layout generado (no cambiar sin plan)
- Por microservicio: `provider.tf`, `variables.tf`, `apigateway.tf`, `apigateway_lambda.tf`, `ecr.tf`, `sqs.tf`, `sns.tf`, `sns_subscription.tf`, `cognito.tf`, `cognito_iam.tf`, `cognito_client.tf`, `cognito_google_provider.tf`, `lambda.tf`.
- Sin `{{MICROSERVICE_NAME }}` en nombres de archivo: la subcarpeta ya identifica el servicio.
- Módulos reutilizables en `modules/`.

## Convenciones y verificación
- Cargar el skill `terraform`: fmt/validate/lint, estilo, variables/outputs, módulos, seguridad.
- `terraform plan` solo con autorización; `apply`/`destroy` DENEGADOS.

## Reglas
- Las plantillas `terraform-*` duplicadas en el componente backend NO están registradas: modificar y registrar SOLO aquí.
- Agregar/renombrar plantilla → actualizar `component.json` en el mismo cambio; verificar placeholders `{{ ... }}` tras editar.
