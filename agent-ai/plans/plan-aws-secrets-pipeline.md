# Plan: AWS Secrets Manager + CodeBuild/CodePipeline/CodeCommit con Terraform

**Tareas del TODO:**
- DevSecOps #3: Crear AWS secret manager con terraform
- DevSecOps #4: Crear CodeBuild, CodePipeline y CodeCommit con terraform

**Fecha:** 2026-09-21 (actualizado)

---

## 1. Contexto: Estado Actual del Proyecto

### Estructura del generador (post-refactor)
```
generator/
  components/
    cloud/
      aws/
        component.json          ← Define type: "cloud", provider: "aws"
        templates/
          terraform-provider.scriban
          terraform-variables.scriban
          terraform-apigateway.scriban
          terraform-lambda.scriban
          terraform-ecr.scriban
          terraform-sqs.scriban
          terraform-sns.scriban
          ... (14 templates actuales)
        defaults/               ← (vacío, no se usa para Terraform)
```

### Salida generada
```
projects/<app>/
  cloud/
    terraform/
      <MICROSERVICE_NAME>/
        provider.tf
        variables.tf
        apigateway.tf
        lambda.tf
        ecr.tf
        sqs.tf
        sns.tf
        ...
```

### Decisiones tomadas
- `cloud` es un componente con `type: "cloud"`, `provider: "aws"` en `component.json`
- `GenerationPlanBuilder` es genérico: `ProcessComponent()` maneja backend, frontend y cloud
- `outputPrefix = null` para cloud (los archivos van directo a `cloud/terraform/...`)
- CodeCommit/CodePipeline comentados temporalmente en `GeneratorApplication.cs`
- `{{MICROSERVICE_NAME}}` identifica el servicio en subcarpetas (no en filenames)
- Templates Scriban para todo contenido Terraform (incluso estático)

---

## 2. Descripción (Web Research)

### AWS Secrets Manager con Terraform
- **Recurso principal:** `aws_secretsmanager_secret` (contenedor) + `aws_secretsmanager_secret_version` (valor).
- **Cifrado:** Por defecto usa KMS managed `aws/secretsmanager`. Para compliance, usar KMS customer-managed key.
- **State file:** El valor del secret se almacena en texto plano en `tfstate`. Usar backend S3 con encryption o write-only attributes (`secret_string_wo`) si Terraform >= 1.10.
- **Convención de nombres:** `{ambiente}/{servicio}/{tipo-secret}`, ej: `dev/quizapi/database-credentials`.

### CodeBuild + CodePipeline + CodeCommit con Terraform
- **CodeCommit:** Repositorio Git gestionado por AWS. Creado con `aws_codecommit_repository`.
- **CodeBuild:** Proyectos de build con `aws_codebuild_project`. Cada stage del pipeline tiene su propio proyecto.
- **CodePipeline:** Orquestador con `aws_codepipeline`. Stages típicos: Source → Plan → Approval → Apply.
- **Artefactos:** S3 bucket para almacenar artefactos entre stages, cifrado con KMS.
- **IAM:** Rol para CodePipeline con permisos mínimos (CodeCommit, CodeBuild, S3, KMS).
- **Buildspec:** Archivos YAML que definen comandos para cada stage.

---

## 3. Objetivo

Crear módulos Terraform reutilizables como templates Scriban dentro del componente `cloud/aws`:
1. **Secrets Manager:** Gestión centralizada de secretos por ambiente/servicio con cifrado KMS y políticas de acceso.
2. **Pipeline CI/CD:** Pipeline completo con CodeCommit, CodeBuild (plan + apply) y CodePipeline para desplegar infraestructura Terraform de forma automatizada.

---

## 4. Arquitectura de Archivos

