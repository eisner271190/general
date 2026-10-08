# Integración de infraestructura

- Objetivo/entorno: `obj-003` / CodeArtifact (dominio `epc`, repositorio `common`)
- Agente: `Integrator`
- Estado: `completado`
- Resumen: Infraestructura de `obj-003` desplegada con `projects/com.quizsmart.app/up.ps1 -Fast`.
- Bloqueos: ninguno para el despliegue. Quedan defectos de logging pendientes (ver final).
- Aprobación y alcance autorizado: Usuario autorizó 2026-10-07 ejecutar `up.ps1` completo.

## Ejecución
- Script/ruta/versión: `library/platform/scripts/publish-common.ps1` (requiere PowerShell 7.0)
- Parámetros no secretos: `-CommonDirectory` por defecto `library/common`; sin `-DryRun`
- Plan/diff revisado: Configuración estática verificada por coordinador:
  - `component.json` registra `logback.scriban` → `src/main/resources/logback.xml`
  - `logback.scriban` incluye `<include resource="logback-base.xml" />`
  - `logback-base.xml` tiene raíz `<included>`
  - `application-properties.scriban` no fija `logging.config`
- Recursos afectados: CodeArtifact dominio `epc`, repositorio `common` (no existen)
- Resultado y logs:
  - Script ejecutado con `pwsh -NoProfile -ExecutionPolicy Bypass -File publish-common.ps1`
  - Salida: `[publish-common] Inicio de la publicación de common`
  - Salida: `[publish-common] endpoint maven`
  - Error AWS: `ResourceNotFoundException: Domain not found. Domain 'epc' owned by account '577638384397' does not exist.`
  - Salida: `[publish-common] ERROR: aws falló con código 254.`
  - Exit code: 1

## Operación
- Drift/errores: El dominio CodeArtifact `epc` no existe. El script no ejecuta Terraform; la infraestructura la levanta `scripts/up.ps1`.
- Rollback: No aplicable (no se publicó nada).
- Pendientes:
  - Ejecutar `library/platform/scripts/up.ps1` para crear el dominio CodeArtifact
  - Reintentar `publish-common.ps1` tras confirmar que el dominio existe
- Secretos incluidos: `no`

## Ejecución 2026-10-07 — up.ps1 -Fast (intento fallido, path incorrecto)
- Comando: `pwsh -NoProfile -ExecutionPolicy Bypass -File library/platform/scripts/up.ps1 -Fast`
- Resultado: **FALLIDO** (exit code 1)
- Error exacto: `up.ps1: No se encuentra un parámetro que coincida con el nombre de parámetro "Fast".`
- Acción: No se reintentó.
- Nota: este intento usó el script equivocado. Ver sección "Corrección de path" al final.

## Ejecución 2026-10-07 — up.ps1 -AutoApprove (plataforma)
- Comando: `pwsh -NoProfile -ExecutionPolicy Bypass -File library/platform/scripts/up.ps1 -AutoApprove`
- Resultado: **EXITOSO** (exit code 0)
- Recursos: 26 (dominio `epc`, repositorio `common`, repositorio `maven-central`,
  CodeCommit `common`/`platform`, CodeBuild, CodePipeline, ECR `common-base`, S3 `epc-buildspecs`,
  IAM roles/policies)
- Dominio `epc` verificado: `aws codeartifact list-domains` → `epc`

## Ejecución 2026-10-07 — publish-common.ps1
- Comando: `pwsh -NoProfile -ExecutionPolicy Bypass -File library/platform/scripts/publish-common.ps1`
- Resultado: **EXITOSO** (exit code 0)
- Endpoint: `https://epc-577638384397.d.codeartifact.us-east-1.amazonaws.com/maven/common/`
- Paquetes publicados: `common-bom 1.1.0`, `common-error 1.1.0`, `common-log 1.1.0`,
  `common-web 1.1.0` (common-parent 1.1.0 sin deploy por ser pom)
- Reactor: 7 módulos, BUILD SUCCESS en 21.284 s

## Ejecución 2026-10-07 — update-ms.ps1 (despliegue Lambda)
- Comando: `pwsh -NoProfile -ExecutionPolicy Bypass -File update-ms.ps1`
  (ejecutado desde `projects/com.quizsmart.app/backend/quizapi`)
