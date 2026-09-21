# Plan: Reducir llamadas a Secret Manager + Un solo secret por app

## Objetivo

1. Reducir la cantidad de llamadas a AWS Secrets Manager verificando primero variables de entorno y archivos locales.
2. Consolidar los 4 secretos actuales (keystore, store-password, key-password, key-alias) en un único secreto JSON por aplicación.
3. Actualizar el pipeline (CodePipeline + CodeBuild) para trabajar con el nuevo formato de secreto único.

## Reglas de codificación aplicables

- **SRP**: Cada clase con una responsabilidad clara. `AwsSecretsManager` maneja AWS, la lógica de verificación local va en servicios separados.
- **DIP**: Alto nivel depende de abstractions. Ya se usa `ISecretsManager`.
- **Naming**: Identificadores en inglés, PascalCase, verbos para métodos, sustantivos para modelos.
- **Architecture**: Application orquesta, Infrastructure implementa.
- **Hardcoded Values**: Usar `const` para nombres de archivos y carpetas en `GeneratorConstants`.
- **Validation**: Validar configuración requerida antes de resolver componentes. Fallar rápido.
- **Testing**: Agregar unit tests para la nueva lógica de verificación local.
- **Change Discipline**: El cambio más pequeño que resuelve el requisito.

## Estado actual

### Problema 1: Demasiadas llamadas API
- `GetAsync()` ejecuta 4 `DescribeSecretAsync` + 4 `GetSecretValueAsync` = **8 llamadas**
- `StoreAsync()` ejecuta 4 `DescribeSecretAsync` + 4 `CreateSecretAsync` = **8 llamadas**
- **Total: hasta 16 llamadas API por aplicación**

### Problema 2: 4 secretos por app
- Cada app crea 4 secretos separados en `/epc/{applicationId}/android-signing/`:
  - `keystore` (binario)
  - `store-password` (texto)
  - `key-password` (texto)
  - `key-alias` (texto)

### Problema 3: Pipeline con 4 llamadas separadas
- `buildspec.yml` ejecuta 4 llamadas `aws secretsmanager get-secret-value`
- IAM policy usa wildcard: `secret:/epc/${ApplicationId}/android-signing/*`

## Investigación

AWS Secrets Manager soporta secretos JSON de hasta 65.536 bytes. Un `.jks` típico pesa 2-10 KB. Combinarlos en un solo JSON es factible.

Referencia: https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieving-secret.html

## Flujo optimizado

| Escenario | Antes | Después |
|-----------|-------|---------|
| Generador (env vars) | 16 | **0** |
| Generador (archivos locales) | 16 | **0** |
| Generador (AWS lectura) | 8 | **2** |
| Generador (AWS creación) | 8 | **2** |
| Pipeline (lectura) | 4 | **1** |

## Tareas de implementación

### Punto 2: Verificación local primero

1. Crear `LocalSecretsProvider.cs` (SRP: solo verifica fuentes locales):
   - Método `TryGetSecrets(string applicationId, string outputDirectory)`:
     - Verificar variables de entorno `ANDROID_{APP_ID}_KEY_ALIAS`, `ANDROID_{APP_ID}_STORE_PASSWORD`, `ANDROID_{APP_ID}_KEY_PASSWORD`.
     - Si las 3 existen, leer keystore desde `ANDROID_{APP_ID}_KEYSTORE_FILE` si existe.
     - Buscar `{outputDir}/android/key.properties` y parsear propiedades.
     - Verificar que `{outputDir}/android/upload-keystore.jks` existe.
     - Retornar `AndroidSigningSecrets` o `null`.
   - Implementar `ILocalSecretsProvider` para DIP.

2. Modificar `GeneratorApplication.CreateAndroidSigningSecretsAsync()`:
   - Inyectar `ILocalSecretsProvider`.
   - Llamar `localSecretsProvider.TryGetSecrets()` primero.
   - Si retorna `null`, proceder con `secretsManager.GetAsync()` (flujo actual).

