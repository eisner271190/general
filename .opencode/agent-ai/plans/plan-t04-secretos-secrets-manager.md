# Plan: T04 — Agregar los secretos a AWS Secrets Manager

**Tarea del TODO:** `.opencode/agent-ai/docs/todo.md` → MVP `T04 — Agregar los secretos a AWS secret manager`
**Fecha:** 2026-09-27 · **Revisión:** secreto **por aplicación** (uno solo), no por microservicio.

## 1. Descripción
El módulo Terraform de Secrets Manager existe pero **nadie lo instancia** y en la cuenta AWS **no hay ningún secreto de la aplicación** (solo el de firma Android, creado por el CI). Tarea: crear **un único secreto por aplicación**, con nombre `{{environment}}/{{applicationId}}`, y sembrar su valor en AWS.

## 2. Objetivo
- 1 secreto por aplicación: **`develop/com.quizsmart.app`**, creado por Terraform y gestionado por su propio estado.
- Valor sembrado en AWS: ni en el repositorio, ni en tfvars, ni en el estado de Terraform.
- Política IAM de la Lambda con `secretsmanager:GetSecretValue` para que T06 pueda leerlo.

## 3. Estado actual vs. nuevo
```text
cloud/terraform/
├── modules/secrets-manager/main.tf      # huérfano: 0 bloques `module "` en todo cloud/terraform
│                                        #   name = "${environment}/${project_name}/${each.key}"
│                                        #   + aws_secretsmanager_secret_version (valor en el estado)
├── quizapi/                             # NO tiene secrets.tf; estado propio por microservicio
└── (no existe directorio de aplicación)
---
cloud/terraform/
├── modules/secrets-manager/main.tf      # 1 secreto: name = "${var.environment}/${var.project_name}"
│                                        #   sin for_each y sin secret_version (valor fuera de TF)
├── app/                                 # NUEVO directorio (estado propio de la aplicación)
│   ├── provider.tf      (plantilla existente terraform-provider.scriban)
│   ├── variables.tf     (plantilla existente terraform-variables.scriban)
│   ├── terraform.{{ENVIRONMENT}}.tfvars (plantilla existente terraform-tfvars.scriban)
│   └── secrets.tf       (NUEVA plantilla terraform-secrets.scriban → module "secrets")
└── quizapi/lambda.tf                    # + permiso secretsmanager:GetSecretValue
```
AWS real hoy (perfil `default`, cuenta 577638384397, us-east-1): `aws secretsmanager list-secrets` → vacío; `terraform.tfstate` local → `resources: []`.

> Nota: `cloud/up.ps1:207-213` y `down.ps1` recorren **todos** los directorios de `cloud/terraform/` salvo `modules`, por lo que `app/` se aplica y destruye automáticamente con los scripts existentes.

## 4. Referencias web
| Referencia | Aporte |
|---|---|
| https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html | No secretos en código/estado; caché en cliente; monitorizar accesos. |
| https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secrets-java-sdk.html | `SecretsManagerClient` + caché (`SecretCache`) — aplica a T06. |
| https://github.com/awspring/spring-cloud-aws | Starters y compatibilidad (3.3.x → Boot 3.4.x) — aplica a T06. |
| `.opencode/agent-ai/plans/plan-reduce-secret-calls.md` | Patrón ya usado: 1 solo secreto JSON consolidado (4→1 en signing). |
| `.opencode/agent-ai/plans/plan-pipeline-only-signing.md` | D1: el generador NO llama a AWS; la siembra es responsabilidad de scripts/CLI. |
| `docs/done.md:49` | "Crear AWS secret manager con terraform" ya estaba contemplado. |

## 5. Tareas de implementación
### Fase 1 — Infraestructura (feature `feature/t04-secretos-infra`)
1. **T4.1 Modificar `terraform-secrets-manager.scriban`**: el módulo pasa a definir **un secreto por instancia**:
   ```hcl
   resource "aws_secretsmanager_secret" "app_secrets" {
     name        = "${var.environment}/${var.project_name}"   # develop/com.quizsmart.app
     description = "Secrets de la aplicación ${var.project_name}"
     kms_key_id  = var.kms_key_arn

     tags = {
       Environment = var.environment
       Project     = var.project_name
       ManagedBy   = "terraform"
     }
   }
   ```
   Quitar `for_each`, `aws_secretsmanager_secret_version` y `variable "secrets"` (el valor nunca entra en el estado).
2. **T4.2 Modificar `terraform-secrets-manager-variables.scriban`**: mantener `environment`, `project_name`, `kms_key_arn`; eliminar `secrets`.
3. **T4.3 Crear `terraform-secrets.scriban`** → destino `cloud/terraform/app/secrets.tf`:
   ```hcl
   module "secrets" {
     source       = "../modules/secrets-manager"
     environment  = var.environment
     project_name = "{{ APPLICATION_ID }}"
     kms_key_arn  = null
   }
   ```
4. **T4.4 Registrar en `components/cloud/aws/component.json`** (regla: plantilla no listada ⇒ no se genera):
   - `directories`: añadir `cloud/terraform/app`.
   - `files`: `cloud/terraform/app/secrets.tf` → `terraform-secrets.scriban`; `cloud/terraform/app/provider.tf`, `.../variables.tf`, `.../terraform.{{ENVIRONMENT}}.tfvars` → plantillas ya existentes (`terraform-provider`, `terraform-variables`, `terraform-tfvars`). El tfvars es obligatorio: `up.ps1:226,234` siempre pasa `-var-file terraform.<env>.tfvars`.
5. **T4.5 IAM Lambda**: en `terraform-lambda.scriban` (política de `quizapi/lambda.tf:18-40`) añadir `secretsmanager:GetSecretValue` sobre `arn:aws:secretsmanager:*:*:secret:{{ ENVIRONMENT }}/{{ APPLICATION_ID }}-*`.
6. **T4.6 Generar la salida**: `dotnet run --project Generator.csproj` (requiere autorización) o replicar a mano en `projects/com.quizsmart.app/cloud/terraform/` (está en `.gitignore`).

### Fase 2 — Siembra del valor (feature `feature/t04-secretos-siembra`)
7. **T4.7 Comando de siembra** (documentar en la ayuda del `cloud/up.ps1` o en el README de cloud):
   ```powershell
   $jwt = openssl rand -base64 48
   aws secretsmanager put-secret-value --secret-id develop/com.quizsmart.app --secret-string ('{"JWT_SECRET":"{0}"}' -f $jwt)
   ```
   - Valor **no versionado** en ningún sitio (regla del `AGENTS.md` raíz).
   - Alternativa descartada: `TF_VAR_secrets` → dejaría el valor en el estado local.
8. **T4.8 Verificación**:
   ```powershell
   terraform -chdir=cloud/terraform/app fmt -check
   terraform -chdir=cloud/terraform/app validate          # fmt/validate: autorización
   aws secretsmanager list-secrets --query 'SecretList[].Name'      # → develop/com.quizsmart.app
   aws secretsmanager get-secret-value --secret-id develop/com.quizsmart.app --query SecretString
   ```

## 6. Flujo de datos
1. Desarrollador/operador genera el valor (`openssl rand`) → `put-secret-value` → **Secrets Manager** (`develop/com.quizsmart.app`).
2. `cloud/up.ps1 -Phase Apply` → directorio `app/` → módulo → crea el **contenedor** del secreto (sin valor).
3. T06: cada microservicio lee el secreto de **la aplicación** y usa las claves que necesita (`JWT_SECRET`, …).
4. CI (ya existente): sigue leyendo `/epc/com.quizsmart.app/android-signing` — sin cambios.

## 7. Archivos a crear
| Archivo | Propósito |
|---|---|
| `generator/components/cloud/aws/templates/terraform-secrets.scriban` | `cloud/terraform/app/secrets.tf`: instancia el módulo de secretos de la aplicación. |

## 8. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `.../templates/terraform-secrets-manager.scriban` | 1 secreto `${environment}/${project_name}`; quitar `for_each` y `secret_version`. |
| `.../templates/terraform-secrets-manager-variables.scriban` | Quitar `variable "secrets"`. |
| `.../cloud/aws/component.json` | `directories` + 4 entradas `files` para `cloud/terraform/app/`. |
| `.../templates/terraform-lambda.scriban` | IAM: `secretsmanager:GetSecretValue` sobre el secreto de la app. |
| `projects/com.quizsmart.app/...` (salida) | Sincronizar los mismos cambios (`.gitignore`, no es fuente de verdad). |

## 9. Preguntas y recomendaciones
1. **¿La cuenta de trabajo es la `577638384397` (perfil `default`)?** Hoy todo vacío y hay 12 perfiles `ban-xrs-iam-cloudops-pragma-001-*`. → *Recomendación:* confirmar **antes** de aplicar.
2. **Granularidad confirmada:** **1 secreto por aplicación** `{{environment}}/{{applicationId}}` (decisión tomada). → *Consecuencia:* la lectura de T06 es `aws-secretsmanager:/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}` y **cada ms sólo usa las claves que necesita**; SSM sigue siendo por microservicio.
3. **¿Dónde vive el estado del secreto?** → *Recomendación:* **directorio nuevo `cloud/terraform/app/`** con estado propio. Meterlo en `quizapi/` obligaría a instanciarlo una sola vez y fallaría con 2 microservicios (`SecretExistsException`).
4. **¿Dejar `aws_secretsmanager_secret_version` (valor en Terraform)?** → *Recomendación:* **no**: fuera del estado y del repo.
5. **¿Cifrado con KMS propio?** → *Recomendación:* por ahora `null` (clave gestionada `aws/secretsmanager`); CMK sólo si hay requisito de custodia/rotación.
6. **Destrucción:** `./cloud/down.ps1` borrará el secreto con ventana de recuperación (30 días por defecto en el proveedor) → re-aplicar dentro de esa ventana da `SecretsManagerException`; si ocurre, purgar la recuperación con `aws secretsmanager delete-secret --force-delete-without-recovery`. → *Recomendación:* documentarlo en la ayuda de `down.ps1`.

## 10. Decisiones tomadas
1. **Un secreto por aplicación**, nombre `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}` (misma filosofía que `/epc/{applicationId}/android-signing`).
2. Terraform sólo crea el **contenedor**; el valor se siembra por CLI (D1 de `plan-pipeline-only-signing.md`).
3. Estado del secreto en `cloud/terraform/app/` (layout nuevo, justificado en este plan).

## 11. Costos
- **Infra:** 1 secreto ≈ **0,40 USD/mes** (Secrets Manager) + 0,04 USD/10.000 llamadas.
- **Esfuerzo:** 5-6 ficheros, 2 capas (cloud + IAM) → 2 features/PRs, **2 sesiones**.
- **Contexto/tokens:** bajo-medio.

## 12. Fuera de alcance
- Rotación automática (Lambda de rotación) y replicación multi-región.
- Que el backend los lea → **T06** (ajusta su `spring.config.import` al secreto de aplicación).
- Credenciales AWS (`AWS_ACCESS_KEY_ID/SECRET`): rol IAM, nunca en secretos.
- Secreto de firma Android (`/epc/com.quizsmart.app/android-signing`): ya operativo en el CI.
- Parámetros no sensibles → **T05**.
