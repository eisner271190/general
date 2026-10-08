# Exploración

- Objetivo: `obj-003 Logs estructurados en common`
- Agente: `Explorer`
- Estado: `completo`
- Fecha: 2026-10-07 09:40 (UTC-5)
- Resumen: el objetivo ya está **implementado en su mayor parte**. `common-log` tiene
  `ILogService`, `Slf4jLogService`, `CommonLogAutoConfiguration`, `LogMessages` y
  `logback-base.xml` con encoder JSON y enmascarado. `common-web` ya consume el puerto.
  30 plantillas `.scriban` ya inyectan `ILogService`. Lo que **falta** es un grupo de
  plantillas Java con lógica que siguen sin log, y la regeneración del ms.
- Bloqueos: ninguno para explorar; hay decisiones de diseño que solo el usuario puede cerrar
  (ver Preguntas Grill-me).

## Entrevista

| Pregunta | Respuesta | Recomendación | Decisión/estado |
|---|---|---|---|
| ¿Existe ya la interfaz? | Sí, `ILogService` ya escrita | No reescribir | Cerrado por código |
| ¿El bean se registra solo? | Sí, `CommonLogAutoConfiguration` + `imports` | Dejar así | Cerrado por código |
| ¿El ms ya está migrado? | Parcial: 20 clases con `ILogService`, 12 sin | Migrar las 12 | Pendiente usuario |
| ¿Falta `component.json`? | Cubre `logback.scriban` y `DomainLogMessages` | Sin cambios | Cerrado |
| ¿Faltan plantillas sin log? | Sí, 12 con lógica y sin puerto | Priorizar por endpoint público | Pendiente usuario |

## Contexto y hallazgos

- Objetivo/alcance entendido:
  - Interfaz inyectable en `common.log`, salida JSON, `info` al inicio de método, `debug` para
    parámetros, enmascaramiento, textos centralizados, migración y regeneración.

- Estado real de `common-log` (ya implementado):
  - `library/common/common-log/src/main/java/com/epc/common/log/ILogService.java:13-43` —
    interfaz con `debug`/`info`/`warn`/`error`, overload `Object...`, overload
    `Map<String,Object>`, `withRequestId` y `clearRequestId`.
  - `library/common/common-log/src/main/java/com/epc/common/log/Slf4jLogService.java:83-89` —
    `logWithFields` emite cada entrada del mapa como `event.addKeyValue`, compatible con el
    enmascarador JSON.
  - `library/common/common-log/src/main/java/com/epc/common/log/CommonLogAutoConfiguration.java:18-22`
    — bean `ILogService` con `@ConditionalOnMissingBean`.
  - `library/common/common-log/src/main/resources/META-INF/spring/
    org.springframework.boot.autoconfigure.AutoConfiguration.imports` — registra la autoconfig.
  - `library/common/common-log/src/main/java/com/epc/common/log/LogMessages.java:14-27` —
    textos transversales: `APPLICATION_STARTED`, `METHOD_ENTER`, `METHOD_EXIT`,
    `BUSINESS_ERROR`, `UNHANDLED_ERROR`.
  - `library/common/common-log/pom.xml:27-32` — `spring-boot-starter` `provided` `optional`.
  - Versión del módulo `1.1.5` (`common-log/pom.xml:10`), ya bumpeada.

- Estado real de la salida JSON y el enmascarado:
  - `library/common/common-log/src/main/resources/logback-base.xml:14` —
    `net.logstash.logback.encoder.LogstashEncoder` con `includeMdc=true`.
  - `library/common/common-log/src/main/resources/logback-base.xml:18-21` —
    `MaskingJsonGeneratorDecorator`, `defaultMask` `***` y lista de 24 paths.
  - `library/common/common-log/src/main/resources/logback-base.xml:24` — root en `info`.
  - `generator/.../templates/logback.scriban:3` — solo `<include resource="logback-base.xml"/>`;
    el ms **no** duplica la configuración.
  - `projects/com.quizsmart.app/backend/quizapi/src/main/resources/logback.xml:3` — ya coincide con
    la plantilla: el ms generado está sincronizado en este punto.