### Estructura propuesta en el componente
```
generator/components/cloud/aws/
  component.json                    ← Agregar nuevos templates
  templates/
    terraform-provider.scriban      ← (existente)
    terraform-variables.scriban     ← (existente)
    ... (14 existentes)
    terraform-secrets-manager.scriban          ← NUEVO
    terraform-secrets-manager-variables.scriban ← NUEVO
    terraform-pipeline.scriban                 ← NUEVO
    terraform-pipeline-variables.scriban       ← NUEVO
    terraform-pipeline-buildspec-plan.scriban  ← NUEVO
    terraform-pipeline-buildspec-apply.scriban ← NUEVO
```

### Estructura de salida generada
```
projects/<app>/cloud/terraform/
  <MICROSERVICE_NAME>/
    provider.tf                     ← (existente)
    variables.tf                    ← (existente)
    ... (recursos actuales)
    secrets-manager.tf              ← NUEVO
    secrets-manager-variables.tf    ← NUEVO
    pipeline.tf                     ← NUEVO
    pipeline-variables.tf           ← NUEVO
    buildspec-plan.yml              ← NUEVO
    buildspec-apply.yml             ← NUEVO
```

---

## 5. Tareas de Implementación

### Tarea 1: Secrets Manager (`terraform-secrets-manager.scriban`)

| # | Subtarea | Detalle |
|---|---|---|
| 1.1 | Crear `terraform-secrets-manager-variables.scriban` | Variables: `environment`, `project_name`, `secrets` (mapa), `kms_key_arn` (opcional) |
| 1.2 | Crear `terraform-secrets-manager.scriban` | Recurso `aws_secretsmanager_secret` con naming `{env}/{project}/{name}` + `aws_secretsmanager_secret_version` |
| 1.3 | Actualizar `component.json` | Agregar entradas en `files` para ambos templates |

### Tarea 2: Pipeline CI/CD (`terraform-pipeline.scriban`)

| # | Subtarea | Detalle |
|---|---|---|
| 2.1 | Crear `terraform-pipeline-variables.scriban` | Variables: `project_name`, `environment`, `repo_name`, `branch`, `tf_version` |
| 2.2 | Crear `terraform-pipeline.scriban` | CodeCommit + S3 bucket + KMS key + IAM roles + CodeBuild (plan + apply) + CodePipeline |
| 2.3 | Crear `terraform-pipeline-buildspec-plan.scriban` | Buildspec para stage de plan (init, validate, fmt, plan) |
| 2.4 | Crear `terraform-pipeline-buildspec-apply.scriban` | Buildspec para stage de apply (init, apply) |
| 2.5 | Actualizar `component.json` | Agregar entradas en `files` para los 4 templates |

### Tarea 3: Integración

| # | Subtarea | Detalle |
|---|---|---|
| 3.1 | Verificar generación | Ejecutar generator y validar que los archivos se generan correctamente |
| 3.2 | Verificar `terraform validate` | Los archivos generados deben pasar validación de Terraform |

---

## 6. Diseño de los Módulos

### Secrets Manager
```hcl
# Se genera por cada microservicio que necesite secretos
resource "aws_secretsmanager_secret" "app_secrets" {
  for_each = var.secrets
  name     = "${var.environment}/${var.project_name}/${each.key}"
  kms_key_id = var.kms_key_arn
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  for_each      = var.secrets
  secret_id     = aws_secretsmanager_secret.app_secrets[each.key].id
  secret_string = each.value
}
```

### Pipeline CI/CD
```hcl
# CodeCommit
resource "aws_codecommit_repository" "repo" {
  repository_name = var.repo_name
  description     = "Repository for ${var.project_name}"
}

# S3 artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-${var.environment}"
}

# KMS
resource "aws_kms_key" "pipeline" {
  description = "KMS key for ${var.project_name} pipeline"
}

# IAM roles (CodePipeline + CodeBuild)
# CodeBuild projects (plan + apply)
# CodePipeline (Source → Plan → Approval → Apply)
```

---

## 7. Variables de Configuración

### En `com.quizsmart.app.json` (o por defecto)
```json
{
  "cloud": {
    "provider": "aws",
    "secrets": {
      "database/credentials": "${DB_PASSWORD}",
      "api/jwt-secret": "${JWT_SECRET}"
    },
    "pipeline": {
      "repo_name": "quizsmart-infra",
      "branch": "main",
      "tf_version": "1.5.0"
    }
  }
}
```

