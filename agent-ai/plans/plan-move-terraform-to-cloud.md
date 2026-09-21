# Plan: Mover proyecto Terraform a la carpeta `cloud`, fuera de `backend`

**Tarea del TODO:** Cloud #2

**Fecha:** 2026-09-21

---

## 1. Descripción

El generador produce archivos Terraform dentro de la carpeta del microservicio backend:
```
{{MICROSERVICE_NAME}}/deploy/terraform/*.tf
```

El objetivo es que Terraform viva en `cloud/terraform/` a nivel de proyecto, separado del código de la aplicación. Cada microservicio tendrá su propia subcarpeta.

---

## 2. Objetivo

Modificar el generador para que los archivos Terraform se generen en:
```
cloud/terraform/{{MICROSERVICE_NAME}}/*.tf
```

---

## 3. Estado Actual vs. Nuevo

**Actual:**
```
backend/quizapi/deploy/terraform/provider.tf
backend/quizapi/deploy/terraform/variables.tf
backend/quizapi/deploy/terraform/ecr_quizapi.tf
...
```

**Nuevo:**
```
cloud/terraform/quizapi/provider.tf
cloud/terraform/quizapi/variables.tf
cloud/terraform/quizapi/ecr_quizapi.tf
...
```

---

## 4. Tareas de Implementación

### Tarea 1: Modificar `component.json`

**Archivo:** `generator/components/backend/spring-boot-3.5.16/component.json`

#### 1.1 Directorios — Eliminar y reemplazar

Eliminar:
```json
"{{MICROSERVICE_NAME}}/deploy",
"{{MICROSERVICE_NAME}}/deploy/terraform"
```

Agregar:
```json
"cloud",
"cloud/terraform",
"cloud/terraform/{{MICROSERVICE_NAME}}"
```

#### 1.2 Archivos — Actualizar keys

Cambiar cada key de `{{MICROSERVICE_NAME}}/deploy/terraform/...` a `cloud/terraform/{{MICROSERVICE_NAME}}/...`:

| Key actual | Key nuevo |
|---|---|
| `{{MICROSERVICE_NAME}}/deploy/terraform/variables.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/variables.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/provider.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/provider.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/apigateway.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/apigateway.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/apigateway_lambda_{{MICROSERVICE_NAME}}.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/apigateway_lambda.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/ecr_{{MICROSERVICE_NAME}}.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/ecr.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/sqs_{{MICROSERVICE_NAME}}.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/sqs.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/sns.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/sns.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/sns_subscription_{{MICROSERVICE_NAME}}.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/sns_subscription.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/cognito.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/cognito.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/cognito_iam.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/cognito_iam.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/cognito_client.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/cognito_client.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/cognito_google_provider.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/cognito_google_provider.tf` |
| `{{MICROSERVICE_NAME}}/deploy/terraform/lambda_{{MICROSERVICE_NAME}}.tf` | `cloud/terraform/{{MICROSERVICE_NAME}}/lambda.tf` |

> **Nota:** Se elimina `{{MICROSERVICE_NAME}}` de los nombres de archivo ya que la subcarpeta ya lo identifica.

### Tarea 2: Verificar templates scriban

| # | Subtarea | Detalle |
|---|---|---|
| 2.1 | Revisar 14 templates `terraform-*.scriban` | Verificar que no contengan rutas hardcodeadas a `deploy/terraform` |
| 2.2 | Verificar dependencias | Confirmar que los templates no referencian rutas que cambien |

### Tarea 3: Verificación

| # | Subtarea | Detalle |
|---|---|---|
| 3.1 | Buscar referencias residuales | Buscar `deploy/terraform` en todo `generator/` |
| 3.2 | Regenerar proyecto de prueba | Ejecutar el generador y confirmar que los archivos salen en `cloud/terraform/<microservice>/` |

---

## 5. Flujo de Datos

```
Generator (component.json)
    │
    □ Resuelve {{MICROSERVICE_NAME}} = quizapi
    □ Resuelve rutas: cloud/terraform/quizapi/*.tf
    │
    ▼
┌─────────────────────────────────────────────┐
│  Escribe archivos en:                       │
│  <project>/cloud/terraform/quizapi/         │
│  - provider.tf                              │
│  - variables.tf                             │
│  - ecr.tf, lambda.tf, cognito.tf, etc.      │
└─────────────────────────────────────────────┘
```

---

## 6. Archivos a Modificar

| Archivo | Cambio Requerido |
|---|---|
| `generator/components/backend/spring-boot-3.5.16/component.json` | Actualizar directorios y keys de archivos Terraform |

---

## 7. Decisiones Tomadas

1. **`{{MICROSERVICE_NAME}}` en subcarpetas:** Cada microservicio tiene su propia carpeta en `cloud/terraform/<microservice>/`.
2. **Sin `{{MICROSERVICE_NAME}}` en nombres de archivo:** Se elimina del nombre del archivo porque la subcarpeta ya lo identifica (ej: `ecr.tf` en lugar de `ecr_quizapi.tf`).
3. **Default files:** No aplica. Default files es para archivos cuyo contenido no varía por ambiente y no tiene placeholders.
