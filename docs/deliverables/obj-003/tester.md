# Informe de pruebas

- Objetivo: `OBJ-003 Logs estructurados en common`
- Agente: `Tester`
- Estado: `parcial`
- Resumen: Generator compila/ejecuta; quizapi regenerado con logback include; compilación OK.
- Bloqueos: JSON/masking runtime pendiente; no se ejecutó aplicación ni AWS.
- Entorno/versiones: Local Windows 10; .NET SDK 10.0.401; JDK 17.0.12; Maven 3.9.9.

## Casos y resultados
| Criterio/caso | Comando o procedimiento | Resultado/evidencia |
|---|---|---|
| Compilación del generator | `dotnet build` en `generator/` | Aprobado: 2 proyectos, 0 errores/advertencias. |
| Regeneración quizapi | `dotnet run --project Generator.csproj` en `generator/` | Aprobada: 1 configuración, OK=1; termina sin error. |
| Diff de salida | `git status --short -- projects/com.quizsmart.app/backend/quizapi` y `git diff --stat` | Sin cambios; código ya regenerado previamente. |
| logback.xml con include | Inspección `src/main/resources/logback.xml` | Aprobado: contiene `<include resource="logback-base.xml" />`. |
| application.properties sin logging.config | Inspección `src/main/resources/application.properties` | Aprobado: no contiene `logging.config`. |
| Compilación sin tests | `mvn -DskipTests compile` en `projects/com.quizsmart.app/backend/quizapi` | BUILD SUCCESS; advertencia unchecked conversion en `DynamoDbGenericPersistence.java:29`. |

## Fallos reproducibles
- Ninguno en esta ejecución.

## Omisiones y limitaciones
- Sin pruebas existentes ejecutadas ni modificadas, conforme a restricciones.
- No se ejecutaron acciones AWS, despliegue, `curl`, publicación a CodeArtifact ni commit/push.
- No se probó el endpoint ni salida real JSON/masking: runtime no iniciado.
- No se verificó resolución de `logstash-logback-encoder` desde CodeArtifact en esta ejecución.

## Veredicto
- `aprobado` para build, regeneración, configuración logback y compilación.
- Pendiente: validación runtime de JSON, masking y endpoint (requiere despliegue autorizado).

## Ejecución 2 — 2026-10-07 14:32 (UTC-5)

- Objetivo: `OBJ-003 Logs estructurados en common`
- Agente: `Tester`
- Alcance: solo lectura/verificación. Sin commit, push, AWS, CodeArtifact ni `curl`.
- Entorno: Windows local; .NET SDK 10.0.401 (build incremental 00:00:01.62).

### Casos y resultados
| Caso | Comando o procedimiento | Resultado/evidencia |
|---|---|---|
| Build generator | `dotnet build` en `generator/` | Aprobado: 2 proyectos, 0 errores, 0 advertencias. |
| Ejecución generator | `dotnet run --project Generator.csproj` | Aprobada: `Configuraciones detectadas: 1`, `Resumen: OK=1, Duracion=1,1s`, sin excepción. |
| Salida del generator | Log de ejecución | Componentes: `backend=spring-boot-3.5.16`, `frontend=flutter3.47.2`, `cloud=aws`; `OutputPath=C:\epc\general\projects\com.quizsmart.app`; `generation-plan.json` regenerado. |
| Plantillas omitidas | Log de ejecución | 74 plantillas omitidas por render vacío (gated `security`/SQS/cognito); esperado para `quizapi`. |
| Diff de salida | `git status --short -- .../backend/quizapi` y `git diff --stat` | Sin salida: el código generado es idéntico al ya versionado. Regeneración reproducible. |
| Nivel raíz | Lectura `logback-base.xml:24` | `<root level="info">`: el runtime no emite `debug`. |
| `logging.level.*` | Búsqueda en `quizapi/src/main/resources` | Solo `application.properties:35` → `logging.level.software.amazon.awssdk=INFO`. No existe `logging.level.com.quizsmart.app=DEBUG`. |
| `logback.xml` generado | Lectura `logback.xml:3` | Contiene `<include resource="logback-base.xml" />`; resuelve el fragmento de `common-log`. |
| Enmascaramiento configurado | Lectura `logback-base.xml:20` | `MaskingJsonGeneratorDecorator` con 23 paths (`password`, `token`, `secretKey`, `email`, ...). |
| Verificabilidad de `debug` | Análisis de nivel efectivo | **No verificable en runtime**: con `root=info` las líneas `log.debug` se descartan antes de escribir. |

### Fallos reproducibles
- Ninguno. No hay errores ni advertencias de compilación.

### Omisiones y limitaciones
- No se compiló ni ejecutó `quizapi` en esta ronda (fuera del alcance solicitado).
- No se publicaron artefactos en CodeArtifact; no se resolvió `logstash-logback-encoder:8.1`.
- No se validó JSON ni masking en runtime; no se consultaron logs de Lambda.
- Sin pruebas existentes ejecutadas ni modificadas.

### Veredicto
- `aprobado`: build del generator, ejecución (`OK=1`), reproducibilidad sin diff y configuración de
  logback/masking en `common-log`.
- `bloqueado` el criterio «parámetros y variables con `log.debug`»: no observable con `root=info`.
  Depende de decisión registrada en `questions.md` (Tester 2026-10-07 14:34).
