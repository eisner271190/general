# Informe de coordinacion

- Objetivo: `OBJ-003 Logs estructurados en common`
- Agente: `Orchestrator`
- Fecha: `2026-10-07`
- Estado: `cerrado parcial` - 3 criterios incumplidos, correccion no autorizada
- Resumen: 10 de 13 criterios de aceptacion cumplidos. Despliegue AWS EXITOSO y endpoint 200.
  Fallan masking, timestamp y nivel debug. Usuario decidio registrar y parar.

## Roster
| Agente | Informe | Estado |
|---|---|---|
| Explorer | `explorer.md` | completo |
| Researcher | `researcher.md` | completo |
| Architect | `architect.md` | completo |
| Developer-Java | `developer.md` | completo |
| Reviewer | `reviewer.md` | completo |
| Tester | `tester.md` | completo |
| Integrator | `integrator.md` | completo |
| Orchestrator | este | completo |

## Resultado por paso solicitado
| Paso | Resultado |
|---|---|
| 1. Compilar y ejecutar el generador | Aprobado. `dotnet build` 0 errores; `dotnet run` `OK=1, 1,1s`; sin diff en `quizapi` |
| 2. Ejecutar `up.ps1 -Fast` | Aprobado. Path correcto `projects/com.quizsmart.app/up.ps1`; exit 0 en 704 s; 5/5 pasos |
| 3. Runtime: JSON y masking de 23 campos | Parcial. JSON por linea OK; masking FALLA, 0 de 23 |
| 4. Nivel debug activo | NO verificable. 0 lineas DEBUG; `root=info` en `logback-base.xml:24` |

## Correccion de error previo
- Informes anteriores atribuyeron a `up.ps1` la falta del parametro `-Fast`.
- Error real: se invoco `library/platform/scripts/up.ps1` (solo plataforma) en vez de
  `projects/com.quizsmart.app/up.ps1`. `-Fast` si existe en el script del proyecto.
- Consecuencia: el "drift" de CodeArtifact anotado era efecto del mismo error de path.
  Tras la ejecucion correcta, dominio `epc` ACTIVO, ECR `quizapi` creado, lambda y APIGateway OK.

## Hallazgos criticos
- **Masking**: `logback-base.xml:20` declara `<addPaths>`, que `logback 1.5.12` descarta por no ser
  propiedad reconocida de `MaskingJsonGeneratorDecorator`. Requiere `<path>` repetido. Ademas el
  dato sensible viaja dentro de `message`, que el enmascarador nunca toca.
- **Timestamp**: `LogstashEncoder` 8.1 emite `@timestamp`. CloudWatch indexa por `timestamp`.
  Falta `<fieldNames>` en `logback-base.xml`.
- **Debug**: criterio de aceptacion no observable mientras root siga en `info` y no exista
  `logging.level.<paquete>=DEBUG`.

## Bloqueos
- Correccion de masking, timestamp y nivel debug: no autorizada (decision del usuario 2026-10-07).
- Dudas con recomendacion registradas en `questions.md`.
- Sin commit ni push.

## Cierre
- Criterios cumplidos: 10 de 13.
- Criterios pendientes: masking en runtime, nivel debug en runtime, timestamp indexable.
- Reapertura recomendada cuando se autorice tocar `logback-base.xml` y las plantillas del generator.