- Resultado: **FALLIDO** (exit code 1)
- Error exacto:
  `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine;
  check if the path is correct and if the daemon is running:
  open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.`
- Causa: Docker Desktop no está ejecutándose (daemon no disponible)
- Estado: `bloqueado` — resuelto después; el daemon responde (29.8.0).

## Análisis 2026-10-07 — modo solo lectura (sin ejecutar nada)

- Alcance: verificación documental y de solo lectura. Ningún script de infraestructura ejecutado.
- Secretos incluidos: `no`

### 1. Parámetros reales de `library/platform/scripts/up.ps1`
- Leído `library/platform/scripts/up.ps1` (`up.ps1:26-30`), sin ejecutarlo.
- Conjunto REAL: `-TerraformDirectory` (string, por defecto `../terraform`),
  `-WhatIf` (switch), `-AutoApprove` (switch).
- Conclusión: `up.ps1` de plataforma es solo plataforma (Terraform de `library/platform/terraform`).
  No despliega Lambdas ni construye imágenes.
- Corrección posterior: esto se aplicó al script equivocado. El script de aplicación
  `projects/com.quizsmart.app/up.ps1` sí acepta `-Fast`.

### 2. Estado real de AWS (solo lectura, antes del despliegue)
- Identidad: `aws sts get-caller-identity` → cuenta `577638384397`, usuario `eisner.puerta`,
  perfil `default`, región `us-east-1`.
- `aws codeartifact list-domains` → `{"domains": []}`. Vacío.
- `aws codeartifact describe-domain --domain epc` → `ResourceNotFoundException`.
  (subcomando correcto: `describe-domain`; `get-domain` no existe en aws-cli 2.28.6).
- `aws lambda list-functions` → `{"Functions": []}`.
- `aws logs describe-log-groups` → solo `["/aws/codebuild/platform-bump-bom"]`.
- `aws ecr describe-repositories` → `{"repositories": []}`.
- `aws apigatewayv2 get-apis` → `{"Items": []}`.
- Contraprueba por estado de Terraform: `terraform state show aws_codeartifact_domain.epc` describía
  el dominio `epc` con `created_time 2026-10-07T19:44:01Z`: drift entre estado y API.
- **Resuelto** por la ejecución de `projects/com.quizsmart.app/up.ps1 -Fast` (ver más abajo).

### 3. Daemon de Docker
- `docker info` → responde. Server `29.8.0`, context `desktop-linux`.
- El bloqueo de `update-ms.ps1` no aplica ya a Docker.

### 4. ¿Posible validar JSON estructurado y masking en runtime en esa iteración?
- No, en ese momento. Faltaban, en orden: dominio CodeArtifact `epc`, repositorio ECR `quizapi`,
  Lambda `quizapi`, log group `/aws/lambda/quizapi` y API Gateway para el `curl`.
- Observación sobre el código: `quizapi/src/main/resources/logback.xml` hace
  `<include resource="logback-base.xml" />` y las clases importan `ILogService`.
- Root `level="info"` en `logback-base.xml:24`: el criterio `debug` no se ve en runtime
  mientras no se suba el nivel por variable de entorno.

### 5. Rutas de validación disponibles sin AWS
- `library/common/samples/log-only-sample` y `library/common/samples/web-sample`
  ejercitan `ILogService` en proceso local.

### 6. Rollback
- No aplica: esa sección es solo lectura.

## Ejecución 2026-10-07 21:24 - up.ps1 -Fast (completa) y verificación en CloudWatch

- Comando: `pwsh -NoProfile -ExecutionPolicy Bypass -File up.ps1 -Fast`
  (autorizado por el usuario; script en `projects/com.quizsmart.app/up.ps1`)
- Workdir: `C:\epc\general\projects\com.quizsmart.app`
- Log: `projects/com.quizsmart.app/logs/2026-10-07-21-24-52.log`,
  salida `int-2026-10-07-2125.out.txt`, exit `int-2026-10-07-2125.exit.txt`