- Estado real de `common-web` (ya migrado al puerto):
  - `library/common/common-web/src/main/java/com/epc/common/web/WebAutoConfiguration.java:4`
    importa `ILogService`.
  - `library/common/common-web/src/main/java/com/epc/common/web/RequestCorrelationFilter.java:30`
    — `log.withRequestId(requestId, () -> log.debug(...))`.
  - `library/common/common-web/src/main/java/com/epc/common/web/GlobalExceptionHandler.java:33-34`
    y `:43-44` — `log.info`/`log.error` con `LogMessages`, sin literales.
  - Nota: `RequestCorrelationFilter.java:30` tiene un literal `"Request correlated: {}"` fuera de
    `LogMessages`. Es el único literal suelto que queda en `common`.

- Plantillas del generator que YA usan el puerto (30, todas con
  `import com.epc.common.log.ILogService;`):
  - `application-java.scriban:3`, `admin-user-adapter.scriban:3`,
    `ai-controller.scriban:3`, `ai-properties.scriban:4`, `ai-usecase.scriban:3`,
    `cancellation-strategy.scriban:3`, `cognito-client.scriban:6`, `cors-config.scriban:3`,
    `expiration-strategy.scriban:3`, `initial-purchase-strategy.scriban:3`,
    `jwt-authentication-filter.scriban:3`, `jwt-provider.scriban:3`,
    `non-renewing-purchase-strategy.scriban:3`, `openrouter-adapter.scriban:3`,
    `password-adapter.scriban:3`, `product-change-strategy.scriban:3`,
    `registration-adapter.scriban:3`, `renewal-strategy.scriban:3`,
    `revenuecat-webhook-filter.scriban:5`, `security-context-repository.scriban:3`,
    `sns-controller.scriban:3`, `sns-event-publisher.scriban:5`, `sqs-controller.scriban:3`,
    `sqs-receiver.scriban:3`, `subscription-adapter.scriban:3`,
    `subscription-controller.scriban:3`, `subscription-usecase.scriban:3`,
    `uncancellation-strategy.scriban:3`, `unknown-event-strategy.scriban:3`,
    `webhook-usecase.scriban:3`.
  - Textos centralizados en `generator/.../templates/domain-log-messages.scriban:17-134`
    (más de 100 constantes), registrado en `component.json:170`.

- Plantillas Java con lógica y SIN puerto (lo que falta), todas en
  `generator/components/backend/spring-boot-3.5.16/templates/`:
  - `parameter-controller.scriban:17-42` — **endpoint público `/api/v1/parameters`**;
    `getParameters()` en `:30` no registra nada.
  - `parameter-properties.scriban:23-102` — `getPublicParameters()` en `:71` y
    `collectIfParameterStore()` en `:77` sin log.
  - `hola-mundo-controller.scriban:16-36` — dos endpoints públicos, `holaMundo()` `:18` y
    `holaError()` `:25` sin log; es el endpoint de error de prueba.
  - `revenuecat-adapter.scriban:23-49` — `fetchSubscription()` `:42` sin log; es el adaptador que
    usa `secretApiKey` en la cabecera `Authorization` (`:45`).
  - `billing-issue-strategy.scriban:11-31` — única estrategia de webhook sin log; las otras ocho
    sí lo tienen.
  - `dynamodb-config.scriban:11`, `sns-config.scriban:11`, `sqs-config.scriban:11` — beans de
    configuración sin log de arranque (el precedente `cors-config.scriban:26,43` sí registra).
  - `mapper-class.scriban:11`, `subscription-table-schema.scriban:10`,
    `webhook-event-table-schema.scriban:10` — soporte, sin lógica de negocio.
  - `LambdaHandler.scriban:9` — clase no Spring; no puede recibir inyección.

- Plantillas Java huérfanas (con lógica, sin registrar en `component.json`, nunca se generan):
  - `security-config.scriban:16`, `jwt-authentication-manager.scriban:15`,
    `path-constants.scriban:1`, `handler.scriban:14`, `router.scriban:9`,
    `DynamoBean.scriban:16`, `service.scriban:10`, `usecase.scriban:10`,
    `controller.scriban:10`, `adapter.scriban:12`, `repository.scriban:7`.
  - Consecuencia: `security-config` y `jwt-authentication-manager` nunca compilan, así que sus
    `log` no son un hueco real hoy. No tocarlas salvo que se registran.

