# Arquitectura OBJ-005

- Objetivo: `OBJ-005: Reemplazar AWS Secrets Manager por SSM Parameter Store SecureString`
- Agente: `Architect (redactado por el coordinador; subagente no disponible por cuota)`
- Fecha: `2026-10-11 03:18:04` (UTC-5)
- Estado: `completo`
- Resumen: `Cierra Q23, Q47, Q53, D41 y D42 con datos verificados (ADR, component.json,
  precios AWS).`
- Bloqueos: `ninguno. Los subagentes fallaron por cuota; no afecta al contenido.`

## Contexto

- Secrets Manager (0,40 USD/secreto/mes) pasa a SSM Parameter Store SecureString Standard.
- El keystore `.jks` sale del JSON (4 KB) y pasa a S3 por entorno.

## Decisiones

### Q23: renombrar las plantillas Terraform

- El contenido deja de ser Secrets Manager; el nombre actual contradice (regla Q23).
- Coherente con Q20: el módulo pasa a `secure-parameters`.
- Nombres nuevos:
  - `terraform-secrets-manager.scriban` → `terraform-ssm-parameter.scriban`.
  - `terraform-secrets-manager-variables.scriban` → `terraform-ssm-parameter-variables.scriban`.
- Registros en `component.json` que cambian (verificados):
  - L10: `cloud/terraform/modules/secrets-manager` → `.../modules/secure-parameters`.
  - L37: `.../modules/secrets-manager/main.tf` → `.../modules/secure-parameters/main.tf`.
  - L38: `.../modules/secrets-manager/variables.tf` → `.../modules/secure-parameters/variables.tf`.
  - L35 sin cambios: `cloud/terraform/app/secrets.tf` ← `terraform-secrets.scriban`.
- Regla del componente: plantilla no registrada no se genera; actualizar en el mismo cambio.

### Q47: coste verificado con precios vigentes

- Secrets Manager: 0,40 USD/secreto/mes + 0,05 USD/10.000 llamadas API.
  Fuente: página oficial de precios de Secrets Manager.
- Parameter Store Standard: sin coste adicional.
  Fuente: página oficial de precios de Systems Manager.
- S3 del keystore: almacenamiento y peticiones de orden 0,005 USD/mes por app.
  Fuente: estimación propia; depende de volumen y región, a revisar si escala.
- Resultado: 0,40 USD/mes → ~0,005 USD/mes por app. Ahorro ~99 %.
- El JSON sin keystore (≈ 210 bytes) no habilita el tier Advanced (4 KB).

### Q53: ADR nuevo

- Número: `0027` (libre; existen 0010, 0012, 0016, 0018, 0020, 0022, 0024, 0025, 0026).
- Título: `SSM Parameter Store SecureString en lugar de Secrets Manager`.
- Sustituye a `ADR-0010`; actualiza `ADR-0012` y `ADR-0022`.
- Corrige la cita rota a `ADR-0023` en `ADR-0022` (Q7, Q8).

### D41 y D42: borrado del bucket sin conflicto de estado

- Requisito de AWS: `terraform destroy` falla si el bucket tiene objetos o versiones.
- Orden efectivo (refina Q90):
  1. Purga por CLI: borrar todas las versiones y el objeto actual
     (`delete-objects` con `VersionId`, más `delete` sin versión).
  2. `terraform destroy` del bucket: el recurso sale del estado, sin desincronización.
  3. CLI final idempotente para restos (sin efecto si el bucket ya no existe).
- Scripts afectados: cloud `down.ps1.scriban` (Q89) y
  `.opencode/scripts/delete-all-services-aws.ps1` (Q91, todos los entornos).
- El nombre del bucket se deriva de `environment` + `project_name` (Q93).

## Consecuencias

- Positivas: coste ~0; sin Secrets Manager; keystore fuera del límite de 4 KB.
- Negativas: `down.ps1` borra el keystore sin copia (Q63, Q65, Q79, Q86).
- Riesgo: si Terraform y CLI discrepan, el estado queda inconsistente; la purga va primero.

## Preguntas nuevas

- Ninguna. Todo lo consultado tenía respuesta verificable.

## Entregables

- Informe: `docs/deliverables/obj-005/architect.md`.
- Decisiones registradas en `questions.md`: Q23, Q47, Q53, D41, D42.