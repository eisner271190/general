# Preguntas OBJ-003: Logs estructurados en common

## Abiertas

- ¿`common-log` puede depender de Spring Boot? Hoy solo tiene `slf4j-api` y no expone beans.
  Rec: sí, `spring-boot-starter` como `provided`, para registrar la interfaz por autoconfiguración.
- ¿La interfaz `LogPort` se inyecta por constructor en domain, o solo en application/infrastructure?
  Rec: solo aplicación e infraestructura; `domain` queda sin logger (ArchUnit lo forbids).
- ¿Nombre de la interfaz? Rec: `ILogService` en `com.epc.common.log` (regla de prefijo `I`).
- ¿Qué formato de salida: JSON por línea vía `logstash-logback-encoder` o Log4j2 `JsonTemplateLayout`?
  Rec: logback + `logstash-logback-encoder`, porque el motor efectivo ya es logback.
- ¿Se añade `logstash-logback-encoder` como dependencia gestionada por `common-bom`?
  Rec: sí, nueva propiedad `epc.logstash-logback-encoder.version`.
- ¿`logback.xml` se centraliza en `common-web` o sigue siendo de cada microservicio?
  Rec: plantilla `common` en `src/main/resources` más override permitido en el ms.
- ¿El microservicio conserva su `logback.xml` o lo borra? Rec: lo borra y hereda el de `common`.
- ¿`logback.scriban` y `log4j2.scriban` unregistered: se borran o se registran?
  Rec: borrar `log4j2.scriban`; queda un solo motor.
- ¿Qué clave se añade al MDC junto a `requestId` (microservicio, ambiente, invocación)?
  Rec: solo `requestId`; el resto va en campos del JSON, no en MDC.
- ¿El API congelada de `common-log` en `1.0.0` se rompe? Rec: sí, hay que subir a `1.1.0`.
- ¿La versión de `common-bom` importada en `pom.scriban` sigue en `1.0.0` mientras el parent está en `1.0.1`?
  Rec: alinear ambas al bumpear `common`; hoy hay desfase sin explicar.
- ¿Qué campos se enmascaran: password, token, secretKey, apiKey, cookie, authorization?
  Rec: lista fija por nombre de campo, con `***` como valor.
- ¿El enmascaramiento es por nombre de clave o por anotación en los DTO?
  Rec: por nombre de clave, para no tocar todos los DTO.
- ¿Los DTOs sensibles se registran enteros o campo a campo? Rec: campo a campo.
- ¿`info` en cada método incluye salida también (R9) o solo entrada? Rec: entrada y salida.
- ¿El nivel por defecto del root sigue en `info` en Lambda? Rec: sí; `debug` solo bajo demanda.
- ¿Se crea clase `LogMessages` en `common.log` o por microservicio?
  Rec: base común en `common.log`; las claves de cada ms en su `infrastructure.configuration`.
- ¿El nombre de la clase de mensajesYF? Rec: `LogMessages`.
- ¿Se genera `LogMessages` por plantilla para cada microservicio? Rec: sí.
- ¿Cada clase del ms recibe `ILogService` por constructor (campo final)?
  Rec: sí, constructor; sin `@Autowired` en campo.
- ¿El enmascaramiento se hace en la implementación, no en el mensaje? Rec: en la implementación.
- ¿Se añade `@Slf4j`? Rec: no; rompe la inyección por dependencia pedida.
- ¿Las clases `Strategy` de suscripción reciben logger? Rec: sí, todas.
- ¿El código no-Spring (LambdaHandler) cómo obtiene el log? Rec: variable estática, con nota.
- ¿El arranque del contexto (`Application.main`) se registra? Rec: sí, una línea `info`.
- ¿Se migra también `GlobalExceptionHandler` de `common-web`? Rec: sí, al puerto.
- ¿Se cambia `log.error(msg, ex)` del advice a la interfaz? Rec: sí.
- ¿`RequestCorrelationFilter` pasa a usar la interfaz? Rec: sí.
- ¿Los tests existentes se tocan? Rec: no; regla dura del workspace.
- ¿ArchUnit `HexagonalArchitectureTest` tolera el nuevo puerto en `domain`?
  Rec: mantener el logger fuera de `domain` y no tocar el test.
- ¿`AiMessages` y `AiConstants` se fusionan con `LogMessages`? Rec: no, son de otro dominio.
- ¿El JSON incluye el MDC (`requestId`) automáticamente? Rec: sí, con `includeMDCEntryInJsonOutput`.
- ¿Se define un esquema de campos (`timestamp`, `level`, `logger`, `message`, `requestId`)?
  Rec: sí, fijo y documentado.
