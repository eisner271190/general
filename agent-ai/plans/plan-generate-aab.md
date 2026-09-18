# Plan: Generar .aab firmado

## Objetivo

Producir localmente un Android App Bundle (`.aab`) de la aplicación Flutter configurada, firmado con una clave de carga privada y apto para publicar en Google Play.

## Estado actual

- El generador crea los frontends Flutter bajo `projects/{applicationId}/frontend/{frontendName}`.
- La plantilla `generator/components/frontend/flutter3.47.2/templates/android/app/build.gradle.kts.scriban` ya carga `android/key.properties`, exige `storeFile` y asigna la firma `release`.
- El `.gitignore` del frontend excluye artefactos Android, pero no excluye explícitamente `android/key.properties` ni archivos `.jks`.
- No hay constancia de un `key.properties`, de un almacén de claves ni de una compilación firmada comprobada.
- El generador no tiene dependencias AWS, no lee `AWS_REGION`, no crea claves y no persiste secretos.
- Play App Signing se usará en la primera publicación.
- Los secretos de firma se crearán para todo frontend Flutter generado, pues Android es una plataforma principal de las aplicaciones.
- Se aprueba el prefijo `/epc/{applicationId}/android-signing/` y el cifrado con la clave KMS administrada de Secrets Manager.
- Cada aplicación se genera localmente como una aplicación nueva; su upload key se crea antes de la primera carga en Google Play.
- El pipeline pertenece a la siguiente tarea prioritaria y queda fuera de este plan.

## Investigación

La guía oficial de Flutter 3.47 indica crear un keystore de carga con `keytool`, mantener privados tanto el keystore como `android/key.properties`, configurar `signingConfigs.release` y ejecutar `flutter build appbundle`. El resultado esperado es `build/app/outputs/bundle/release/app.aab`.

AWS Secrets Manager permite secretos binarios cifrados y nombres de 1 a 512 caracteres. El generador usará el SDK oficial de AWS para .NET, tomará la región exclusivamente de `AWS_REGION` y utilizará la cadena de credenciales predeterminada del SDK. Secrets Manager limita cada secreto a 65.536 bytes; el generador debe detenerse antes de subir un `.jks` que supere ese límite.

Referencia: https://docs.flutter.dev/deployment/android

Referencia: https://docs.aws.amazon.com/secretsmanager/latest/userguide/create_secret.html

## Tareas de implementación

1. Definir el contrato de secretos de firma.
   - Generar nombres deterministas a partir de `applicationId`: `/epc/{applicationId}/android-signing/keystore`, `/store-password`, `/key-password` y `/key-alias`.
   - Definir un `AndroidSigningSecrets` inmutable que contenga el alias, las contraseñas, bytes del keystore y nombres de secretos durante la ejecución, sin serializarlo en `generation-plan.json` ni registrarlo.

2. Crear el upload keystore y las credenciales.
   - Validar que existe y no está vacía la variable de entorno `AWS_REGION` antes de generar secretos o escribir archivos.
   - Generar criptográficamente `storePassword` y `keyPassword`, independientes y con longitud y conjunto de caracteres compatibles con `keytool` y archivos `.properties`.
   - Crear un alias determinista y no secreto derivado de `applicationId`.
   - Invocar `keytool` mediante un proceso sin shell y entradas protegidas para crear un `.jks` temporal; no pasar contraseñas por argumentos ni registrarlas.
   - Validar que el archivo resultante existe, es legible y no excede 65.536 bytes.

3. Almacenar secretos en AWS Secrets Manager.
   - Añadir `AWSSDK.SecretsManager` y un adaptador de infraestructura `IAwsSecretsManager` inyectado en la aplicación.
   - Crear el secreto binario del `.jks` y secretos de texto separados para alias y contraseñas, todos en la región `AWS_REGION`.
   - Cifrar con la clave administrada de Secrets Manager inicialmente; permitir un KMS CMK configurable en una ampliación posterior.
   - Fallar si alguno de los nombres ya existe; no sobrescribir ni rotar claves existentes implícitamente.
   - Si falla una creación posterior, eliminar solo los secretos creados en esa ejecución y borrar siempre el `.jks` temporal.

4. Preparar la configuración de firma local.
   - Generar `android/key.properties` solo cuando el proceso de build local lo requiera, con `storeFile` temporal y valores obtenidos de Secrets Manager; no incorporarlo al plan ni a archivos versionados.
   - Añadir exclusiones de Git para `android/key.properties` y `*.jks`.
   - Verificar que la plantilla `build.gradle.kts.scriban` siga leyendo las cuatro propiedades y falle antes de crear un release si falta alguna.
   - Documentar en la plantilla README el procedimiento de recuperación de secretos, el build firmado y la ubicación del AAB.

