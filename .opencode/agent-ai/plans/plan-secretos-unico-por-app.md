# Plan: Un único secreto por aplicación en AWS Secrets Manager

**Tarea del TODO:** `.opencode/agent-ai/docs/todo.md` → MVP `T04 — Agregar los secretos a AWS secret manager`
**Fecha:** 2026-09-28 · **Sustituye a:** `plan-t04-secretos-secrets-manager.md` (queda obsoleto).

## 1. Descripción
Hoy **no existe ningún secreto de la aplicación** en AWS (sólo el de firma Android `/epc/com.quizsmart.app/android-signing`, creado por el buildspec) y el módulo `modules/secrets-manager` está **huérfano**: ningún `.tf` lo instancia. Además, el generador **no produce** ningún archivo Terraform de secretos.

Este plan crea **un solo secreto por aplicación** llamado `{{ENVIRONMENT}}/{{APPLICATION_ID}}` (p. ej. `develop/com.quizsmart.app`) con **un único JSON** que contiene `android-signing`, `jwt-secret` y `api-key`. Un único JSON es una **decisión de costo** (1 × 0,40 USD/mes en lugar de 3 × 0,40).

> **Fuente de verdad:** todo cambio se hace en **`generator/components/…` (plantillas `.scriban` + `component.json`)**. Las rutas `cloud/…`, `frontend/…`, `buildspec.yml`, etc. que aparecen en el plan son **destinos de renderizado**, sólo para explicar el resultado esperado: **nunca se editan a mano**.

## 2. Objetivo
1. El **generador** produce los archivos Terraform que crean el secreto (contenedor) en `cloud/terraform/app/`.
2. **Terraform** crea el contenedor del secreto **sin valor** (el valor nunca entra en el estado de Terraform ni en el repositorio).
3. **`templates/up.ps1.scriban` de cloud** (genera `cloud/up.ps1`) siembra `jwt-secret` (aleatorio) y `api-key` (placeholder) sólo si faltan.
4. **`templates/up.ps1.scriban` de frontend** (genera `frontend/{name}/up.ps1`) valida que el secreto existe (si no → falla), crea el keystore y siembra/lee `android-signing`, y con `-Sign` compila el `.aab` firmado.
5. `buildspec.yml` del frontend pasa a **sólo ejecutar el script**.
6. Los valores son **temporales**: el usuario los cambia a mano en AWS al terminar el despliegue.

## 3. Estado actual vs. nuevo

> El árbol es la **salida renderizada** (para orientar); el trabajo se hace sobre `generator/components/…`.

```text
ACTUAL
generator/components/cloud/aws/
├── templates/terraform-secrets-manager.scriban     # for_each + secret_version (valor en el estado)
├── templates/terraform-secrets-manager-variables.scriban  # variable "secrets"
└── component.json                                  # NO genera cloud/terraform/app/

cloud/terraform/      # ningún bloque `module "` en todo el componente
frontend/quizsmart/up.ps1     # clean → pub get → icons → appbundle → run   (sin -Sign, sin secretos)
buildspec.yml                 # lógica bash de keystore inline (23 líneas)
codepipeline.yml              # IAM: Get/Describe/Create sobre /epc/${ApplicationId}/android-signing-*
application-properties        # jwt.secret=${JWT_SECRET}   (env var, no existe en cloud)

---
NUEVO
generator/components/cloud/aws/
├── templates/terraform-secrets-manager.scriban     # 1 secreto ${environment}/${project_name}, SIN version
├── templates/terraform-secrets-manager-variables.scriban  # sin variable "secrets"
├── templates/terraform-secrets.scriban             # NUEVO → cloud/terraform/app/secrets.tf
└── component.json                                  # + directorio app/ y 4 entradas files