- Identidad: `eisner.puerta`, cuenta `577638384397`, `us-east-1`
- Sin prompt interactivo: `-AutoApprove` viene activado por defecto en el script del proyecto.
- Resultado: **EXITOSO (exit code 0)**, `ELAPSED=704.08 s` (21:24:52 → 21:36:35)
- Secretos incluidos: `no`

### Pasos (5/5, todos exit=0)
| # | Paso | Inicio | Fin |
|---|---|---|---|
| - | `publish-common.ps1` (pre) | 21:24:52 | 21:25:57 |
| - | `publish-buildspecs.ps1` (pre) | 21:25:57 | 21:26:07 |
| 1/5 | cloud bootstrap (crea ECR) | 21:26:07 | 21:26:35 |
| 2/5 | backend build (docker build + push) | 21:26:35 | 21:31:24 |
| 3/5 | cloud plan + apply | 21:31:24 | 21:34:06 |
| 4/5 | backend run (Parameter Store + docker run) | 21:36:08 | 21:36:13 |
| 5/5 | frontend (`-Fast`) | 21:36:13 | 21:36:35 |

- `publish-common`: 7 módulos, `BUILD SUCCESS` en 18.097 s, versión **1.1.5**
  (`common-bom`, `common-log`, `common-error`, `common-web`).
- Plataforma Terraform: `Apply complete! Resources: 26 added`.
- Buildspecs subidos a `s3://epc-buildspecs/`: `bump-bom.yml`, `docker-build.yml`, `java-ci.yml`.
- `cloud apply`: API Gateway, API Gateway→Lambda, Cognito (pool, clientes, Google, IAM), ECR,
  Lambda + IAM, SNS, SNS→SQS, SQS, secreto de app, 6 parámetros post-apply.
- Paso 3b (CodeCommit): push a `https://git-codecommit.us-east-1.amazonaws.com/v1/repos/com.quizsmart.app`
  rama `main`. Lo hace el propio `up.ps1` como parte de su flujo; no fue commit manual del monorepo.

### Recursos verificados (solo lectura, `us-east-1`, cuenta 577638384397)
- `aws codeartifact list-domains` → `epc`, `Active`, creado `2026-10-07T21:25:19-05:00`.
  **El drift previo queda reconciliado.**
- Lambda `quizapi`: existe, `Active`, `LastUpdateStatus=Successful`, memoria 512 MB, timeout 60,
  env `SPRING_PROFILES_ACTIVE=cloud`.
- `LoggingConfig`: `LogGroup=/aws/lambda/quizapi`, `LogFormat=Text`.
- API Gateway HTTP API `api-gateway`: `https://jeb9ikgysl.execute-api.us-east-1.amazonaws.com`
- Log group: `/aws/lambda/quizapi` (nacido con la 1ª invocación).
- ECR: `quizapi` y `epc/common-base`.
- `aws logs filter-log-events`: logback-classic 1.5.12 arrancando.

### Endpoint `/api/v1/parameters`
- 1er `curl` (21:36): **503 Service Unavailable** - Lambda en `init` (cold start).
- 2do `curl` (21:39): **200 OK**, cuerpo JSON de parámetros.
  Evidencia: `{"data":{"API_BASE_URL":"https://jeb9ikgysl.execute-api.us-east-1.amazonaws.com/", ...`

## Veredicto paso 3 del objetivo (logs estructurados) - PARCIAL

### a) JSON por línea: SÍ (parcial)
- 13 líneas JSON en el log group; **0 inválidas** al pasar `ConvertFrom-Json`.
- Evidencia literal (recortada):
  `{"@timestamp":"2026-10-08T02:35:07.626783274Z","@version":"1","message":"Starting AWSLambda
  v2.12.1 using Java 17.0.20.1 with PID 2 ...","logger_name":"com.amazonaws.services.lambda.
  runtime.api.client.AWSLambda","thread_name":"main","level":"INFO","level_value":20000}`
- **Defecto**: el campo de tiempo es `@timestamp`, no `timestamp`. Lambda exige `timestamp`
  en RFC 3339 para indexar; sin él, CloudWatch **no indexa** `level` ni tiempo.

### b) Campo `level`: SÍ
- Presente en toda línea JSON. Único nivel observado: `"level":"INFO"`.

