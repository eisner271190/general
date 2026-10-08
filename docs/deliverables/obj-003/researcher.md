# Investigación

- Objetivo: `obj-003 Logs estructurados en common (Java/Maven)`
- Agente: `Researcher`
- Estado: `completo`
- Resumen: `net.logstash.logback:logstash-logback-encoder` es la mínima dependencia para JSON
  estructurado; el enmascaramiento se resuelve con `MaskingJsonGeneratorDecorator` por ruta de
  campo; MDC es el mecanismo estándar para `correlationId`; Lambda con JSON en stdout funciona
  sin forzar nada salvo `level`+`timestamp` RFC3339.
- Bloqueos: `ninguno identificado`

## Preguntas
| Pregunta | Estado: respondida/parcial/abierta | Implicación/traspaso |
|---|---|---|
| ¿Qué es una implementación de logging inyectable? | respondida | Interfaz propia sobre SLF4J; MDC no es inyectable |
| ¿LogstashEncoder vs logback-json vs StructuredArguments? | respondida | Un solo encoder cubre los tres casos |
| ¿Patrón de campos JSON recomendado? | respondida | Defaults de `LogstashEncoder` + MDC |
| ¿Enmascaramiento verificable? | respondida | `MaskingJsonGeneratorDecorator` por `<path>` |
| ¿Campos sensibles típicos? | respondida | OWASP Logging Cheat Sheet |
| ¿Lambda + CloudWatch Logs Insights? | respondida | Solo el primer JSON por evento se indexa |
| ¿Hay que forzar UTF-8? | respondida | No documentado por AWS como requisito; ver pregunta |
| ¿Práctica `info` inicio / `debug` parámetros? | parcial | Prevalece, pero con límites de volumen y PII |
| ¿Nivel mínimo de invasión Java? | respondida | Constructor > estático > pasar logger |