### En `EpcConfiguration.cs` (modelos)
```csharp
public sealed record CloudConfiguration(
    string Provider,
    string? Name = null,
    Dictionary<string, string>? Secrets = null,   // NUEVO
    PipelineConfiguration? Pipeline = null         // NUEVO
);

public sealed record PipelineConfiguration(
    string? RepoName = null,
    string? Branch = null,
    string? TfVersion = null
);
```

---

## 8. Preguntas / Decisiones Pendientes

| # | Pregunta | Recomendación |
|---|---|---|
| 1 | ¿Secretos hardcoded o por variable? | Usar variables de entorno como `${JWT_SECRET}`, el template las referencia |
| 2 | ¿Pipeline genérico o por microservicio? | **Genérico** — un solo pipeline para todo el proyecto Terraform |
| 3 | ¿CodeCommit nuevo o existente? | Crear nuevo via Terraform (el comentado en GeneratorApplication era para frontend) |
| 4 | ¿S3 backend para Terraform state? | Incluir recurso `aws_s3_bucket` para state en el módulo pipeline |
| 5 | ¿Multi-ambiente? | Soporte via variable `environment` (dev/staging/prod) |

---

## 9. Flujo de Datos

```
generator ejecuta
    │
    ▼
ProcessComponent("cloud", "aws", ...)
    │
    ▼
Lee component.json → procesa templates Scriban
    │
    ▼
Genera en projects/<app>/cloud/terraform/<service>/
    ├── provider.tf              (existente)
    ├── variables.tf             (existente)
    ├── secrets-manager.tf       (NUEVO)
    ├── pipeline.tf              (NUEVO)
    ├── buildspec-plan.yml       (NUEVO)
    └── buildspec-apply.yml      (NUEVO)
    │
    ▼
Desarrollador ejecuta:
    cd projects/<app>/cloud/terraform/<service>
    terraform init
    terraform apply
    │
    ▼
AWS crea:
    ├── Secrets Manager (secretos por servicio)
    ├── CodeCommit (repo Git)
    ├── CodeBuild (proyectos plan + apply)
    ├── CodePipeline (Source → Plan → Approval → Apply)
    ├── S3 bucket (artefactos)
    └── KMS key (cifrado)
```

---

## 10. Archivos a Crear/Modificar

| Archivo | Acción | Propósito |
|---|---|---|
| `generator/components/cloud/aws/templates/terraform-secrets-manager.scriban` | CREAR | Lógica de secrets manager |
| `generator/components/cloud/aws/templates/terraform-secrets-manager-variables.scriban` | CREAR | Variables del módulo secrets |
| `generator/components/cloud/aws/templates/terraform-pipeline.scriban` | CREAR | CodeCommit + S3 + KMS + IAM + CodeBuild + CodePipeline |
| `generator/components/cloud/aws/templates/terraform-pipeline-variables.scriban` | CREAR | Variables del módulo pipeline |
| `generator/components/cloud/aws/templates/terraform-pipeline-buildspec-plan.scriban` | CREAR | Buildspec para plan |
| `generator/components/cloud/aws/templates/terraform-pipeline-buildspec-apply.scriban` | CREAR | Buildspec para apply |
| `generator/components/cloud/aws/component.json` | MODIFICAR | Agregar 6 nuevas entradas en `files` |
| `generator/Models/EpcConfiguration.cs` | MODIFICAR | Agregar `Secrets` y `Pipeline` a `CloudConfiguration` |

---

## 11. Orden de Ejecución

1. Modificar `EpcConfiguration.cs` — agregar modelos `Secrets` y `Pipeline`
2. Crear templates Scriban (6 archivos)
3. Actualizar `component.json` — registrar nuevos templates
4. Ejecutar generator — verificar salida
5. Validar con `terraform validate`