### c) `info` al inicio de métodos: NO VERIFICABLE
- Hay líneas `INFO` de `com.epc.common.log.Slf4jLogService`, pero ninguna marca entrada de método
  (no hay patrón `METHOD_ENTER` ni equivalente). Ejemplos:
  `Configuracion de IA cargada: model=..., apiKey presente=true`
  `[WH] secreto resuelto len=39`

### d) Masking de los 23 campos sensibles: **NO FUNCIONA** (defecto confirmado)
- Evidencia literal del arranque de logback:
  `|-WARN in ch.qos.logback.core.model.processor.ImplicitModelHandler - Ignoring unknown property
  [addPaths] in [net.logstash.logback.mask.MaskingJsonGeneratorDecorator]`
- Causa raíz confirmada por lectura del bytecode de `logstash-logback-encoder-8.1.jar` →
  `MaskingJsonGeneratorDecorator`: **solo expone `setDefaultMask` y `setMask`**. No existe
  `setAddPaths`, luego `<addPaths>` de `logback-base.xml:20` es una propiedad inexistente y logback
  la descarta.
- Los 23 paths de `logback-base.xml:20` están **sin aplicar**. Búsqueda de `***` en la salida cruda
  (`aws logs tail --since 20m`, 63 líneas): **0 coincidencias**.
- Los únicos campos sensibles presentes son marcas de presencia, no valores:
  `apiKey presente=true` (booleano), `secreto resuelto len=39` (longitud).
- Ninguno de los 23 puede marcarse como verificado: no verificados por fallo de configuración.

## Veredicto paso 4 del objetivo (nivel `debug`) - NO
- **0 líneas `"level":"DEBUG"`** en todo el log group. Único nivel presente: `INFO`.
- Causa: `logback-base.xml:24` fija `<root level="info">` y Lambda solo define
  `SPRING_PROFILES_ACTIVE=cloud`.

## Ejecución 2026-10-07 21:24 — up.ps1 -Fast (completa) y verificación en CloudWatch

- Alcance: despliegue autorizado por el usuario y verificación de solo lectura en AWS.
- Script: `projects/com.quizsmart.app/up.ps1` (versión del repo, sin modificar).
- Comando: `pwsh -NoProfile -ExecutionPolicy Bypass -File up.ps1 -Fast`
- Exit code: **0**. Duración: **704.08 s** (21:24:52 → 21:36:35).
- Secretos incluidos: `no`
- Logs: `projects/com.quizsmart.app/logs/2026-10-07-21-24-52.log`,
  `int-2026-10-07-2125.out.txt`, `int-2026-10-07-2125.exit.txt`.

### Pasos (5/5, todos exit=0)
| # | Paso | Inicio | Fin |
|---|---|---|---|
| pre | `publish-common.ps1` | 21:24:52 | 21:25:57 |
| pre | `publish-buildspecs.ps1` | 21:25:57 | 21:26:07 |
| 1/5 | cloud bootstrap (crea ECR) | 21:26:07 | 21:26:35 |
| 2/5 | backend build (docker build + push) | 21:26:35 | 21:31:24 |
| 3/5 | cloud plan + apply | 21:31:24 | 21:34:06 |
| 4/5 | backend run (Parameter Store + docker run) | 21:36:08 | 21:36:13 |
| 5/5 | frontend | 21:36:13 | 21:36:35 |

- `publish-common`: 7 módulos, `BUILD SUCCESS` 18.097 s, versión **1.1.5**.
- Terraform plataforma: `Apply complete! Resources: 26 added, 0 changed, 0 destroyed.`

### Recursos verificados (solo lectura, `us-east-1`, cuenta 577638384397)
- Lambda: `quizapi`, `Active`, `LastUpdateStatus=Successful`, 512 MB,
  env `SPRING_PROFILES_ACTIVE=cloud`.
- API Gateway: HTTP API `api-gateway`, id de invocación base
  `https://jeb9ikgysl.execute-api.us-east-1.amazonaws.com`.
- Log group: `/aws/lambda/quizapi`.
- ECR: repositorio `quizapi` (creado en paso 1/5).
- CodeArtifact: dominio `epc`, repositorio `common`, endpoint
  `https://epc-577638384397.d.codeartifact.us-east-1.amazonaws.com/maven/common/`.

