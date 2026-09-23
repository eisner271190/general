# Debugging Pipeline Flutter AAB en AWS CodeBuild

## Resumen

Pipeline CI/CD para compilar un Flutter AAB (Android App Bundle) firmado usando AWS CodeCommit + CodeBuild + CodePipeline. Se encontraron y resolvieron **7 errores** durante el diagnóstico.

**Proyecto:** `com.quizsmart.app`  
**Framework:** Flutter 3.47.2, Dart 3.13.2  
**Docker image:** `ghcr.io/gmeligio/flutter-android:3.47.2`  
**Region:** `us-east-1`

---

## Errores encontrados y soluciones

### Error 1: `YAML_FILE_ERROR: YAML file does not exist`

**Mensaje de CodeBuild:**
```
YAML_FILE_ERROR: YAML file does not exist
```

**Causa:** El buildspec se generaba en `frontend/quizsmart/buildspec.yml` pero CodeBuild lo busca en la raíz del repositorio.

**Solución:** Copiar `buildspec.yml` a la raíz del directorio del proyecto antes de subir a CodeCommit. En el generador, `GeneratorApplication.cs` se encarga de esto al final de la generación.

---

### Error 2: Filtro excluía archivos `.gradle.kts` por subcadena

**Mensaje:** Flutter falla con `Build failed due to use of deleted Android v1 embedding`

**Causa raíz:** En `CodeCommitService.cs`, el patrón de exclusión `.gradle` en la línea 40 usaba `f.Contains(".gradle")`. Esto coincidía con `build.gradle.kts` y `settings.gradle.kts` porque contienen `.gradle` como subcadena.

```csharp
// ANTES (bug):
var excludePatterns = new[] { ..., ".gradle", ... };
// f.Contains(".gradle") matchea "build.gradle.kts" → EXCLUIDO

// DESPUÉS (fix):
var excludePatterns = new[] { ..., "local.properties" };
var excludeDirPatterns = new[] { 
    $"{Path.DirectorySeparatorChar}.gradle{Path.DirectorySeparatorChar}", // \.gradle\ en Windows
    $"/.gradle/" // /.gradle/ en Linux/Mac
};
```

**Archivos afectados en CodeCommit:**
- `android/app/build.gradle.kts` — FALTABA
- `android/build.gradle.kts` — FALTABA
- `android/settings.gradle.kts` — FALTABA

**Por qué Flutter detectaba v1 embedding:**

El método `computeEmbeddingVersion()` en `project.dart` de Flutter verifica:
1. Si `appManifestFile` existe
2. Si `isUsingGradle` es true (busca `build.gradle.kts` en `android/app/`)
3. Si el AndroidManifest.xml tiene `flutterEmbedding=2`

Sin `build.gradle.kts`:
- `isUsingGradle = false`
- `appManifestFile` se resuelve a `android/AndroidManifest.xml` (no `android/app/src/main/AndroidManifest.xml`)
- No encuentra el archivo → retorna v1 embedding
- Flutter aborta: "Build failed due to use of deleted Android v1 embedding"

**Solución completa:**
1. Fix en `CodeCommitService.cs` (generador)
2. Subir manualmente los 3 archivos `.gradle.kts` a CodeCommit para el proyecto existente

---

### Error 3: CodeBuild falla UPLOAD_ARTIFACTS — permisos S3

**Mensaje de CodeBuild:**
```
AccessDenied: User: arn:aws:sts::577638384397:assumed-role/com-quizsmart-app-codebuild-role/
AWSCodeBuild-fe704f02-... is not authorized to perform: s3:PutObject on resource: 
"arn:aws:s3:::com-quizsmart-app-aab-artifacts/..."
```

**Causa:** El policy IAM `S3ArtifactsAccess` del CodeBuild role solo tenía permisos de lectura (`s3:GetObject`, `s3:GetObjectVersion`, `s3:GetBucketVersioning`), faltaba `s3:PutObject` para subir artifacts.

**Solución:**

En `PipelineDeployer.cs`, línea 122, agregar `s3:PutObject`:

```csharp
// ANTES:
var s3Policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:GetObjectVersion\",\"s3:GetBucketVersioning\"],...

// DESPUÉS:
var s3Policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:GetObjectVersion\",\"s3:GetBucketVersioning\",\"s3:PutObject\"],...
```

Para el proyecto existente, se actualizó el policy con:
```bash
aws iam put-role-policy \
  --role-name com-quizsmart-app-codebuild-role \
  --policy-name S3ArtifactsAccess \
  --policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Action":["s3:GetObject","s3:GetObjectVersion","s3:GetBucketVersioning","s3:PutObject"],
      "Resource":["arn:aws:s3:::com-quizsmart-app-aab-artifacts/*","arn:aws:s3:::com-quizsmart-app-aab-artifacts"]
    }]
  }'
```

---

### Error 4: Gradle Daemon OOM — `DaemonDisappearedException`

