# Arquitectura

- Objetivo: `obj-003 Logs estructurados en common`
- Agente: `Architect`
- Estado: `completo`
- Resumen: puerto `ILogService` en `common-log` (interfaz + autoconfiguración), salida JSON por
  línea con `logstash-logback-encoder` 8.x y enmascarado por nombre de campo, textos en
  `LogMessages`, migración de las 27 plantillas y regeneración. Sin Terraform ni IAM.
- Bloqueos: lista definitiva de campos sensibles pendiente de aprobación del usuario.

## Entradas, requisitos y restricciones

- Fuentes leídas: `obj-003.md`, `explorer.md`, `researcher.md`, `questions.md` (96 decisiones).
- Requisitos: interfaz inyectable en `common.log`; `info` en entrada y salida; `debug` para
  parámetros; textos centralizados; enmascarado; JSON; migrar `quizapi`; regenerar.
- Restricciones: `AGENTS.md` cambio mínimo, no tocar tests, no editar código generado, no hardcodear
  rutas, `generator` es fuente de verdad, líneas ≤ 100 caracteres, idioma de logs en inglés.
- Hechos fijados: `common-log` solo tiene `MdcCorrelation` (API congelada 1.0.0); motor efectivo
  logback vía `spring-boot-starter`; `log4j2.scriban` no está en `component.json`;
  `maven.compiler.release=17` (`library/common/pom.xml:24`); Jackson 2 (Boot 3.4.0).
- De Researcher: `MaskingConverter` no existe en logback; enmascarado por `<path>` de un token;
  Lambda indexa solo el primer JSON de la línea y exige `level` + `timestamp` RFC 3339; MDC es
  estático y no se inyecta.

## Diseño

### 1. Contrato del puerto de logging

- Nombre: `ILogService`, paquete `com.epc.common.log` (prefijo `I` por `clean-code`; decisión 9).
- Implementación: `Slf4jLogService`, en el mismo módulo, `final`, un solo constructor.
- Convenio: placeholders `{}` con `Object...` como norma; el mapa es la excepción para campos
  sueltos que no caben en `{}` (decisiones 85-86).
- `Throwable` va en overload propio, nunca como `{}` (decisión 83).

```java
public interface ILogService {
  void debug(String message);
  void debug(String message, Object... args);
  void debug(String message, Map<String, Object> fields);
  void info(String message);
  void info(String message, Object... args);
  void info(String message, Map<String, Object> fields);
  void warn(String message, Object... args);
  void warn(String message, Throwable error);
  void error(String message, Object... args);
  void error(String message, Throwable error);
  void withRequestId(String requestId, Runnable action);
  void clearRequestId();
}
```

- `withRequestId` / `clearRequestId` son el método propio que envuelve a `MDC`: `MDC` es clase final
  de métodos estáticos, luego no es inyectable (Researcher). Delegan en `MdcCorrelation`, que no se
  toca (decisión 69).
- `clearRequestId` va en `finally` dentro de `withRequestId`; `MDC.putCloseable` no se usa para no
  añadir dependencia a la versión mínima de slf4j que resuelve Boot.
- No se expone `Map` en `warn`/`error`: no hay caso de uso actual (YAGNI). Se añade si aparece.
- Sin `@Nullable`, sin `isXEnabled` (decisión 82).

### 2. Punto de registro del bean

- `common-log` con `spring-boot-starter` en scope `provided` y su propio
  `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`
  (decisiones 75-76).
- `CommonLogAutoConfiguration` declara `@Bean @ConditionalOnMissingBean ILogService`, con el
  `LoggerFactory.getLogger(Slf4jLogService.class)` dentro (decisión 71: el ms puede sobrescribir).
- Justificación: (a) el puerto pertenece al módulo que lo define, no a `common-web`;
  (b) así lo heredan los ms sin web, como `log-only-sample`; (c) `provided` no arrastra Spring al
  que solo consume `MdcCorrelation`.
- `logstash-logback-encoder` no se declara en `common-log`: solo se usa desde `logback.xml`, luego
  va como dependencia `runtime` del microservicio (declaración explícita en el `pom` del ms).

### 3. Esquema de campos JSON