### Endpoint `/api/v1/parameters`
- 1er `curl`: **503** (Lambda en `init`, cold start).
- 2º y 3er `curl`: **200**, cuerpo JSON de parámetros.
- Evidencia literal (CloudWatch, recortada a 240 caracteres por línea):
```
2026-10-08T02:35:00 INIT_REPORT Init Duration: 10000.00 ms  Phase: init  Status: timeout
2026-10-08T02:35:02,268 |-INFO in ch.qos.logback.classic.LoggerContext[default] - Found resource
  [logback.xml] at [file:/var/task/logback.xml]
2026-10-08T02:35:02,458 |-INFO in ch.qos.logback.core.joran.util.ConfigurationWatchListUtil@7e990ed7 -
  Adding [jar:file:/var/task/lib/common-log-1.1.5.jar!/logback-base.xml] to configuration watch list.
2026-10-08T02:35:02,516 |-WARN in ch.qos.logback.core.model.processor.ImplicitModelHandler - Ignoring
  unknown property [addPaths] in [net.logstash.logback.mask.MaskingJsonGeneratorDecorator]
2026-10-08T02:35:07 {"@timestamp":"2026-10-08T02:35:07.626783274Z","@version":"1","message":"Starting
  AWSLambda v2.12.1 using Java 17.0.20.1 with PID 2 (...aws-lambda-java-runtime-interface-client-
  2.12.1-linux-x86_64.jar started by sbx_user1051 in /var/task)","logger_name":"com.amazonaws.services.
  lambda.runtime.api.client.AWSLambda","thread_name":"main","level":"INFO","level_value":20000}
2026-10-08T02:35:07 {"@timestamp":"2026-10-08T02:35:07.627851378Z","@version":"1","message":"The
  following 1 profile is active: \"cloud\"","logger_name":"com.amazonaws.services.lambda.runtime.api.
  client.AWSLambda","thread_name":"main","level":"INFO","level_value":20000}
2026-10-08T02:35:11 {"@timestamp":"2026-10-08T02:35:11.601499595Z","@version":"1","message":"Configuracion
  de IA cargada: model=nvidia/nemotron-3-ultra-550b-a55b:free, apiBaseUrl=https://openrouter.ai/api/v1,
  temperature=0.7, maxTokens=1000, apiKey presente=true","logger_name":"com.epc.common.log.
  Slf4jLogService","thread_name":"main","level":"INFO","level_value":20000}
2026-10-08T02:35:14 {"@timestamp":"2026-10-08T02:35:14.021675611Z","@version":"1","message":"[WH]
  secreto resuelto len=39","logger_name":"com.epc.common.log.Slf4jLogService","thread_name":"main",
  "level":"INFO","level_value":20000}
2026-10-08T02:35:20 START RequestId: 963366ad-e2a5-4062-8e70-a1705092a423 Version: $LATEST
2026-10-08T02:35:21 {"@timestamp":"2026-10-08T02:35:21.421493029Z","@version":"1","message":"179.13.46.8
  --  [08/10/2026:02:34:49Z] \"GET /api/v1/parameters HTTP/1.1\" 200 2357 \"-\" \"Mozilla/5.0 (Windows NT
  10.0; Microsoft Windows 10.0.19045; es-CO) PowerShell/7.6.6\" combined","logger_name":"com.amazonaws.
  serverless.proxy.internal.LambdaContainerHandler","thread_name":"main","level":"INFO","level_value":20000}
2026-10-08T02:35:21 END RequestId: 963366ad-e2a5-4062-8e70-a1705092a423
2026-10-08T02:35:21 REPORT RequestId: 963366ad-e2a5-4062-8e70-a1705092a423  Duration: 20953.39 ms
  Billed Duration: 20954 ms  Memory Size: 512 MB  Max Memory Used: 312 MB
2026-10-08T02:36:24 {"@timestamp":"2026-10-08T02:36:24.70127579Z","@version":"1","message":"179.13.46.8
  --  [08/10/2026:02:36:24Z] \"GET /api/v1/parameters HTTP/1.1\" 200 2358 \"-\" \"Mozilla/5.0 (Windows NT
  10.0; Windows NT 10.0.19045; es-CO) PowerShell/7.6.6\" combined","logger_name":"com.amazonaws.
  serverless.proxy.internal.LambdaContainerHandler","thread_name":"main","level":"INFO","level_value":20000}
2026-10-08T02:36:24 REPORT RequestId: d7fc576b-2796-4ac6-a16f-862814ad6fa4  Duration: 35.00 ms
  Billed Duration: 35 ms  Memory Size: 512 MB  Max Memory Used: 312 MB
```
- Volcado íntegro sin recortar disponible en
  `projects/com.quizsmart.app/logs/cw-dump-2.txt` (63 líneas, `aws logs tail --since 60m`).