- ¿CloudWatch Logs subgroup por microservicio o stream por requestId?
  Rec: stream por `requestId`, agrupado por Lambda.
- ¿Se crea `aws_cloudwatch_log_group` en Terraform? Rec: no, el default `/aws/lambda/*` basta.
- ¿Se necesita permiso IAM nuevo? Rec: no; ya hay `logs:PutLogEvents`.
- ¿Se añade `AWS_LAMBDA_LOG_FORMAT` como variable de entorno en Terraform?
  Rec: no, logback decide el formato.
- ¿Se usan `update-all.ps1` y `update-ms.ps1` para desplegar? Rec: sí, ya están.
- ¿Se necesita un script nuevo para consultar logs? Rec: no; `aws logs tail` manual.
- ¿El criterio de aceptación "logs en JSON" se valida con `aws logs tail`?
  Rec: sí, y con postman contra `/api/v1/parameters`.
- ¿Niveles `warn`/`error` quedan fuera del alcance? Rec: sí, se mantienen.
- ¿Los logs de AWS SDK en `DEBUG` (`application-properties.scriban:34`) se suben o bajan?
  Rec: bajar a `INFO`; satura y filtra cabeceras.
- ¿Cómo se verifica el enmascaramiento? Rec: log de prueba con password/token.
- ¿La plantilla `graalvm-hints` y `native-image-properties` necesitan el encoder en runtime hints?
  Rec: sí, añadir `RuntimeHints` para el encoder.
- ¿Hay coste de arranque por el encoder? Rec: se mide en el cold start.
- ¿La API de `MdcCorrelation` sigue igual? Rec: sí, no tocar.
- ¿Se añade un `masking` por anotación Java? Rec: no, por nombre de clave.
- ¿El microservicio puede sobreescribir el bean de log? Rec: sí, vía `@ConditionalOnMissingBean`.
- ¿Quién decide los textos: `common.log` o cada ms? Rec: cada clave en su ms, formato común en `common`.
- ¿Cuántas claves de log se estandarizan? Rec: las de los mensajes ya existentes.
- ¿Se genera `ILogService` mock para tests? Rec: no, no se tocan tests.
- ¿`common-log` publica su propio `AutoConfiguration.imports`? Rec: sí, si se opta por beans.
- ¿El nombre del módulo de autoconfig es `common-web` o `common-log`? Rec: `common-log`, le corresponde.
- ¿Qué pasa con microservicios sin web (SQS, batch)? Rec: mismo puerto, sin filtro.
- ¿Se registra en MDC el nombre del microservicio? Rec: no, ya va `spring.application.name`.
- ¿El enmascarador también actúa sobre `MDC`? Rec: no.
- ¿Se expone un `info` de arranque con versión y ambiente? Rec: sí, con placeholders de Spring.
- ¿El formato de fecha del JSON es ISO-8601? Rec: sí.
- ¿Se usa `@Nullable` en los métodos del puerto? Rec: no, KISS.
- ¿El puerto tiene `error(msg, throwable)`? Rec: sí, overload explícito.
- ¿El puerto tiene `warn`? Rec: sí, mismo trato que `error`.
- ¿`debug` acepta varargs de clave/valor o solo placeholders `{}`?
  Rec: placeholders `{}` y una variante con mapa para campos sueltos.
- ¿Se mantienen los literales en inglés como hoy? Rec: sí, uniforme en inglés.
- ¿Se añade ADR para la decisión de motor? Rec: sí, ADR nueva.
- ¿Se actualiza `README.md` y `docs/como-usar.md` de `common`? Rec: sí.
- ¿Se actualiza la colección postman si no cambian endpoints? Rec: no cambia nada.
- ¿Se versiona `common` con `bump-bom-version.py` tras el cambio? Rec: sí, flujo estándar.
- ¿Se regenera el código y se revisa el diff completo? Rec: sí.
- ¿Se compila `common` antes de regenerar? Rec: sí, en ese orden.
- ¿El objetivo cubre `samples/log-only-sample`? Rec: sí, como prueba del puerto.
- ¿El objetivo cubre `samples/web-sample`? Rec: sí, para validar el patrón JSON.
- ¿Quién aprueba el listado de campos sensibles? Rec: el usuario, antes de codificar.

- ¿Se aprueba la lista de campos sensibles de `architect.md` §4 (23 nombres por path)?
  Rec: sí, tal cual; bloquea la implementación del enmascarado.
