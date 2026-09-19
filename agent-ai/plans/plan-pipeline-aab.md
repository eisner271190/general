# Plan: Pipeline para generar .aab firmado

## Objetivo

Crear un pipeline de CI/CD en AWS (CodePipeline + CodeBuild) que recupere los secretos de firma Android desde AWS Secrets Manager, configure el entorno de firma, compile el Flutter App Bundle firmado (`.aab`) y publique el artefacto resultante.

## Estado actual

- El generador ya crea la upload key y la almacena en AWS Secrets Manager (tarea 1 completada).
- `GeneratorApplication` escribe `android/key.properties` y `upload-keystore.jks` en el directorio de salida durante la generación.
- La plantilla `build.gradle.kts.scriban` lee `key.properties` y exige `storeFile` para release signing.
- El `.gitignore` de Flutter **no excluye** `android/key.properties` ni `*.jks` — riesgo de que se suban al repositorio.
- El README de la plantilla documenta el proceso manual de recuperación de secretos y build firmado.
- El backend ya usa Azure Pipelines (`azure-build.yml`); el frontend no tiene pipeline.
- No existe ningún pipeline ni script automatizado para compilar el `.aab` firmado.

## Investigación

La guía oficial de Flutter recomienda `flutter build appbundle` para generar el AAB. En CI/CD, el keystore se inyecta como archivo temporal decodificado desde un secreto (base64 o binario), `key.properties` se genera dinámicamente con las credenciales, y tras el build se eliminan ambos archivos.

AWS CodePipeline orquesta las etapas de fuente, build y artefactos. AWS CodeBuild ejecuta el build dentro de un contenedor con Flutter SDK preinstalado. Los secretos se recuperan directamente desde Secrets Manager usando el IAM role del CodeBuild, sin necesidad de credenciales explícitas.

Las mejores prácticas indican:
- Almacenar el keystore como secreto binario en el gestor de secretos.
- Decodificar y escribir en un directorio temporal durante el build.
- Eliminar keystore y `key.properties` después del build (cleanup).
- No exponer contraseñas en logs del pipeline.
- Excluir archivos sensibles del control de versiones.
- Usar IAM roles en lugar de credenciales estáticas.

Referencia: https://docs.flutter.dev/deployment/android
Referencia: https://docs.aws.amazon.com/codepipeline/latest/userguide/welcome.html
Referencia: https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
Referencia: https://docs.aws.amazon.com/secretsmanager/latest/userguide/retrieve-secret.html

## Flujo del pipeline

