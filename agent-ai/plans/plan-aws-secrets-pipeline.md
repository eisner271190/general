# Plan: AWS Secrets Manager + CodeBuild/CodePipeline/CodeCommit con Terraform

**Tareas del TODO:**
- DevSecOps #3: Crear AWS secret manager con terraform
- DevSecOps #4: Crear CodeBuild, CodePipeline y CodeCommit con terraform

**Fecha:** 2026-09-21

---

## 1. Descripción (Web Research)

### AWS Secrets Manager con Terraform
- **Recurso principal:** `aws_secretsmanager_secret` (contenedor) + `aws_secretsmanager_secret_version` (valor).
- **Cifrado:** Por defecto usa KMS managed `aws/secretsmanager`. Para compliance, usar KMS customer-managed key.
- **Rotación:** `aws_secretsmanager_secret_rotation` con Lambda rotation (útil para RDS, pero no requerido aún).
- **Políticas:** `aws_secretsmanager_secret_policy` para acceso cross-account o restricciones VPC.
- **State file:** El valor del secret se almacena en texto plano en `tfstate`. Usar backend S3 con encryption o write-only attributes (`secret_string_wo`) si Terraform >= 1.10.
- **Convención de nombres:** `{ambiente}/{servicio}/{tipo-secret}`, ej: `dev/myapp/database-credentials`.

### CodeBuild + CodePipeline + CodeCommit con Terraform
- **CodeCommit:** Repositorio Git gestionado por AWS. Creado con `aws_codecommit_repository`.
- **CodeBuild:** Proyectos de build con `aws_codebuild_project`. Cada stage del pipeline tiene su propio proyecto.
- **CodePipeline:** Orquestador con `aws_codepipeline`. Stages típicos: Source → Plan → Approval → Apply.
- **Artefactos:** S3 bucket para almacenar artefactos entre stages, cifrado con KMS.
- **IAM:** Rol para CodePipeline con permisos mínimos (CodeCommit, CodeBuild, S3, KMS).
- **Buildspec:** Archivos YAML que definen comandos para cada stage (init, validate, fmt, plan, apply).

---

## 2. Objetivo

Crear módulos Terraform reutilizables para:
1. **Secrets Manager:** Gestión centralizada de secretos por ambiente/servicio con cifrado KMS y políticas de acceso.
2. **Pipeline CI/CD:** Pipeline completo con CodeCommit, CodeBuild (plan + apply) y CodePipeline para desplegar infraestructura Terraform de forma automatizada.

---

## 3. Estado Actual