**Mensaje de CodeBuild:**
```
FAILURE: Build failed with an exception.
* What went wrong:
Gradle build daemon disappeared unexpectedly (it may have been killed or may have crashed)
org.gradle.launcher.daemon.client.DaemonDisappearedException
```

**Causa:** El `gradle.properties` tenía `org.gradle.jvmargs=-Xmx8G` pero el compute type `BUILD_GENERAL1_MEDIUM` solo tiene 7 GB de RAM. El daemon JVM pedía 8 GB, el SO lo mataba (OOM killer).

**Solución:**
1. Reducir `Xmx8G` → `Xmx4G` en `gradle.properties`
2. Agregar `org.gradle.daemon=false` para evitar el overhead del daemon

```properties
# ANTES:
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError

# DESPUÉS:
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.daemon=false
```

Aplicado tanto al proyecto como al template del generador (`gradle.properties.scriban`).

---

### Error 5: `--no-daemon` no es un flag válido de Flutter

**Causa:** Se intentó pasar `--no-daemon` al comando `flutter build appbundle --release --verbose --no-daemon`. Este flag es de **Gradle**, no de Flutter. Flutter no lo reconoce y muestra el mensaje de ayuda.

**Mensaje:**
```
BUILD EXIT=64
Run 'flutter -h' (or 'flutter <command> -h') for available flutter commands and options.
```

**Solución:** En lugar de pasar `--no-daemon` como argumento a Flutter, se deshabilita el daemon en `gradle.properties` con `org.gradle.daemon=false`. Así Gradle no inicia daemon cuando Flutter lo invoca internamente.

---

### Error 6: `echo "..." > file` producía archivos vacíos en Docker

**Causa:** En la imagen Docker `ghcr.io/gmeligio/flutter-android:3.47.2`, los comandos `echo "contenido" > archivo` producían archivos vacíos (0 bytes). Esto se debía a que el shell en la imagen Docker maneja redirecciones de manera diferente.

**Solución:** Usar `printf ... | tee file` en lugar de `echo "..." > file`:

```bash
# ANTES (falla — archivo vacío):
echo "sdk.dir=/path/to/sdk" > local.properties

# DESPUÉS (funciona):
printf "sdk.dir=%s\nflutter.sdk=%s\n" "$ANDROID_SDK" "$FLUTTER_SDK" | tee local.properties
```

---

### Error 7: `export` y `VAR=value` no persisten entre comandos YAML

**Causa:** En CodeBuild buildspec v0.2, cada ítem `-` de la lista YAML se ejecuta en un shell separado. Las variables asignadas con `VAR=value` (sin `export`) no persisten entre ítems.

```yaml
# ESTO NO FUNCIONA:
- VAR=value    # Shell 1: VAR=value se pierde
- echo $VAR    # Shell 2: VAR está vacío

# ESTO FUNCIONA:
- export VAR=value    # Shell 1: export persiste en el entorno de CodeBuild
- echo $VAR           # Shell 2: VAR tiene el valor
```

**Solución:** Usar `&&` para encadenar comandos que dependen de variables, o usar `export` cuando el valor necesita persistir.

---

## Archivos modificados en el generador

| Archivo | Cambios |
|---|---|
| `generator/Services/CodeCommitService.cs` | Patrón `.gradle` → `\.gradle\` + `/.gradle/` para no excluir `build.gradle.kts` |
| `generator/Services/PipelineDeployer.cs` | Agregado `s3:PutObject` al policy S3 + Docker image `ghcr.io/gmeligio/flutter-android:3.47.2` |
| `generator/Tools/Program.cs` | Utilidad para subir buildspec manualmente a CodeCommit |
| `templates/buildspec.yml.scriban` | Docker image + `printf | tee` + `set -o pipefail` + `exit $EXIT` |
| `templates/pubspec.yaml.scriban` | `flutter_secure_storage: ^10.0.0` → `^11.2.0` |
| `templates/android/gradle.properties.scriban` | `Xmx8G` → `Xmx4G`, agregado `org.gradle.daemon=false` |

## Buildspec exitoso (referencia)

```yaml
version: 0.2

env:
  variables:
    APPLICATION_ID: "com.quizsmart.app"