- ¿La clase de textos por microservicio se llama `DomainLogMessages` para no colisionar con
  `com.epc.common.log.LogMessages` al importarlas juntas? Rec: sí, nombre distinto.
- ¿Qué versión exacta de `logstash-logback-encoder` 8.x se fija? Rec: la última 8.x que resuelva
  CodeArtifact; verificar antes de codificar.
- ¿CodeArtifact replica `net.logstash.logback:logstash-logback-encoder`? Rec: verificar resolución
  antes de implementar, si no hay que replicarlo en la plataforma.
- ¿El microservicio sigue generando `logback.xml` o se borra y hereda `logback-base.xml` de
  `common-log`? Rec: se borra la generación; si el ms necesita ajuste, lo añade a mano.
- ¿Se expone `info(String, Map)` en `warn`/`error` cuando aparezca el primer caso real?
  Rec: no; añadirlo con el caso, no antes.
- ¿`withRequestId` cubre también la propagación de MDC a hilos de pool? Rec: no; cada plantilla que
  use `Executors` copia el MDC explícitamente.
- ¿El esquema JSON renombra `@timestamp` a `timestamp` con `<fieldNames>` en la versión 8.x?
  Rec: sí, pero confirmar en tester; si no funciona, se deja `@timestamp` y se acepta que Lambda
  asigne nivel INFO.

## Respuestas del usuario

- 2026-10-07 13:20 · ¿Se aprueba la lista de campos sensibles (`architect.md` §4)?
  → Sí, tal cual. Enmascarar con `***`.
- 2026-10-07 13:20 · ¿Se escribe ADR-0025? → Sí, estado `propuesto`, pendiente de aprobación.
- 2026-10-07 13:20 · ¿Se autoriza `developer-java`? → Sí: Tarea 2 (`library/common`) y
  Tarea 3 (`generator`).
- 2026-10-07 14:18 · ¿Se autoriza SLF4J fluent key-value para overload Map si lo soporta la
  versión gestionada? → Sí; emitir cada entrada como key-value estructurado, sin concatenarla
  al mensaje.
- 2026-10-07 · ¿El generator debe emitir logback.xml incluyendo el recurso base de common-log?
  → Sí; generar configuración mínima con `<include resource="logback-base.xml"/>`. El recurso
  common debe ser un fragmento `<included>` empaquetado en el jar, no duplicarlo.

## Preguntas abiertas — ronda 2 (Researcher, 2026-10-07)

- ¿El enmascaramiento por campo es requisito duro? Spring Boot 3.5.16 ya emite JSON sin
  dependencia nueva; `logstash-logback-encoder` solo aporta `MaskingJsonGeneratorDecorator`.
  Rec: mantener el encoder; el enmascaramiento no se puede replicar con TurboFilter.
- ¿Se quiere filtrado por nivel gestionado por Lambda? `logstash` escribe `@timestamp` y Lambda
  exige `timestamp`. Rec: dejar el filtrado en logback (`root level="info"`); no usar ALC.
- ¿El ALC de Lambda sirve aquí? Solo estructura `LambdaLogger` y Log4j2, no logback.
  Rec: no usar ALC en este stack.
- ¿Se fija `RetentionInDays` en el log group de la Lambda? Hoy nace `Never Expire`.
  Rec: sí, 14 días; el coste de archivo crece linealmente si no.
- ¿Cuántas invocaciones/mes se esperan? Con 30 métodos son ~9 KB por invocación; a 1M/mes son
  ~9 GB y ~3,10 USD/mes. Rec: decidir antes de aplicar `info` sin excepción.
- ¿`quizapi` se despliega como native-image o como JAR? Cambia el trabajo de reachability
  metadata para `logback-base.xml` y el encoder. Rec: confirmar antes de tocar native.
- ¿Se sube `logstash-logback-encoder` a 9.0? 9.0 exige Jackson 3 y Boot 3.5.16 gestiona
  `jackson-bom` 2.21.4. Rec: no; mantener 8.1.
- ¿Se acepta que el nivel efectivo del AWS SDK siga en `DEBUG`? Satura CloudWatch.
  Rec: bajarlo a `INFO` (ya decidido en ronda 1, confirmar que sigue vigente).

## Explorer · 2026-10-07 09:40

- [ ] ¿Se añaden `oldPassword` y `newPassword` a la lista de paths del enmascarador?
  — rec: sí; `change-password.scriban:5-6` los declara y hoy nadie los enmascara.