### Veredicto por criterio
| Criterio | Resultado | Detalle |
|---|---|---|
| Endpoint `/api/v1/parameters` | **sí**, 200 | 503 en el primer intento por cold start |
| JSON estructurado (1 línea = 1 JSON) | **sí** | 13 líneas, 0 inválidas con `ConvertFrom-Json` |
| Campo `timestamp` | **no** | emite `@timestamp`; CloudWatch no indexa ni `level` ni tiempo |
| Campo `level` | **sí** | presente en toda línea; único valor observado `INFO` |
| Masking de campos sensibles | **no** | `addPaths` descartado por logback; 0 apariciones de `***` |
| Nivel `debug` observable | **no** | 0 líneas `DEBUG`; `root level="info"` (`logback-base.xml:24`) |
| `info` al inicio de métodos | **no verificable** | no hay marca de entrada de método en la salida |

## Diagnóstico 2026-10-07 21:50 — por qué no se aplica el masking (solo lectura)

- Sin cambios en código de producto. Reproducción en scratch, ya borrado.
- Fuentes: `logback-base.xml:18-21`, bytecode de `logstash-logback-encoder-8.1.jar`
  (`javap`) y fuente oficial del `MaskingJsonGeneratorDecorator` en `main`.
- Versión gestionada: `common-bom/pom.xml:58` fija
  `epc.logstash-logback-encoder.version=8.1`. Es la que viaja en la imagen.

### Candidatos evaluados
1. **La versión no soporta `<addPaths>`** → **PARCIALMENTE CIERTO, y es la causa principal.**
   - `javap` de 8.1: `addPath(String)` y `addPaths(String)` **sí existen**, más
     `setDefaultMask(String)` y `addPathMask(...)`.
   - La fuente oficial confirma que `addPaths(String)` existe.
   - Pero logback 1.5.12 **no lo resuelve como propiedad**: solo reconoce el método
     `set<Propiedad>`, y los métodos `add<Propiedad>` solo se usan para elementos hijos
     repetidos, no para texto escalar.
   - Reproducido localmente con el mismo stack (logback 1.5.12 + encoder 8.1):
     `<addPaths>password,apiKey</addPaths>` emite exactamente
     `WARN Ignoring unknown property [addPaths] in
     [net.logstash.logback.mask.MaskingJsonGeneratorDecorator]`,
     idéntico al de CloudWatch.
   - Con la forma documentada `<path>password</path>` repetida, el `WARN` desaparece.
   - **Conclusión**: la propiedad está mal escrita; el API correcto en 8.1 es
     `<path>` (o `<setPath>`) por cada campo, no `<addPaths>` con lista separada por comas.
2. **El sensible llega en `message` y no como propiedad JSON** → **CONFIRMADO como segundo
   defecto, independiente del primero.**
   - El decorador enmascara por **nombre de campo JSON**, nunca el texto de `message`.
     El propio `logback-base.xml:9-10` lo documenta así.
   - Reproducido: con dato en `message` el valor sale en claro
     (`"message":"with map {password=secret123, apiKey=AKIA-XYZ, n=1}"`).
   - Con el mismo dato como campo JSON (MDC) y `<path>` correcto, sale enmascarado:
     `..."message":"entrada",...,"password":"***","apiKey":"***","token":"***"}`.
   - En la salida real de CloudWatch el `apiKey` aparece como
     `apiKey presente=true` y el secreto como `[WH] secreto resuelto len=39`,
     o sea **el código ya evita filtrar el valor** por diseño. Eso oculta el defecto, pero
     el criterio de aceptación sigue incumplido porque el decorador está inactivo.
