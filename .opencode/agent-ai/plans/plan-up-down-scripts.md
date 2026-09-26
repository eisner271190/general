# Plan: Scripts `up.ps1` / `down.ps1` para levantar la aplicación completa

**Tarea del TODO:** N/A — solicitado directamente (vincula a **T01** Frontend compilando, **T03** Backend con infra AWS)
**Fecha:** 2026-09-25

---

## 1. Descripción

Hoy no existe una forma única de levantar la aplicación generada. Cada componente debe ejecutarse a mano con comandos sueltos, y `cloud/terraform` **ni siquiera es ejecutable** (no hay `.tfvars` y las 12 variables no tienen `default` → `terraform plan` aborta).

Se quiere un `up.ps1` en la raíz de `projects/{applicationID}/` que levante todo, más un `up.ps1` por componente (backend, frontend, cloud), y su contraparte `down.ps1`.

Como `projects/` es **salida generada** (está en `.gitignore`), los scripts deben salir de **plantillas Scriban** en `generator/components/`, nunca escribirse a mano.

---

## 2. Objetivo

1. `projects/{appId}/up.ps1` levanta la app completa en orden `cloud → backend → frontend`.
2. Cada componente tiene su `up.ps1` / `down.ps1` ejecutable de forma aislada.
3. `cloud` es ejecutable de verdad: `.tfvars` generados, variables tipadas con `default`.
4. Los secretos salen de **Parameter Store**, no de archivos en disco.
5. Los scripts **fallan en el primer error** (el referente `ejecutar-tarea.ps1` no lo hace).

---

## 3. Estado actual vs. nuevo

### Actual

```text
projects/com.quizsmart.app/
├── cloud/terraform/
│   ├── modules/{pipeline,secrets-manager}/     ← sin instanciar
│   └── quizapi/                                ← 13 .tf, SIN .tfvars
│       ├── variables.tf      ← 12 vars SIN type/description/default
│       └── ...
├── frontend/{FRONTEND_NAME}/   ← sin script de build
└── {MICROSERVICE_NAME}/        ← sin script de build
# 0 scripts .ps1
```

### Nuevo

```text
projects/com.quizsmart.app/
├── up.ps1                        ← orquestador raíz   [NUEVO]
├── down.ps1                      ← paro en orden inv. [NUEVO]
├── cloud/
│   ├── up.ps1                    ← init/plan/apply    [NUEVO]
│   ├── down.ps1                  ← destroy            [NUEVO]
│   └── terraform/quizapi/
│       ├── variables.tf          ← tipadas + defaults [MODIFICA]
│       ├── local.tfvars          ← generado           [NUEVO]
│       └── qa.tfvars             ← generado           [NUEVO]
├── frontend/
│   ├── up.ps1                    ← flutter ...        [NUEVO]
│   └── down.ps1                                        [NUEVO]
└── {MICROSERVICE_NAME}/
    ├── up.ps1                    ← docker build/push  [NUEVO]
    └── down.ps1                  ← docker stop/rm     [NUEVO]
```

### Mecánica del generador (verificada)

```csharp
// generator/Application/GenerationPlanBuilder.cs
83:  foreach (var microservice in context.Configuration.Microservices)  // backend  → N veces
117: AddFrontendComponent(context)                                      // frontend → 1 vez
171: foreach (var microservice in context.Configuration.Microservices)  // cloud    → N veces
```

**Consecuencia:** el `up.ps1` **raíz** no puede vivir en backend ni cloud → se escribiría N veces (colisión). Requiere un componente nuevo.

---

## 4. Referencias web