- Plantillas gated que hoy no se generan para `quizapi`:
  - Todas las de seguridad llevan `{{ if(Name == "security") }}` en la línea 1 y el ms se llama
    `quizapi` (`generator/target/com.quizsmart.app/com.quizsmart.app.json:58`). Ejemplos:
    `user-controller.scriban:1`, `user-usecase.scriban:1`, `auth-usecase.scriban:1`,
    `password-usecase.scriban:1`, `admin-user-usecase.scriban:1`, `exchange-usecase.scriban:1`.
  - De ese grupo solo tres ya tienen el puerto: `admin-user-adapter.scriban:3`,
    `password-adapter.scriban:3`, `registration-adapter.scriban:3`, más `cognito-client.scriban:6`.
  - Las demás (`user-*`, `auth-*`, `password-*`, `admin-user-*`, `exchange-*` controller/usecase/
    service/adapter) quedan sin migrar, pero no afectan al ms actual.

- `component.json`: qué cubre y qué habría que tocar
  - Ya cubre `logback.scriban` en `:76` y `domain-log-messages.scriban` en `:170`.
  - `pom.scriban:36-39` declara `common-log`; `:44-48` declara `logstash-logback-encoder` con
    `scope runtime`; `:28-29` importa `common-bom` `1.1.5` (ya alineado, el desfase 1.0.0/1.0.1
    del informe anterior quedó cerrado).
  - **No habría que tocar `component.json`**: no se crean ni se renombran plantillas. Solo si se
    decide registrar las huérfanas o retirar alguna.
  - GraalVM ya cubre el encoder: `graalvm-hints.scriban:13-14` registra
    `LogstashEncoder` y `MaskingJsonGeneratorDecorator`; `native-image-properties.scriban:20-21`
    también.

- Configuración del nivel de log (generator y ms generado)
  - `logback-base.xml:24` — root `info`. Es el único lugar donde se decide el nivel.
  - `templates/application-properties.scriban:35` — `logging.level.software.amazon.awssdk=INFO`;
    ya está en `INFO`, no satura.
  - `templates/application-properties.scriban` **no** define `logging.level.root` ni
    `logging.level.<paquete>`: no hay forma por propiedad de subir a `debug`.
  - `application-cloud.properties.scriban:1` — solo importa Parameter Store y Secrets Manager;
    no toca logging.
  - Consecuencia: en Lambda el nivel efectivo es `info`, así que todos los `log.debug` de
    parámetros quedan invisibles. Es coherente con el riesgo declarado en `obj-003.md:66`, pero
    deja el criterio de aceptación de "parámetros con `debug`" sin forma de verificarse.

- Endpoint `/api/v1/parameters`
  - Generado por `parameter-controller.scriban:16` (`@RequestMapping("/api/v1/parameters")`) y
    `:29` (`@GetMapping`). Registrado en `component.json:102`.
  - **Sí está en la colección Postman**: `postman-collection.scriban:94` carpeta `Parameters`,
    `:97` request `Get`, `:114` URL `{{baseUrl}}/api/v1/parameters`, sin `Authorization`
    (público, coherente con la regla de `components/backend/AGENTS.md`).
  - Doble uso: sirve de endpoint de prueba y de producto público para el frontend
    (`parameter-properties.scriban:15-20`).
  - Riesgo: expone todo Parameter Store salvo la lista `EXCLUDED`
    (`parameter-properties.scriban:25-62`). La lista no cubre `JWT_SECRET` ni
    `SUBSCRIPTION_SECRET_KEY` como nombres; se salvan porque viven en Secrets Manager
    (`parameter-properties.scriban:19`, `:95-98`), no por la lista.

