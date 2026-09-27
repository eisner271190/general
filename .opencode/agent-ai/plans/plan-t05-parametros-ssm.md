# Plan: T05 — Agregar los parámetros a AWS Parameter Store

**Tarea del TODO:** `.opencode/agent-ai/docs/todo.md` → MVP `T05 — Agregar los parametros a AWS parameter store`
**Fecha:** 2026-09-27

## 1. Descripción
La declaración de los parámetros **ya existe** (`ssm.tf` con `for_each`), pero **no están desplegados**: la cuenta AWS no tiene ni un parámetro y el `terraform.tfstate` local está vacío (`resources: []`). Tarea: completar el mapa de parámetros no sensibles, desplegarlos y verificarlos.

## 2. Objetivo
- Parámetros no sensibles de cada microservicio viviendo en Parameter Store bajo `/{entorno}/{applicationId}/{microservicio}/`.
- Fuente de verdad única (configuración de la aplicación) y valores verificables con AWS CLI.
- `backend/quizapi/up.ps1` (fase Run) sigue funcionando con `get-parameters-by-path`.

## 3. Estado actual vs. nuevo
```text
cloud/terraform/quizapi/ssm.tf:3-13   resource aws_ssm_parameter.environment
                                       for_each = var.environment_variables
                                       name = "/develop/com.quizsmart.app/quizapi/${each.key}"
                                       type = "String"          # ya existente
cloud/terraform/quizapi/terraform.develop.tfvars:5
                                       8 claves: API_URL, APPLICATION_ID, APPLICATION_NAME,
                                       APPLICATION_PACKAGE, DATABASE_HOST, DATABASE_NAME,
                                       DEBUG, ENVIRONMENT
---
AWS real: 0 parámetros (aws ssm get-parameters-by-path → vacío)
Estado:   resources: []   (serial 310)
Nuevo:    8 + JWT_EXPIRATION desplegados y verificados en la cuenta correcta
```

## 4. Referencias web
| Referencia | Aporte |
|---|---|
| https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store.html | Límites y tipos (String/SecureString/StringList), gratuidad del nivel Standard. |
| https://docs.spring.io/spring-cloud-config/reference/server/environment-repository/aws-parameter-store-backend.html | Convención de rutas y mapeo de nombres a propiedades (aplica a T06). |
| `generator/.../templates/terraform-ssm.scriban` | Plantilla existente: placeholders `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/{{ MICROSERVICE_NAME }}`. |
| `.opencode/agent-ai/plans/plan-reduce-secret-calls.md` | Regla ya adoptada: probar siempre env vars/archivo local antes que llamar a AWS. |