- Un evento = una línea JSON en `ConsoleAppender`. Nunca agrupar eventos: CloudWatch indexa solo
  el primer fragmento JSON de cada línea (Researcher).
- `LogstashEncoder` con `<fieldNames>` para fijar el esquema. Se renombran y se retiran campos.

| Clave JSON | Origen | Regla |
|---|---|---|
| `timestamp` | `@timestamp` | ISO_OFFSET_DATE_TIME; cumple RFC 3339, obligatorio para Lambda |
| `level` | `level` | `INFO`/`DEBUG`/...; obligatorio para que Lambda filtre por nivel |
| `message` | `message` | texto ya resuelto con los `{}` |
| `logger` | `logger_name` | clase que emite |
| `thread` | `thread_name` | hilo de ejecución |
| `stack_trace` | `stack_trace` | solo cuando hay excepción |
| `requestId` | MDC | clave `MdcCorrelation.REQUEST_ID_KEY`, aparece sola |

- Se anulan: `@version`, `level_value`, `tags`. No se activa `includeCallerData` (coste).
- No se añade `@timestamp` duplicado: Lambda lee `timestamp`.
- Nombre del microservicio: no va en MDC ni en campo propio; ya existe `spring.application.name`
  (decisión 78) y el log group de Lambda lo identifica.
- `service` se acepta como campo estático del encoder solo si el usuario lo pide; por defecto no
  (YAGNI).

### 4. Campos sensibles enmascarados — APROBACIÓN PENDIENTE

- Mecanismo: `MaskingJsonGeneratorDecorator` con `<path>` de un solo token, que enmascara todas
  las apariciones de ese campo (Researcher). Máscara `***` (decisión 25).
- Lista propuesta (OWASP Logging Cheat Sheet + workspace):

```
password, passwd, secret, secretKey, clientSecret, token, accessToken, refreshToken,
idToken, apiKey, authorization, cookie, setCookie, sessionId, connectionString,
awsSecretAccessKey, awsSessionToken, cardNumber, pan, cvv, email, phone, documentId
```

- Enmascarado por valor (regex) queda fuera: la propia librería lo marca como mucho más caro.
- El enmascarador no actúa sobre el MDC (decisión 79).
- **Esta lista no se implementa hasta que el usuario la apruebe y quede su respuesta en
  `questions.md`.**

### 5. Ubicación de la clase de textos

- Base común: `com.epc.common.log.LogMessages` con los textos transversales (arranque, versión,
  ambiente, entrada/salida genérica, errores no previstos).
- Textos propios de cada ms: clase generada por plantilla en
  `{{PACKAGE}}.infrastructure.configuration`, siguiendo el precedente `ai-messages.scriban`.
- Se aplica la decisión 32 tal cual. Única desviación: la clase por ms se llama `DomainLogMessages`
  para no colisionar con `LogMessages` al importarlas en la misma clase. Nueva pregunta añadida.
- `AiMessages` y `AiConstants` conviven; no se absorben (decisión 48).
- `GlobalExceptionHandler` de `common-web` pasa al puerto (decisiones 42-43).

### 6. Componentes y responsabilidades

- `common-log`: `ILogService`, `Slf4jLogService`, `CommonLogAutoConfiguration`, `LogMessages`,
  `MdcCorrelation` (intacto), `logback-base.xml` como recurso.
- `common-bom`: propiedad `epc.logstash-logback-encoder.version` y la coordenada en
  `dependencyManagement` (decisión 13).
- `common-web`: `GlobalExceptionHandler` y el filtro de correlación migrados al puerto; sin registrar
  bean propio (decisión 76).
- `generator`: 27 plantillas, `pom.scriban`, `logback.scriban`, `application-properties.scriban`,
  `graalvm-hints.scriban`, `native-image-properties.scriban`, `component.json`.
- `quizapi`: solo código regenerado.

### 7. Integraciones, contratos, datos y flujos

- Flujo de escritura: `ILogService` → `Slf4jLogService` → SLF4J API → logback `ConsoleAppender` →
  `LogstashEncoder` + `MaskingJsonGeneratorDecorator` → stdout → CloudWatch `/aws/lambda/quizapi`.