- Candidatos reales de campos sensibles (`ruta:línea`)
  - `templates/register-user.scriban:5` `email`, `:6` `password`.
  - `templates/register-user-request-dto.scriban:5` `email`, `:6` `password`.
  - `templates/token-request.scriban:5` `password`.
  - `templates/token-request-dto.scriban:5` `password`.
  - `templates/auth-request-dto.scriban:5` `password`.
  - `templates/auth-response-dto.scriban:5` `password` — DTO de **respuesta** con password: es un
    hallazgo, expone una credencial hacia el cliente.
  - `templates/change-password.scriban:4` `accessToken`, `:5` `oldPassword`, `:6` `newPassword`.
  - `templates/change-password-request-dto.scriban:4` `accessToken`, `:5` `oldPassword`,
    `:6` `newPassword`.
  - `templates/recover-password.scriban:4` `email`.
  - `templates/recover-password-request-dto.scriban:4` `email`.
  - `templates/ai-properties.scriban:31` `apiKey` (ya solo registra presencia, `ai-properties.scriban:45`).
  - `templates/revenuecat-adapter.scriban:30` `secretApiKey` (campo `private final`).
  - `templates/jwt-provider.scriban:31` `secret` (clave de firma).
  - `templates/cognito-client.scriban:280-285` `access_token`, `id_token`, `refresh_token`;
    el comentario en `:228-230` documenta que no se registran a propósito.
  - `templates/application-properties.scriban:30` `jwt.secret`,
    `:47` `subscription.secret-key`, `:48` `subscription.webhook-secret`.
  - `templates/parameter-properties.scriban:49` `AWS_SECRET_ACCESS_KEY`, `:50` `AWS_SESSION_TOKEN`,
    `:46` `AWS_LAMBDA_METADATA_TOKEN` — ya en `EXCLUDED`.
  - Cobertura del enmascarador: `logback-base.xml:20` enmascara `password`, `secret`, `secretKey`,
    `clientSecret`, `token`, `accessToken`, `refreshToken`, `idToken`, `apiKey`, `authorization`,
    `cookie`, `sessionId`, `awsSecretAccessKey`, `awsSessionToken`, `cardNumber`, `pan`, `cvv`,
    `email`, `phone`, `documentId`.
  - **Hueco real**: `oldPassword` y `newPassword` no coinciden con ningún path de
    `logback-base.xml:20`. Si se registra el DTO de cambio de contraseña con `debug`, ambos salen
    en claro. Requiere decisión (añadir `oldPassword`/`newPassword` o no registrar ese DTO).
  - Segundo hueco: el enmascarado es por **nombre de campo JSON**, no por contenido. Los mensajes
    con `{}` (`domain-log-messages.scriban`) interpolan el valor dentro de `message`, que el
    enmascarador no ve. Ejemplo real: `password-adapter.scriban:46` registra `request.getEmail()`
    en un placeholder. `email` sí está en la lista, pero queda como texto del mensaje, no como
    campo JSON. La protección real depende de que el código no pase el secreto al placeholder.

- Literales de log sueltos que quedan (3)
  - `templates/sqs-receiver.scriban:45` — `log.debug("Cola: {}", queueUrl)`, duplica
    `DomainLogMessages.SQS_QUEUE` que ya se usa en `:34`.
  - `library/common/common-web/.../RequestCorrelationFilter.java:30` —
    `"Request correlated: {}"` fuera de `LogMessages`.
  - `templates/cognito-client.scriban:215` — literal en línea comentada, sin efecto.
  - `templates/openrouter-adapter.scriban:108,120` — `log.error(detail)`: variable, no literal, pero
    el texto se compone en otro método (`:92`); conviene confirmar que no contiene el prompt.