phases:
  pre_build:
    commands:
      - git config --global --add safe.directory /home/flutter/sdks/flutter
      - flutter --version
      - dart --version
      - java -version 2>&1
      - echo "ANDROID_HOME=$ANDROID_HOME"
      - echo "JAVA_HOME=$JAVA_HOME"
      # AWS CLI
      - pip install awscli 2>/dev/null || pip3 install awscli 2>/dev/null || (curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && cd /tmp && unzip -q awscliv2.zip && ./aws/install 2>/dev/null)
      - aws --version
      # local.properties
      - 'ANDROID_SDK="$ANDROID_HOME" && FLUTTER_SDK=$(which flutter | sed "s|/bin/flutter||") && printf "sdk.dir=%s\nflutter.sdk=%s\nflutter.buildMode=release\nflutter.versionName=1.0.0\nflutter.versionCode=1\n" "$ANDROID_SDK" "$FLUTTER_SDK" | tee "$CODEBUILD_SRC_DIR/frontend/quizsmart/android/local.properties" && echo "local.properties OK"'
      # Keystore create-or-get (esquema actual: secreto unico JSON; el keystore lo crea la pipeline si no existe)
      - 'SECRET_NAME="/epc/com.quizsmart.app/android-signing"; KS="$CODEBUILD_SRC_DIR/frontend/quizsmart/android/upload-keystore.jks"; SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query SecretString --output text 2>/dev/null) || SECRET_JSON=""; if [ -z "$SECRET_JSON" ]; then echo "Secreto no existe, generando keystore con keytool"; PW=$(openssl rand -base64 24 | tr -d "/+="); keytool -genkeypair -alias "upload-com.quizsmart.app" -keyalg RSA -keysize 2048 -validity 10000 -storetype JKS -keystore "$KS" -storepass "$PW" -keypass "$PW" -dname "CN=com.quizsmart.app" && SECRET_JSON=$(jq -n --arg keyAlias "upload-com.quizsmart.app" --arg storePassword "$PW" --arg keyPassword "$PW" --arg keystoreBase64 "$(base64 -w0 < "$KS")" "{keyAlias:\$keyAlias,storePassword:\$storePassword,keyPassword:\$keyPassword,keystoreBase64:\$keystoreBase64}") && aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$SECRET_JSON" >/dev/null && echo "Secreto creado: $SECRET_NAME" || { echo "ERROR: no se pudo crear el secreto de firma $SECRET_NAME"; exit 1; }; fi; test -n "$SECRET_JSON" || { echo "ERROR: no se pudo obtener el secreto de firma $SECRET_NAME"; exit 1; }; echo "$SECRET_JSON" | jq -r ".keystoreBase64" | base64 --decode > "$KS" && STORE_PW=$(echo "$SECRET_JSON" | jq -r ".storePassword") && KEY_PW=$(echo "$SECRET_JSON" | jq -r ".keyPassword") && KEY_ALIAS=$(echo "$SECRET_JSON" | jq -r ".keyAlias") && printf "storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=upload-keystore.jks\n" "$STORE_PW" "$KEY_PW" "$KEY_ALIAS" | tee "$CODEBUILD_SRC_DIR/frontend/quizsmart/android/key.properties" && echo "Keystore OK: $(wc -c < "$KS") bytes" && echo "key.properties OK"'

  build:
    commands:
      - 'set -o pipefail && chmod +x "$CODEBUILD_SRC_DIR/frontend/quizsmart/android/gradlew" && cd "$CODEBUILD_SRC_DIR/frontend/quizsmart" && START=$(date +%s) && flutter build appbundle --release --verbose 2>&1 | tee /tmp/flutter_full.log; EXIT=$?; END=$(date +%s); echo "=== BUILD RESULT ==="; echo "BUILD EXIT=$EXIT"; echo "BUILD SECONDS=$((END - START))"; echo "=== LAST 200 LINES ==="; tail -200 /tmp/flutter_full.log; echo "=== END ==="; exit $EXIT'

  post_build:
    commands:
      - rm -f "$CODEBUILD_SRC_DIR/frontend/quizsmart/android/key.properties"
      - rm -f "$CODEBUILD_SRC_DIR/frontend/quizsmart/android/upload-keystore.jks"
      - echo "Cleanup completed"

artifacts:
  files:
    - frontend/quizsmart/build/app/outputs/bundle/release/app-release.aab
  discard-paths: no
  name: $APPLICATION_ID-aab-$CODEBUILD_BUILD_ID
```

## Docker image utilizada

**`ghcr.io/gmeligio/flutter-android:3.47.2`**

| Componente | Versión |
|---|---|
| Flutter | 3.47.2 |
| Dart | 3.13.2 |
| JDK | 17 |
| Android SDK | 36.0.0 |
| `ANDROID_HOME` | `/home/flutter/sdks/android-sdk` |
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk-amd64` |

**Requisitos:**
- `git config --global --add safe.directory /home/flutter/sdks/flutter` (evita "dubious ownership")
- AWS CLI no viene instalado — se instala via `pip` o `curl` en pre_build

## Recursos AWS

| Recurso | Nombre |
|---|---|
| S3 Bucket | `com-quizsmart-app-aab-artifacts` |
| CodeCommit Repo | `quizsmart` |
| IAM Role CodeBuild | `com-quizsmart-app-codebuild-role` |
| IAM Role CodePipeline | `com-quizsmart-app-codepipeline-role` |
| CodeBuild Project | `com-quizsmart-app-flutter-aab` |
| CodePipeline | `com-quizsmart-app-aab-pipeline` |
| CloudWatch Log Group | `/aws/codebuild/com-quizsmart-app-flutter-aab` |

## Resultado final

```
|  Source |  Succeeded  |
|  Build  |  Succeeded  |
```

BUILD EXIT=0 en ~580 segundos (~10 min) con `--release`.