- Flujo de correlación: filtro o `LambdaHandler` → `withRequestId(id, accion)` → `MDC.put` en el
  hilo → cada evento incluye `requestId` → `finally` `clearRequestId`.
- MDC no se propaga a hilos de pool: si alguna plantilla usa `Executors`, debe copiar con
  `MDC.getCopyOfContextMap()`/`setContextMap()` (Researcher). Revisar en la migración.
- No hay flujo de red nuevo. No hay contrato de API nuevo: no cambia ningún endpoint, luego la
  colección postman no se toca.

### 8. Seguridad, identidad y permisos

- Sin cambios en IAM: `logs:PutLogEvents` ya está (decisión 55). Sin Terraform (decisión 54).
- Sin cambio de identidad ni de autorización de la API.
- Baja de `logging.level.software.amazon.awssdk` de `DEBUG` a `INFO`
  (`application-properties.scriban:34`): el SDK puede imprimir cabeceras (decisión 64).
- `includeCallerData` desactivado: no expone ni añade datos, y cuesta.
- Nivel efectivo en Lambda: `info`. `debug` se activa por propiedad del ms cuando se investiga
  (decisiones 30, 20).

### 9. Operación y despliegue

- Publicar `common` antes de regenerar: sin `common-bom 1.1.0` en CodeArtifact el `pom` del ms no
  resuelve.
- Despliegue con `update-all.ps1` o `update-ms.ps1`; nunca `up.ps1 -Fast` (no refresca imagen).
- Verificación de logs con `aws logs tail` manual sobre `/aws/lambda/quizapi` (decisión 59).
- Coste: sin infraestructura nueva; sube el volumen ingerido por el `info` en cada método. Cuantificar
  en fase de tester.

### 10. Impacto en el `generator`

- Plantillas con `Logger LOG = LoggerFactory.getLogger(...)` (27): sustituir por campo
  `private final ILogService log;` recibido por constructor (decisión 36), sin `@Autowired` en
  campo, sin `@Slf4j` (decisión 38).
- Excepciones ya decididas: `LambdaHandler` y `CommandLineRunner` de los samples usan variable
  estática con nota (decisión 40); `Application.main` emite una línea `info` (decisión 41);
  `CorsConfig` y `CognitoClient`, que hoy loguean sin declarar `Logger`, pasan al puerto.
- Mensajes concatenados con `+` (`revenuecat-webhook-filter.scriban:81-82`, `:150-152`): se
  convierten en placeholders.
- Enmascarado ad hoc existente (`secretLength()`, `abbreviate(webhookSecret, 4)`): se elimina; pasa
  el enmascarador (decisión 27).
- `templates/logback.scriban`: se reescribe con `LogstashEncoder` y el decorador de enmascarado.
  El `logback.xml` del ms pasa a ser opcional: `common-log` publica `logback-base.xml` y el ms puede
  sobrescribirlo (decisiones 15-16).
- `component.json`:
  - registrar `templates/domain-log-messages.scriban` → destino
    `{{MICROSERVICE_NAME}}/src/main/java/{{APPLICATION_PACKAGE}}/infrastructure/configuration/DomainLogMessages.java`;
  - quitar la entrada de `logback.xml` (línea 169) si el ms deja de generarlo; si se conserva como
    override vacío, se mantiene;
  - la plantilla nueva debe registrarse en el mismo cambio o no se genera.
- `templates/log4j2.scriban`: borrar. Un solo motor (decisión 18).
- `templates/graalvm-hints.scriban` y `native-image-properties.scriban`: registrar reflexión para
  `net.logstash.logback.encoder.LogstashEncoder` y
  `net.logstash.logback.mask.MaskingJsonGeneratorDecorator` (decisión 67).
- `templates/pom.scriban`: subir el `import` de `common-bom` y declarar `common-log` explícito.
- Código generado en `projects/com.quizsmart.app/backend/quizapi`: no se edita; se regenera y se
  revisa el diff completo (decisiones 24, 92).

### 11. Versionado

- `common-log` 1.0.0 → 1.1.0: la API congelada en `como-usar.md:64-67` exige release mayor al añadir
  el puerto (decisión 21).
