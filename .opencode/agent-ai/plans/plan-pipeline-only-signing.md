# Plan: Firmar el .aab solo en el pipeline (no en local)

**TODO relacionado:** Frontend #1 (refina "Generar el .aab firmado"), Frontend #2/#3 (secretos), DevSecOps #4 (D7: infra solo terraform).

**Fecha:** 2026-09-22 (v4 — decisiones D1-D7 y preguntas H1-H6 cerradas)

**Estado:** ✅ **IMPLEMENTADO** (sin tests y sin compilar, por indicación del usuario). Pendiente autorización para `dotnet build`/regenerar `projects/`/commit.

---

## 1. Descripción (Web Research)

- **Best practice CI/CD (Atlassian, GitHub Actions, Android docs):** el keystore de producción vive **solo en los secretos del pipeline**; nunca en máquinas de desarrollo ni en defaults del repo.
- **Flutter docs:** el `.aab` firmado para Play se genera en CI con `key.properties`; el dev local trabaja con builds **debug**.
- **Gradle:** `signingConfigs.release` con `check()` → release sin `key.properties` **falla** (fail-fast correcto: firmado solo en CI).
- **AWS:** `CreateSecret`/`GetSecretValue` se hacen desde el rol IAM de CodeBuild; el generador no necesita SDK de AWS para esta función.

## 2. Decisiones del usuario (2026-09-22)