5. Generar y verificar el AAB.
   - Ejecutar `flutter clean`, `flutter pub get` y `flutter build appbundle` desde el frontend.
   - Confirmar la existencia del AAB en la ruta de salida de Flutter.
   - Inspeccionar el certificado del artefacto con herramientas del Android SDK o Java y contrastar su alias y huella con el upload keystore.

6. Preparar la entrega a Google Play.
   - Confirmar que `applicationId` es definitivo antes de la primera carga.
   - Crear la aplicación en Google Play Console después de generar localmente el AAB firmado con su upload key nueva.
   - Subir el AAB al canal de pruebas interno con Play App Signing y registrar el resultado de la validación.

## Archivos a crear

- `generator/Models/AndroidSigningSecrets.cs`: datos sensibles efímeros de la firma, excluidos de los artefactos de generación.
- `generator/Models/AndroidSigningSecretReferences.cs`: nombres no sensibles de los secretos por aplicación.
- `generator/Services/AndroidSigningKeyGenerator.cs`: creación de contraseñas, alias y `.jks` temporal mediante `keytool`.
- `generator/Services/AwsSecretsManager.cs`: adaptador de AWS Secrets Manager para secretos binarios y de texto.
- `generator/Services/ISecretsManager.cs`: contrato de infraestructura para persistir y compensar secretos.

## Archivos a modificar

- `generator/Generator.csproj`: añadir el paquete `AWSSDK.SecretsManager`.
- `generator/Program.cs`: componer los servicios de creación de claves y AWS.
- `generator/Services/GeneratorApplication.cs`: coordinar creación, persistencia y limpieza de secretos antes de generar el frontend.
- `generator/Configuration/GeneratorConstants.cs`: centralizar nombres de variables, prefijos y límites de secretos.
- `generator/Messages/ErrorCodes.cs` y `generator/Messages/GeneratorMessages.cs`: errores accionables de AWS, región, `keytool`, tamaño y conflicto.
- `generator/components/frontend/flutter3.47.2/templates/android/app/build.gradle.kts.scriban`: completar validaciones de propiedades solo si la inspección revela que faltan.
- `generator/components/frontend/flutter3.47.2/templates/.gitignore.scriban`: excluir la configuración y claves privadas de firma.
- `generator/components/frontend/flutter3.47.2/templates/README.md.scriban`: documentar el build firmado y la ubicación del AAB.

## Dependencias

- JDK con `keytool`, Flutter 3.47.2 y Android SDK instalados localmente.
- `AWS_REGION` configurada en el entorno que ejecuta el generador.
- Credenciales AWS disponibles mediante perfil local, variables de entorno o rol IAM, con permisos mínimos `secretsmanager:CreateSecret`, `DescribeSecret`, `GetSecretValue` y eliminación de los recursos creados para compensación.
- Permisos KMS necesarios si se configura una clave administrada por el cliente.
- Acceso a la consola de Google Play para validar la primera carga.
- La tarea posterior “Pipeline para generar .aab firmado” consumirá la plantilla y el mecanismo de firma definidos aquí.

## Validación

1. Sin `AWS_REGION`, comprobar que el generador falla antes de crear el keystore o escribir secretos.
2. Con credenciales AWS autorizadas, comprobar que crea cuatro secretos con los nombres esperados en `AWS_REGION` y que el `.jks` se almacena como binario.
3. Recuperar los secretos en un directorio temporal, crear `android/key.properties` y generar el AAB con `flutter build appbundle`.
4. Verificar que el certificado del AAB corresponde al alias almacenado.
5. Confirmar que `git status` no muestra `key.properties`, `.jks`, contraseñas ni valores de secretos.
6. Simular un nombre existente y un fallo de AWS; confirmar que no se sobrescribe una clave y se eliminan los secretos creados parcialmente.
7. Cargar el AAB en el canal interno de Google Play y comprobar que acepta la firma.

## Criterios de aceptación

- El generador crea un `.jks`, alias y dos contraseñas sin exponerlas por consola, plan, logs ni control de versiones.
- El generador usa exclusivamente `AWS_REGION` para seleccionar la región y falla sin esa variable.
- Secrets Manager contiene el `.jks` binario y los tres secretos de texto bajo nombres deterministas por `applicationId`.
- Un proyecto Flutter generado incluye una plantilla de configuración de firma sin secretos.
- El release falla con un mensaje accionable si falta la configuración o el keystore.
- `quizsmart` genera `app.aab` firmado localmente.
- Ninguna clave, contraseña o archivo de configuración privado queda versionado.
- Google Play acepta el AAB en pruebas internas.

## Preguntas de implementación