3. **El appender de Lambda no pasa por el decorador** → **DESCARTADO.**
   - El log muestra que `CONSOLE`/`LogstashEncoder`/`MaskingJsonGeneratorDecorator`
     se instanciaron correctamente; solo se descartó la propiedad `addPaths`.
   - El include funciona: `logback-base.xml` se resuelve desde
     `jar:file:/var/task/lib/common-log-1.1.5.jar!/logback-base.xml`.

### Causa raíz del masking
- **Defecto de configuración en `library/common/common-log/src/main/resources/
  logback-base.xml:20`**: `<addPaths>` no es una propiedad válida para logback 1.5.12 y se
  descarta en silencio (solo un `WARN` en el arranque). El decorador queda sin rutas, así que
  **ningún campo se enmascara**.
- **Defecto de uso, independiente**: los datos sensibles se interpolan en `message`, donde el
  enmascarador por campo no puede actuar.
- Los 23 campos de `logback-base.xml:20` quedan **no verificables**: ninguno llega a la
  salida como campo JSON con valor.

### Causa probable del `@timestamp` en lugar de `timestamp`
- **El `LogstashEncoder` 8.1 emite `@timestamp` por defecto y `logback-base.xml` no lo renombra.**
  Es comportamiento de la librería, no un fallo del despliegue.
- El comentario de `logback-base.xml:5-7` promete el esquema con `timestamp`, y el objetivo
  requiere que CloudWatch indexe por `timestamp` y `level`. Falta el
  `<fieldNames><timestamp>@timestamp</timestamp></fieldNames>` en el encoder.
- Impacto: CloudWatch Logs no indexa nivel ni tiempo, así que los filtros por nivel no funcionan.

## Operación
- Drift: ninguno detectado en AWS respecto al apply de esta ejecución.
- Rollback: no aplicable; no hubo cambios fuera del alcance autorizado.
- No se hizo commit ni push del monorepo. No se modificó código de producto.
- Costes observados: `INIT_REPORT Init Duration: 10000.00 ms Phase: init Status: timeout`
  (la función sí arrancó después); invocación `Duration: 20953.39 ms`,
  `Max Memory Used: 312 MB` de 512 MB.

## Corrección de path 2026-10-07 21:45 - error registrado antes

- Las secciones "up.ps1 -Fast" y "Análisis §1" atribuyen el error
  `No se encuentra un parámetro que coincida con el nombre de parámetro "Fast"` a `up.ps1`.
  **Esa conclusión es errónea**: se invocó el script equivocado.
- Script correcto: `projects/com.quizsmart.app/up.ps1`. **Sí acepta `-Fast`**.
- Parámetros reales: `-Environment`, `-AutoApprove`, `-PlanOnly`, `-SkipFrontend`, `-Fast`,
  `-DeviceId`, `-PlatformRoot`, `-SkipPlatform`.
- `library/platform/scripts/up.ps1` es solo plataforma: `-TerraformDirectory`, `-WhatIf`,
  `-AutoApprove`. No es el script de aplicación.
- Impacto: el bloqueo "requiere `-AutoApprove` porque `-Fast` no existe" queda anulado.
  `-AutoApprove` viene activado por defecto en el script del proyecto.
- Consecuencia: el `drift` de `Análisis §2` (`list-domains` vacío) era efecto del mismo error
  de path. Reconciliado en la ejecución de `up.ps1 -Fast`; `list-domains` ya devuelve `epc`.
- El historial anterior se conserva sin borrar.

## Nota de incidente 2026-10-07 21:50 - pérdida del informe

- Al anexar esta corrección se sobrescribió por error el archivo completo con la herramienta de
  escritura, perdiendo el contenido previo. **No hay copia**: el archivo no estaba trackeado en
  git y los snapshots de opencode no lo contienen.
- El archivo fue reconstruido a partir de las lecturas hechas en esta sesión. Las secciones
  "Ejecución", "Análisis" y "up.ps1 -Fast (completa)" están restauradas; puede haber ligeras
  diferencias de formato respecto al original.
- Sin impacto en infraestructura: solo afecta a la documentación del entregable.