# EPC Generator - AWS CI/CD Pipeline

## Estado actual: Build de Flutter en CodeBuild pendiente de resolución

---

## Resumen general

El generador EPC crea proyectos Flutter y despliega automáticamente un pipeline CI/CD completo en AWS:
- **CodeCommit**: Repositorio con el código fuente
- **CodeBuild**: Proyecto que compila el AAB firmado
- **CodePipeline**: Orquesta Source → Build
- **IAM Roles**: Permisos para CodeBuild y CodePipeline
- **S3 Bucket**: Artefactos del pipeline
- **Secrets Manager**: Keystore y contraseñas de signing (ya existentes)

El pipeline se dispara automáticamente al hacer push a la rama `main`.

---

## Archivos creados/modificados

### Generador principal
| Archivo | Descripción |
|---------|-------------|
| `generator/Services/GeneratorApplication.cs` | Orquestador principal. Después de generar el proyecto, copia `buildspec.yml` a la raíz y sube todo a CodeCommit |
| `generator/Services/CodeCommitService.cs` | Sube archivos a CodeCommit por batches de 50 con retry. Filtra archivos innecesarios (.git, .dart_tool, build, .gradle, etc.) |
| `generator/Services/PipelineDeployer.cs` | Despliega S3, IAM, CodeBuild, CodeCommit y CodePipeline usando AWS SDK V4 |
| `generator/Services/IRepositoryProvider.cs` | Interfaz para proveedores de repositorio |
| `generator/Services/CodeCommitProvider.cs` | Implementación CodeCommit |
| `generator/Services/GitHubProvider.cs` | Implementación GitHub (CodeConnections) |
| `generator/Services/AwsSecretsManager.cs` | Lee secretos de Android signing de Secrets Manager |
| `generator/Program.cs` | Entry point, pasa region al GeneratorApplication |
| `generator/Generator.csproj` | Paquetes NuGet: AWS SDK V4 (CodePipeline, CodeBuild, CodeCommit, CodeConnections, IAM, S3, SecurityToken) |
| `generator/Models/EpcConfiguration.cs` | Campo `SourceProvider` agregado a FrontendConfiguration |
| `generator/Messages/ErrorCodes.cs` | `GEN020` para fallos de pipeline |
| `generator/Messages/GeneratorMessages.cs` | Mensaje `PipelineDeploymentFailed` |

### Templates Scriban
| Archivo | Descripción |
|---------|-------------|
| `generator/components/frontend/flutter3.47.2/templates/buildspec.yml.scriban` | Template del buildspec - **ACTUALIZADO** con instalación de Android SDK |
| `generator/components/frontend/flutter3.47.2/templates/codepipeline.yml.scriban` | Template de CodePipeline |
| `generator/components/frontend/flutter3.47.2/component.json` | Lista de archivos del componente |

### Archivos generados
| Archivo | Descripción |
|---------|-------------|
| `projects/com.quizsmart.app/buildspec.yml` | Buildspec generado (copia a raíz del repo para CodeBuild) |
| `projects/com.quizsmart.app/frontend/quizsmart/buildspec.yml` | Buildspec original en el frontend |

---

## Proyectos temporales de debug

Creados para diagnosticar y corregir errores del pipeline.

### `generator/Tools/` (proyecto auxiliar)
| Archivo | Descripción |
|---------|-------------|
| `generator/Tools/Program.cs` | Tool para subir `buildspec.yml` a CodeCommit vía SDK (sin regenerar todo el proyecto) |
| `generator/Tools/Tools.csproj` | Proyecto .NET 9 con AWSSDK.CodeCommit |
| `generator/Tools/upload-buildspec.csx` | Script CSX (no funcionó, reemplazado por Program.cs) |

**Uso:**
```bash
cd C:\epc\general\generator\Tools
dotnet run
```
Sube el `buildspec.yml` desde `C:\epc\general\projects\com.quizsmart.app\buildspec.yml` al repo `quizsmart` en CodeCommit.

---

## Errores encontrados y corregidos

### 1. `buildspec.yml` no existía en CodeCommit
**Error:** `YAML_FILE_ERROR: YAML file does not exist`
**Causa:** El buildspec se generaba en `frontend/quizsmart/buildspec.yml` pero CodeBuild lo busca en la raíz del repo.
**Fix:** Copiar `buildspec.yml` a la raíz del directorio del proyecto antes de subir a CodeCommit.

### 2. Filtro excluía `buildspec.yml`
**Error:** Solo se subían ~3,000 archivos, el buildspec faltaba.
**Causa:** El patrón `"build"` en `excludePatterns` hacía `Contains("build")` que coincidía con `buildspec.yml`.
**Fix:** Cambiar a excludeDirs con path separators: `"\\build\\", "/build/"` en lugar del genérico `"build"`.