- [ ] ¿Se acepta que el enmascarador actúa sobre nombre de campo JSON y no sobre `message`?
  — rec: sí, y se documenta la regla: el sensible va como campo JSON, nunca interpolado en `{}`.
- [ ] ¿Se añade `logging.level.<microservicio>=DEBUG` en `develop` para verificar el criterio de `debug`?
  — rec: sí; hoy root `info` (`logback-base.xml:24`) hace el criterio de `debug` no verificable.
- [ ] ¿Se generaliza `METHOD_ENTER` de `LogMessages:18` a cada método, o se mantiene mensaje propio?
  — rec: mensaje propio por operación; el genérico solo genera volumen sin información.
- [ ] ¿Se inyecta `ILogService` en `parameter-controller.scriban:17` aunque rompa su test?
  — rec: inyectar y avisar; los tests no se tocan y hace falta decisión explícita.
- [ ] ¿Se migran ahora las ~40 plantillas gated `Name == "security"`?
  — rec: no; hoy no compilan para `quizapi`, se migran cuando exista el ms de seguridad.
- [ ] ¿Se corrige `auth-response-dto.scriban:5`, que expone `password` en un DTO de respuesta?
  — rec: sí; es un defecto de una línea, no una cuestión de logging.
- [ ] ¿Se fija el esquema JSON con `<fieldNames>` o se acepta el de la librería?
  — rec: aceptar el de la librería; `<fieldNames>` ata el ms a la versión del encoder.
- [ ] ¿Se registran las plantillas huérfanas (`security-config`, `handler`, `router`, `service`,
  `usecase`, `controller`, `adapter`, `repository`) en `component.json`?
  — rec: no; no registrar nada, `component.json` no necesita cambios en este objetivo.
- [ ] ¿Se acepta como alcance solo las 12 plantillas Java con lógica y sin puerto ya registradas?
  — rec: sí, y priorizar las que sirven endpoints públicos: `parameter-controller`,
  `hola-mundo-controller`, `revenuecat-adapter`.

## Dependencias

- `library/common` debe compilar y publicar (`library/platform/scripts/publish-common.ps1`)
  antes de que el pom del microservicio resuelva `common-bom`.
- `generator/components/backend/spring-boot-3.5.16/templates/*` debe cambiar antes de regenerar
  `projects/com.quizsmart.app/backend/quizapi`.
- Despliegue: `projects/com.quizsmart.app/backend/quizapi/update-ms.ps1` o
  `backend/update-all.ps1` (no `up.ps1 -Fast`, no refresca la imagen).
- Verificación de logs: log group por defecto `/aws/lambda/quizapi`.
- Explorer 2026-10-07: `common-log` y `common-web` ya están migrados al puerto; falta migrar 12
  plantillas Java con lógica y regenerar `quizapi`.
- Explorer 2026-10-07: migrar `parameter-controller.scriban` puede romper
  `parameter-controller-test.scriban`; los tests no se pueden modificar (regla dura del workspace).
- Versión gestionada: `logstash-logback-encoder` 8.1 (pin actual en `common-bom`). No subir a 9.0
  mientras Boot 3.5.16 gestione `jackson-bom` 2.21.4.
- GraalVM native: si `quizapi` se compila con native-image, `logback-base.xml` debe registrarse
  como recurso en reachability metadata (fuente GraalVM, guía "Add Logging to Native Executable").

## Dudas de implementación

- Tester 2026-10-07 14:34 · ¿Se acepta añadir `logging.level.com.quizsmart.app=DEBUG` en `quizapi`
  para validar `debug`?
  Rec: sí, solo en entorno de prueba, no en producción; con `root=info`
  (`logback-base.xml:24`) el criterio «parámetros y variables con `log.debug`» no es observable
  en runtime. No se modifica producto hasta aprobarlo.

- Resuelta 2026-10-07: ¿Debe generarse `logging.config=classpath:logback-base.xml`? No; se
  eliminó para permitir la búsqueda estándar de Spring Boot/Logback de `logback.xml`, que incluye
  `logback-base.xml`.

- ¿Debe el generator retirar el `logback.xml` heredado al regenerar quizapi? Rec: dejar de
  generarlo en `component.json` no borra el archivo preexistente; retirar solo salidas obsoletas
  propiedad del generator y regenerar antes de verificar JSON.

- ¿CodeArtifact resuelve `logstash-logback-encoder:8.1`? Rec: confirmar en fase de publicación;
  no se publicó ni consultó el repositorio externo durante esta implementación.