| # | Decisión |
|---|----------|
| D1 | **El generador NO debe obtener nada de AWS** (al ejecutarlo aún no hay infraestructura creada). Cero llamadas AWS. |
| D2 | `defaults/android/upload-keystore.jks` es el keystore de respaldo → **borrarlo y quitarlo de `defaultFiles`**. |
| D3 | **El keystore se crea en el pipeline si no existe en AWS; si existe, se usa el que está en el secret manager.** (create-or-get dentro de CodeBuild) |
| D4 | Local: nada de keystore, `key.properties` ni variables de entorno con credenciales. |
| D5 | **El generador crea apps desde cero: en su ejecución aún no existe AWS secret manager → sin llamadas y SIN SIEMBRA.** Solo la pipeline decide: keystore existente → lo usa; no existe → lo crea. |
| D6 | **CodeCommit también se quita del generador** (servicios C#, paquete `AWSSDK.CodeCommit`, código comentado muerto, campo `SourceProvider`). La fuente de la pipeline frontend sigue siendo **GitHub** en `codepipeline.yml` (CloudFormation) — resuelto en H6 |
| D7 | **CodeCommit, CodeBuild y CodePipeline se crean SOLO con terraform** (TODO DevSecOps #4): el generador **no los crea por SDK** → fuera `PipelineDeployer`, `GitHubProvider`, `IRepositoryProvider` y **todos los paquetes `AWSSDK.*`** (generador 100% sin AWS). Terraform **conserva** CodeCommit (H4 = no migrar a GitHub). |

## 3. Hallazgos (forense de keystores, verificado antes de borrar nada)

| Keystore | Tamaño | SHA256 (16) | Contraseña conocida | Origen probable |
|---|---|---|---|---|
| **A** = `generator/.../defaults/android/upload-keystore.jks` | 2744 B | `E01C8A9A...` | ❌ **incorrecta** (`keytool error: password was incorrect`) | respaldo antiguo; contraseña perdida |
| **B** = `%TEMP%\epc-upload-keystore\...` **y** `projects/.../android/upload-keystore.jks` (idénticos) | 2106 B | `0362883C...` | ✅ abre con las env vars `ANDROID_COM_QUIZSMART_APP_STORE_PASSWORD` (alias `upload-com-quizsmart-app`, creado 19/09/2026) | el que estaba en los 4 secretos legacy (y con el que el pipeline firmaba) |

**Situación AWS actual:**
- Secretos legacy (4): **borrados con force** (sin recuperación).
- Secreto único `/epc/com.quizsmart.app/android-signing`: **NO existe** (`ResourceNotFoundException` verificado).
- Copias locales de B: env vars (User), `%TEMP%`, `projects/.../android/{upload-keystore.jks,key.properties}`.

**Implicaciones (según D5: apps desde cero, sin siembra):**
1. B es el único keystore utilizable hoy (A no abre sin su contraseña), pero A y B son **restos del enfoque anterior**: no se siembran en AWS.
2. En la **primer** ejecución de la pipeline para `com.quizsmart.app` se creará un keystore **nuevo** (y el secreto único). Si en el futuro una app ya publicada en Play necesitara conservar su clave, ese caso puntual se resolvería siembrando su secreto antes del primer run — fuera del alcance actual.
3. Borrar A (D2) elimina un archivo cuya contraseña se desconoce → sin pérdida funcional (recuperable solo si está trackeado en git).

## 4. Objetivo

- **Generador:** cero llamadas AWS, cero materialización local de secretos. Simplemente genera proyectos.
- **Pipeline (CodeBuild):** única fuente de firma — `get-secret-value`; si no existe, **crea** keystore con `keytool`, `create-secret` y firma; si existe, usa el de AWS.
- **Local:** `flutter build appbundle --release` falla con mensaje explícito; solo debug.

## 5. Tareas de implementación

### Tarea A — Generador: eliminar toda la lógica de firmado/AWS

| # | Subtarea | Detalle |
|---|---|---|
| A1 | `GeneratorApplication.cs` | Eliminar la llamada a `CreateAndroidSigningSecretsAsync` (línea ~80, bloque flutter) y los métodos `CreateAndroidSigningSecretsAsync` + `AssignSigningSecretsAsync` |
| A2 | Constructor de `GeneratorApplication` | Quitar parámetros `localSecretsProvider` e `ISecretsManager? secretsManager` (y `IAndroidSigningKeyGenerator signingKeyGenerator` si nada más lo usa) |
| A3 | `Program.cs` | Quitar `new LocalSecretsProvider()`, `new AwsSecretsManager(region)` y su paso al constructor; `var region` se elimina en A10.3 |
| A4 | **ELIMINAR archivos** | `Services/LocalSecretsProvider.cs`, `Services/ILocalSecretsProvider.cs`, `Services/AwsSecretsManager.cs`, `Services/ISecretsManager.cs`, `Services/AndroidSigningKeyGenerator.cs`, `Models/AndroidSigningSecrets.cs`, `Models/AndroidSigningSecretData.cs`, `Models/AndroidSigningSecretReferences.cs`, `Tests/Services/LocalSecretsProviderTests.cs`, `Tests/Services/AndroidSigningSecretDataTests.cs` |
| A5 | `GeneratorConstants.cs` | Quitar `AndroidSigningSecret*`, `Android*VariableFor()`, `KeyProperties*`, `KeystoreFileName`, `AndroidDirectoryName`, `AndroidKeystoreTemporaryDirectoryName`, `MaximumSecretSizeInBytes` (todo sin uso tras A1-A4) |
| A6 | `ErrorCodes`/`GeneratorMessages` | Quitar `MissingAwsRegion`, `SigningKeyCreationFailed`, `SigningSecretTooLarge`, `SigningSecretPersistenceFailed`, `InvalidSigningSecretFormat` y **`PipelineDeploymentFailed`/GEN020** (solo lo usaba `PipelineDeployer` — A10.1) *(verificar otros usos antes)* |
| A7 | `Generator.csproj` | **ELIMINAR todos los `PackageReference AWSSDK.*`** (SecretsManager, CodePipeline, CodeBuild, CodeCommit, CodeConnections, IdentityManagement, S3, SecurityToken): tras A4+A9+A10 no queda ningún `using Amazon.*` → generador sin dependencia AWS (D7) |
| A8 | Tests | `dotnet test` en verde (autorización para compilar) |

### Tarea A9 — CodeCommit: eliminar del generador (D6)

| # | Subtarea | Detalle |
|---|---|---|
| A9.1 | **ELIMINAR** `Services/CodeCommitService.cs` (121 líneas), `Services/CodeCommitProvider.cs` (46), `Services/GitService.cs` (65) | Solo los referencian bloques comentados / `PushToCodeCommitAsync`; `Program.cs` ya pasa `null` para `IGitService` |
| A9.2 | `Generator.csproj` | Quitar `<PackageReference Include="AWSSDK.CodeCommit">` |
| A9.3 | `GeneratorApplication.cs` | Quitar parámetro `IGitService? gitService` (línea 17) y los bloques comentados muertos (~82-104, ~219-238) que citan CodeCommit/`deployer` (TODO obsoleto: se cubre con TODO DevSecOps #4) |
| A9.4 | `Program.cs` | Quitar el `null` de `gitService` en `new GeneratorApplication(...)` |
| A9.5 | ~~`PipelineDeployer.cs` línea 144~~ | **Obsoleto → A10.1**: se elimina el archivo entero (no solo `codecommit:*`) |
| A9.6 | `Models/EpcConfiguration.cs` + `target/com.quizsmart.app.json` | Quitar campo `SourceProvider` (default `"codecommit"`, solo lo leía el código comentado) y la línea `"sourceProvider": "codecommit"` (los campos `GitHub*` los completa A10.5) |
| A9.7 | ~~**NO tocar** providers/deployer~~ | **Obsoleto → D7 (A10.1)**: `IRepositoryProvider`, `GitHubProvider` y `PipelineDeployer` también se eliminan (solo los usaba el SDK) |

### Tarea A10 — SDK de infraestructura: fuera (D7)

CodeCommit/CodeBuild/CodePipeline (y S3/IAM/STS/CodeConnections) se crean **solo con terraform** → el generador elimina su creación por SDK.

| # | Subtarea | Detalle |
|---|---|---|
| A10.1 | **ELIMINAR** `Services/PipelineDeployer.cs` (240), `Services/GitHubProvider.cs` (57), `Services/IRepositoryProvider.cs` (8) | Solo los usaba el flujo comentado `CreatePipelineDeployerAsync` (borrado en A9.3); `Program.cs` ya pasa `null` |
| A10.2 | `GeneratorApplication.cs` | Quitar parámetros `IPipelineDeployer? pipelineDeployer` e `IGitService? gitService` (líneas 16-17) |
| A10.3 | `Program.cs` | Quitar los dos `null` del constructor y `var region = ...` (línea 27): nada queda que lea `AWS_REGION` |
| A10.4 | `GeneratorConstants.cs` / `ErrorCodes` / `GeneratorMessages` | −`AwsRegionVariable`, −GEN016 `MissingAwsRegion`, −`MissingAwsRegion()` (cierra A5/A6) |
| A10.5 | `EpcConfiguration.cs` + `target/com.quizsmart.app.json` | −`FrontendConfiguration.{SourceProvider,GitHubOwner,GitHubRepo,GitHubBranch}` (solo los leían el deployer y los bloques comentados; `GenerationPlanBuilder` no los usa) y sus líneas del JSON (`sourceProvider`, `gitHubRepo`, `gitHubBranch`) — si otros JSON las conservan, verificar que `JsonFileReader` ignora propiedades extra |
| A10.6 | **NO tocar** | `templates/codepipeline.yml.scriban` (CloudFormation) **se queda como está** (H5) salvo la Tarea D2 (+`secretsmanager:CreateSecret`). `Cloud.PipelineConfiguration`/`Cloud.Secrets` se conservan: config para terraform (D7) |

### Tarea B — Gradle: mensaje explícito

| # | Subtarea | Detalle |
|---|---|---|
| B1 | `templates/android/app/build.gradle.kts.scriban` | Mantener `check()`; mensaje nuevo: `"Release AAB is signed only in the CI pipeline (CodePipeline). Use flutter build apk --debug locally."` |

### Tarea C — README: solo pipeline

| # | Subtarea | Detalle |
|---|---|---|
| C1 | Sección "Android signing" | Keystore vive solo en AWS Secrets Manager; el `.aab` firmado **solo sale del pipeline**; en la **primera** ejecución de la pipeline se crea el secreto si no existe |
| C2 | Sección "Local build" | **Eliminar** el bloque `aws secretsmanager get-secret-value ...` (0 exposición del secreto a devs) |

### Tarea D — Pipeline: create-or-get del keystore

| # | Subtarea | Detalle |
|---|---|---|
| D1 | `templates/buildspec.yml.scriban` | En `pre_build`, sustituir el `get-secret-value` directo por **create-or-get**: |
| | | a. Intentar `get-secret-value --secret-id "/epc/$APPLICATION_ID/android-signing"` → si OK: `SECRET_JSON=...` |
| | | b. Si falla (`ResourceNotFoundException`): generar keystore en el build: `keytool -genkeypair -alias upload-$APPLICATION_ID -keyalg RSA -keysize 2048 -validity 10000 -storetype JKS -keystore android/upload-keystore.jks -storepass "$PW" -keypass "$PW" -dname "CN=$APPLICATION_ID"` con `PW=$(openssl rand -base64 24 | tr -d '/+=')`; montar JSON (`jq -n`) con `keyAlias/storePassword/keyPassword/keystoreBase64`; `aws secretsmanager create-secret --name "/epc/$APPLICATION_ID/android-signing" --secret-string "$JSON"` |
| | | c. Con `SECRET_JSON` disponible: `jq` extrae keystore/passwords → `key.properties` (flujo actual) → build → `post_build` limpia ✔ |
| | | d. Añadir guard `test -n "$SECRET_JSON" || exit 1` (mensaje claro) |
| D2 | `templates/codepipeline.yml.scriban` | IAM CodeBuild: añadir `secretsmanager:CreateSecret` (hoy solo `GetSecretValue`) sobre `.../android-signing-*`. `DescribeSecret` no hace falta (se usa el error de `GetSecretValue`) |
| D3 | Verificación | Primer run de la pipeline con la decisión de H1 (sembrar vs crear nuevo) |

### Tarea E — defaults: keystore estático (decidido: borrar)

| # | Subtarea | Detalle |
|---|---|---|
| E1 | `component.json` | Quitar `"defaults/android/upload-keystore.jks"` de `defaultFiles` |
| E2 | Borrar `defaults/android/upload-keystore.jks` | Decidido por el usuario (⚠ es A: contraseña desconocida; confirmar H1 antes por prudencia — ver §3)

### Tarea F — Siembra: NO aplicable (decidido en D5)

El generador no siembra ni consulta AWS. La pipeline, en su **primer run**, ejecuta el create-or-get de la Tarea D1: como el secreto no existe, generará el keystore y lo almacenará. No se requiere paso manual de siembra.

### Tarea G — Limpieza local (restos del enfoque anterior)

| # | Subtarea | Detalle |
|---|---|---|
| G1 | Borrar copias locales de B | `projects/.../android/upload-keystore.jks`, `projects/.../android/key.properties`, `%TEMP%\epc-upload-keystore\` |
| G2 | Borrar env vars (User) | `ANDROID_COM_QUIZSMART_APP_{STORE_PASSWORD,KEY_PASSWORD,KEY_ALIAS,KEYSTORE_FILE}` |
| G3 | Regenerar | Ejecutar el generador → README/buildspec/gradle nuevos, sin firma local |

## 6. Flujo de datos (nuevo)

```
1. Desarrollador ejecuta el generador
   → genera proyectos (Scriban)                               [0 llamadas AWS, 0 escrituras de secretos]

2. push a main → CodePipeline → CodeBuild (pre_build)
   → aws secretsmanager get-secret-value "/epc/<appId>/android-signing"
      ├─ existe  → SECRET_JSON desde AWS                      [1 llamada]
      └─ no existe → keytool genera keystore
                   → jq monta JSON → create-secret            [1 get (falló) + 1 create]
   → jq extrae campos → android/upload-keystore.jks + key.properties (temporales)
   → flutter build appbundle --release → .aab FIRMADO
   → post_build: borra ambos archivos
   → artefacto firmado en S3

3. Desarrollador local
   → flutter build appbundle --release → Gradle check() falla
     "signed only in the CI pipeline"                         [0 llamadas AWS]
   → flutter build apk --debug para pruebas
```

## 7. Archivos a crear

| Archivo | Propósito |
|---|---|
| `agent-ai/plans/plan-pipeline-only-signing.md` | Este plan |

## 8. Archivos a crear / eliminar / modificar

**ELIMINAR (Tareas A4 + A9 + A10 + E2):**
| Archivo | Motivo |
|---|---|
| `generator/Services/LocalSecretsProvider.cs` | sin consumidor (D1/D4) |
| `generator/Services/ILocalSecretsProvider.cs` | ídem |
| `generator/Services/AwsSecretsManager.cs` | el generador ya no toca AWS |
| `generator/Services/ISecretsManager.cs` | ídem |
| `generator/Services/AndroidSigningKeyGenerator.cs` | el keystore ahora se crea en la pipeline (D3) |
| `generator/Models/AndroidSigningSecrets.cs` | sin uso |
| `generator/Models/AndroidSigningSecretData.cs` | sin uso |
| `generator/Models/AndroidSigningSecretReferences.cs` | sin uso |
| `generator.Tests/Services/LocalSecretsProviderTests.cs` | prueba de código eliminado |
| `generator.Tests/Services/AndroidSigningSecretDataTests.cs` | ídem *(ya borrados por el usuario)* |
| `generator/components/frontend/flutter3.47.2/defaults/android/upload-keystore.jks` | D2 |
| `generator/Services/CodeCommitService.cs` | D6 — solo lo usaba el código comentado |
| `generator/Services/CodeCommitProvider.cs` | D6 — ídem |
| `generator/Services/GitService.cs` | D6 — solo `PushToCodeCommitAsync` |
| `generator/Services/PipelineDeployer.cs` | D7 — creación por SDK (CodePipeline/CodeBuild/IAM/S3/STS) |
| `generator/Services/GitHubProvider.cs` | D7 — solo lo usaba `PipelineDeployer` (CodeConnections) |
| `generator/Services/IRepositoryProvider.cs` | D7 — interfaz de los dos providers |

**MODIFICAR:**
| Archivo | Cambio |
|---|---|
| `generator/Services/GeneratorApplication.cs` | Quitar flujo de firmado (A1-A2), `gitService`/`pipelineDeployer` y bloques comentados (A9.3, A10.2) |
| `generator/Program.cs` | Quitar provider/secretsManager, `null`s y `region` (A3, A9.4, A10.3) |
| `generator/Generator.csproj` | −**todos** los `AWSSDK.*` (A7, A9.2) |
| `generator/Models/EpcConfiguration.cs` | −`SourceProvider`/`GitHubOwner`/`GitHubRepo`/`GitHubBranch` (A9.6, A10.5) |
| `generator/target/com.quizsmart.app.json` | −líneas `sourceProvider`/`gitHubRepo`/`gitHubBranch` (A9.6, A10.5) |
| `generator/Configuration/GeneratorConstants.cs` | Quitar consts sin uso (A5) |
| `generator/Messages/ErrorCodes.cs` / `GeneratorMessages.cs` | Quitar códigos/mensajes sin uso (A6) |
| `generator/components/frontend/flutter3.47.2/component.json` | Quitar defaultFile del keystore (E1) |
| `generator/components/.../templates/README.md.scriban` | Secciones firma/local-build → solo pipeline (C1-C2) |
| `generator/components/.../templates/android/app/build.gradle.kts.scriban` | Mensaje de `check()` (B1) |
| `generator/components/.../templates/buildspec.yml.scriban` | Create-or-get del secreto (D1) |
| `generator/components/.../templates/codepipeline.yml.scriban` | +`secretsmanager:CreateSecret` (D2) |
| `agent-ai/docs/pipeline-flutter-debugging.md` | Actualizar: aún documenta los 4 secretos legacy |

## 9. Preguntas / Decisiones pendientes

| # | Pregunta | Recomendación |
|---|---|---|
| H1 | ~~Siembrar keystore B?~~ | **Resuelto por D5**: sin siembra; la pipeline crea el keystore en su primer run; A y B se limpian (Tarea G) |
| H2 | ~~¿Eliminar TODO el código C# de firmado?~~ | **Resuelto: SÍ** — eliminar los 14 archivos (firmado 8 + CodeCommit 3 + SDK 3) y todo el código embebido (A1-A6, A9, A10) |
| H3 | ~~Borrar A (defaults)?~~ | **Resuelto por D2**: borrar archivo + quitar de `defaultFiles` |
| H4 | ~~¿terraform pasa a GitHub?~~ | **Resuelto por D7**: **NO** — terraform sigue creando `aws_codecommit_repository`; lo que desaparece es el SDK del generador. `todo.md` #4 y `plan-aws-secrets-pipeline.md` **no cambian** |
| H5 | ~~¿Migrar la pipeline frontend de CloudFormation a terraform?~~ | **Resuelto: NO — se queda como está** `codepipeline.yml.scriban`. CloudFormation no es el SDK ni viola D7 (que aplica al TODO #4). La Tarea D2 sigue sobre ella |
| H6 | ~~"Ya no tenemos integración con github": ¿alcanza a `codepipeline.yml`/README?~~ | **Resuelto: SOLO los 3 archivos C#** (`PipelineDeployer`, `GitHubProvider`, `IRepositoryProvider`). `codepipeline.yml.scriban` y `README.md.scriban` **conservan GitHub** como fuente; no se tocan por esto. Los campos `GitHub*`/`SourceProvider` de `FrontendConfiguration` sí se quitan (A10.5): solo los leían el deployer y el código comentado |

## 10. Costos

| Concepto | Antes (tarea #2/#3) | Después |
|---|---|---|
| Almacenamiento SM | $0.40/mes (1 secreto) | $0.40/mes (sin cambio) |
| API en el **generador** | 0 (acierto env/local) u 8-16 (fallo) | **0 (nunca toca AWS)** |
| API en la **pipeline** | 1 `GetSecretValue`/build | 1 `GetSecretValue`/build; **+1 `CreateSecret` solo en el primer run** (~$0.000005) |
| Servicios nuevos | — | $0 (KMS managed incluido, sin rotation) |

Beneficio: seguridad (keystore solo en AWS y efímero en CodeBuild), −$0.00001/run, y el generador funciona **sin credenciales AWS**.

## 11. Orden de ejecución

1. ~~Confirmar H2 y H5~~ **Cerrados: H1-H6 todos resueltos** → plan listo para implementar.
2. Tareas A + A9 + A10 (firmado, CodeCommit y SDK de infra) + `dotnet test` en verde (previa autorización).
3. Tareas B, C, D (plantillas) — D1 create-or-get + D2 IAM `CreateSecret`.
4. Tarea E (borrar defaults keystore + `defaultFiles`).
5. Tarea G (limpieza local: env vars, `%TEMP%`, `key.properties`/`jks` del proyecto).
6. Regenerar `projects/com.quizsmart.app` y push → verificar 1er run de la pipeline: **crea** el keystore y el secreto único, AAB firmado en S3.
7. TODO DevSecOps #4 sigue su curso aparte: CodeCommit+CodeBuild+CodePipeline **por terraform** (sin SDK).