| Componente | Estado |
|---|---|
| Terraform | Proyecto existe en `backend/` (según TODO #2 se debe mover a `cloud/`) |
| CodeCommit | Creado manualmente al generar proyectos (TODO #2 DEVSECOPS = DONE) |
| Secrets Manager | No existe infraestructura Terraform |
| Pipeline CI/CD | Pipeline para .aab firmado existe (DONE), pero no hay pipeline genérico para Terraform |

---

## 4. Tareas de Implementación

### Tarea 1: Módulo Secrets Manager (`cloud/modules/secrets-manager/`)

| # | Subtarea | Detalle |
|---|---|---|
| 1.1 | Crear `variables.tf` | `environment`, `project_name`, `secrets` (mapa de secretos a crear), `kms_key_arn` (opcional) |
| 1.2 | Crear `main.tf` | Recurso `aws_secretsmanager_secret` con naming convention `{env}/{project}/{name}` |
| 1.3 | Crear `outputs.tf` | ARN del secret, nombre, versión |
| 1.4 | Crear `versions.tf` | `required_providers` y `required_version` de Terraform |
| 1.5 | Ejemplo de uso | `cloud/examples/secrets-manager/main.tf` mostrando cómo invocar el módulo |

### Tarea 2: Módulo Pipeline CI/CD (`cloud/modules/pipeline/`)

| # | Subtarea | Detalle |
|---|---|---|
| 2.1 | Crear `variables.tf` | `project_name`, `environment`, `repo_name`, `branch`, `build_projects`, `tf_version` |
| 2.2 | Crear CodeCommit | `aws_codecommit_repository` (opcional, crear o usar existente) |
| 2.3 | Crear S3 artifacts bucket | `aws_s3_bucket` + cifrado + lifecycle |
| 2.4 | Crear KMS key | Para cifrado de artefactos del pipeline |
| 2.5 | Crear IAM roles | Rol CodePipeline (Source, CodeBuild, S3) + Rol CodeBuild (Terraform, S3, CloudWatch) |
| 2.6 | Crear CodeBuild projects | Proyecto para `plan` y proyecto para `apply` |
| 2.7 | Crear CodePipeline | Stages: Source → Plan → Approval → Apply |
| 2.8 | Crear buildspecs | `buildspec-plan.yml` y `buildspec-apply.yml` |
| 2.9 | Crear `outputs.tf` | ARNs de CodePipeline, CodeBuild, CodeCommit, S3, KMS |
| 2.10 | Ejemplo de uso | `cloud/examples/pipeline/main.tf` |

### Tarea 3: Integración y Pruebas

| # | Subtarea | Detalle |
|---|---|---|
| 3.1 | Verificar `terraform validate` | Ambos módulos deben pasar validación |
| 3.2 | Documentar uso | Actualizar README con comandos de uso |

---

## 5. Flujo de Datos

```
Desarrollador
    │
    ▼
┌─────────────────────────────────────────────┐
│  terraform apply (módulo secrets-manager)   │
│  → Crea secrets en AWS Secrets Manager      │
│  → Los valores se inyectan vía CI/CD o CLI  │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  terraform apply (módulo pipeline)          │
│  → Crea CodeCommit repo                     │
│  → Crea S3 bucket para artefactos           │
│  → Crea KMS key para cifrado                │
│  → Crea IAM roles (CodePipeline + CodeBuild)│
│  → Crea CodeBuild projects (plan + apply)   │
│  → Crea CodePipeline con stages             │
│  → Buildspec files se suben al repo         │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  Push a CodeCommit → CodePipeline se dispara│
│  Source → Plan → Approval → Apply           │
│  CodeBuild ejecuta: init, validate, plan,   │
│  apply                                     │
└─────────────────────────────────────────────┘
```

---

## 6. Archivos a Crear

| Archivo | Propósito |
|---|---|
| `cloud/modules/secrets-manager/variables.tf` | Variables del módulo de secrets |
| `cloud/modules/secrets-manager/main.tf` | Lógica de creación de secrets |
| `cloud/modules/secrets-manager/outputs.tf` | Outputs del módulo |
| `cloud/modules/secrets-manager/versions.tf` | Versiones de proveedor |
| `cloud/modules/pipeline/variables.tf` | Variables del módulo de pipeline |
| `cloud/modules/pipeline/main.tf` | CodeCommit + S3 + KMS + IAM + CodeBuild + CodePipeline |
| `cloud/modules/pipeline/outputs.tf` | Outputs del módulo |
| `cloud/modules/pipeline/versions.tf` | Versiones de proveedor |
| `cloud/modules/pipeline/buildspec-plan.yml` | Buildspec para stage de plan |
| `cloud/modules/pipeline/buildspec-apply.yml` | Buildspec para stage de apply |
| `cloud/examples/secrets-manager/main.tf` | Ejemplo de uso del módulo secrets |
| `cloud/examples/pipeline/main.tf` | Ejemplo de uso del módulo pipeline |

---

## 7. Archivos a Modificar

| Archivo | Cambio Requerido |
|---|---|
| `cloud/README.md` | Documentar módulos creados (si existe) |

---

## 8. Preguntas / Dudas

1. **¿Estado Terraform actual?** El TODO dice mover Terraform de `backend/` a `cloud/`. ¿Ya se hizo este movimiento? ¿Los módulos van dentro de `cloud/modules/` o en otra ubicación?

2. **¿Secretos a gestionar?** ¿Qué secretos específicos necesita la app? (ej: database credentials, API keys, tokens de terceros). ¿Se crean como placeholders o con valores reales?

3. **¿Pipeline genérico o específico?** ¿El pipeline debe servir para cualquier proyecto Terraform del workspace, o está diseñado para un proyecto específico?

4. **¿Ambientes?** ¿Se necesita soporte multi-ambiente (dev/staging/prod) con variables separadas, o solo un ambiente por ahora?

5. **¿Estado remoto?** ¿Ya hay un S3 bucket configurado para el backend de Terraform, o también se debe crear?

6. **¿CodeCommit existente?** El TODO #2 dice que CodeCommit ya se crea al generar proyectos. ¿Se debe usar el repositorio existente o crear uno nuevo desde el módulo?

7. **¿Rotación de secretos?** ¿Se necesita configurar rotación automática (Lambda) o solo almacenamiento por ahora?