- ¿Qué mecanismo Java aprobado debe usar `Slf4jLogService` para emitir cada entrada de
  `Map<String, Object>` como propiedad JSON estructurada y compatible con
  `MaskingJsonGeneratorDecorator`? Architect define el mapa como campos sueltos, pero no la API.
  Rec: aprobar SLF4J fluent key-value si está disponible en la versión gestionada; en otro caso,
  definir un mecanismo compatible ya presente. Hasta entonces no implementar el overload.

## Integrator · 2026-10-07 — análisis solo lectura (runtime)

- [ ] El dominio CodeArtifact `epc` **no existe** en la API de AWS
  (`describe-domain` → `ResourceNotFoundException`) pero el estado de Terraform lo describe como
  creado (`created_time 2026-10-07T19:44:01Z`, `repository_count 2`). Hay drift.
  Rec: antes de cualquier despliegue, reejecutar `library/platform/scripts/up.ps1 -AutoApprove`
  (o `-WhatIf` primero) y volver a verificar con `list-domains`. Requiere autorización.
- [ ] Se autoriza `library/platform/scripts/up.ps1 -AutoApprove` para reconciliar el dominio `epc`?
  Rec: sí; es el único script autorizado para crear la plataforma y ya se usó con éxito antes.
- [ ] Se autoriza `projects/com.quizsmart.app/cloud/up.ps1 -AutoApprove` para crear la lambda
  `quizapi`, su ECR y el API Gateway? Sin esto no hay runtime donde validar.
  Rec: sí, es requisito de los criterios de aceptación 43-47. El historial no registra que se haya
  aplicado nunca.
- [ ] ¿Se acepta validación local en vez de CloudWatch para esta iteración, usando
  `library/common/samples/log-only-sample` y `samples/web-sample`?
  Rec: sí, como paso intermedio: valida JSON y los 23 `addPaths` en proceso local. Dejaría el
  criterio CloudWatch pendiente para la siguiente iteración.
- [ ] ¿Se sube el nivel a `DEBUG` para validar el criterio `debug`? `logback-base.xml:24` fija
  root en `info`. Rec: añadir `logging.level.com.quizsmart.app=DEBUG` solo en `develop`; no tocar el
  base común.
- [ ] ¿Se acepta que `up.ps1` no acepta `-Fast`? Confirmado leyendo `up.ps1:26-30`.
  Rec: documentarlo en `README` de `library/platform` para que nadie lo intente otra vez.
- [ ] Nota de operación: el subcomando correcto es `aws codeartifact describe-domain`, no
  `get-domain`. Rec: sin acción; solo evitar el falso error en consultas futuras.

## Integrator · 2026-10-07 21:43 — runtime CloudWatch (up.ps1 -Fast exit 0)

- [ ] **BLOQUEANTE** · `logback-base.xml:20` usa `<addPaths>`, que `logstash-logback-encoder` 8.1
  no tiene. Logback lo ignora con `WARN Ignoring unknown property [addPaths] in
  [MaskingJsonGeneratorDecorator]` y **los 23 campos sensibles NO se enmascaran**.
  Rec: migrar a la API real de 8.1, que solo expone `setDefaultMask`/`setMask`
  (`<setMask><path>...</path></setMask>`). Es cambio en `common-log` + republicar `common` +
  redesplegar; requiere autorización de `developer-java` antes de tocar código de producto.
- [ ] **BLOQUEANTE** · El JSON emite `@timestamp`, no `timestamp`. Lambda no indexa `level` ni
  tiempo, así que el filtrado por nivel en CloudWatch no funciona, en contra de lo que promete
  `logback-base.xml:5-7`.
  Rec: `<fieldNames><timestamp>@timestamp</timestamp></fieldNames>` en el encoder 8.1
  (queda pendiente de confirmar que 8.1 lo soporte; si no, campo `timestamp` propio).
- [ ] El criterio `debug` sigue **no observable** en runtime: 0 líneas `DEBUG`, único nivel
  `INFO`, porque `logback-base.xml:24` fija `root=info` y la Lambda solo define
  `SPRING_PROFILES_ACTIVE=cloud`.
  Rec: añadir variable de entorno `LOGGING_LEVEL_COM_QUIZSMART_APP=DEBUG` en el Terraform de
  `quizapi` solo para `develop`; no tocar el base común. Misma recomendación registrada el
  2026-10-07 14:34 por `tester`, sigue vigente y ahora está confirmada con evidencia de runtime.