## 5. Tareas de implementación
### T5.1 Revisar y ampliar el mapa de parámetros (fuente de verdad)
En `generator/target/com.quizsmart.app/com.quizsmart.app.json` → `environments[].variables` (de ahí sale `ENVIRONMENT_VARIABLES_HCL` y el tfvars):
- **Añadir** los no sensibles referenciados por `application-properties.scriban`: `JWT_EXPIRATION`.
- **Mantener** `DATABASE_HOST`, `DATABASE_NAME`, `API_URL`, `DEBUG`, `APPLICATION_NAME`, `APPLICATION_ID`, `APPLICATION_PACKAGE`, `ENVIRONMENT`.
- **No añadir**: `JWT_SECRET` (→ T04), `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (→ rol IAM), `AWS_SQS_URL_*`/`AWS_SNS_TOPIC_ARN` (derivados de infra, ver §9.4).

### T5.2 Desplegar
```powershell
./cloud/up.ps1 -Phase Apply        # init → plan → apply (requiere autorización)
```
Estado vacío ⇒ el apply crea todo el stack (ECR, API GW, Lambda, SNS/SQS, Cognito, SSM).

### T5.3 Verificación (evidencia obligatoria)
```powershell
aws ssm get-parameters-by-path --path /develop/com.quizsmart.app/quizapi/ --recursive --query 'Parameters[].{Name:Name,Value:Value}' --output table
aws ssm get-parameter --name /develop/com.quizsmart.app/quizapi/DATABASE_HOST
```
Esperado: 9 parámetros `String` con valores del tfvars.

### T5.4 Comprobación del consumidor local
```powershell
./backend/quizapi/up.ps1 -Phase Run   # ya ejecuta get-parameters-by-path y docker run -e
```
Debe listar los parámetros y arrancar el contenedor sin errores.

### T5.5 Ajuste de documentación
Actualizar la ayuda de `cloud/up.ps1` (parámetro `Phase`) para indicar que el apply crea también los parámetros; añadir en `README` de cloud la verificación de T5.3.

## 6. Flujo de datos
1. `environments[].variables` (config de la app) → `ENVIRONMENT_VARIABLES_HCL` (generador) → `terraform.develop.tfvars`.
2. `terraform apply` → `aws_ssm_parameter` → **Parameter Store** (`/develop/com.quizsmart.app/quizapi/*`).
3. `backend/quizapi/up.ps1 -Phase Run` → `get-parameters-by-path` → `docker run -e CLAVE=valor` (local).
4. `lambda.tf:53-55` sigue inyectando el mismo mapa como env vars (sin cambios en este plan).
5. T06 añadirá la lectura directa desde el microservicio.

## 7. Archivos a crear
| Archivo | Propósito |
|---|---|
| — | Ninguno (la infra ya está declarada). |

## 8. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `generator/target/com.quizsmart.app/com.quizsmart.app.json` | Añadir `JWT_EXPIRATION` a `environments[].variables`. |
| `generator/components/cloud/aws/templates/up.ps1.scriban` | Ayuda + log de verificación de parámetros tras el apply. |
| `projects/com.quizsmart.app/...` (salidas: tfvars, up.ps1) | Sincronizar tras regenerar o a mano (están en `.gitignore`). |

## 9. Preguntas y recomendaciones
1. **¿Cuenta/perfil AWS correcto?** Hoy `default` → `577638384397` y está vacío; existen 12 perfiles `ban-xrs-iam-cloudops-pragma-001-*`. → *Recomendación:* confirmar **antes** de ejecutar el apply (§5.2 crea infra real con coste).
2. **¿`type = "String"` o `"SecureString"`?** → *Recomendación:* **String** mientras los valores sean no sensibles; cualquier valor sensible va a Secrets Manager (T04), no a SSM como String.
3. **¿Mantener los valores en tfvars (git)?** → *Recomendación:* sí mientras sean no sensibles (patrón actual, marcado "Generado por EPC — no editar"); si algún valor se vuelve sensible, moverlo a T04.
4. **¿Parámetros derivados de infra (`AWS_SQS_URL_*`, `AWS_SNS_TOPIC_ARN`)?** → *Recomendación:* **fase 2**: hoy se inyectan como env vars de la Lambda; meterlos en SSM exige recursos `aws_ssm_parameter` con valores de salida (ciclo de vida distinto) y no es necesario para el MVP.
5. **¿Destruir lo que se cree si la cuenta no es la correcta?** → *Recomendación:* aplicar solo tras confirmar la cuenta; si se creó en una cuenta equivocada, `./cloud/down.ps1` (nunca `destroy` manual con recursos ajenos).

## 10. Decisiones tomadas
1. SSM queda como fuente de parámetros **no sensibles**; Secret Manager (T04) para los sensibles.
2. El tfvars sigue siendo generado desde la configuración de la aplicación (no se edita a mano).

## 11. Costos
- **Infra:** Parameter Store Standard es **gratis** hasta 10.000 parámetros/10.000 llamadas API (límite diario de la capa gratuita). **0 USD** para 9 parámetros.
  - *Ojo:* aplicar el plan crea el stack completo (ECR ~0,10 USD/GB-mes, API GW ~1 USD/millón de llamadas, Lambda/Cognito dentro del nivel gratuito) — desmontable con `./cloud/down.ps1`.
- **Esfuerzo:** 3-4 archivos, **1 sesión**.
- **Contexto/tokens:** bajo.

## 12. Fuera de alcance
- Que el microservicio lea los parámetros por su cuenta → **T06**.
- Parámetros derivados de infraestructura (§9.4).
- Rotación/versionado de parámetros (`Tier Advanced`, `AWSCURRENT`).