### Punto 3: Un solo secret por app

3. Crear `AndroidSigningSecretData.cs` (DTO para serialización JSON):
   ```csharp
   internal sealed record AndroidSigningSecretData(
       string KeyAlias,
       string StorePassword,
       string KeyPassword,
       string KeystoreBase64);
   ```

4. Modificar `AndroidSigningSecretReferences.cs`:
   - Simplificar a un solo campo: `string SecretName`.

5. Modificar `AwsSecretsManager.cs`:
   - `GetAsync()`: 1 `DescribeSecret` + 1 `GetSecretValue` → deserializar JSON + decodificar base64.
   - `StoreAsync()`: 1 `DescribeSecret` + 1 `CreateSecret` → serializar JSON con keystore en base64.
   - Validar JSON recuperado (campos requeridos) antes de usar (Fail Fast).

6. Actualizar `GeneratorConstants.cs`:
   - Agregar constantes para nombres de archivos: `KeyPropertiesFileName`, `KeystoreFileName`, `AndroidDirectory`.
   - Actualizar path del secreto: `/epc/{applicationId}/android-signing` (sin subdirectorios).

### Punto 3: Pipeline

7. Modificar `buildspec.yml.scriban`:
   - Leer un solo secreto JSON en `pre_build`.
   - Extraer campos con `jq`:
     ```bash
     SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_PREFIX" --query SecretString --output text)
     KEYSTORE_B64=$(echo "$SECRET_JSON" | jq -r '.keystore')
     STORE_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.storePassword')
     KEY_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.keyPassword')
     KEY_ALIAS=$(echo "$SECRET_JSON" | jq -r '.keyAlias')
     ```

8. Modificar `codepipeline.yml.scriban`:
   - Actualizar IAM policy para apuntar al secreto único:
     ```yaml
     Resource: !Sub 'arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:/epc/${ApplicationId}/android-signing'
     ```

### Testing

9. Agregar unit tests:
   - `LocalSecretsProviderTests.cs`: probar detección de env vars, archivos locales, y fallback a null.
   - `AwsSecretsManagerTests.cs`: probar serialización/deserialización del JSON consolidado.
   - `GeneratorApplicationTests.cs`: probar flujo completo con mock de `ILocalSecretsProvider` e `ISecretsManager`.

## Archivos a crear

- `generator/Services/LocalSecretsProvider.cs`: verificación de fuentes locales.
- `generator/Services/ILocalSecretsProvider.cs`: contrato para DIP.
- `generator/Models/AndroidSigningSecretData.cs`: DTO para serialización JSON.
- `generator.Tests/Services/LocalSecretsProviderTests.cs`: unit tests.
- `generator.Tests/Services/AwsSecretsManagerTests.cs`: unit tests del JSON consolidado.

## Archivos a modificar

- `generator/Services/GeneratorApplication.cs`: inyectar `ILocalSecretsProvider`, modificar flujo.
- `generator/Services/AwsSecretsManager.cs`: consolidar en un solo secreto JSON.
- `generator/Services/ISecretsManager.cs`: actualizar contrato.
- `generator/Models/AndroidSigningSecretReferences.cs`: simplificar a un solo nombre.
- `generator/Configuration/GeneratorConstants.cs`: agregar constantes de archivos.
- `generator/components/frontend/flutter3.47.2/templates/buildspec.yml.scriban`: leer un solo JSON.
- `generator/components/frontend/flutter3.47.2/templates/codepipeline.yml.scriban`: actualizar IAM policy.

## Preguntas de implementación

1. ¿Se debe validar el formato del JSON recuperado de AWS? → Sí, validar campos requeridos antes de usar (Fail Fast).
2. ¿Se debe mantener compatibilidad con el formato anterior (4 secretos)? → No, es un cambio de formato nuevo.
3. ¿Se debe instalar `jq` en el buildspec? → No, viene preinstalado en `codebuild/standard:7.0`.