| Referencia | Aporte |
|---|---|
| [flutter_launcher_icons — pub.dev](https://pub.dev/packages/flutter_launcher_icons) | Orden canónico: `flutter pub get` → `flutter pub run flutter_launcher_icons`. La dependencia debe estar ya en `dev_dependencies`. |
| [dart pub add](https://dart.dev/tools/pub/cmd/pub-add) | `dart pub add --dev` modifica `pubspec.yaml` **y** resuelve → debe ir **antes** de ejecutar el paquete. |
| [about_Error_Handling — Microsoft](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_error_handling) | `$LASTEXITCODE` es lo que detecta fallos de `terraform`/`flutter`/`docker` (comandos nativos). |
| [about_Preference_Variables — Microsoft](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables) | `$ErrorActionPreference = 'Stop'` no cubre comandos nativos; se necesita `$PSNativeCommandUseErrorActionPreference` o chequeo explícito. |
| [dev.ps1 — ejemplo real](https://github.com/JuneQQQ/polynoia/blob/main/dev.ps1) | Estructura de un `up.ps1`: `$ErrorActionPreference = "Stop"`, `$PSScriptRoot`, `Start-Job` + `finally { Stop-Job }`. |
| [Handling Errors the PowerShell Way](https://devblogs.microsoft.com/scripting/handling-errors-the-powershell-way) | `$ErrorActionPreference = 'Stop'` convierte errores no terminantes en terminantes. |
| [`aws_ssm_parameter`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | Recurso para publicar los outputs. |
| [terraform-aws-ssm-parameter](https://github.com/terraform-aws-modules/terraform-aws-ssm-parameter) | `for_each` para publicar N parámetros desde un `locals`. |
| [HashiCorp Discuss — outputs a SSM](https://discuss.hashicorp.com/t/aws-parameter-store-parameters-instead-of-variables/2192) | Patrón `data "aws_ssm_parameter"` inverso. |

**Referente interno (solo lectura):** `D:\codigo\test\backend\infrastructure\terraform\` — 5 scripts. Ver §10.3.

---

## 5. Tareas de implementación

Se descomponen en **3 PRs** (skill `plan-workflow`: >5 archivos y 3 componentes = tarea grande).

### 5.0 Regla global — EPC Clean Code aplicado a PowerShell

**Los 13 scripts `.ps1` nuevos y sus plantillas Scriban deben cumplir `epc-clean-code`.**
Cargar el skill antes de escribir. Traducción de las reglas al lenguaje:

| Regla | EPC (original) | Aplicación en PowerShell |
|---|---|---|
| **R1** | métodos ≤ 20 líneas | funciones ≤ 20 líneas. `up.ps1` raíz y de componente son **orchestrators cortos**; la lógica va a funciones. |
| **R2** | extraer cada bloque `{}` a un método | extraer **cada `if`/`foreach`/`try`** a una función con nombre. Nada de anidar lógica en el flujo principal. |
| **R3** | una clase/interfaz por archivo | **una responsabilidad por script**; como máximo una `class`/`function` principal por fichero de plantilla. |
| **R4** | variantes → Strategy | las variantes `local`/`qa`/`prod` van en **handlers separados** (`Get-LocalSettings`, `Get-QaSettings`…) o un hashtable de estrategias; **no** un `if/else` gigante dentro del flujo. |
| **R5** | queries encapsulados en métodos | **toda** llamada externa (`aws`, `terraform`, `docker`, `flutter`) se encapsula en una función: `Get-SsmParameters`, `Invoke-TerraformApply`, `Publish-DockerImage`, `Invoke-FlutterBuild`. Nunca sueltas en el flujo principal. |
| **R6** | extraer condiciones complejas | condiciones con `2+` operadores lógicos → variable con nombre descriptivo o función `Test-Estado`. |
| **R7** | ≤ 2 parámetros | ≤ 2 parámetros posicionales. El resto, en un **objeto de opciones** o `CmdletBinding` con `[switch]`. |
| **R8** | no instanciar en el flujo principal | encapsular construcción en funciones dedicadas: `New-DockerRunArgs`, `New-TerraformArguments`. |
| **R9** | Facade | **el `up.ps1` raíz ES un Facade**: valida → delega en cada componente → reporta. No contiene lógica de negocio. |

**Ejemplo de la forma esperada** (T5, `cloud/up.ps1`):

```powershell
# ❌ Viola R1, R2 y R5: todo pegado, queries sueltas
foreach ($dir in (Get-ChildItem -Directory 'terraform')) {
    Push-Location $dir.FullName
    terraform init -input=false
    if ($AutoApprove) { terraform apply -auto-approve ... } else { terraform apply ... }
    Pop-Location
}

# ✅ Cumple: Facade corto + queries encapsuladas
function Invoke-TerraformApply { param($Dir, $Env, $AutoApprove) ... }   # R1, R5
function Test-AutoApproveFlag  { param($AutoApprove) ... }                # R6, R7

function Update-CloudStack {                                                # R9 Facade
    param($Environment, $AutoApprove)
    foreach ($dir in Get-TerraformDirectories) {                            # R2, R5
        Invoke-TerraformApply -Dir $dir -Env $Environment -AutoApprove:$AutoApprove
    }
}
```

**Verificación obligatoria al final de cada PR** (añadida a la §11):

- [ ] Ninguna función supera 20 líneas (R1)
- [ ] Sin `if`/`foreach` anidados en el flujo principal (R2)
- [ ] Sin llamadas crudas a `aws`/`terraform`/`docker` fuera de una función (R5)
- [ ] Sin condiciones con `2+` operadores lógicos sin nombre propio (R6)
- [ ] Ninguna función con más de 2 parámetros posicionales (R7)
- [ ] El `up.ps1` raíz solo delega, no ejecuta (R9)

---

### PR 1 — Cloud ejecutable (bloquea todo lo demás)

#### T1 — `terraform-variables.scriban`: tipar, defaults y quitar credenciales

**Archivo:** `generator/components/cloud/aws/templates/terraform-variables.scriban`

Reemplazar las 12 declaraciones vacías por:

```hcl
variable "region" {
  type        = string
  description = "Región AWS"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Ambiente: local | qa | prod"
  validation {
    condition     = contains(["local", "qa", "prod"], var.environment)
    error_message = "environment debe ser local, qa o prod."
  }
}

variable "endpoint_url" {
  type        = string
  description = "Vacío en AWS real; http://localhost:4566 en LocalStack"
  default     = ""
}

variable "skip_credentials_validation" { type = bool, default = false }
variable "skip_metadata_api_check"     { type = bool, default = false }

variable "image_uri_ecr" {
  type        = string
  description = "URI base del ECR con {SERVICENAME} como marcador"
}

variable "google_client_id"     { type = string, sensitive = true }
variable "google_client_secret" { type = string, sensitive = true }
```

**Se eliminan:** `access_key`, `secret_key`, `profile`, `environment_variables`.
**Por qué:** las credenciales pasan a la cadena estándar del proveedor AWS (resuelve el hallazgo de secretos en claro del "antes"); `profile` no se usaba.

#### T2 — `terraform-provider.scriban`: quitar credenciales

```hcl
provider "aws" {
  region                      = var.region
  skip_credentials_validation = var.skip_credentials_validation
  skip_metadata_api_check     = var.skip_metadata_api_check
  endpoints { /* sin cambios */ }
}
```

#### T3 — Plantilla nueva `terraform-tfvars.scriban`

**Archivo nuevo:** `generator/components/cloud/aws/templates/terraform-tfvars.scriban`

```hcl
environment                 = "{{ Environment }}"
region                      = "{{ Region }}"
image_uri_ecr               = "{{ ImageUriEcr }}"
endpoint_url                = "{{ EndpointUrl }}"
skip_credentials_validation = {{ SkipCredentialsValidation }}
skip_metadata_api_check     = {{ SkipMetadataApiCheck }}
google_client_id            = "{{ GoogleClientId }}"
google_client_secret        = "{{ GoogleClientSecret }}"
```

Las 4 variables `{{ EndpointUrl }}`, `{{ SkipCredentialsValidation }}`, `{{ SkipMetadataApiCheck }}`, `{{ ImageUriEcr }}` se computan según `Environment` (patrón copiado de `terraform-environment.ps1:20-26`):

| `Environment` | `endpoint_url` | `skip_*` | `image_uri_ecr` |
|---|---|---|---|
| `local` | `http://localhost:4566` | `true` | `{SERVICENAME}:latest` |
| `qa` / `prod` | `""` | `false` | `{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com/{SERVICENAME}:latest` |

> ⚠️ El cálculo se hace en **Scriban/C#** (dentro del generador), no en runtime — así el `.tfvars` sale listo.

#### T4 — Registrar en `component.json`

```json
{ "key": "cloud/terraform/{{MICROSERVICE_NAME}}/local.tfvars", "value": "templates/terraform-tfvars-local.scriban" },
{ "key": "cloud/terraform/{{MICROSERVICE_NAME}}/qa.tfvars",    "value": "templates/terraform-tfvars-qa.scriban" }
```

> **Decisión:** ¿1 plantilla parametrizada por `{{ Environment }}` (se renderiza N veces, sobrescribe) o 2 plantillas fijas `local`/`qa`?
> → *Recomendación:* **2 plantillas fijas** (`terraform-tfvars-local.scriban`, `terraform-tfvars-qa.scriban`). Evita el orden de renderizado y deja ambos archivos siempre presentes.

#### T5 — Plantilla `cloud/up.ps1.scriban`

```powershell
#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('local','qa','prod')][string]$Environment = 'qa',
    [switch]$AutoApprove
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Push-Location $PSScriptRoot
try {
    foreach ($dir in (Get-ChildItem -Directory 'terraform' | Sort-Object Name)) {
        Push-Location $dir.FullName
        try {
            terraform init -input=false
            terraform plan  -input=false -var-file="$Environment.tfvars" -out=tfplan
            if ($AutoApprove) { terraform apply -input=false -auto-approve tfplan }
            else              { terraform apply -input=false tfplan }
        } finally { Pop-Location }
    }
} finally { Pop-Location }
```

> **Nota de diseño:** itera `terraform/*/` en lugar de usar `{{MICROSERVICE_NAME}}` → el archivo es idéntico aunque el componente se renderice N veces (mismo truco que `modules/`), y sirve con 1 o N microservicios.

#### T6 — Plantilla `cloud/down.ps1.scriban`

Misma estructura, con `terraform destroy -var-file=$Environment.tfvars` y confirmación (`Read-Host`) salvo `-Force`.

**Archivos de este PR:** 5 nuevos + 2 modificados.

---

### PR 2 — Backend y frontend

#### T7 — `backend` `up.ps1` (1 por microservicio)

**Plantilla:** `generator/components/backend/spring-boot-3.5.16/templates/up.ps1.scriban`
**Key:** `"{{MICROSERVICE_NAME}}/up.ps1"` ← así no colisiona entre microservicios

```powershell
[CmdletBinding()]
param(
    [ValidateSet('local','qa','prod')][string]$Environment = 'qa',
    [string]$DeviceId,                 # no hardcodeado
    [switch]$SkipPush
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Push-Location $PSScriptRoot
try {
    # 1. leer parámetros de Parameter Store
    $prefix = "/{{ APPLICATION_ID }}/$Environment/shared"
    $params = aws ssm get-parameters-by-path --path $prefix --recursive --query 'Parameters[].{K:Name,V:Value}' --output json |
              ConvertFrom-Json
    $envVars = @{}
    foreach ($p in $params) { $envVars[($p.K -split '/')[-1]] = $p.V }

    # 2. build de la imagen
    docker buildx build --platform linux/amd64 --provenance=false -t "{{ MICROSERVICE_NAME }}" .
    if (-not $SkipPush) {
        aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $Registry
        docker tag  "{{ MICROSERVICE_NAME }}:latest" "$Registry/{{ MICROSERVICE_NAME }}:latest"
        docker push "$Registry/{{ MICROSERVICE_NAME }}:latest"
    }

    # 3. arrancar inyectando las env vars (NADA en disco)
    $runArgs = @('run','--rm','-d','--name',"{{ MICROSERVICE_NAME }}")
    foreach ($k in $envVars.Keys) { $runArgs += @('-e', "$k=$($envVars[$k])") }
    $runArgs += "{{ MICROSERVICE_NAME }}:latest"
    docker @runArgs
} finally { Pop-Location }
```

#### T8 — `backend` `down.ps1` → `docker stop -t 10 {{ MICROSERVICE_NAME }}`

#### T9 — `frontend` `up.ps1` (se renderiza 1 vez)

**Plantilla:** `generator/components/frontend/flutter3.47.2/templates/up.ps1.scriban`
**Key:** `"frontend/up.ps1"`

**Orden corregido respecto al enunciado** (`dart pub add` movido antes de `pub run`):

```powershell
param(
    [string]$DeviceId = '2201117SL',   # parámetro, valor por defecto conservado
    [switch]$ReleaseOnly,
    [switch]$SkipIcons
)
flutter clean
flutter pub get
if (-not $SkipIcons) {
    dart pub add dev:flutter_launcher_icons     # ← modifica pubspec, ANTES de usarlo
    flutter pub run flutter_launcher_icons
}
flutter build appbundle --release
if (-not $ReleaseOnly) { flutter run -d $DeviceId --debug }
```

#### T10 — `frontend` `down.ps1` → `flutter clean` + `flutter devices` no aplica → se limita a abortar la sesión `flutter run` si está corriendo.

**Archivos de este PR:** 4 nuevos.

---

### PR 3 — Orquestador raíz + Parameter Store

#### T11 — Componente `root` + `AddRootComponent`

**Bloqueo verificado:** los tres `Add*` existentes renderizan backend/cloud N veces. El raíz necesita un componente que se procese **una sola vez**.

| Archivo | Cambio |
|---|---|
| `generator/Configuration/GeneratorConstants.cs` | `public const string RootComponentType = "root";` |
| `generator/Application/GenerationPlanBuilder.cs` | nuevo `AddRootComponent(context)` llamado en L24 |
| `generator/components/root/workspace/component.json` | **nuevo** — `type: "root"` |
| `generator/components/root/workspace/templates/up.ps1.scriban` | **nuevo** |
| `generator/components/root/workspace/templates/down.ps1.scriban` | **nuevo** |
| `generator/AGENTS.md` | documentar el componente `root` |

> **Alternativa sin tocar C#** (si se quiere mínimo): poner `up.ps1`/`down.ps1` en el componente **frontend** con key `"up.ps1"` — se renderiza 1 vez, contenido idéntico. Funciona hoy con 0 líneas de C#, pero es semánticamente incorrecto (frontend definiendo el orquestador global).
> → *Recomendación:* **componente `root`**. Son ~20 líneas y deja la puerta abierta a otros artefactos globales.

#### T12 — Contenido del `up.ps1` raíz

```powershell
[CmdletBinding()]
param(
    [ValidateSet('all','cloud','backend','frontend')][string]$Component = 'all',
    [ValidateSet('local','qa','prod')][string]$Environment = 'qa',
    [string]$DeviceId = '2201117SL',
    [switch]$AutoApprove
)
$order = @('cloud','backend','frontend')
$todo  = if ($Component -eq 'all') { $order } else { $Component }

foreach ($c in $todo) {
    $script = Join-Path $PSScriptRoot $c 'up.ps1'
    if (-not (Test-Path $script)) { Write-Warning "No existe $script"; continue }
    Write-Host "==> $c" -ForegroundColor Cyan
    & $script -Environment $Environment -AutoApprove:$AutoApprove -DeviceId $DeviceId
    if ($LASTEXITCODE -ne 0) { throw "Falló '$c' (exit $LASTEXITCODE)" }
}
```

`down.ps1` raíz = mismo bucle con **orden invertido** (`@('frontend','backend','cloud')`).

#### T13 — Plantilla `terraform-ssm-parameters.scriban`

```hcl
locals {
  shared_parameters = {
    "sns-topic-arn"       = aws_sns_topic.main.arn
    "cognito-user-pool-id" = aws_cognito_user_pool.user_pool.id
    "region"              = var.region
  }
}

resource "aws_ssm_parameter" "shared" {
  for_each    = local.shared_parameters
  name        = "/{{ APPLICATION_ID }}/${var.environment}/shared/${each.key}"
  type        = "String"
  value       = each.value
  description = "Compartido entre microservicios"
}
```

Registrar en `cloud/aws/component.json`.

#### T14 — IAM de lectura SSM en `terraform-lambda.scriban`

Aprovecha para rellenar el `Resource = []` (P0 #3):

```json
{
  Effect   = "Allow"
  Action   = ["ssm:GetParameter", "ssm:GetParametersByPath"]
  Resource = "arn:aws:ssm:*:*:parameter/{{ APPLICATION_ID }}/${var.environment}/*"
}
```

#### T15 — Spring lee de SSM

| Archivo | Cambio |
|---|---|
| `templates/pom.scriban` | dependencia `spring-cloud-starter-aws-parameter-store` |
| `templates/application-properties.scriban` | `cloud.aws.parameter-store.enabled=true` + rutas de los parámetros |
| `templates/parameter-store-config.scriban` | **nuevo** — cliente, siguiendo el patrón de `sns-config.scriban` |
| backend `component.json` | registrar la plantilla nueva |

#### T16 — Primera ejecución (romper el ciclo huevo-gallina)

Si `aws ssm get-parameters-by-path` devuelve vacío → `up.ps1` pide los valores por `Read-Host` y los publica con `aws ssm put-parameter`. Solo la primera vez.

**Archivos de este PR:** ~9.

---

## 6. Flujo de datos

```text
target/{appId}/{appId}.json
   │  applicationId, environments[], cloud.account/region, frontend, microservices[]
   ▼
GENERADOR (Scriban)
   ├─► cloud/terraform/{ms}/local.tfvars      ← Environment + Account + Region
   ├─► cloud/terraform/{ms}/qa.tfvars
   ├─► cloud/terraform/{ms}/variables.tf      ← tipadas
   ├─► cloud/terraform/{ms}/*.tf
   ├─► cloud/up.ps1 · cloud/down.ps1
   ├─► frontend/up.ps1 · frontend/down.ps1
   ├─► {ms}/up.ps1 · {ms}/down.ps1
   └─► up.ps1 · down.ps1  (raíz)
   ▼
EJECUCIÓN  .\up.ps1 -Environment qa
   1. cloud/up.ps1
        terraform init / plan -var-file=qa.tfvars / apply
        └─► publica en SSM  /{appId}/qa/shared/{sns-topic-arn,...}
   2. {ms}/up.ps1
        aws ssm get-parameters-by-path  ← LEE
        docker buildx build → tag → push
        docker run -e AWS_SNS_TOPIC_ARN=...   ← inyecta, NADA en disco
   3. frontend/up.ps1
        flutter clean → pub get → dart pub add → pub run → appbundle → run
```

**De dónde sale cada dato:**

| Dato | Origen |
|---|---|
| `region`, `account_id` | `target/{appId}.json` → `cloud.account`/`cloud.region` |
| `environment` | parámetro `-Environment` de `up.ps1` |
| `endpoint_url`, `skip_*` | derivados de `environment` (T3) |
| `image_uri_ecr` | `account_id` + `region` + `{SERVICENAME}` |
| `sns-topic-arn`, `cognito-user-pool-id` | `terraform output` → SSM → `docker run -e` |
| `google_client_secret` | SSM (SecureString) → `TF_VAR_google_client_secret` |
| `DeviceId` | parámetro de `frontend/up.ps1` |

---

## 7. Archivos a crear

| Archivo | Propósito | PR | Estado |
|---|---|---|---|
| `components/cloud/aws/templates/terraform-tfvars.scriban` | `.tfvars` parametrizado → `terraform.{{ENVIRONMENT}}.tfvars` | 1 | ✅ |
| `components/cloud/aws/templates/up.ps1.scriban` | init/plan/apply + `-Phase Bootstrap` | 1 | ✅ |
| `components/cloud/aws/templates/down.ps1.scriban` | destroy en orden inverso | 1 | ✅ |
| `components/cloud/aws/templates/terraform-ssm.scriban` | publica `environment_variables` en Parameter Store | 1 | ✅ |
| `components/backend/spring-boot-3.5.16/templates/up.ps1.scriban` | `-Phase Build\|Run\|All`: docker build/push + SSM → docker run | 2 | ✅ |
| `components/backend/spring-boot-3.5.16/templates/down.ps1.scriban` | para y borra contenedor/imagen local | 2 | ✅ |
| `components/frontend/flutter3.47.2/templates/up.ps1.scriban` | clean → pub get → (pub add) → iconos → appbundle → run | 2 | ✅ |
| `components/frontend/flutter3.47.2/templates/down.ps1.scriban` | para `flutter run` + clean | 2 | ✅ |
| `components/root/workspace/component.json` | componente raíz | 3 | ✅ |
| `components/root/workspace/templates/up.ps1.scriban` | orquestador (Bootstrap → Build → Apply → Run → frontend) | 3 | ✅ |
| `components/root/workspace/templates/down.ps1.scriban` | paro en orden inverso | 3 | ✅ |
| `components/backend/.../templates/parameter-store-config.scriban` | Spring lee SSM | 3 | ❌ descartado: el SDK de AWS se evita leyendo SSM con la CLI `aws` desde `up.ps1` |

**Total: 11 archivos nuevos (1 descartado del conteo original de 13).**

---

## 8. Archivos a modificar

| Archivo | Cambio | PR | Estado |
|---|---|---|---|
| `components/cloud/aws/templates/terraform-variables.scriban` | tipar + defaults + quitar credenciales | 1 | ✅ |
| `components/cloud/aws/templates/terraform-provider.scriban` | quitar `access_key`/`secret_key`; `endpoints` solo en `develop` | 1 | ✅ |
| `components/cloud/aws/templates/terraform-lambda.scriban` | `image_uri` ← recurso ECR; `Resource = []` → `"*"` (policy inválida bloqueaba el apply) | 1 | ✅ |
| `components/cloud/aws/component.json` | registrar tfvars + up/down + ssm | 1 | ✅ |
| `components/backend/.../component.json` | registrar `up.ps1`, `down.ps1` | 2 | ✅ |
| `components/frontend/.../component.json` | registrar `up.ps1`, `down.ps1` | 2 | ✅ |
| `generator/Configuration/GeneratorConstants.cs` | `RootComponentType`, `RootComponentName`, `CloudRegionVariable`, `EnvironmentVariablesHclVariable`, `DefaultCloudRegion` | 3 | ✅ |
| `generator/Application/GenerationPlanBuilder.cs` | `AddRootComponent`, `CLOUD_REGION`, `ENVIRONMENT_VARIABLES_HCL` | 3 | ✅ |
| `generator/Domain/Models/CloudConfiguration.cs` | propiedad `Region` (`cloud.region` en `epc.json`) | 3 | ✅ |
| `generator/AGENTS.md` | documentar componente `root` | 3 | ✅ |
| `components/backend/.../templates/pom.scriban` | dependencia SSM | 3 | ⬜ descartado (CLI `aws`, no SDK) |
| `components/backend/.../templates/application-properties.scriban` | props SSM | 3 | ⬜ pendiente |

**Total: 10 modificados, 2 pendientes/descartados.**

---

## 9. Preguntas y recomendaciones (resueltas al implementar)

Decisiones tomadas entre paréntesis:

1. **¿Dónde vive el `up.ps1` raíz?** → *Recomendación:* componente **`root` nuevo** + `AddRootComponent` (~20 líneas en C#). Alternativa mínima: key `"up.ps1"` en el componente **frontend** (0 líneas de C#, pero semánticamente incorrecto). **→ Tomada: componente `root/workspace` + `AddRootComponent`.**

2. **¿Backend `up.ps1` hace 1 ms o todos?** → *Recomendación:* **1 microservicio** (`{{MICROSERVICE_NAME}}/up.ps1`, porque backend se renderiza N veces) y que el **raíz** itere sobre todos. Así se cumple "build image docker all ms" sin romper la mecánica. **→ Tomada.**

3. **¿`cloud/up.ps1` itera o usa `{{MICROSERVICE_NAME}}`?** → *Recomendación:* **itera `terraform/*/`**. El archivo queda idéntico aunque se renderice N veces y sirve con cualquier número de microservicios. **→ Tomada (excluye `modules/`).**

4. **¿2 plantillas de tfvars o 1 parametrizada?** → *Recomendación:* **2 fijas** (`local`, `qa`), evita dependencia del orden de renderizado. **→ Cambiada a 1 parametrizada**: la clave del `component.json` se renderiza (`terraform.{{ENVIRONMENT}}.tfvars`), así que sirve con cualquier nombre de entorno sin plantillas nuevas. `region`/`environment` viven en `variables.tf` (defaults desde `epc.json`); el `.tfvars` solo aporta lo específico del entorno.

5. **¿`dart pub add` en cada `up`?** → *Recomendación:* **sí, con `-SkipIcons`** para saltárselo. Añade ~3 s y garantiza que `pubspec.yaml` queda correcto. ⚠️ Modifica `pubspec.yaml` en cada ejecución. **→ Cambiada**: `pubspec.yaml` ya declara `flutter_launcher_icons: ^0.14.3`, así que `dart pub add` solo corre si se pasa `-Dependencies <paquete>`. El paso existe, no muta el proyecto por defecto.

6. **¿Incluir Parameter Store en este plan?** → *Recomendación:* **sí, en el PR 3**, porque el punto 5 del requerimiento lo exige literalmente. **→ Tomada, adelantada al PR 1** (`terraform-ssm.scriban`) porque `cloud/up.ps1` la crea con el resto de la infraestructura y `{ms}/up.ps1 -Phase Run` depende de ella.

7. **¿DeviceId hardcodeado `2201117SL`?** → *Recomendación:* **parámetro con ese default**. **→ Cambiada**: parámetro **sin default**; si se omite, `flutter run` elige el dispositivo conectado. Un ID de dispositivo concreto no puede ser valor por defecto de una plantilla que se genera para cualquier proyecto.

8. **¿`-AutoApprove` por defecto?** → *Recomendación:* **no**. `apply` interactivo por defecto; `-AutoApprove` explícito (evita el `-auto-approve` masivo del referente). **→ Tomada** (con salvedad: `-Phase Bootstrap` siempre usa `-auto-approve`, porque crea solo el repositorio ECR y es idempotente).

---

## 10. Decisiones tomadas

1. **Todo sale de plantillas Scriban** — `projects/` es salida generada y está en `.gitignore`; escribir a mano ahí se pierde en la próxima regeneración (regla del `AGENTS.md`).
2. **Los 13 scripts cumplen `epc-clean-code`** (§5.0): funciones ≤ 20 líneas, sin `if`/`foreach` en el flujo principal, toda llamada a `aws`/`terraform`/`docker`/`flutter` encapsulada en una función, ≤ 2 parámetros posicionales, variantes de ambiente como handlers separados, y el `up.ps1` raíz como **Facade**. Checklist de verificación en §5.0.
3. **Orden `up`:** `cloud → backend → frontend`; **`down`:** inverso. Cloud primero porque crea SSM/ECR que el backend consume.
4. **`$ErrorActionPreference = 'Stop'` + `$PSNativeCommandUseErrorActionPreference = $true` + chequeo de `$LASTEXITCODE`** en los 6 scripts. Corrige el defecto nº3 del referente (`ejecutar-tarea.ps1` no detecta fallos).
5. **`Push-Location $PSScriptRoot` + `try/finally { Pop-Location }`** — sin rutas absolutas `D:\codigo\test\...` (defecto nº8 del referente).
6. **Credenciales fuera de las variables de Terraform** — cadena estándar del proveedor. Elimina los secretos en claro (defecto nº6 del referente).
7. **Env vars vía `docker run -e`, no `.env` ni env var global de Windows.** Evita el defecto nº4 del referente (`SetEnvironmentVariable(..., 'User')`, que persiste para siempre).
8. **Sin `-target`** — el referente usa 24 `apply -target`; se sustituye por `terraform apply` completo por directorio.
9. **Orden del frontend corregido:** `clean → pub get → dart pub add → pub run → appbundle → run`. En el enunciado, `dart pub add` estaba **después** de `flutter pub run`, lo que falla (el paquete aún no existe en `dev_dependencies`).

12. **Formato de consola y log (iteración 2, 2026-09-26):** la consola muestra **solo** líneas con el patrón `[yyyy-MM-dd HH:mm:ss] [etapa] mensaje` con textos naturales en español (`Iniciando despliegue`, `[Cloud Bootstrap] Creando ECR {ms}` / `Creado ECR {ms}`, `[Backend] Creando imagen docker {ms}` / `Imagen docker creada {ms}`, `Iniciando sesión en ECR`, ...). Etapas: `Cloud Bootstrap` | `Cloud Apply` | `Cloud Destroy` | `Backend` | `Frontend` (el orquestador raíz va sin etapa). La **salida real de cada herramienta** (`terraform`, `docker`, `aws`, `flutter`) y el detalle (`rutas`, `argumentos`, `exit`) van **solo al archivo** `logs/yyyy-MM-dd-HH-mm-ss.log` (`| Out-File -Append` para stdout+stderr, `2>>` para el stderr de `aws`, `Tee-Object` solo para `flutter run`, que es interactivo y sí se muestra en consola). Los hijos emiten solo líneas amigables hacia arriba, de modo que el log raíz las replica tal cual. Los fallos terminan con `Stop-WithError` (`ERROR: …` + ruta del log, `exit 1`, sin stack trace) y el orquestador raíz aborta si un componente devuelve `exit ≠ 0`.

13. **Chequeo de Docker en backend `up`/`down` (iteración 2026-09-26):** `Assert-DockerEngine` comprueba el CLI y el motor (`docker info`); si el motor está caído intenta arrancar `C:\Program Files\Docker\Docker\Docker Desktop.exe` y espera hasta 60 s (3 s de sondeo); si no levanta, sale con mensaje claro indicando qué hacer (sin `throw` con código de salida). Verificado en ejecución real: caído → auto-arranque → disponible en 20 s.

14. **`terraform-dynamodb.scriban` queda pendiente** (decisión del usuario, 2026-09-26): la plantilla es por entidad (`{{ Entity }}`) y el generador no tiene bucle de entidades (`StrictVariables=true` fallaría con `GEN002`); registrarla exige decidir entre tabla por microservicio o implementar el bucle en `GenerationPlanBuilder`. Ver `.opencode/agent-ai/docs/templates-sin-registro.md`.

10. **Ejecución 100% PowerShell** — sin runner en C#. El `.ps1` contiene la secuencia de ejecución; no se añade ningún `PackageReference` a `Generator.csproj` (hoy solo `Scriban`) ni se requiere .NET SDK para levantar la app. La lógica de **generación** (valores de `.tfvars`, rutas, microservicios) sigue en C#/Scriban.

11. **Flujo por fases para romper el ciclo ECR ↔ Lambda** — un único `apply` fallaría porque la Lambda exige la imagen ya subida y el `push` exige el repo ya creado. Se divide en `bootstrap` (ECR, state propio) → `build` (docker) → `apply` (resto) → `run` (lee SSM). Sin `-target`:

11. **Flujo por fases para romper el ciclo ECR ↔ Lambda** — un único `apply` fallaría porque la Lambda exige la imagen ya subida y el `push` exige el repo ya creado. Se divide en `bootstrap` (ECR, state propio) → `build` (docker) → `apply` (resto) → `run` (lee SSM). Sin `-target`:

```text
up.ps1 (raíz)
 ├─ 1. cloud/up.ps1     -Phase Bootstrap   → init + apply -target=aws_ecr_repository.<x>  (crea ECR)
 ├─ 2. {ms}/up.ps1      -Phase Build        → docker build → tag → push al ECR
 ├─ 3. cloud/up.ps1     -Phase Apply        → init + plan + apply  (Lambda + Cognito + SNS + SSM)
 ├─ 4. {ms}/up.ps1      -Phase Run          → aws ssm get-parameters-by-path → docker run -e
 └─ 5. frontend/up.ps1                      → flutter clean → … → run

down.ps1 (raíz)  = orden exactamente inverso:
   frontend/down → {ms}/down (N) → cloud/down (destroy en orden inverso)
```

Cada `up.ps1` de componente acepta `-Phase` para su ejecución aislada (`cloud`: `Bootstrap|Apply`; `backend`: `Build|Run|All`); por defecto hace su flujo completo.

### 10.1 Archivos del referente leídos (solo lectura, sin modificar)

`terraform-environment.ps1` (59 L) · `update-env.ps1` (114 L) · `qa_exec.ps1` (103 L) · `local_exec.ps1` (90 L) · `ejecutar-tarea.ps1` (18 L) · más los 22 `.tf` y 2 `.tfvars`.

### 10.2 Qué se copia del referente

- `.tfvars` **generado**, nunca escrito a mano.
- Cálculo de dinámicos por ambiente (`endpoint_url`, `skip_*`, `image_uri_ecr`).
- `$excludedKeys` → credenciales fuera del `environment_variables` de la Lambda.
- Orden ECR → docker build/tag/push → cognito → sns → dynamodb → lambda → apigateway.
- `docker buildx build --platform linux/amd64 --provenance=false`.

### 10.3 Qué NO se copia (defectos verificados)

| # | Archivo:línea | Defecto |
|---|---|---|
| 1 | `local_exec.ps1:26-29` | usa `qa.tfvars` en bloque COGNITO → crea recursos de QA desde local |
| 2 | `terraform-environment.ps1:8` | usa `$jsonPath` pero el param es `$path` → solo funciona por dot-sourcing |
| 3 | `ejecutar-tarea.ps1` | no comprueba `$job.State` → si un `apply` falla, continúa igual |
| 4 | `update-env.ps1:84` | `SetEnvironmentVariable(..., 'User')` → persiste en Windows para siempre |
| 5 | `update-env.ps1:35` | loguea valores en claro en `update-env.log` |
| 6 | `qa_exec.ps1:18-19` | credenciales AWS reales hardcodeadas |
| 7 | `qa_exec.ps1` (×24) | `apply -target` → cambios fuera de targets se aplazan sin avisar |
| 8 | `local_exec.ps1:11` etc. | `cd D:\codigo\test\...` hardcodeado en 12 sitios |

> **Seguridad:** hay credenciales AWS y de Google reales en ese directorio. **Sugiero rotarlas** aunque no pertenezcan a este repo.

---

## 11. Costos

**Infraestructura: $0.**
- SSM Parameter Store *Standard* es gratis hasta 10.000 parámetros (luego $0,05/10.000/mes) — se usan <10.
- No se crea ningún recurso AWS nuevo más allá de los parámetros.

**Esfuerzo: ~24 archivos en 3 PRs — 2 a 3 sesiones.**

| PR | Archivos | Complejidad |
|---|---|---|
| 1 — Cloud ejecutable | 7 (5 nuevos, 2 mod.) | media |
| 2 — Backend + frontend | 4 (4 nuevos) | baja |
| 3 — Raíz + Parameter Store | ~9 (4 nuevos, 5 mod.) | **alta** (toca C#) |

**Impacto de contexto: medio-alto.** Requiere cargar: `GenerationPlanBuilder.cs`, `GeneratorConstants.cs`, 4 `component.json`, 2 `AGENTS.md` de componente, y el contenido de las plantillas nuevas.

**Riesgo:**
- 🔴 **PR 3 toca el código del generador** (`AddRootComponent`) — afecta a los 3 componentes a la vez. Mitigación: regenerar `projects/` y comparar diff completo antes de mergear.
- 🟡 `dart pub add` modifica `pubspec.yaml` en cada ejecución.
- 🟡 El `apply` pasa de 24 `-target` a 1 completo → puede destapar cambios pendientes la primera vez (revisar el plan antes de aplicar).

**Verificación previa obligatoria:** `dotnet build generator/Generator.csproj` (requiere tu autorización) + regenerar `projects/` + `git diff` completo.

---

## 12. Fuera de alcance

Quedan pendientes de otros planes (P0 detectados en la revisión de Terraform):

1. **P0 #1 — sufijo `aws`** de los nombres de recurso (`GenerationPlanBuilder.cs:186`: `cloud.Name ?? cloud.Provider`) → `ANY /aws/{proxy+}` en vez del nombre del microservicio.
2. **P0 #4 — modelo de state**: cognito/apigateway/sns se generan **dentro de cada microservicio** → con 2 ms hay 2 `domain = "user-management-domain"` (rechazo de AWS). *Este plan asume 1 microservicio; con más, bloquea.*
3. **P0 #7 — `terraform-dynamodb.scriban` huérfana** (existe, no registrada en `component.json`) → permisos DynamoDB colgados en la Lambda.
4. **Backend S3 + `versions.tf`** (bloqueo de estado).
5. **`fmt -check`** de la buildspec (11 de 13 archivos fallen).
6. **ECR en root bootstrap** (estado de Terraform propio para ECR en lugar de `-target`) — hoy el ciclo se resuelve con `cloud/up.ps1 -Phase Bootstrap` (`apply -target=aws_ecr_repository.<x>`); separarlo en su propio estado sigue fuera de alcance.
7. **Callbacks `localhost:3000`** en las plantillas.

> ⚠️ **Nota:** el punto 2 (modelo de state) es **previo** a poder probar este plan con más de un microservicio. Con `quizapi` solo, funciona.

---

## 13. Estado de implementación

### Hecho
- **11 plantillas nuevas** (ver §7) y **11 ficheros modificados** (ver §8): todo lo necesario para que `projects/{appId}/up.ps1` y `down.ps1` existan y orquesten cloud → backend → frontend.
- Componente **`root/workspace`** creado y enganchado con `AddRootComponent` (se ejecuta el primero en `Build`).
- **Logs línea a línea con valores** en los 8 scripts (helper `Write-Log` en cada plantilla: timestamp + mensaje, y línea siguiente con los valores `clave=valor`). Cada script imprime sus parámetros de entrada, rutas, comandos, `exit` de cada proceso, descubrimiento de microservicios/scripts y cada parámetro leído de Parameter Store.
- **Iteración 2026-09-26 (ver §10, puntos 12–14):** formato de consola `[yyyy-MM-dd HH:mm:ss] [etapa] mensaje` con textos naturales (`Creando ECR {ms}`, `Creando imagen docker {ms}`, …), salida real de las herramientas **solo** en `logs/yyyy-MM-dd-HH-mm-ss.log` por script (`Out-File`/`2>>`; `Tee-Object` solo para `flutter run`), errores finales con `Stop-WithError` (mensaje claro + ruta del log, sin stack trace) y `Assert-DockerEngine` en backend `up`/`down` (comprueba → arranca Docker Desktop → espera 60 s → mensaje claro si no levanta).
- **Verificado con ejecución real (2026-09-26):**
  - `dotnet build` → **0 errores**; `dotnet run` → 8 `.ps1` regenerados, **0 placeholders sin resolver**, parser de PowerShell **0 errores**, sin funciones >20 líneas ni >2 parámetros.
  - `backend/quizapi/down.ps1` (formato nuevo) → consola solo con `[2026-09-26 11:27:53] [Backend] …` (4 líneas amigables), el log `2026-09-26-11-27-53.log` incluye la salida real de `docker rm`/`docker rmi` y los `exit`, exit 0.
  - `frontend/quizsmart/down.ps1` → consola solo `[Frontend] …`, el log contiene la salida real de `flutter clean` (banner de versión y `Deleting build...`), exit 0.
  - Orquestador raíz con stubs (directorio temporal): escenario feliz `Iniciando despliegue` → `Despliegue finalizado` (exit 0) con las líneas de los hijos replicadas en el log raíz; escenario de fallo (`exit=9` en fase Run) → `ERROR: …` + ruta del log + `exit 1`, sin stack trace.
  - Docker caído (10:38, versión anterior de los mensajes): `estado=caido` → auto-arranque → motor disponible en 20 s → exit 0.
- **Verificado con ejecución real:**
  - `dotnet build` → **0 errores, 0 advertencias**;
  - `dotnet run` → `Componente 'root' seleccionado: workspace`, 8 `.ps1` generados, **0 placeholders sin resolver**, parser de PowerShell **0 errores**;
  - `terraform init` → exit 0; `terraform validate` → **`Success! The configuration is valid.`**;
  - `terraform fmt -check` → los `.tf` de este plan pasan; quedan 8 preexistentes sin formatear;
  - ejecución de `backend/quizapi/down.ps1` → logs correctos, exit 0;
  - ejecución de `cloud/up.ps1 -PlanOnly` → logs correctos, `init` exit 0, `plan` **queda esperando** a LocalStack (`localhost:4566`) que no está corriendo.

### Pendiente (requiere autorización o entorno)
1. LocalStack levantado en `localhost:4566` para que `terraform plan/apply` de `develop` termine.
2. `terraform plan`/`apply` reales y `docker build`/`flutter build` (compilan).
3. Commit de los cambios (no autorizado).
4. Reformatear las 8 plantillas `.tf` preexistentes que siguen fallando `fmt -check`.
5. IAM de la Lambda: `Resource = ["*"]` es amplio → acotar a la tabla DynamoDB cuando exista recurso.

### Riesgos abiertos
- `endpoints` del provider solo se emiten si `ENVIRONMENT == "develop"`: cualquier entorno no listado que quiera LocalStack necesita tocar `terraform-provider.scriban`.
- `terraform-ssm.scriban` publica **todas** las variables del entorno como `String` (no `SecureString`): no usar para secretos hasta que se añada un criterio de tipo.