cloud/terraform/app/{provider,variables,secrets}.tf + terraform.<env>.tfvars   # estado propio
cloud/up.ps1        # + Update-ApplicationSecret (siembra jwt-secret/api-key si faltan)
frontend/up.ps1     # + parámetro -Sign, lectura/creación de android-signing, key.properties
buildspec.yml       # instala pwsh si falta + ejecuta `pwsh up.ps1 -Sign`
```

**JSON final del secreto** (kebab-case):

```json
{
  "android-signing": {
    "key-alias": "com.quizsmart.app",
    "store-password": "<aleatorio>",
    "key-password": "<aleatorio>",
    "keystore-base64": "<upload-keystore.jks en base64>"
  },
  "jwt-secret": "<aleatorio 48 bytes base64>",
  "api-key": "PLACEHOLDER_CAMBIAR_EN_AWS"
}
```

## 4. Referencias web

| Referencia | Aporte |
|---|---|
| https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/using-secrets-manager-and-terraform.html | Patrón oficial: Terraform sólo crea el **contenedor**; el valor se gestiona fuera del estado. |
| https://github.com/aws/aws-codebuild-docker-images/blob/master/ubuntu/standard/7.0/Dockerfile | `aws/codebuild/standard:7.0` **ya trae PowerShell 7.6.4 (`pwsh`)**, AWS CLI v2, `jq`, `openssl` y Corretto 17 (`keytool`). |
| https://docs.aws.amazon.com/codebuild/latest/userguide/available-runtimes.html | Runtimes/imágenes soportadas de CodeBuild. |
| https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html | Caché en cliente, monitorizar accesos, no replicar secretos en código/estado. |
| `.opencode/agent-ai/plans/plan-t04-secretos-secrets-manager.md` | Plan sustituido: decisiones de granularidad y layout `app/` que se reutilizan. |
| `.opencode/agent-ai/plans/plan-reduce-secret-calls.md` | Patrón JSON consolidado 1-vs-4 ya aplicado a signing. |
| `.opencode/agent-ai/docs/parametros.md` §3 | `JWT_SECRET` y `API_KEY` clasificados como `S` (Secret), nunca en target. |

## 5. Tareas de implementación

### Fase 1 — `feature/t04-secreto-terraform`
**T1.1 Reescribir `templates/terraform-secrets-manager.scriban`** → un secreto por instancia, sin valor en el estado:
```hcl
resource "aws_secretsmanager_secret" "app_secret" {
  name        = "${var.environment}/${var.project_name}"   # develop/com.quizsmart.app
  description = "Secrets of the application ${var.project_name}"
  kms_key_id  = var.kms_key_arn

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
```
Se elimina `for_each`, `aws_secretsmanager_secret_version` y el bloque `variable "secrets"` del fichero de variables (T1.2). **Razón:** con `secret_version` el valor quedaría en `terraform.tfstate`.

**T1.3 Crear `templates/terraform-secrets.scriban`** → destino `cloud/terraform/app/secrets.tf`:
```hcl
module "secrets" {
  source       = "../modules/secrets-manager"
  environment  = var.environment
  project_name = "{{ APPLICATION_ID }}"
  kms_key_arn  = null          # clave gestionada aws/secretsmanager (decisión de costo)
}
```

**T1.4 Registrar en `generator/components/cloud/aws/component.json`** (regla: plantilla no listada ⇒ no se genera):
- `directories`: añadir `"cloud/terraform/app"`.
- `files`: añadir
  - `cloud/terraform/app/provider.tf` → `templates/terraform-provider.scriban`
  - `cloud/terraform/app/variables.tf` → `templates/terraform-variables.scriban`
  - `cloud/terraform/app/terraform.{{ENVIRONMENT}}.tfvars` → `templates/terraform-tfvars.scriban`
  - `cloud/terraform/app/secrets.tf` → `templates/terraform-secrets.scriban`

> Las plantillas `templates/up.ps1.scriban`/`down.ps1.scriban` recorren **todos** los directorios de `cloud/terraform/` salvo `modules/`, por lo que `app/` se aplica y destruye **sin tocar esas plantillas**.
> El tfvars es obligatorio: `templates/up.ps1.scriban:286,294` siempre pasa `-var-file terraform.<env>.tfvars`.

**T1.5 IAM Lambda — `templates/terraform-lambda.scriban`**: añadir a `aws_iam_role_policy`:
```hcl
{
  Effect = "Allow",
  Action = ["secretsmanager:GetSecretValue"],
  Resource = ["arn:aws:secretsmanager:*:*:secret:{{ ENVIRONMENT }}/{{ APPLICATION_ID }}-*"]
}
```

**T1.6 `generator/components/backend/spring-boot-3.5.16/templates/application-properties.scriban:28`** — la clave del JSON pasa a ser `jwt-secret`; se deja como *fallback* sin romper el flujo actual (la env var sigue teniendo prioridad):
```properties
jwt.secret=${JWT_SECRET:${jwt-secret:}}
```
Con T06 aún no hecho, `jwt-secret` no existe en el `Environment` → resuelve a vacío, igual que hoy. Con T06 hecho, la lectura del secreto la hará operativa. *(Ver Q2 §9.)*

**T1.7 Label en `generator/components/cloud/aws/templates/up.ps1.scriban:51`**: añadir `'secrets.tf' = 'Secrets'` a `$script:ResourceLabels`.

### Fase 2 — `feature/t04-secreto-cloud-script`
**T2.1 `generator/components/cloud/aws/templates/up.ps1.scriban` — nueva función `Update-ApplicationSecret`**, invocada al final de `Invoke-CloudUp` (sólo si `-Phase Apply` y `-not $PlanOnly`):

```powershell
function New-RandomSecretValue {
    param([Parameter(Mandatory)][int]$ByteLength = 48)
    $bytes = [byte[]]::new($ByteLength)
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [Convert]::ToBase64String($bytes)   # equivalente a openssl rand -base64 48
}

function Update-ApplicationSecret {
    $secretName = "$Environment/{{ APPLICATION_ID }}"
    # 1. aws secretsmanager get-secret-value --secret-id $secretName --query SecretString --output text
    #    ResourceNotFoundException -> Stop-WithError "El secreto $secretName no existe: ejecuta primero la fase Apply de cloud (Terraform lo crea)."
    # 2. ConvertFrom-Json -> añadir SOLO las claves que falten:
    #      jwt-secret -> New-RandomSecretValue
    #      api-key    -> 'PLACEHOLDER_CAMBIAR_EN_AWS'
    # 3. Si cambió algo -> aws secretsmanager put-secret-value --secret-string $json
    # 4. Si nada cambió  -> log "valores ya presentes (no se sobrescriben)"
}
```
Reglas duras de la función:
- **Nunca sobrescribe** una clave existente (el usuario la cambia a mano en AWS).
- **Nunca crea** el secreto: si no existe, es un error de secuencia (Terraform debe haber corrido).
- Si `aws` CLI no está en el PATH → `Stop-WithError` con mensaje explícito (coherente con el guard de `Update-PostApplyParameters` en la misma plantilla).
- Usa `Write-Log`/`Write-LogDetail` y `$script:LogFile` como el resto de la plantilla (G30: una función = una cosa).

**T2.2 Ayuda de la plantilla**: documentar en `.PARAMETER Phase`/`.DESCRIPTION` que el `up.ps1` generado siembra el secreto y que los valores son temporales.

### Fase 3 — `feature/t04-secreto-frontend-script`
**T3.1 `generator/components/frontend/flutter3.47.2/templates/up.ps1.scriban`** — nuevas piezas:

- Parámetros: añadir `[switch]$Sign` y `[string]$Environment = '{{ ENVIRONMENT }}'`.
- `Ensure-Prerequisites`: `flutter`, `keytool`, `aws`, `pwsh >= 7` → si falta algo, `Stop-WithError` con el nombre exacto (fail-fast).
- `Get-ApplicationSecret`:
  1. `aws secretsmanager get-secret-value --secret-id "$Environment/{{ APPLICATION_ID }}"`.
  2. **No existe → `Stop-WithError`** ("el pipeline de cloud debe ejecutarse primero"). El frontend **nunca** crea el secreto.
  3. Sin valor (SecretString nulo) → tratar como JSON vacío y continuar.
- `Sync-AndroidSigning` (sólo con `-Sign`):
  - Si el JSON **tiene** `android-signing` → **sólo leer** (`key-alias`, `store-password`, `key-password`, `keystore-base64`).
  - Si **no lo tiene** → generar el keystore y añadir **únicamente** esa clave, preservando `jwt-secret`/`api-key`:
    ```powershell
    keytool -genkeypair -alias "{{ APPLICATION_ID }}" -keyalg RSA -keysize 2048 `
      -validity 10000 -storetype JKS -keystore $ks -storepass $pw -keypass $pw `
      -dname "CN={{ APPLICATION_ID }}"
    # pw = New-RandomSecretValue -ByteLength 24 (sin /+= para que sirva de contraseña)
    # put-secret-value con el JSON combinado (merge por clave, nunca overwrite total)
    ```
  - Escribir `android/upload-keystore.jks` y `android/key.properties` (misma salida que hoy genera el buildspec, para que la plantilla `templates/android/app/build.gradle.kts.scriban:48-66` siga funcionando sin cambios).
- `Invoke-FrontendUp` pasa a:
  - `-Sign` → `Sync-AndroidSigning` → `Invoke-Bundle` (firmado).
  - sin `-Sign` → **borrar** `android/key.properties` y `android/upload-keystore.jks` si existen → `Invoke-Bundle` (sin firma).
- Compresión de responsabilidades: extraer `Invoke-Bundle` de hoy y añadir el paso de firma como función propia; la lógica de secreto vive en `Sync-AndroidSigning`, no dentro de `Invoke-FrontendUp`.

**T3.2 `generator/components/frontend/flutter3.47.2/templates/buildspec.yml.scriban`** → aplanar a:
```yaml
version: 0.2
phases:
  pre_build:
    commands:
      - command -v pwsh >/dev/null || (wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/ms.deb && dpkg -i /tmp/ms.deb && apt-get update -qq && apt-get install -y -qq powershell)
      - pwsh --version
      - git config --global --add safe.directory /home/flutter/sdks/flutter
      - pwsh -File "frontend/{{ FRONTEND_NAME }}/up.ps1" -Sign
artifacts:
  files:
    - frontend/{{ FRONTEND_NAME }}/build/app/outputs/bundle/release/*.aab
  discard-paths: no
  name: $APPLICATION_ID-aab-$CODEBUILD_BUILD_ID
```
> `standard:7.0` **ya trae `pwsh`** (Dockerfile oficial), así que la rama de instalación sólo se ejecuta en imágenes ajenas. El resto de la lógica (local.properties, limpieza, aws cli) **se muda al script**.

**T3.3 `generator/components/frontend/flutter3.47.2/templates/codepipeline.yml.scriban`**:
- Parámetro nuevo `Environment` (`Type: String`, `Default: 'develop'`) + EnvironmentVariable `ENVIRONMENT` en `CodeBuildProject` (junto a `APPLICATION_ID`/`AWS_REGION`).
- Política `SecretsManagerAccess` → recurso `arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:${Environment}/${ApplicationId}-*` y acciones `GetSecretValue`, `DescribeSecret`, **`PutSecretValue`** (quita `CreateSecret`: el frontend no crea secretos).

**T3.4 `generator/components/frontend/flutter3.47.2/templates/README.md.scriban`** — sección *Android signing*: nuevo nombre `{{ENVIRONMENT}}/{{APPLICATION_ID}}`, JSON kebab-case, `-Sign`, nuevo ARN IAM y nota de que el `.aab` sin `-Sign` sale sin firmar.

**T3.5 `templates/.gitignore.scriban`** — sin cambios: ya ignora `/android/key.properties` y `/android/upload-keystore.jks`.

### Fase 4 — Limpieza (manual, con autorización)
**T4.1 Borrar los secretos legados** (`borrón y cuenta nueva`) — operación sobre AWS, no sobre archivos:
```powershell
aws secretsmanager list-secrets --query 'SecretList[].Name'
aws secretsmanager delete-secret --secret-id "/epc/<APPLICATION_ID>/android-signing" --force-delete-without-recovery
# + los 4 legacy /epc/<APPLICATION_ID>/android-signing/{keystore,store-password,key-password,key-alias}
# + cualquier <ENVIRONMENT>/<APPLICATION_ID>/* residual
```
> ⚠️ Comando destructivo → **ejecutar sólo con autorización explícita del usuario**. `--force-delete-without-recovery` es definitivo.

## 6. Flujo de datos

> Los pasos 2-5 describen el comportamiento de los **scripts que genera** cada plantilla; se implementan y modifican siempre en la plantilla.

1. **Generador** lee `target/{APPLICATION_ID}/{APPLICATION_ID}.json` → renderiza plantillas registradas → escribe `cloud/terraform/app/*.tf`, `cloud/up.ps1`, `frontend/{name}/up.ps1`, `buildspec.yml`, `codepipeline.yml`.
2. **`up.ps1` raíz** (orden ya existente): `cloud -Phase Bootstrap` → `backend Build` → **`cloud -Phase Apply`** → `backend Run` → **`frontend`**.
3. **`cloud/up.ps1 -Phase Apply`** → `terraform apply` en `cloud/terraform/app/` → crea el **contenedor** `develop/com.quizsmart.app` (sin valor) → `Update-ApplicationSecret` siembra `jwt-secret` + `api-key` sólo si faltan.
4. **`frontend/up.ps1 -Sign`** (pipeline) → `get-secret-value` (si no existe → **fallo**) → si falta `android-signing`, genera el `.jks`, hace **merge** y `put-secret-value` → escribe `key.properties` + `.jks` → `flutter build appbundle --release` → `post_build` borra los dos archivos.
5. **`frontend/up.ps1` sin `-Sign`** (local) → borra `key.properties`/`.jks` si existen → `flutter build appbundle --release` **sin firma**.
6. **Usuario** cambia `jwt-secret` y `api-key` a mano en AWS al terminar el despliegue (hoy manual; sin rotación automática).
7. **T06** (fuera de alcance): la Lambda leerá `aws-secretsmanager:/{ENVIRONMENT}/{APPLICATION_ID}` con `secretsmanager:GetSecretValue` (ya concedido en T1.5).

## 7. Archivos a crear

| Archivo | Propósito |
|---|---|
| `generator/components/cloud/aws/templates/terraform-secrets.scriban` | `cloud/terraform/app/secrets.tf`: instancia el módulo de secretos de la aplicación. |

## 8. Archivos a modificar

| Archivo (fuente de verdad: plantillas y registros) | Cambio |
|---|---|
| `generator/components/cloud/aws/templates/terraform-secrets-manager.scriban` | 1 secreto `${environment}/${project_name}`; quitar `for_each` y `secret_version`. |
| `generator/components/cloud/aws/templates/terraform-secrets-manager-variables.scriban` | Quitar `variable "secrets"`. |
| `generator/components/cloud/aws/component.json` | `directories` + 4 entradas `files` para `cloud/terraform/app/`. |
| `generator/components/cloud/aws/templates/terraform-lambda.scriban` | IAM: `secretsmanager:GetSecretValue` sobre el secreto de la app. |
| `generator/components/cloud/aws/templates/up.ps1.scriban` | `New-RandomSecretValue` + `Update-ApplicationSecret`; label `secrets.tf`. |
| `generator/components/frontend/flutter3.47.2/templates/up.ps1.scriban` | `-Sign`, `-Environment`, `Get-ApplicationSecret`, `Sync-AndroidSigning`, `Ensure-Prerequisites`. |
| `generator/components/frontend/flutter3.47.2/templates/buildspec.yml.scriban` | Sólo: asegurar `pwsh` + ejecutar `up.ps1 -Sign`. |
| `generator/components/frontend/flutter3.47.2/templates/codepipeline.yml.scriban` | Parámetro `Environment`, env var `ENVIRONMENT`, IAM `PutSecretValue` + nuevo ARN. |
| `generator/components/frontend/flutter3.47.2/templates/README.md.scriban` | Sección de firma y permisos IAM actualizadas. |
| `generator/components/backend/spring-boot-3.5.16/templates/application-properties.scriban:28` | `jwt.secret=${JWT_SECRET:${jwt-secret:}}`. |
| `.opencode/docs/decisions.md` | Registrar: 1 secreto/JSON por app, valor fuera de estado, kebab-case, `-Sign`. |

> **No se edita ningún archivo generado.** Tras implementar, la salida (`projects/…`, `cloud/…`, `frontend/…`) se **regenera** con el generador; si un archivo generado no coincide, el arreglo va en la plantilla correspondiente, nunca en la salida.

## 9. Preguntas y recomendaciones

1. **¿La cuenta de trabajo sigue siendo la `577638384397` (perfil `default`)?** → *Recomendación:* confirmar antes de T4.1 (borrado destructivo) y antes de cualquier `terraform apply`.
2. **¿`jwt.secret` se referencia ya, o se deja para T06?** T1.6 sólo añade un *fallback* (`${JWT_SECRET:${jwt-secret:}}`): sin T06 la property `jwt-secret` no existe en el `Environment`, así que **el comportamiento de hoy no cambia**. → *Recomendación:* aplicarlo ahora (es aditivo y deja el template listo para T06).
3. **Imagen con Flutter.** La plantilla `templates/codepipeline.yml.scriban:94` declara `aws/codebuild/standard:7.0`, que **no incluye Flutter**, pero la plantilla `buildspec.yml.scriban` asume `/home/flutter/sdks/flutter`. → *Recomendación:* mantener la imagen declarada y que `Ensure-Prerequisites` falle con un mensaje claro si `flutter` no está en el PATH; **instalar Flutter en el pipeline queda fuera de alcance** (¿o hay una imagen custom que deba referenciarse?).
4. **Race condition entre scripts.** Si `cloud/up.ps1` y `frontend/up.ps1` corren a la vez, el `put-secret-value` de uno puede pisar al otro (se hace read-modify-write). → *Recomendación:* aceptarlo: el orden cloud → frontend ya lo garantiza el `up.ps1` raíz.
5. **Destrucción.** `down.ps1` borrará el secreto con la ventana de recuperación (30 días); re-aplicar dentro de esa ventana da `SecretsManagerException`. → *Recomendación:* documentarlo en la ayuda de `down.ps1` y, si ocurre, `delete-secret --force-delete-without-recovery`.
6. **Alias del keystore.** Fijado a `{{ APPLICATION_ID }}` (`com.quizsmart.app`, sin prefijo `upload-`), coherente con el keystore nuevo que se genere. → *Recomendación:* confirmar que ninguna app publicada conserve el keystore anterior (`upload-com-quizsmart-app`).
7. **`api-key` placeholder.** Valor `PLACEHOLDER_CAMBIAR_EN_AWS`; el valor real **nunca** se escribe en un archivo de texto. → *Recomendación:* dejarlo así hasta que exista rotación/inyección.

## 10. Decisiones tomadas
1. **Un secreto por aplicación**, nombre `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}`, con **un único JSON** (kebab-case) por **costo**: 1 × 0,40 USD/mes en vez de 3 × 0,40.
2. **Terraform sólo crea el contenedor**; el valor nunca entra en `terraform.tfstate` ni en el repo.
3. **`cloud/up.ps1` siembra `jwt-secret` + `api-key`**; **`frontend/up.ps1` sólo gestiona `android-signing`** (merge por clave, nunca sobrescribe lo demás).
4. El frontend **nunca crea** el secreto: si no existe → **fallo** (el pipeline de cloud va primero).
5. **`-Sign` = pipeline**: con `-Sign` compila el `.aab` firmado; sin él, borra los archivos de firma y compila sin firmar. Ambos casos, el `buildspec.yml` sólo ejecuta el script.
6. **"Pipeline de cloud" = `cloud/up.ps1`** invocado por el `up.ps1` raíz. El módulo `modules/pipeline` **no está instanciado** y su imagen (`hashicorp/terraform`) no tiene PowerShell: **fuera de alcance** (coste diferido: ≈2-5 USD/mes si se activa, ver §11).
7. **Clave KMS gestionada** (`kms_key_id = null`): una CMK propia costaría **+1 USD/mes** (+0,03 USD/10.000 llamadas KMS) → se descarta hasta que haya requisito de custodia/rotación.
8. **`environment` por defecto `develop`**; los permisos IAM (CodeBuild `PutSecretValue` + Lambda `GetSecretValue`) **entran en este alcance**.
9. **Borrón y cuenta nueva**: los secretos legados se borran.
10. **Kebab-case** en todo el JSON del secreto.
11. Este plan **sustituye** a `plan-t04-secretos-secrets-manager.md`.

## 11. Costos

### AWS (el diseño apunta a minimizarlos)

| Concepto | Costo | Nota |
|---|---|---|
| **1 secreto / aplicación** (decisión de JSON único) | **0,40 USD/mes** | Frente a 3 secretos sueltos (1,20 USD/mes) → **ahorro 0,80 USD/mes**. Frente a los 5 legados actuales (4 signing + 1 residual ≈ 2,00 USD/mes) → **ahorro ≈ 1,60 USD/mes** al hacer borrón y cuenta nueva. |
| Cifrado | **0 USD** | KMS **gestionada** `aws/secretsmanager` incluida. Una **CMK propia costaría +1 USD/mes** (+0,03 USD/10.000 llamadas KMS): por eso `kms_key_id = null`. |
| `put-secret-value` / `get-secret-value` | **0,04 USD / 10.000 llamadas** | Despreciable: 1 get por despliegue de cloud + 1 get/put por build del frontend + (T06) 1 get por arranque de Lambda **con caché** (`SecretCache`) → ~decenas de llamadas/mes. |
| Estado de Terraform | **0 USD** | Local (sin S3/DynamoDB): al no meter el valor en el estado no hay backend remoto que pagar ni cifrar. |
| `delete-secret --force-delete-without-recovery` | **0 USD** | Borra definitivamente; sin ventana de recuperación no hay coste residual de secretos huérfanos. |
| **Total nuevo** | **≈ 0,40 USD/mes** por aplicación y entorno | 10 apps × 1 entorno ≈ 4 USD/mes. Cada **entorno adicional** añade **+0,40 USD/mes** (el secreto es `{{ENVIRONMENT}}/{{APPLICATION_ID}}`). |
| **Módulo `modules/pipeline` (fuera de alcance)** | CodePipeline 1 USD/mes + CodeBuild por minuto + S3 de artefactos + KMS propia 1 USD/mes | **No se instanció** en este plan; si en el futuro se activa, sumaría ≈ **2-5 USD/mes** adicionales. Se informa como coste diferido. |

### Esfuerzo
- **1 archivo a crear** + **~11 a modificar**, **3 capas** (Terraform cloud · script cloud · script/CI frontend) + 1 template backend → **tarea grande** → 3 features/PRs:
  1. `feature/t04-secreto-terraform` (T1.1-T1.7)
  2. `feature/t04-secreto-cloud-script` (T2.1-T2.2)
  3. `feature/t04-secreto-frontend-script` (T3.1-T3.5) + T4.1 manual
  → **3 sesiones**.

### Impacto de contexto/tokens
- Medio-alto en la fase 3 (`templates/up.ps1.scriban` del frontend es el fichero más grande del componente).

## 12. Fuera de alcance
- **T06**: `spring.config.import=optional:aws-secretsmanager:` y el caché de cliente (Sólo se deja el fallback de la property y el permiso IAM).
- **T05** (parámetros SSM) y la separación `/frontend/quizsmart/` en `ssm.tf`.
- Instanciar el módulo `modules/pipeline` y migrar su buildspec a PowerShell.
- Instalar Flutter en la imagen de CodeBuild.
- Rotación automática de secretos, replicación multi-región y CMK.
- Inyección de `api-key` real (hoy manual en AWS).
- Credenciales AWS (`AWS_ACCESS_KEY_ID/SECRET`): rol IAM, nunca en secretos.

## 13. Verificación (con autorización)

La verificación se hace **contra la fuente de verdad** (plantillas + `component.json`) y, sólo como *smoke test*, contra la salida **regenerada** (que no se edita):

```powershell
# 1) Fuente de verdad
dotnet build                                            # generator (requiere autorización)

# 2) Plantillas: no quedan placeholders sin resolver tras editar
#    (grep de {{ ... }} en los .scriban tocados en §8)

# 3) component.json: las 4 entradas de cloud/terraform/app/ y el directorio existen
#    (regla: plantilla no listada ⇒ no se genera)

# 4) Salida REGENERADA con el generador (no se edita a mano)
terraform -chdir=<salida>/cloud/terraform/app fmt -check
terraform -chdir=<salida>/cloud/terraform/app validate
terraform -chdir=<salida>/cloud/terraform/<ms> fmt -check

# 5) Secreto en AWS (operación sobre el servicio, no sobre archivos)
aws secretsmanager list-secrets --query 'SecretList[].Name'   # → <env>/<applicationId>
aws secretsmanager get-secret-value --secret-id <env>/<applicationId> --query SecretString

# 6) Scripts generados
pwsh <salida>/cloud/up.ps1 -PlanOnly
pwsh <salida>/frontend/<name>/up.ps1                  # sin firma
pwsh <salida>/frontend/<name>/up.ps1 -Sign            # con firma
```