- Versión única del sistema: `common-parent` 1.0.1 → 1.1.0 y todos los módulos la heredan
  (`README.md:34`). `common-bom` queda en 1.1.0.
- Desfase actual (`common-bom 1.0.0` en `pom.scriban:29` vs `common-parent 1.0.1`): se alinea a
  1.1.0 con `library/platform/scripts/bump-bom-version.py` (decisiones 23, 91).
- `logstash-logback-encoder`: se fija 8.x. Motivo: 9.x exige Jackson 3 y el proyecto usa Jackson 2
  con Boot 3.4.0; 8.x exige Java 11 y el proyecto ya es Java 17.

## Trazabilidad

| Requisito | Componente/decisión | Evidencia/ADR | Verificación |
|---|---|---|---|
| Interfaz en `common.log`, inyectable | `ILogService` + `Slf4jLogService` | ADR-0025 | `mvn -o dependency:tree` muestra `common-log` |
| Bean sin tocar el ms | `CommonLogAutoConfiguration` + imports | ADR-0025 | contexto arranca sin error; bean resoluble |
| `info` en entrada y salida | uso en 27 plantillas | decisión 29 | diff del código generado |
| `debug` para parámetros | overload `debug(String, Object...)` | decisión 30 | log con nivel `debug` al subir la propiedad |
| Textos centralizados | `LogMessages` + `DomainLogMessages` | `ai-messages.scriban` como precedente | grep sin literales sueltos en plantillas |
| Enmascarado | `MaskingJsonGeneratorDecorator` | lista §4, pendiente aprobación | log de prueba con password/token |
| JSON estructurado | `LogstashEncoder` + `fieldNames` | esquema §3 | `aws logs tail` muestra una línea JSON |
| Lambda indexa y filtra | `timestamp` RFC 3339 + `level` | docs AWS Java logging | Logs Insights filtra por `level` |
| Correlación consultable | `requestId` en MDC + `withRequestId` | `MdcCorrelation` intacta | filtro por `requestId` en Insights |
| Sin Terraform/IAM nuevo | decisiones 54-55 | `lambda.tf:27` ya permite | despliegue sin cambios de infra |
| Generadorhealthy | `dotnet build` + `dotnet run` | — | salida sin error, diff revisado |
| No se tocan tests | ningún cambio en plantillas de test | `AGENTS.md:20` | `git diff --name-only` sin rutas de test |

## Riesgos e incógnitas

- Lista de campos sensibles sin aprobar: impacto alto si se codifica sinOK del usuario. Respuesta:
  bloquea la implementación del enmascarado hasta la aprobación.
- `logstash-logback-encoder` no verificado en CodeArtifact: si el repositorio no lo replica, el
  `mvn deploy` del ms falla. Respuesta: verificar resolución antes de la fase de developer.
- Versión 8.x exacta sin fijar: 8.0 y 8.1 difieren. Respuesta: fijar una versión concreta en
  `common-bom` y verificar que compila con Jackson 2.
- La regla `info` sin excepción puede caer en bucles cerrados, que logback marca como mala práctica,
  y multiplica coste de ingesta en Lambda. Respuesta: medido en tester; hoy es requisito del
  objetivo, no se relaja.
- `debug` de parámetros expone PII y el nivel por defecto es `info` en Lambda: la exposición existe
  cuando alguien sube el nivel. Respuesta: enmascarado por nombre cubre los campos de la lista.
- Tests existentes que construyen clases con `new` pueden romper al pasar a inyección, y están
  prohibidos de tocar (decisión 45). Respuesta: se reporta en fase de tester, sin arreglar aquí.
- MDC no se propaga a hilos de pool: si una plantilla usa `Executors`, la traza se parte. Respuesta:
  revisar en la migración.
- `@timestamp` vs `timestamp`: si el encoder 8.x no acepta el renombrado con el nombre pedido por
  Lambda, hay que validar en tester (Researcher lo dejó como supuesto).

## ADR

- `docs/adr/0025-logs-json-con-logstash-logback-encoder.md` — estado `propuesto`, pendiente de
  revisión y decisión del usuario. No aprobado: no iniciar implementación que dependa de él.

## Guía de implementación y verificación