- [ ] El criterio «`info` al inicio de cada método» no es observable: las únicas líneas de
  `com.epc.common.log.Slf4jLogService` son de arranque
  (`Configuracion de IA cargada: ...`, `[WH] secreto resuelto len=39`), sin marca de entrada.
  Rec: definir una clave estable de log de entrada (p. ej. prefijo `enter:` con clase y método)
  para que el criterio sea verificable con `aws logs filter-log-events`. No es solo un ajuste de
  nivel: hoy no hay nada que buscar.
- [ ] ¿Cómo se valida el masking una vez arreglado? Hoy ningún endpoint recibe un secreto, así que
  el dato nunca llega al log y el `***` no se puede ver aunque el enmascarador esté bien.
  Rec: el test debe emitir un log con un valor sensible conocido en entorno de prueba y comprobar
  `***` en la salida. Requiere decidir quién lo emite (`tester`).
- [ ] `INIT_REPORT Phase: init Status: timeout` con `Init Duration: 10000.00 ms`, aunque la función
  arrancó y respondió 200 después. Duración total de invocación 20953 ms.
  Rec: revisar `Timeout`/`InitTimeout` y el tamaño de la imagen antes de optimizar; no bloquea
  este objetivo, se anota como observación.

## Integrator · 2026-10-07 21:50 — bloqueos con causa raíz diagnosticada (solo lectura)

- [ ] **BLOQUEANTE · masking** · Causa raíz: `<addPaths>` de `logback-base.xml:20` no es propiedad
  válida en logback 1.5.12; se descarta con
  `WARN Ignoring unknown property [addPaths] in [MaskingJsonGeneratorDecorator]`.
  Reproducido localmente con el mismo stack. El API correcto de encoder 8.1 es `<path>` repetido.
  Defecto secundario, independiente: el sensible se interpola en `message`, y el enmascarador por
  nombre de campo JSON nunca alcanza el texto de `message`. Los 23 campos siguen sin verificar.
## Integrator 2026-10-07 21:50 - pendientes tras despliegue `up.ps1 -Fast`

- [ ] **Masking de los 23 campos NO funciona en runtime.** Logback avisa
  `Ignoring unknown property [addPaths] in [MaskingJsonGeneratorDecorator]`.
  `MaskingJsonGeneratorDecorator` de `logstash-logback-encoder 8.1` solo expone `setDefaultMask` y
  `setMask`; `<addPaths>` no existe. Rec: migrar `logback-base.xml:20` al formato soportado
  (múltiples `<mask>` con `<path>`/`<defaultMask>`) o bajar a encoder 7.x si expone `addPaths`.
  Requiere cambio en `library/common` y republicar `common` 1.1.6; regenerar `quizapi`.
- [ ] **Campo de tiempo `@timestamp` en vez de `timestamp`.** CloudWatch no indexa ni tiempo ni
  `level`, así que el filtro por nivel no funciona en consola. Rec: renombrar el campo en
  `logback-base.xml` vía `fieldNames` del `LogstashEncoder` y republicar.
- [ ] **Nivel `debug` no observable.** 0 líneas `DEBUG`; `logback-base.xml:24` fija root en `info`
  y la lambda solo define `SPRING_PROFILES_ACTIVE=cloud`. Rec: añadir
  `LOGGING_LEVEL_COM_QUIZSMART_APP=DEBUG` como variable de entorno de la lambda en `develop`
  (Terraform `cloud/terraform/quizapi`); no tocar el base común.
- [ ] **Cold start**: `INIT_REPORT Init Duration: 10000.00 ms Status: timeout`; el primer `curl`
  dio 503. Rec: Java snapshot tiers o subir `InitTimeout`. No bloquea los criterios de log.
- [ ] **Verificación de los 23 campos**: aun arreglado `addPaths` falta una fuente que emita los 23
  campos con valores reales. Rec: validar el masking en proceso local con
  `library/common/samples/log-only-sample` y dejar CloudWatch como verificación de humo.
- [ ] **Corrección de path**: los informes previos usaron `library/platform/scripts/up.ps1`; el
  script correcto es `projects/com.quizsmart.app/up.ps1` (sí acepta `-Fast`). Rec: sin acción de
  código; ya documentado en `integrator.md`. Considerar nota en el template de integrator.

## Dependencias
- Orden pendiente: arreglar `addPaths` y `timestamp` en `common` → `publish-common` (1.1.6) →
  `generator` regenera `quizapi` → `projects/com.quizsmart.app/up.ps1 -Fast` → `curl` →
  `aws logs tail /aws/lambda/quizapi`.