- Repositorios y qué no tocar
  - `library/common` — editable. Contiene `common-log` (puerto, textos, `logback-base.xml`) y
    `common-web` (ya migrado). También `common-bom`, `common-error`, `samples/log-only-sample`,
    `samples/web-sample` (`library/common/samples/`): los samples son parte de la librería.
  - `generator` — **fuente de verdad**. Editar solo
    `generator/components/backend/spring-boot-3.5.16/templates/*.scriban` y `component.json`
    si hiciera falta. No tocar `generator/Application/`, `Domain/`, `Infrastructure/`,
    `Configuration/` (logging del propio .NET está fuera de alcance).
  - `projects/com.quizsmart.app/backend/quizapi` — **código generado, no editar**. Se elimina y se
    regenera. Los 20 archivos con `ILogService` (`Application.java:3`, `AiController.java:3`,
    `AiProperties.java:4`, `AiUseCase.java:3`, `SubscriptionAdapter.java:3`,
    `SubscriptionController.java:3`, `SubscriptionUseCase.java:3`, `WebhookUseCase.java:3`,
    `OpenRouterAdapter.java:3`, `SNSController.java:3`, `SnsEventPublisher.java:5`,
    `RevenueCatWebhookFilter.java:5`, las 8 estrategias, `UnknownEventStrategy.java:3`) ya
    reflejan las plantillas.
  - `projects/com.quizsmart.app/cloud/terraform/*` — no tocar. El IAM ya permite
    `logs:PutLogEvents` y el log group por defecto basta; el formato lo decide logback.
  - Tests: regla dura del workspace, no se crean ni modifican. Afecta a
    `parameter-controller-test.scriban` y `hexagonal-architecture-test.scriban`: si se inyecta
    `ILogService` en `ParameterController`, su test puede dejar de compilar y **no se puede tocar**.
    Es el riesgo concreto del siguiente cambio.

- Restricciones y verificaciones disponibles:
  - No se ejecutó ningún build ni comando (modo solo análisis).
  - Verificables sin AWS: `dotnet build` en `generator`, `mvn clean install` en `library/common`,
    `mvn -q compile` en el ms, parseo JSON de la colección Postman.

## Incógnitas, límites y traspasos

- Incógnitas/supuestos:
  - **Supuesto**: la inyección de `ILogService` en `ParameterController` rompe
    `ParameterControllerTest` (construye el controller con `new`). No verificado; si se confirma,
    la regla de no tocar tests bloquea esa migración.
  - **Supuesto**: `oldPassword`/`newPassword` deben entrar en la lista de paths. No decided si se
    añade el path o se deja de registrar ese DTO.
  - **No verificado**: que `quizapi` compile hoy con `common-log 1.1.5` y el `logback-base.xml`
    incluido desde el jar. Requiere `mvn compile` y publicación previa.
  - **No verificado**: que `logstash-logback-encoder` resuelva en CodeArtifact.
  - **No verificado**: si el grupo de plantillas gated `Name == "security"` se migrará ahora o se
    deja para cuando exista un ms de seguridad.

- Áreas no revisadas:
  - `generator/Application/`, `Domain/`, `Infrastructure/`, `Configuration/` (logging del .NET).
  - Componentes `frontend`, `cloud` y `root` del generador.
  - `library/platform/` más allá de lo citado; `common-error`; los dos `samples`.
  - Tests del ms: no revisados por regla dura.
  - No se regeneró ni se compiló nada, así que no hay diff contra las plantillas actuales.

- Traspasos:
  - Architect: decidir si `oldPassword`/`newPassword` entran en la lista de paths y qué hacer con
    `ParameterControllerTest` si la inyección rompe la construcción.
  - Developer-Java: migrar las 12 plantillas sin puerto, empezando por las que sirven endpoints
    públicos; regenerar `quizapi` y revisar el diff completo.
  - Reviewer: verificar que no se tocan tests y que no se registran plantillas huérfanas por error.
  - Tester: `dotnet build`, `mvn clean install` en `library/common`, regeneración, compilación del
    ms, `curl` a `/api/v1/parameters` y lectura de logs en JSON.
  - Preguntas abiertas y dependencias: `docs/deliverables/obj-003/questions.md`.

## Confirmación

- Entendimiento confirmado por el usuario: `no; 2026-10-07`

## Preguntas Grill-me

Ronda 1 — frontera disponible (hechos ya verificados en el repo):

❓ **Q1** — ¿Qué cuenta como "sensible" para el enmascarador?: la lista de `logback-base.xml:20`
tiene 24 nombres, pero `change-password.scriban:5-6` declara `oldPassword` y `newPassword`, que no
coinciden con ningún path. ¿Se añaden esos dos nombres, o se acepta que ese DTO no se registre?