```
Trigger (push a rama principal)
    │
    ▼
┌─ CodePipeline ─────────────────────────────────────────────┐
│                                                             │
│  1. Source Stage (GitHub)                                   │
│     └─ Checkout del código fuente via webhook               │
│                                                             │
│  2. Build Stage (CodeBuild)                                 │
│     ├─ Instalar Flutter SDK                                 │
│     ├─ Recuperar secretos desde Secrets Manager             │
│     │   └─ /epc/{app}/android-signing/keystore              │
│     │   └─ /epc/{app}/android-signing/store-password        │
│     │   └─ /epc/{app}/android-signing/key-password          │
│     │   └─ /epc/{app}/android-signing/key-alias             │
│     ├─ Decodificar keystore y escribir temporalmente        │
│     ├─ Generar android/key.properties                       │
│     ├─ flutter clean && flutter pub get                     │
│     ├─ flutter build appbundle --release                    │
│     ├─ Verificar AAB generado                               │
│     └─ Cleanup: eliminar key.properties y keystore          │
│                                                             │
│  3. Artifact Stage                                          │
│     └─ Publicar build/app/outputs/bundle/release/app.aab    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Tareas de implementación

### 1. Crear buildspec.yml para CodeBuild

- Crear un archivo `buildspec.yml` parametrizado con variables de entorno.
- Definir runtime con Flutter SDK y AWS CLI preinstalados.
- Fase `install`: instalar dependencias Flutter.
- Fase `pre_build`: recuperar secretos de firma desde Secrets Manager.
- Fase `build`: compilar AAB firmado.
- Fase `post_build`: cleanup de archivos sensibles.
- Exportar el AAB como artifact del CodeBuild.

### 2. Crear template CloudFormation / Terraform para CodePipeline

- Definir CodePipeline con 2 etapas: Source (GitHub) y Build (CodeBuild).
- Conectar GitHub como fuente via OAuth o GitHub App.
- Definir CodeBuild project con:
  - IAM role con permisos `secretsmanager:GetSecretValue` para los paths de firma.
  - Runtime: Ubuntu con Flutter SDK.
  - Variables de entorno: `APPLICATION_ID`, `AWS_REGION`.
- Configurar artifact S3 para almacenar el AAB.

### 3. Recuperación de secretos en CodeBuild

- Usar AWS CLI (`aws secretsmanager get-secret-value`) con el IAM role del CodeBuild.
- Decodificar el keystore binario de base64 a archivo temporal.
- Crear `android/key.properties` con las 4 propiedades.
- No loguear valores de contraseñas ni del keystore.

### 4. Build del AAB firmado

- Ejecutar `flutter clean`, `flutter pub get`, `flutter build appbundle --release`.
- Verificar que `build/app/outputs/bundle/release/app-release.aab` existe.
- Validar tamaño mínimo del AAB (> 0 bytes).

### 5. Cleanup post-build

- Eliminar `android/key.properties` y el keystore temporal después del build.
- Usar `finally` del buildspec para garantizar la limpieza incluso si el build falla.

### 6. Actualizar .gitignore de la plantilla Flutter

- Añadir `android/key.properties` y `*.jks` al `.gitignore.scriban`.
- Evitar que credenciales de firma se suban al repositorio.

### 7. Documentar el pipeline en el README de la plantilla

- Actualizar `README.md.scriban` con instrucciones del pipeline.
- Documentar variables de entorno y permisos IAM requeridos.
- Documentar cómo ejecutar el pipeline localmente (si aplica).

## Archivos a crear

| Archivo | Propósito |
|---------|-----------|
| `generator/components/frontend/flutter3.47.2/templates/buildspec.yml.scriban` | Buildspec de AWS CodeBuild para build firmado del AAB |
| `generator/components/frontend/flutter3.47.2/templates/codepipeline.yml.scriban` | Template CloudFormation de AWS CodePipeline con GitHub como fuente |

## Archivos a modificar

| Archivo | Cambio |
|---------|--------|
| `generator/components/frontend/flutter3.47.2/templates/.gitignore.scriban` | Añadir exclusiones para `android/key.properties` y `*.jks` |
| `generator/components/frontend/flutter3.47.2/templates/README.md.scriban` | Documentar el pipeline, variables IAM y procedimiento |
| `generator/components/frontend/flutter3.47.2/component.json` | Añadir los archivos `buildspec.yml` y `codepipeline.yml` al listado de files |

## Decisiones tomadas

1. **applicationId:** variable de entorno del CodeBuild.
2. **Trigger:** push a la rama principal.
3. **Publicación:** solo artefacto (sin upload a Google Play).
4. **Ambientes:** pipeline parametrizado para todos los ambientes.
5. **Fuente:** GitHub via OAuth o GitHub App.

## Criterios de aceptación

- El pipeline recupera los 4 secretos de firma desde AWS Secrets Manager usando IAM role (sin credenciales estáticas).
- El `.aab` se genera firmado en `build/app/outputs/bundle/release/app-release.aab`.
- El AAB se publica como artifact del pipeline con metadatos de trazabilidad.
- `key.properties` y el keystore se eliminan después del build (incluso si falla).
- `android/key.properties` y `*.jks` están excluidos del control de versiones.
- El pipeline es parametrizable y reutilizable para cualquier `applicationId`.
- El pipeline se ejecuta automáticamente en cada push a la rama principal.
- El README documenta los permisos IAM requeridos y el procedimiento.