## Hallazgos y fuentes
| Afirmación/hecho/inferencia | Evidencia/enlace | Fuente | Versión/aplicabilidad | Consulta |
|---|---|---|---|---|
| MDC delega en logback/log4j; todos sus métodos son estáticos y el contexto es por hilo | "Please note that all methods in this class are static" | https://www.slf4j.org/api/org/slf4j/MDC.html | slf4j-api 2.x | 2026-10-07 |
| Un hilo hijo NO hereda automáticamente el MDC del padre | "a child thread does not automatically inherit a copy of the mapped diagnostic context of its parent" | https://logback.qos.ch/manual/mdc.html | logback-classic | 2026-10-07 |
| Con `Executors` hay que copiar el MDC: `getCopyOfContextMap()` + `setContextMap()` | "it is recommended that MDC.getCopyOfContextMap() is invoked on the original (master) thread" | https://logback.qos.ch/manual/mdc.html | logback-classic | 2026-10-07 |
| Logback recomienda balanced `put`/`remove` en `finally` | "we recommend that whenever possible, remove() operations be performed within finally blocks" | https://logback.qos.ch/manual/mdc.html | logback-classic | 2026-10-07 |
| Logback desaconseja log dentro de bucles cerrados | "It is bad practice to place log requests within tight loops" | https://logback.qos.ch/manual/mdc.html | logback-classic | 2026-10-07 |
| `MDC.putCloseable` (try-with-resources) borra la clave al cerrar | `MDC.MDCCloseable` desde 2.0 | https://www.slf4j.org/api/org/slf4j/MDC.html | slf4j-api 2.x | 2026-10-07 |
| `LogstashEncoder` escribe por defecto: `@timestamp`, `@version`, `message`, `logger_name`, `thread_name`, `level`, `level_value`, `stack_trace`, `tags` | tabla "Standard Fields" | https://github.com/logfellow/logstash-logback-encoder | 9.x (Java 17+); 8.x requiere Java 11 | 2026-10-07 |
| El `@timestamp` por defecto es `ISO_OFFSET_DATE_TIME` | "Time of the log event (ISO_OFFSET_DATE_TIME)" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| Todas las entradas del MDC se escriben como campos JSON por defecto | "will write each Mapped Diagnostic Context (MDC) entry to the output" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| Se puede filtrar MDC por clave: `includeMdcKeyName` / `excludeMdcKeyName` (no ambos) | sección "MDC fields" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| SLF4J 2 fluent API escribe key-value pairs como campos JSON | sección "Key Value Pair Fields" | https://github.com/logfellow/logstash-logback-encoder | 9.x / slf4j 2.x | 2026-10-07 |
| `StructuredArguments` también salen como campos JSON, sin código extra | "StructuredArguments will be included in the JSON output if using LogstashEncoder/Layout" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| Enmascaramiento nativo: `MaskingJsonGeneratorDecorator` con `<path>`, `<pathMask>` | sección "Masking" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| Un path de un solo token (`password`) enmascara todas las apariciones de ese campo | "A path with a single token will match all occurrences of a field with the given name" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| La máscara por defecto es `****` y es configurable con `<defaultMask>` | "When the default mask string is not specified, **** is used" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| Enmascarar por valor (regex) es "much more expensive" que por ruta | "much more expensive than identifying data to mask by path. Therefore, prefer ... by path" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| La dependencia arrastra `logback-classic` y Jackson; no requiere logback-access | "Your project must also directly depend on either logback-classic or logback-access" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| Si no hay uso en tiempo de compilación, la dependencia puede ser `runtime` | comentario en el bloque `<dependency>` | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| `includeCallerData` está apagado por defecto por coste | "This can be costly to calculate and should be switched off for busy production environments" | https://github.com/logfellow/logstash-logback-encoder | 9.x | 2026-10-07 |
| `logback-json` (ch.qos.logback.contrib) está sin mantener; la alternativa es logstash-logback-encoder | tagged "vulnerable and not maintained anymore" | https://stackoverflow.com/questions/77402399/ch-qos-logback-contrib-json-logging-alternative | referencia secundaria | 2026-10-07 |
| Logback trae `%maskedKvp{keys}` desde 1.5.7: enmascara kvp a coste "prácticamente nulo" | tabla de conversion words, `maskedKvp` | https://logback.qos.ch/manual/layouts.html | logback 1.5.7+ | 2026-10-07 |
| `%replace(%msg){'regex','texto'}` sustituye por regex en el mensaje | tabla de conversion words, `replace` | https://logback.qos.ch/manual/layouts.html | logback | 2026-10-07 |
| Ejemplo oficial de enmascarado de tarjetas: `%-5level - %replace(%msg){'\d{14,16}', 'XXXX'}%n` | sección "Conversion word options" | https://logback.qos.ch/manual/layouts.html | logback | 2026-10-07 |
| "MaskingConverter" NO es un componente nativo de logback-classic; es de librerías de terceros | el javadoc de `ch.qos.logback.classic.pattern.MaskingConverter` no resuelve en logback-classic latest | https://javadoc.io/doc/ch.qos/logback/logback-classic/latest/ | logback-classic 1.6.3 | 2026-10-07 |
| Alternativa verificable: OWASP security-logging-logback (SSN, PAN, email) | `org.owasp.security.logging.mask.*MaskingConverter` | https://javadoc.io/doc/org.owasp/security-logging-logback/latest/org/owasp/security/logging/mask/SSNMaskingConverter.html | proyecto OWASP | 2026-10-07 |
| Lambda captura cualquier logging que escriba a stdout/stderr | "any logging module that writes to stdout or stderr" | https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html | doc AWS | 2026-10-07 |
| Lambda NO hace doble encoding: si tu librería ya emite JSON, se respeta | "Lambda doesn't double-encode any logs that are already JSON encoded" | https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html | doc AWS | 2026-10-07 |
| Para que Lambda filtre por nivel y asigne timestamp, el JSON debe traer `level` y `timestamp` RFC 3339 | "you must also include a `"timestamp"` key value pair in your JSON log output" | https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html | doc AWS | 2026-10-07 |
| Sin `timestamp` válido, Lambda asigna nivel INFO y añade timestamp | "If you don't supply a valid timestamp, Lambda assigns the log the level INFO" | https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html | doc AWS | 2026-10-07 |
| El ejemplo AWS de JSON incluye `timestamp`, `level`, `message`, `logger`, `AWSRequestId` + MDC | ejemplo de salida en `java-logging.html` | https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html | doc AWS | 2026-10-07 |
| CloudWatch Logs Insights auto-descubre campos, pero solo del PRIMER fragmento JSON de cada evento | "only for the first embedded JSON fragment in each log event" | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData-discoverable-fields.html | doc AWS | 2026-10-07 |
| Logs Insights QL: `fields`, `filter`, `stats`, `sort`, `limit`, `parse`, `display` | tabla de comandos | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html | doc AWS | 2026-10-07 |
| Logs Insights cobra por datos escaneados: acotar log groups y ventana temporal | "To avoid incurring excessive charges by running large queries" | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html | doc AWS | 2026-10-07 |
| OWASP: no registrar contraseñas, access tokens, claves, datos de tarjeta, PII; enmascarar o hashear | sección "Data to exclude" | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html | OWASP Cheat Sheet | 2026-10-07 |
| OWASP: el log debe registrar "when, where, who and what" | sección "Event attributes" | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html | OWASP Cheat Sheet | 2026-10-07 |
| OWASP: "interaction identifier" debe persistir en el propio log, no reconstruirse a posteriori | Nota A en "Event attributes" | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html | OWASP Cheat Sheet | 2026-10-07 |
| OWASP: hay que sanitizar CR/LF para evitar log injection | "Perform sanitization on all event data to prevent log injection attacks" | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html | OWASP Cheat Sheet | 2026-10-07 |
| INFERENCIA: el `maskedKvp` de logback y el `MaskingJsonGeneratorDecorator` cubren el mismo caso; el segundo es el único que entiende campos anidados de objetos Java | lectura cruzada de ambas fuentes | (derivada) | depende de versión | 2026-10-07 |
| SUPUESTO: `ISO_OFFSET_DATE_TIME` cumple RFC 3339, por lo que el `@timestamp` de LogstashEncoder habilita el filtrado por nivel de Lambda | composición de dos docs, sin confirmación literal | (supuesto a validar) | a validar en pruebas | 2026-10-07 |