➡️ Añadir `oldPassword` y `newPassword` a la lista. Son credenciales aunque el nombre no lo parezca,
y la lista ya incluye `passwd` como sinonimo.

---

❓ **Q2** — ¿El enmascarado protege de verdad?: el enmascarador actúa sobre **nombres de campo
JSON**, no sobre el texto del mensaje. Casi todos los logs usan placeholders `{}`, así que el valor
interpolado dentro de `message` nunca se enmascara. ¿Se acepta este modelo (el código no debe pasar
el secreto al placeholder) o se cambia el contrato para que los campos sensibles vayan siempre como
campos JSON?

➡️ Aceptar el modelo actual y reforzarlo con la regla R10: los parámetros sensibles se registran
como campo JSON, nunca interpolados. Documentarlo en `LogMessages`.

---

❓ **Q3** — ¿Nivel por defecto y forma de verificar `debug`?: `logback-base.xml:24` fija root en
`info` y `application-properties.scriban` no define ninguna propiedad `logging.level.*` del ms.
El criterio de aceptación "parámetros con `debug`" no es verificable en Lambda tal como está.
¿Se añade `logging.level.${microservicio}=DEBUG` por ambiente, o se sube el root en `develop`?

➡️ Propiedad por microservicio en `application.properties`, con `debug` activo solo en `develop` y
bajo demanda en cloud. Es el cambio más pequeño que hace verificable el criterio.

---

❓ **Q4** — ¿Granularidad de `info` al inicio de cada método?: la regla fija de `obj-003.md:29` pide
`info` en cada método, pero hoy solo lo hacen ~30 clases y con mensajes propios, no con
`METHOD_ENTER` de `LogMessages.java:18`. ¿Se generaliza el genérico `METHOD_ENTER` por método, o
se mantiene un mensaje propio y legible por operación?

➡️ Mantener el mensaje propio por operación. `METHOD_ENTER` con el nombre del método genera ruido
sin información de negocio y multiplica el volumen en Lambda.

---

❓ **Q5** — `ParameterController` y su test: inyectar `ILogService` en
`parameter-controller.scriban:17` cambia el constructor, y `parameter-controller-test.scriban`
construye el controller con `new`. Los tests no se pueden tocar. ¿Se inyecta igual y se acepta que
el test possibly no compile, o se deja este controller sin puerto y se registra desde el filtro?

➡️ Inyectar igual y avisar: si el test rompe, la salida es borrarlo de `component.json` (regenera
el árbol sin tests) o dejarlo. Necesito la decisión explícita porque no puedo editar tests.

---

❓ **Q6** — ¿Plantillas gated `Name == "security"`?: unas 40 plantillas solo se generan si el ms se
llama `security`. `quizapi` no lo es, así que hoy no compilan. Tres ya tienen el puerto
(`admin-user-adapter`, `password-adapter`, `registration-adapter`) y el resto no. ¿Se migran ahora
para que estén listas, o se dejan hasta que exista el ms de seguridad?

➡️ Dejarlas. Migrar plantillas que no compilan es trabajo no verificable; se hace cuando exista el
microservicio que las genera.

---

❓ **Q7** — `AuthResponseDTO` con password: `auth-response-dto.scriban:5` declara `password` en un
DTO de **respuesta**. Si algún día se registra con `debug`, sale una credencial al log y además el
cliente la recibe. ¿Se corrige el DTO ahora o es fuera de alcance?

➡️ Corregir el DTO: un DTO de respuesta con `password` es un defecto, no una cuestión de logging.
Es un cambio de una línea en la plantilla y no altera ningún endpoint.

---

❓ **Q8** — Salida de Lambda: el esquema documentado en `logback-base.xml:5-7` promete los campos
`timestamp`, `level`, `message`, `logger`, `thread`, `stack_trace`, `requestId`, pero
`LogstashEncoder` por defecto no garantiza ese esquema exacto. ¿Se fija con `<fieldNames>` o se
acepta el esquema por defecto de la librería y se documenta?

➡️ Aceptar el esquema por defecto y documentarlo. Fijar `<fieldNames>` ata el microservicio a la
versión concreta del encoder, que se gestiona en el BOM.