1. Aprobar la lista de campos sensibles (§4) y responder las preguntas nuevas de `questions.md`.
2. Aprobar `docs/adr/0025`.
3. En `library/common`: bumpear a 1.1.0, añadir la propiedad del encoder al `common-bom`, crear
   `ILogService`, `Slf4jLogService`, `CommonLogAutoConfiguration`, el `imports`, `LogMessages`,
   migrar `common-web`, añadir `logback-base.xml`, actualizar `README.md` y `docs/como-usar.md`.
4. `mvn clean install` en `library/common` y `library/platform/scripts/publish-common.ps1`.
5. En `generator`: cambiar las 27 plantillas, `pom.scriban`, `logback.scriban`,
   `application-properties.scriban`, `graalvm-hints.scriban`, `native-image-properties.scriban`;
   borrar `log4j2.scriban`; registrar la plantilla nueva en `component.json`.
6. `dotnet build` y `dotnet run --project Generator.csproj`. Revisar el diff completo de
   `projects/com.quizsmart.app/backend/quizapi`.
7. Compilar el ms (`mvn clean test-compile`) sin tocar tests.
8. Desplegar con `update-all.ps1`.
9. Verificar: `curl` a `/api/v1/parameters`, `aws logs tail` sobre `/aws/lambda/quizapi`, comprobar
   una línea JSON con `timestamp` y `level`, comprobar `requestId` en dos eventos seguidos, y un
   log de prueba con `password`/`token` que salga enmascarado.
10. Documentar en `architect.md` el resultado del cold start con el encoder.

## Lista de tareas y subtareas

- [ ] **Tarea 1**: Cerrar decisiones pendientes
  - [ ] 1.1: Usuario aprueba la lista de campos sensibles (§4)
  - [ ] 1.2: Usuario revisa y aprueba `ADR-0025`
  - [ ] 1.3: Usuario responde las preguntas nuevas de `questions.md`
- [ ] **Tarea 2**: `library/common` (Developer-Java)
  - [ ] 2.1: Bumpear `common-parent` y módulos a 1.1.0
  - [ ] 2.2: Propiedad `epc.logstash-logback-encoder.version` y `dependencyManagement` en `common-bom`
  - [ ] 2.3: `ILogService` + `Slf4jLogService` en `common-log`
  - [ ] 2.4: `CommonLogAutoConfiguration` + `AutoConfiguration.imports`
  - [ ] 2.5: `LogMessages` en `common-log` y `logback-base.xml`
  - [ ] 2.6: Migrar `GlobalExceptionHandler` y el filtro de correlación de `common-web`
  - [ ] 2.7: Actualizar `README.md` y `docs/como-usar.md`
  - [ ] 2.8: `mvn clean install` y `publish-common.ps1`
- [ ] **Tarea 3**: `generator` (Developer-Java)
  - [ ] 3.1: Migrar las 27 plantillas al puerto inyectado
  - [ ] 3.2: Nueva `domain-log-messages.scriban` y registro en `component.json`
  - [ ] 3.3: Reescribir `logback.scriban` con el encoder y el decorador
  - [ ] 3.4: Ajustar `component.json` según la decisión sobre `logback.xml` del ms
  - [ ] 3.5: Borrar `log4j2.scriban`
  - [ ] 3.6: `pom.scriban`: `common-bom` 1.1.0 y `common-log` explícito
  - [ ] 3.7: `application-properties.scriban`: AWS SDK a `INFO`
  - [ ] 3.8: Runtime hints del encoder en `graalvm-hints.scriban` y `native-image-properties.scriban`
- [ ] **Tarea 4**: Regenerar y verificar (Tester)
  - [ ] 4.1: `dotnet build` y `dotnet run`, diff completo del ms
  - [ ] 4.2: Compilar el ms sin tocar tests
  - [ ] 4.3: Desplegar con `update-all.ps1`
  - [ ] 4.4: `curl` a `/api/v1/parameters`
  - [ ] 4.5: `aws logs tail`: JSON, `level`, `timestamp`, `requestId`, enmascarado

## Archivos creados/modificados

- `docs/deliverables/obj-003/architect.md`
- `docs/deliverables/obj-003/questions.md`
- `docs/adr/0025-logs-json-con-logstash-logback-encoder.md`