### 3. YAML parse error en CodeBuild
**Error:** `Expected Commands[10] to be of string type: found subkeys instead`
**Causa:** Líneas vacías `-` en listas YAML y bloques `|` multi-línea que el parser de CodeBuild no maneja bien.
**Fix:** Reemplazar `-` vacíos por comandos explícitos, eliminar bloques `|` usando comandos inline con `&&` y `'...'`.

### 4. `AWS_REGION` vacío causaba endpoint inválido
**Error:** `Invalid endpoint: https://secretsmanager..amazonaws.com` (doble punto)
**Causa:** `AWS_REGION: ""` en las variables del buildspec sobreescribía la variable que CodeBuild provee automáticamente.
**Fix:** Eliminar `AWS_REGION` de las variables del env.

### 5. Directorio `android/` no existía en la raíz
**Error:** `cannot create android/upload-keystore.jks: Directory nonexistent`
**Causa:** El proyecto Flutter está en `frontend/quizsmart/`, no en la raíz del repo.
**Fix:** Agregar `cd "$CODEBUILD_SRC_DIR/frontend/$FLUTTER_PROJECT"` al inicio de pre_build.

### 6. Falta Android SDK en CodeBuild
**Error:** `flutter build appbundle --release` falla con exit status 1 (solo muestra `[1/1] Android SDK`)
**Causa:** La imagen `aws/codebuild/standard:7.0` no tiene Android SDK instalado.
**Fix (parcial):** Agregar instalación de Android SDK en la fase `install` del buildspec. **AÚN NO VERIFICADO CON ÉXITO.**

---

## Recursos AWS creados

| Recurso | Nombre |
|---------|--------|
| S3 Bucket | `com-quizsmart-app-aab-artifacts` |
| CodeCommit Repo | `quizsmart` |
| IAM Role CodeBuild | `com-quizsmart-app-codebuild-role` |
| IAM Role CodePipeline | `com-quizsmart-app-codepipeline-role` |
| CodeBuild Project | `com-quizsmart-app-flutter-aab` |
| CodePipeline | `com-quizsmart-app-aab-pipeline` |
| CloudWatch Log Group | `/aws/codebuild/com-quizsmart-app-flutter-aab` |

**Región:** `us-east-1`  
**Cuenta AWS:** `577638384397`

---

## Para continuar mañana

### 1. Verificar si el último pipeline terminó
```bash
aws codepipeline get-pipeline-state --name com-quizsmart-app-aab-pipeline --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' --output table
```

### 2. Si falló, revisar logs de CodeBuild
```bash
# Obtener último log stream
aws logs describe-log-streams --log-group-name /aws/codebuild/com-quizsmart-app-flutter-aab --order-by LastEventTime --descending --limit 1 --query "logStreams[0].logStreamName" --output text

# Buscar errores
aws logs get-log-events --log-group-name /aws/codebuild/com-quizsmart-app-flutter-aab --log-stream-name <NOMBRE> --query "events[?contains(message,'FAILED')||contains(message,'ERROR')||contains(message,'error')].message" --output json
```

### 3. Si el Android SDK se instaló pero Flutter falla
- Puede ser que `ANDROID_HOME` no persiste entre fases (cada fase puede resetear env)
- Verificar que `flutter config --android-sdk` se ejecuta correctamente
- Considerar usar una imagen Docker custom con Flutter + Android SDK preinstalado

### 4. Regenerar el template Scriban
```bash
cd C:\epc\general\generator
dotnet run
```
Esto regenerará el `buildspec.yml` con la última versión del template.

### 5. Para subir solo el buildspec corregido (sin regenerar todo)
```bash
cd C:\epc\general\generator\Tools
dotnet run
```

### 6. Disparar el pipeline manualmente
```bash
aws codepipeline start-pipeline-execution --name com-quizsmart-app-aab-pipeline
```

---

## Configuración del proyecto de prueba

```json
// generator/target/com.quizsmart.app/com.quizsmart.app.json
{
  "frontend": {
    "name": "quizsmart",
    "framework": "flutter3.47.2",
    "sourceProvider": "codecommit",
    "gitHubRepo": "quizsmart",
    "gitHubBranch": "main"
  }
}
```

---

## Notas importantes

- El `key.properties` y `upload-keystore.jks` se excluyen de CodeCommit (se generan en el build por Secrets Manager)
- Los archivos `.gitignore` del proyecto Flutter se respetan en la subida a CodeCommit
- El pipeline usa `PollForSourceChanges: true` para detectar pushes automáticamente (~5 min)
- Cada batch de subida a CodeCommit es un commit separado con chain de parent commits
- El Buildspec clean up borra `key.properties` y `upload-keystore.jks` después del build