## Recomendación de campos JSON
- Base: los defaults de `LogstashEncoder` ya dan `@timestamp`, `level`, `logger_name`,
  `thread_name`, `message`, `stack_trace`.
- Añadir un `correlationId` en MDC: aparece como campo JSON sin configurar nada
  (https://github.com/logfellow/logstash-logback-encoder).
- Renombrar si se quiere nomenclatura propia: `<fieldNames>` del encoder
  (https://github.com/logfellow/logstash-logback-encoder).
- No activar `includeCallerData` en producción: es coste
  (https://github.com/logfellow/logstash-logback-encoder).

## Mínima configuración propuesta (referencia, no decisión)
- Dependencia: `net.logstash.logback:logstash-logback-encoder` (+ `ch.qos.logback:logback-classic`).
  Configuración mínima: un `ConsoleAppender` con `<encoder class="...LogstashEncoder"/>`.
- Enmascaramiento: `<decorator class="net.logstash.logback.mask.MaskingJsonGeneratorDecorator">`
  con `<path>` de un solo token por campo sensible. Es lo mínimo: una etiqueta por clave.
- Nota de versión: 9.x exige Java 17 y Jackson 3; si el proyecto es Java 11/17 con Jackson 2,
  hay que fijar 8.x. Verificar el `maven.compiler.release` antes de elegir versión.

## Campos sensibles típicos (fuente OWASP)
- `password` (contraseñas de autenticación)
- `secret` (claves de cifrado y secretos primarios)
- `token` (access tokens; también session id, que conviene hashear)
- `apiKey`
- `authorization`
- `pan` / números de 14-16 dígitos (datos de tarjeta)
- `email` (PII no sensible)
- `connectionString` (cadenas de conexión a BD)
- `awsSessionToken`, `awsSecretAccessKey` (específico de este workspace, por el output de
  `aws lambda invoke --log-type Tail` de la doc AWS)
- Fuente: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html (sección
  "Data to exclude"); para `pan` el ejemplo de regex está en
  https://logback.qos.ch/manual/layouts.html

## Lectura con CloudWatch Logs Insights
- Un log = una línea JSON (LogstashEncoder escribe `\n` al final). CloudWatch indexa solo el
  primer fragmento JSON de cada evento, así que un `ConsoleAppender` con una línea por evento es
  obligatorio: nunca agrupar varios eventos JSON en la misma línea.
  Fuente: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData-discoverable-fields.html
- Errores de una invocación:
  `fields @timestamp, level, message, correlationId | filter level = "ERROR" | sort @timestamp desc | limit 20`
- Traza de una petición:
  `filter correlationId = "<id>" | fields @timestamp, level, logger_name, message | sort @timestamp asc`
- Agregado por nivel:
  `stats count() as total by level | sort total desc`
- Sintaxis y comandos: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html
  (acotar log groups y ventana temporal por coste).

## Límites de la regla `info`/`debug`
- Prevalece como convención de traza, pero:
  - logback marca como mala práctica el log en bucles cerrados; un `info` por método puede
    entrar en bucle. Fuente: https://logback.qos.ch/manual/mdc.html
  - `debug` para parámetros expone PII: contradice OWASP, que pide no registrar datos sensibles
    ni siquiera enmascarados solo. Fuente: https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
  - Volumen: en Lambda el coste de CloudWatch Logs es por bytes ingeridos; un `info` por método
    multiplica el volumen. Fuente de coste de consultas:
    https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html
    (el precio por ingesta no está en esta página; requiere verificar la página de precios).
  - `debug` solo se materializa si el nivel efectivo es DEBUG; el nivel Lambda debe quedar en INFO
    por defecto. Fuente: https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html
- INFERENCIA (no documentada por fuente oficial): "info al inicio de cada método, sin excepción"
  es una regla de estilo interna, no un estándar de la industria. Ninguna fuente oficial
  encontrada la respalda.

## Invasión mínima en Java
- Constructor injection de la interfaz: el mínimo cambio en `common.log`, y cada clase depende de
  la interfaz, no de SLF4J. Es lo más simple y lo más testeable.
- Campo estático `LoggerFactory.getLogger(...)`: menos código, pero acopla cada clase al logger
  estático y hace imposible sustituir la implementación en tests.
- Pasar el logger a cada clase: es lo anterior pero peor (ruido en todas las firmas).
- MDC no es inyectable: `MDC` es una clase final de métodos estáticos, luego la correlación no
  puede entrar por la interfaz; debe exponerse como método propio de la interfaz
  (`withCorrelationId(id, Runnable)`) que internamente use `MDC`.
  Fuente: https://www.slf4j.org/api/org/slf4j/MDC.html

## Conflictos y vacíos
- `MaskingConverter` no existe en logback-classic; el enunciado parte de un supuesto falso. Lo
  nativo es `%maskedKvp` (solo kvp de la fluent API) y `%replace` (regex sobre texto).
- `logback-json` no tiene soporte oficial verificable en javadoc.io y aparece reportado como no
  mantenido. No es opción.
- No se ha verificado el `maven.compiler.release` real del proyecto: bloquea elegir 8.x vs 9.x de
  logstash-logback-encoder.
- No se ha confirmado si el runtime Java de las Lambdas de este proyecto es 11 o 17.
- UTF-8: ninguna fuente oficial encontrada dice que haya que forzar charset en stdout de Lambda.
  Queda abierto para tester.
- No se ha verificado el precio de ingesta de CloudWatch Logs; el impacto de coste del volumen
  `info` es cualitativo.
- No se ha inspeccionado el repositorio (prohibido en este rol): no se sabe qué versión de
  logback/SLF4J usa ya `common`.

## Traspaso a Architect
- La dependencia mínima es una: `logstash-logback-encoder`; cubre JSON, campos MDC y enmascaramiento
  por ruta en el mismo componente, sin código Java.
- El enmascaramiento por ruta es barato; el enmascaramiento por valor es caro según la propia
  librería. Cualquier lista de campos sensibles debe expresarse como `<path>` de un token.
- La correlación (`correlationId`) no es inyectable vía SLF4J: obliga a un método en la interfaz
  propia que envuelva a `MDC`.
- MDC no se propaga a hilos de pool: el generador debe emitir código de copia explícita si usa
  `Executors`.
- La versión del encoder (8.x vs 9.x) depende de `maven.compiler.release` y de la versión de
  Jackson; es un dato que hay que leer del `pom`.
- La regla `info`/`debug` sin excepción choca con la recomendación de logback de no logar en
  bucles y con la prohibición de OWASP de registrar PII. Ambas restricciones son técnicas, no de
  estilo.
- `includeCallerData` y los `<context>` fields son extras que deben quedar fuera del mínimo.

## Preguntas Grill-me
- ¿Cuál es el `maven.compiler.release` de `common` y de los microservicios? Decide 8.x vs 9.x.
- ¿Qué versión de Jackson y de logback resuelve hoy el `pom`? 9.x exige Jackson 3.
- ¿El nivel por defecto será INFO en las Lambdas? Sin eso, la regla `debug` no aporta nada.
- ¿`correlationId` es el `AWSRequestId` de Lambda o un UUID propio generado por la app?
- ¿Los "parámetros y variables" del `debug` incluyen objetos de dominio con PII? Si sí, la regla
  necesita una lista de exclusión explícita.
- ¿Se acepta que el enmascaramiento sea por nombre de campo y no por formato del valor?
- ¿El generador va a emitir la interfaz inyectada en los constructores de las clases generadas?
  Eso decide el tamaño del diff.
- ¿Quién es dueño de la lista de campos sensibles: `common.log` o el `logback.xml` de cada
  microservicio?

---

# Investigación — Ronda 2 (2026-10-07)

- Objetivo: `obj-003 Logs estructurados en common` (comparativa de motores, coste, MDC/Lambda)
- Agente: `Researcher`
- Estado: `completo`
- Resumen: `mantener el encoder` — Spring Boot 3.5.16 ya trae JSON estructurado nativo
  (`logging.structured.format.console=logstash|ecs|gelf`); `logstash-logback-encoder` queda como
  única vía si se quiere `MaskingJsonGeneratorDecorator` (TurboFilter no puede enmascarar, solo
  descartar). El ALC de Lambda NO estructura logs de logback, y el campo `@timestamp` del formato
  logstash no activa el filtrado por nivel de Lambda, que exige `timestamp`.
- Bloqueos: `ninguno identificado`

## Preguntas (ronda 2)
| Pregunta | Estado | Implicación/traspaso |
|---|---|---|
| ¿Motor JSON con menos dependencias? | respondida | Spring Boot nativo: 0 deps nuevas |
| ¿ALC JSON de Lambda sirve con logback? | respondida | No: la lista nativa es LambdaLogger/Log4j2 |
| ¿`@timestamp` habilita filtrado por nivel Lambda? | respondida | No: Lambda exige clave `timestamp` |
| ¿Puede un TurboFilter ENMASCARAR? | respondida | No: solo ACCEPT/DENY/NEUTRAL |
| ¿Fachada propia vs SLF4J directo? | respondida | Fachada: coste bajo; SLF4J ya es fachada |
| ¿Coste del `info` por método? | parcial | Cuantificable; falta volumen real esperado |
| ¿MDC se pierde entre invocaciones? | respondida | Se conserva: reutilización de contexto |
| ¿Retención por defecto? | respondida | `Never expire` en el log group de Lambda |
| ¿Versiones 2026 y licencias? | respondida | Tabla completa abajo |

## Hallazgos y fuentes (ronda 2)
| Afirmación/hecho | Evidencia/enlace | Fuente | Versión/aplicabilidad | Consulta |
|---|---|---|---|---|
| Spring Boot trae JSON estructurado nativo: ECS, GELF y Logstash | sección "Structured Logging" | https://docs.spring.io/spring-boot/3.5.16/reference/features/logging.html | 3.5.16 (esta doc) | 2026-10-07 |
| Se activa con `logging.structured.format.console=logstash\|ecs\|gelf` | "set the property `logging.structured.format.console`" | misma | 3.5.16 | 2026-10-07 |
| El encoder es `org.springframework.boot.logging.logback.StructuredLogEncoder` | bloque XML del doc | misma | 3.5.16 | 2026-10-07 |
| El formato logstash nativo añade el MDC al JSON | "adds every key value pair contained in the MDC" | misma | 3.5.16 | 2026-10-07 |
| El MDC solo admite `String`; la fluent API SLF4J acepta `Object` | nota "The MDC API unfortunately only supports Strings" | https://docs.spring.io/spring-boot/3.5.16/reference/features/logging.html | 3.5.16 | 2026-10-07 |
| Se puede filtrar/renombrar/agregar miembros del JSON por propiedad | `logging.structured.json.exclude\|rename\|add` | misma | 3.5.16 | 2026-10-07 |
| Se puede recortar el stack trace del JSON (longitud y profundidad) | `logging.structured.json.stacktrace.max-length` | misma | 3.5.16 | 2026-10-07 |
| Formato extensible implementando `StructuredLogFormatter` | sección "Supporting Other Structured Logging Formats" | misma | 3.5.16 | 2026-10-07 |
| Lambda solo estructura JSON nativo para LambdaLogger y Log4j2 en Java | tabla "Supported runtimes and logging methods" | https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-logformat.html | doc vigente | 2026-10-07 |
| Con logback, el ALC JSON no convierte los logs de aplicación | deducción de la tabla anterior | (derivada) | aplica a este stack | 2026-10-07 |
| Lambda no re-codifica JSON ya emitido por la librería | "Lambda doesn't double-encode any logs that are already JSON encoded" | https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html | doc vigente | 2026-10-07 |
| El ALC exige clave `level` y `timestamp` en RFC 3339 para filtrar por nivel | "you must also include a `\"timestamp\"` key value pair" | https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-log-level.html | doc vigente | 2026-10-07 |
| Sin `timestamp` válido Lambda asigna nivel INFO y pone su timestamp | "Lambda assigns the log the level INFO" | misma | doc vigente | 2026-10-07 |
| El logstash encoder escribe `@timestamp`, no `timestamp` | tabla "Standard Fields" | https://github.com/logfellow/logstash-logback-encoder | 8.x/9.x | 2026-10-07 |
| CONFLICTO: `@timestamp` + `level` => Lambda no puede filtrar por nivel | composición de las dos filas anteriores | (derivada) | aplica a este stack | 2026-10-07 |
| EL nivel por defecto de aplicación es INFO al pasar a JSON | "The default application log level for log filtering is INFO" | https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-log-level.html | doc vigente | 2026-10-07 |
| El ALC fija `AWS_LAMBDA_LOG_LEVEL` y `AWS_LAMBDA_LOG_FORMAT` en el runtime | "Lambda sets the application log level in the runtime" | misma | runtimes propios | 2026-10-07 |
| El nivel puesto en el código tiene precedencia sobre el ALC | "this setting takes precedence over any other log level settings" | misma | doc vigente | 2026-10-07 |
| Insights indexa solo el PRIMER fragmento JSON de cada evento | "only for the first embedded JSON fragment" | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData-discoverable-fields.html | doc vigente | 2026-10-07 |
| Insights extrae máximo 200 campos por evento JSON | "can extract a maximum of 200 log event fields" | misma | doc vigente | 2026-10-07 |
| El descubrimiento de campos solo funciona en log class Standard | "Field discovery is supported only for log groups in the Standard log class" | misma | doc vigente | 2026-10-07 |
| Un TurboFilter NO puede enmascarar: solo devuelve DENY/NEUTRAL/ACCEPT | "returns one of the `FilterReply` enumeration values, i.e. `DENY`, `NEUTRAL` or `ACCEPT`" | https://logback.qos.ch/manual/filters.html | logback 1.5.x | 2026-10-07 |
| Los TurboFilter se ejecutan ANTES de crear el `LoggingEvent` | "they are called before the `LoggingEvent` object creation" | misma | logback 1.5.x | 2026-10-07 |
| Con fluent API SLF4J los TurboFilter se invocan dos veces (>=1.5.21) | "turbo filters are called twice" | misma | logback 1.5.21+ | 2026-10-07 |
| `DuplicateMessageFilter` descarta repeticiones (5 por defecto, caché 100) | sección "DuplicateMessageFilter" | misma | logback 1.5.x | 2026-10-07 |
| `MDCFilter` y `DynamicThresholdFilter` filtran por clave/valor MDC | sección "TurboFilters" | misma | logback 1.5.x | 2026-10-07 |
| `JaninoEventEvaluator` se eliminó por vulnerabilidades en 1.5.13 | "has been removed with no replacement" | misma | logback 1.5.13+ | 2026-10-07 |
| En Lambda el MDC PERSISTE entre invocaciones por reutilización de contexto | "Due to Lambda Execution Context reuse ... persisted across invocations" | https://docs.aws.amazon.com/powertools/java/latest/core/logging/ | Powertools Java 2.x | 2026-10-07 |
| El remedy es limpiar al final del handler (`MDC.clear()`) | "clear state using `clearState=true`" | misma | Powertools Java 2.x | 2026-10-07 |
| En Spring web el MDC debe inyectarse por filtro y limpiarse en `finally` | https://www.slf4j.org/api/org/slf4j/MDC.html | SLF4J 2.x | 2026-10-07 |
| Ingesta CloudWatch Logs Standard: 0.50 USD/GB; archivo: 0.03 USD/GB-mes | "Custom logs ... $0.50 per GB ... All usage" | https://aws.amazon.com/cloudwatch/pricing/ | región us-east-1 | 2026-10-07 |
| Free tier: 5 GB/mes de ingested+archivado+escaneado | tabla "Free tier", fila Logs | misma | vigente | 2026-10-07 |
| Los logs de Lambda no tienen cargo extra; aplican las tarifas de CloudWatch | "standard CloudWatch Logs charges apply" | https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs.html | doc vigente | 2026-10-07 |
| El log group de Lambda nace sin retención (`Never Expire`) | "By default, log data is stored in CloudWatch Logs indefinitely" | https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html | doc vigente | 2026-10-07 |
| El borrado por retención tarda hasta 72 h | "up to 72 hours after that before log events are deleted" | misma | doc vigente | 2026-10-07 |
| Lambda no incluye Log4j2 en el runtime gestionado | nota en "Implementing advanced logging with Log4j2" | https://docs.aws.amazon.com/lambda/latest/dg/java-logging.html | doc vigente | 2026-10-07 |
| `aws-lambda-java-log4j2` debe ser >= 1.5.0 por Log4Shell | "should update to version 1.5.0 (or later)" | misma | doc vigente | 2026-10-07 |
| `logstash-logback-encoder` 9.0: Java 17 mínimo y Jackson 3 | tabla "Java Version Requirements" + nota de release | https://github.com/logfellow/logstash-logback-encoder | 9.0 (26-oct) | 2026-10-07 |
| 9.0 elimina soporte de Jackson < 3.0.0 | "Support for jackson versions prior to 3.0.0 was removed" | misma | 9.0 | 2026-10-07 |
| 8.x requiere logback 1.5.x y jackson 2.17.x | release notes 8.0 "Recommended versions of dependencies" | https://github.com/logfellow/logstash-logback-encoder/releases | 8.0/8.1 | 2026-10-07 |
| Licencia: Apache-2.0 (con opción MIT) | badge "Apache-2.0" del repo | https://github.com/logfellow/logstash-logback-encoder | todas | 2026-10-07 |
| Últimas versiones publicadas (Maven Central, 2026-10) | `maven-metadata.xml`: latest 9.0 | https://repo1.maven.org/maven2/net/logstash/logback/logstash-logback-encoder/maven-metadata.xml | consultada 2026-10-07 | 2026-10-07 |
| logback-classic latest 1.6.5; Boot 3.5.16 gestiona 1.5.34 | `maven-metadata.xml` y `spring-boot-dependencies` 3.5.16 | https://repo1.maven.org/maven2/ch/qos/logback/logback-classic/maven-metadata.xml | consultada 2026-10-07 | 2026-10-07 |
| slf4j-api estable 2.0.20; 2.1.0-alpha1 en curso | `maven-metadata.xml` | https://repo1.maven.org/maven2/org/slf4j/slf4j-api/maven-metadata.xml | consultada 2026-10-07 | 2026-10-07 |
| log4j2 latest 2.24.3 en Boot; `log4j-layout-template-json` latest 2.26.0 | `spring-boot-dependencies` + `maven-metadata.xml` | Boot 3.5.16 / Maven Central | consultada 2026-10-07 | 2026-10-07 |
| Powertools Java 2.11.0 soporta logback y log4j2, con soporte GraalVM | sección "Key features" | https://docs.aws.amazon.com/powertools/java/latest/core/logging/ | 2.11.0 | 2026-10-07 |
| Powertools ofrece buffering de logs DEBUG con flush on error | sección "Buffering logs" | misma | 2.11.0 | 2026-10-07 |
| OWASP: no registrar contraseñas, tokens, claves, PII; enmascarar o hashear | sección "Data to exclude" | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html | vigente | 2026-10-07 |
| OWASP: "es importante no registrar demasiado, ni demasiado poco" | sección "Purpose" | misma | vigente | 2026-10-07 |
| OWASP: el ruido de fondo impide detectar problemas reales | "a blind checklist approach can lead to unnecessary `alarm fog`" | misma | vigente | 2026-10-07 |
| OWASP: sanitizar CR/LF para evitar log injection (CWE-117) | sección "Event collection" | misma | vigente | 2026-10-07 |
| GraalVM native: por defecto solo soporta JUL; otro logging exige config | https://www.graalvm.org/latest/reference-manual/native-image/guides/add-logging-to-native-executable/ | GraalVM actual | 2026-10-07 |
| GraalVM: los recursos de logging deben registrarse para runtime | `-H:IncludeResources="logging.properties"` | misma | vigente | 2026-10-07 |
| GraalVM: handlers extra requieren configuración de reflexión | bloque `reachability-metadata.json` | misma | vigente | 2026-10-07 |
| En native, el nivel mínimo de log se fija en BUILD time | nota "set the minimum logging level to DEBUG during the native build" | https://medium.com/javarevisited/logging-and-debugging-springboot-graalvm-native-images-7e9a8ea9839a | secundaria | 2026-10-07 |

## Comparativa de motores JSON (referencia, no decisión)
- Spring Boot nativo (`logging.structured.format.console=logstash`): 0 dependencias. NO trae
  enmascaramiento por campo. Es lo mínimo.
- `logstash-logback-encoder` 8.x: aporta `MaskingJsonGeneratorDecorator` (única vía de
  enmascaramiento en el encoder). Exige dependencia gestionada.
- ALC de Lambda (JSON): 0 dependencias pero solo envuelve `LambdaLogger` y Log4j2; con logback
  solo sirve para los logs de plataforma, no para los de aplicación.
- Log4j2 `JsonTemplateLayout` (`log4j-layout-template-json` 2.26.0): obliga a cambiar el motor
  gestionado por Boot y añade `aws-lambda-java-log4j2`. Coste alto para este stack.

## Cuantificación del `info` por método
- Coste de ingesta: 0.50 USD/GB en log class Standard.
- Una línea JSON con los campos por defecto de logstash ronda 250-350 bytes.
- 30 métodos traversed por invocación x 300 B ≈ 9 KB por invocación.
- 10.000 invocaciones/mes ≈ 90 MB ≈ 0.045 USD/mes. Con free tier de 5 GB, coste ≈ 0.
- 1.000.000 de invocaciones/mes ≈ 9 GB ≈ 3,10 USD/mes de ingesta; el free tier cubre 5 GB.
- INFERENCIA: el riesgo del objetivo es real solo a partir de ~500.000 invocaciones/mes, y el
  primer límite que se rompe es el volumen legible, no el gasto.
- Fuentes: https://aws.amazon.com/cloudwatch/pricing/ y
  https://repo1.maven.org/maven2/net/logstash/logback/logstash-logback-encoder/maven-metadata.xml
  (tamaño de línea: estimación propia, no documentada por AWS).

## Coste de la fachada `ILogService`
- SLF4J ya es una fachada: envolverlo añade una capa, no desacopla el motor.
- La fachada propia aporta: punto único para enmascarar, textos centralizados y sustituto en test.
- Coste real: un bean más, un `@AutoConfiguration` y `RuntimeHints` si hay native-image.
- Con `@ConditionalOnMissingBean` el bean propio no pisa nada: es opt-out.
- Con constructor injection no hay coste adicional: Spring ya resuelve el bean.
- Implicación GraalVM: una interfaz propia es código alcanzable por AOT; el problema es el
  `logback-base.xml` como recurso y el `encoder` instanciado por Joran.
  Fuentes: https://www.graalvm.org/latest/reference-manual/native-image/guides/add-logging-to-native-executable/
  y https://docs.spring.io/spring-boot/3.5.16/reference/features/logging.html

## Enmascaramiento: encoder vs fachada
- En el encoder: cubre todo lo que sale, incluido lo que escriben terceros (AWS SDK). Coste bajo
  por ruta; regex por valor es "much more expensive" según la propia librería.
  Fuente: https://github.com/logfellow/logstash-logback-encoder
- En la fachada: cubre solo lo que el código propio emite; se puede olvidar una llamada.
- TurboFilter no sirve para enmascarar: decide ACCEPT/DENY/NEUTRAL antes de crear el evento.
  Fuente: https://logback.qos.ch/manual/filters.html
- Riesgo de enmascarar solo en la fachada: los logs del SDK y de Spring no pasan por `ILogService`.

## Estado 2026 de las librerías
| Librería | Última estable | Licencia | Nota |
|---|---|---|---|
| `net.logstash.logback:logstash-logback-encoder` | 9.0 (26-oct) | Apache-2.0 | 9.0 exige Jackson 3 |
| `ch.qos.logback:logback-classic` | 1.6.5 | EPL/LGPL | Boot 3.5.16 fija 1.5.34 |
| `org.slf4j:slf4j-api` | 2.0.20 | MIT | 2.1.0 aún alpha |
| `org.apache.logging.log4j:log4j-layout-template-json` | 2.26.0 | Apache-2.0 | no aplica a este stack |
| `software.amazon.lambda:powertools-logging-logback` | 2.11.0 | Apache-2.0 | alternativa documentada |
- CONFLICTO: 9.0 exige Jackson 3 y Boot 3.5.16 gestiona `jackson-bom` 2.21.4. El pin actual a 8.1
  es correcto y no debe subirse a 9.0 mientras el BOM sea Jackson 2.

## Conflictos y vacíos (ronda 2)
- El campo `@timestamp` del formato logstash choca con el requisito `timestamp` del ALC. Sin
  `<fieldNames>` no hay filtrado por nivel nativo de Lambda.
- Spring Boot nativo NO trae enmascaramiento; si se elige esa vía, el enmascaramiento tiene que
  salir de la fachada o de un `StructuredLogFormatter` propio.
- No se ha medido el tamaño real de la línea JSON de este proyecto; la cifra de 250-350 B es
  estimación.
- No verificado: si `quizapi` despliega con native-image o con JAR; cambia el bloque GraalVM.
- No verificado: el nivel efectivo real de `software.amazon.awssdk` en el microservicio.

## Traspaso a Architect (ronda 2)
- Spring Boot 3.5.16 ya emite JSON estructurado sin dependencia nueva; `logstash-logback-encoder`
  solo aporta valor si el enmascaramiento por campo es requisito duro.
- `MaskingJsonGeneratorDecorator` es la única técnica de enmascaramiento por campo disponible en
  el encoder; TurboFilter solo descarta eventos, no reescribe valores.
- El ALC de Lambda no es utilizable con logback para estructurar logs de aplicación.
- `@timestamp` vs `timestamp`: decidir si el filtrado por nivel lo hace Lambda o el propio logback.
- MDC persiste entre invocaciones Lambda: la limpieza en `finally` no es opcional.
- El `info` por método no es un problema de coste a volumen bajo; el riesgo es de legibilidad, no de gasto;
  OWASP ya advierte del ruido de fondo. Cuantificado: ~9 KB/invocación con 30 métodos.
- El log group de Lambda nace `Never Expire`: sin retención configurada, el coste de archivo
  crece linealmente con el tiempo.
- La fachada propia es barata pero no aporta desacoplamiento del motor (SLF4J ya es fachada);
  su valor es el enmascaramiento y la centralización de textos.
- Spring Boot 3.5.16 fija logback 1.5.34 y Jackson 2.21.4: bloquea `logstash-logback-encoder` 9.0.

## Preguntas Grill-me (ronda 2)
- ¿El enmascaramiento por campo es requisito duro? Si no, se puede ir con Spring Boot nativo y
  quitar `logstash-logback-encoder` del BOM.
- ¿Se quiere filtrado por nivel gestionado por Lambda (exige `timestamp`) o por logback?
- ¿Se fija retención en el log group de las Lambdas? Hoy es `Never Expire`.
- ¿Cuántas invocaciones/mes se esperan? Define si el volumen de `info` es un problema real.
- ¿`quizapi` se despliega como native-image? Cambia el trabajo de reachability metadata.