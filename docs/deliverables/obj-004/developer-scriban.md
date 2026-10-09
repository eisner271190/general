# Implementación

- Objetivo: `obj-004` Migrar backend generado de hexagonal horizontal a vertical slice
- Agente/especialidad: `Developer / Scriban`
- Estado: `parcial`
- Resumen:
  - Paso 1 completo: 133 plantillas Java movidas a slices; `component.json` regenerado.
  - Paso 2 parcial: solo Subscription (Handler, Commands, Controllers, puerto).
  - Compilación OK; 10/10 tests OK (baseline 10/10).
  - Pendiente: webhook y ai (Handler, Command, Controller, puertos I{Module}Port).
- Bloqueos:
  - Ninguno de ejecución. Decisiones abiertas: I42–I45 en `questions.md`.
- Alcance y ADR aprobados: `obj-004.md`, `questions.md` (D1–D48), ADR-0026.

## Cambios

| Archivo | Cambio | Motivo |
|---|---|---|
| `templates/*.scriban` (133 Java) | `package` e `import` a slices | D9, D14, D24-D28, D33, D39 |
| `templates/*DTO*.scriban` (12) | Clase `*DTO` renombrada a `*Dto` | D8 |
| `subscription-port.scriban` | `SubscriptionPort` a `ISubscriptionPort` | D9 |
| `subscription-handler.scriban` | Nuevo; reemplaza `subscription-usecase` | D22, D43 |
| `get-subscription-status-command.scriban` | Nuevo `record` | D41 |
| `sync-subscription-command.scriban` | Nuevo `record` | D41 |
| `subscription-endpoint.scriban` | Nuevo; reemplaza `subscription-controller` | D38, D43 |
| `webhook-endpoint.scriban` | Nuevo; ruta `/webhook` separada | D38 |
| `isubscription-service-port.scriban` | Eliminado | D45 |
| `subscription-usecase.scriban` | Eliminado (reemplazado por handler) | D22, D45 |
| `subscription-controller.scriban` | Eliminado (reemplazado por endpoint) | D38 |
| `hexagonal-architecture-test.scriban` | Regla de ciclos por slice | D1, D34 |
| `revenuecat-adapter.scriban` | Import explícito de tipo anidado | Compilación |
| `pom.scriban` | `pitest.excludedClasses` con rutas de slices | Rutas antiguas |
| `component.json` | 151 archivos y 140 directorios | D31, I25 |

- Placeholders usados: `{{ PACKAGE }}`, `{{ if(Name == "security") }}` (sin cambio).
- Efecto en salida: `security` no se genera (render vacío, D48 lo mueve a otro objetivo).
- `sqs-controller` y `sqs-receiver` tampoco se generan (render vacío; ya en baseline).

## Decisiones y desviaciones

- Paquetes: `{domain}.{usecase}.{domain|application|infrastructure}` (ADR-0026, D87).
- Modelos en `domain.model`; puertos en `domain.port` (D9, D30).
- Commands en `{domain}.{usecase}.domain` (D41, D87).
- Adaptadores en `infrastructure.adapters`; persistencia en `infrastructure.persistence` (D33).
- Configuración de feature en `infrastructure.configuration` (D39).
- Beans AWS en `common.infrastructure.beans` (D28); persistencia genérica en `connections`.
- `ParameterController` y `HolaMundoController` conservan su nombre (D42).
- Desviación: un DTO por operación, no `{Module}RequestDto` único (ver I43).
- Desviación temporal: `WebhookUseCase` y `AiUseCase` siguen con Service/UseCase (paso 2).
- Script de migración en `%TEMP%\opencode\obj004\`, fuera de `generator/`.

## Verificaciones y resultados

- `dotnet run --project generator\Generator.csproj`: OK=1, sin errores.
- Limpieza previa de `src/main/java` y `src/test/java` de `quizapi` (salida de D44).
- `mvn -q -B compile` en `quizapi`: exit 0; 0 errores de compilación.
- `mvn -B test` en `quizapi`: 10 tests, 0 fallos, 0 errores (baseline 10/10).
  - HexagonalArchitectureTest 3/3; ApplicationContextTest 3/3.
  - ParameterControllerTest 3/3; HolaMundoControllerTest 1/1.
- El proyecto no tiene `mvnw`; se usó `mvn` 3.9.9 con Java 17.0.12.
- TC-01: ruta `..\..\..\generator\target\...` resuelve y existe. No se ejecutó `update-all`.
- TC-02: `C:\` en `update-all.ps1` generado: 0 coincidencias.
- SOAP en templates y salida: 0 coincidencias.
- `{{` sin resolver en salida: 0 (solo `{{baseUrl}}` de Postman).
- Tests D23: solo cambian `package` e imports; `application-context-test` sin cambios.
- Postman: rutas sin cambio; no se editó.
- `generator` `.cs`: 0 archivos modificados.

## Defectos, limitaciones y riesgos

- Paso 2 pendiente: webhook y ai (I44, I45).
- Plantillas no listadas con nombres antiguos (no se generan; I42): `adapter-test`,
  `controller-test`, `service-test`, `usecase-test`, `iauthservice`, `iservice`,
  `servicePort`, `usecase`, `router`, `handler`, `dto`, `mapperDto`, `mapperDynamo`,
  `mapperEntity`, `DynamoBean`, `port`, `adapter`, `model`, `mapperPersistenceModel`.
- `pitest.excludedClasses` con `**`: no verificado (plugin no ejecutado).
- Renombre `DTO` a `Dto` aplicado solo a identificadores de clase.
- Finales de línea CRLF en los templates tocados a mano.

## Anexo técnico condicional

- Java: JDK 17.0.12; Maven 3.9.9; Spring Boot 3.4.0 (pom).
- Build: `mvn -B compile` y `mvn -B test` en `quizapi`.
- JaCoCo emite avisos de instrumentación de AWS SSM; no son fallos.

## Traspaso

- Reviewer/Tester: pendiente (revisar paso 1, verificación y decisiones I42–I45).

## Registro D49: Endpoint a Controller (2026-10-08 19:40:29)

- Objetivo: renombrar sufijo `Endpoint` por `Controller` en clases REST (D49).
- Estado: `completo`.

| Archivo | Cambio | Motivo |
|---|---|---|
| `templates/subscription-endpoint.scriban` | Renombrado a `subscription-controller.scriban`; clase `SubscriptionController` | D49 |
| `templates/webhook-endpoint.scriban` | Renombrado a `webhook-controller.scriban`; clase `WebhookController` | D49 |
| `component.json` | Claves y valores `SubscriptionController.java` / `WebhookController.java` | D49, D31 |

- Sin cambios de lógica, rutas ni asserts. Constantes `*_ENDPOINT` de logs no se renombran.
- Paths HTTP sin cambio: `postman-collection.scriban` no requiere edición.
- Tests D42 (`ParameterController`, `HolaMundoController`): sin cambios.
- Salida: `projects/com.quizsmart.app/backend/quizapi` regenerada; eliminados
  `SubscriptionEndpoint.java` y `WebhookEndpoint.java` obsoletos (evita dos controllers en la misma ruta).
- `dotnet run --project generator\Generator.csproj`: OK=1.
- `mvn -B compile`: BUILD SUCCESS (exit 0).
- `mvn -B test`: 10/10 OK, 0 fallos, 0 errores (exit 0).
- Imports sin resolver: 0 (compilación OK). Sin `Endpoint` como clase en `generator` ni salida.
- No se ejecutó deploy, push, commit, AWS, `up.ps1` ni `update-all`.
- Pendientes fuera de esta orden (abiertos): I42, I43, I44, I45, I36, D48 (ver `questions.md`).

## Archivos creados/modificados

- `generator/components/backend/spring-boot-3.5.16/component.json`
- `generator/components/backend/spring-boot-3.5.16/templates/*.scriban` (ver tabla)
- `projects/com.quizsmart.app/backend/quizapi/` (salida regenerada, D44)
- `docs/deliverables/obj-004/developer-scriban.md`
- `docs/deliverables/obj-004/questions.md` (registro, I42–I45)
- `docs/deliverables/obj-004/obj-004.md` (criterios)
- `docs/deliverables/obj-004/use-cases.md` (casos de prueba)

## Registro developer-scriban: Endpoint a Controller en plantillas (2026-10-08 19:44:26)

- Objetivo: renombrar `*-endpoint.scriban` a `*-controller.scriban` y `{Module}Endpoint` a
  `{Module}Controller` (orden "Los templates también").
- Estado: `completo` (sin cambios nuevos; el renombrado ya estaba aplicado por D49).

### Verificación del estado previo

- Plantillas `*endpoint*.scriban` en `generator/**`: 0.
- Clases `*Endpoint` en plantillas `.scriban`: 0 (solo prosa y nombres de función, ver abajo).
- `component.json`: 0 referencias a `Endpoint`; 151 `files`; 0 rutas faltantes.
- Plantillas `*-controller*.scriban` presentes: 14 (auth, user, registration, password,
  admin-user, ai, subscription, webhook, sns, sqs, parameter, hola-mundo).
- `exchange` no tiene plantilla `*-controller`; su endpoint `/exchange` vive en `AuthController`.
- Guard `security` sin cambio (D48).

### Cambios

| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `templates/*.scriban` | Ninguno | Ya renombrados (D49) |
| `component.json` | Ninguno | Ya apunta a `*-controller.scriban` |
| `generator/**/*.cs` | Ninguno (0 modificados) | Fuente de verdad intacta |

### Referencias a "Endpoint" restantes (no son clases REST; sin cambio)

- `ai-controller.scriban:25`: comentario Javadoc "Endpoint de IA generativa".
- `cognito-client.scriban:205-220`: variable `tokenEndpoint` (URL OAuth2).
- `up.ps1.scriban:143-193`: función `Get-CodeArtifactEndpoint` (PowerShell).
- `token_exchanger.dart.scriban:27,104`: `_logCallingEndpoint` (Flutter).
- `generator/Domain/Models/EndpointConfiguration.cs` y `GeneratorConstants.EndpointsVariable`:
  modelo del JSON de entrada; código fuente, no se toca.

### Verificaciones y resultados

- `dotnet run --project generator\Generator.csproj`: OK=1 (19:42:32).
- Salida en `projects/com.quizsmart.app/backend/quizapi` (appId de `target`, D47; D44).
- Archivos `*Endpoint.java` en salida: 0.
- `mvn -q -B compile` en `quizapi`: exit 0 (19:42:38). Imports sin resolver: 0.
- `mvn -B test`: 10 tests, 0 fallos, 0 errores; BUILD SUCCESS (19:42:49).
  - HexagonalArchitectureTest 3/3; ApplicationContextTest 3/3.
  - ParameterControllerTest 3/3; HolaMundoControllerTest 1/1.
- Tests no modificados ni creados.
- No ejecutado: deploy, push, commit, AWS, `up.ps1`, borrado de recursos.

### Defectos, limitaciones y riesgos

- Ninguno nuevo. Abiertos sin implementar: I42, I43, I44, I45, I36, D48.
- Prosa y nombres de función con "Endpoint" (lista arriba): ver I46 en `questions.md`.

## Registro D50 (2026-10-08 19:47:37): imports de common

Estado: bloqueado en I47. Sin cambios en templates.

### Localización de library\common (solo lectura)

- Ruta: library\common (multi-módulo Maven, com.epc.common:common-parent:1.1.5).
- Paquetes reales: com.epc.common.error, com.epc.common.log, com.epc.common.web.
- No contiene paquetes configuration, eans ni connections.
- library\common\docs\como-usar.md: DomainLogMessages vive en
  infrastructure.configuration del microservicio (generado por plantilla).

### Cambios

| Archivo/componente | Cambio | Motivo |
|---|---|---|
| generator/**/*.scriban | Ninguno | Paquete destino no definido (I47) |
| docs/deliverables/obj-004/questions.md | D50 e I47 añadidos | Regla de dudas |

### Verificaciones y resultados

- No ejecutadas: generación, compilación y tests. Motivo: sin paquete destino (I47).
- Tests no modificados ni creados. Sin commit, push, deploy ni comandos AWS.

### Defectos, limitaciones y riesgos

- Sustituir {{ PACKAGE }}.common.infrastructure por com.epc.common.* rompería imports
  (esos paquetes no existen en library\common).
- Decisión pendiente: I47 en questions.md (opciones A y B).
## Registro developer-scriban: paso 2 (webhook y ai), D53, I57 (2026-10-08 21:53:42)

- Estado: `parcial`. Bloqueos de library abiertos (I59–I63).

### Cambios

| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `webhook-handler.scriban` | Nuevo; reemplaza `webhook-usecase` | D22, D59 |
| `iwebhook-port.scriban` | Nuevo `IWebhookPort`; reemplaza service-port | D6, D59, D45 |
| `process-webhook-command.scriban` | Nuevo record `ProcessWebhookCommand` | D41, D43 |
| `webhook-controller.scriban` | Usa `IWebhookPort` y `ProcessWebhookCommand` | D43 |
| `ai-handler.scriban` | Nuevo; reemplaza `ai-usecase` | D22, D59 |
| `iai-port.scriban` | Nuevo `IAiPort`; reemplaza service-port | D6, D59, D45 |
| `generate-ai-command.scriban` | Nuevo record `GenerateAiCommand` | D41, D43 |
| `ai-controller.scriban` | Usa `IAiPort` y `GenerateAiCommand`; `aiHandler` | D43 |
| `mapper-class`, `mapper-info` | Paquete `common.persistence`; imports locales | D53 |
| `imapper*`, `iproviderpersistence` | Paquete `common.persistence` | D53 |
| `dynamodb-generic-persistence.scriban` | Imports a `common.persistence` | D53 |
| `*-test` (adapter, controller, service, usecase) | Eliminados | D66, I57 |
| `*-usecase` y `*-service-port` de webhook y ai | Eliminados | D22, D45 |
| `component.json` | Rutas de handler, puertos, commands y `common/persistence` | D31, D53 |

- Placeholders usados: `{{ PACKAGE }}` (sin cambio nuevo).
- Efecto en salida: webhook y ai con Handler, Command y puerto; sin service-port ni usecase.

### Verificaciones

- `dotnet run --project generator\Generator.csproj`: OK=1 (21:50:59).
- `mvn -q -B compile` en `quizapi`: exit 0 (21:51:07).
- `mvn -B test` en `quizapi`: 10 tests, 0 fallos, BUILD SUCCESS (21:51:21–21:52:05).
  - Tests no modificados ni creados. Avisos JaCoCo (SSM) no son fallos.
- Búsqueda de nombres antiguos en `src`: 0 (solo un comentario de `HexagonalArchitectureTest`).
- SOAP en templates y salida: 0. Placeholders `{{` en salida: 0.
- Faltantes en salida (`component.json`): 71, todos de `security` (guard D48) o guards
  `ConsumedEvents` (`SqsConfig`, `SQSController`, `SqsReceiver`; ya en baseline).
- `.cs` del generador modificados: 0.
- No ejecutado: commit, push, deploy, publicación, comandos AWS, `up.ps1`, creación de tests.

### Bloqueos y decisiones pendientes (questions.md)

- I59: `DynamoDbGenericPersistence` depende de clases de la app (D65 vs D53).
- I60: `CorsConfig` usa `DomainLogMessages` de la app (D68).
- I61: `CognitoClient` usa modelos de `security` (D64, D48).
- I62: versión de módulos nuevos (1.1.5 única; publicar fuera de alcance).
- I63: nombre de clase por módulo para `DomainLogMessages` (D55).
- I64: confirmar nombres `ProcessWebhookCommand` y `GenerateAiCommand`.
- I65: constantes `*_ENDPOINT` sin renombrar.

### Pendientes

- Crear `library/common/common-aws` y `common-config` (pom, bom) y compilarlos (tras I59–I62).
- Dividir `DomainLogMessages` por módulo (tras I63).
- Migrar `CorsConfig`, `CognitoClient`, `DynamoDbGenericPersistence` (tras I59–I61).

## Registro developer-scriban: library common y D76–D78 (2026-10-08 22:32:32)

- Objetivo: `obj-004`. Aplicar D1–D78; crear módulos library; dividir `DomainLogMessages`.
- Estado: `completo`. Pendientes en `questions.md`: I69–I74.
- Bloqueos: ninguno de ejecución.
- Alcance y ADR: `obj-004.md`, `questions.md` (D1–D78), ADR-0026 (`Aceptada`).

### Cambios

| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `library/common/**/pom.xml` | Versión 1.1.6; módulos nuevos; BOM AWS | D69, D71, D78 |
| `library/common/common-bom/pom.xml` | Entradas de los 3 módulos nuevos | D71 |
| `library/common/common-aws` (nuevo) | Sqs/Sns/DynamoDBConfig, DynamoTable | D64, D65, D67 |
| `library/common/common-config` (nuevo) | `CorsConfig` (log local), `GraalHints` | D68, D72 |
| `library/common/common-persistence` (nuevo) | Mapper*, IMapper*, Dynamo | D69, D76, D78 |
| `templates/cognito-client` -> `cognito-adapter` | `CognitoAdapter` en auth (adapters) | D77 |
| `templates/auth-log-messages` (nuevo) | `AuthLogMessages` (guard security) | D73, I70 |
| `templates/*-log-messages` (ai, subscription, webhook, sns, sqs) | `{Module}LogMessages` | D73 |
| `templates/domain-log-messages` | Solo constantes de seguridad; sin registrar | D48, D62, I69 |
| 23 templates de slices | Import y referencias a `{Module}LogMessages` | D73, D75 |
| 6 adaptadores de security | `CognitoClient` a `CognitoAdapter` (imports y tipo) | D77 |
| `templates/application-java` | `@Import` de beans de library; imports con guard | D71, I71 |
| `templates/pom` | Versión 1.1.6; deps common-aws, common-config, common-persistence | D71 |
| `templates/ai-controller` | Prosa `Endpoint` a `Controller` | D61 |
| 12 templates movidos a library | Eliminados (cors, graal, sqs, sns, dynamo, mapper) | D64–D69 |
| `component.json` | 146 archivos, 140 directorios; sin rutas `common` | D31, D73, I57 |

- Placeholders usados: `{{ PACKAGE }}`, `{{ Name }}`, `{{ if(Name == "security") }}`,
  `{{ if ConsumedEvents.size > 0 }}`.
- Efecto en salida: beans AWS y persistencia salen de `com.epc.common.*`; sin `common/` en la app;
  logs por slice; `CognitoAdapter` solo en security.
- Salida: `projects/com.quizsmart.app/backend/quizapi` regenerada (D44). Antes se eliminó
  `src/main/java/.../common` obsoleto para no ocultar imports rotos.

### Decisiones y desviaciones

- `library/common` solo recibe clases agnósticas; no importa `{{ PACKAGE }}`.
- Beans de library con `@Import` en `Application`, sin escaneo de `com.epc.common` (I71).
- `MapperClass` se importa para conservar el bean que antes escaneaba la app.
- `AuthLogMessages` incluye `USER_CONFIRMED` y `USER_CONFIRM_FAILED` (I70).
- Versión 1.1.6 nueva; 1.1.5 no se sobrescribe en `~/.m2` (I62, D71).

### Verificaciones y resultados

- `mvn -B -DskipTests install` en `library/common` (7 módulos, local): exit 0 (TC-19).
- `dotnet run --project generator\Generator.csproj`: OK=1, sin errores.
- `mvn -B clean test` en `quizapi`: BUILD SUCCESS, 10/10, 0 fallos (TC-20, TC-21).
  - HexagonalArchitectureTest 3/3; ApplicationContextTest 3/3 (TC-22).
  - ParameterControllerTest 3/3; HolaMundoControllerTest 1/1.
  - Avisos de JaCoCo sobre clases SSM: no son fallos.
- `Endpoint|ENDPOINT` (sensible a mayúsculas) en `src`: 0 (TC-23).
- `DomainLogMessages` o `common.infrastructure` en salida: 0 (TC-24).
- SOAP (`soap|wsdl|WebService`) en salida: 0. Placeholders `{{` en salida: 0.
- `.cs` del generador modificados: 0. Sin tests creados ni modificados.
- No ejecutado: commit, push, deploy, publicación, comandos AWS, `up.ps1`, borrado de recursos.

### Defectos, limitaciones y riesgos

- `security` no se genera ni verifica (D48). Sus adaptadores siguen con `DomainLogMessages` (I69).
- ADR-0026 aún cita `CognitoClient` y no lista `MapperInfo` (I74; lo edita architect).
- `pitest.excludedClasses` con `**`: no verificado (TC-11).
- `library/common/docs` y `README.md` no listan los módulos nuevos (I74).

### Anexo técnico condicional

- Java: JDK 17.0.12; Maven 3.9.9; Spring Boot 3.4.0 (parent); AWS SDK 2.31.73.
- Library: `common-persistence` usa Lombok y Reactor como `provided`.
- Build: `mvn -B install -DskipTests` (library, local); `mvn -B clean test` (quizapi).

### Traspaso

- Reviewer/Tester: pendiente (revisar módulos library, D76–D78, I69–I74).

### Archivos creados/modificados

- `library/common/pom.xml`, `common-bom/pom.xml`, `common-log|error|web/pom.xml`
- `library/common/samples/*/pom.xml`
- `library/common/common-aws/**`, `common-config/**`, `common-persistence/**` (nuevos)
- `generator/components/backend/spring-boot-3.5.16/component.json`
- `generator/components/backend/spring-boot-3.5.16/templates/*.scriban` (tabla)
- `projects/com.quizsmart.app/backend/quizapi/` (salida regenerada, D44)
- `docs/deliverables/obj-004/developer-scriban.md`, `questions.md`, `obj-004.md`,
  `use-cases.md`
## Registro D85 (2026-10-08 22:55:00)

- Estado: completo.
- Resumen: `Application` solo con `@SpringBootApplication` y `main()`.
  - Imports de library movidos a `ApplicationConfig` con `@Configuration` y `@Import`.
- Bloqueos: ninguno. Duda I75 registrada (paquete de `ApplicationConfig`).
- Alcance y ADR: obj-004; ADR-0026; D85 (supera D81); D52–D78.

### Cambios

| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `templates/application-java.scriban` | Solo `@SpringBootApplication` y `main()`. | D85 |
| `templates/application-config-java.scriban` | Nueva; `@Configuration` con `@Import`. | D85 |
| `component.json` | Registra `ApplicationConfig.java` en `{{APPLICATION_PACKAGE}}`. | Plantilla nueva |

### Placeholders y variables

- `{{ PACKAGE }}`: paquete Java en ambas plantillas.
- `ConsumedEvents.size > 0`: `SqsConfig` (solo si hay eventos consumidos).
- `Name == "security"`: `CorsConfig` (guard; fuera de obj-004, D48).

### Decisiones y desviaciones

- `@Import` en vez de escaneo: `com.epc.common.*` está fuera del paquete de la app.
  - `common-log` y `common-web` se cargan por `AutoConfiguration.imports`; no se importan.
  - `@ComponentScan("com.epc.common")` no se usa: cargaría beans no pedidos.
- `ApplicationConfig` en el paquete raíz (I75); ADR-0026 dice `common`. Pendiente confirmar.
- Sin `@Bean` en plantillas: no hay beans que duplicar.

### Verificaciones y resultados

- Generación: `dotnet run --project Generator.csproj` en `generator/`; OK=1.
  - Sin placeholders `{{ }}` en `Application.java` ni `ApplicationConfig.java`.
- Compilación: `mvn -B -q compile` en `projects/com.quizsmart.app/backend/quizapi`; exit 0.
- Tests: `mvn -B test` (sin modificar tests): 10/10; BUILD SUCCESS.
  - `ApplicationContextTest` 3/3: contexto arranca sin perfil cloud ni AWS.
  - Aviso JaCoCo al instrumentar `DefaultSsmClient`; no es fallo ni cambio de este objetivo.
- Beans duplicados: búsqueda estática de anotaciones; sin duplicados de tipo ni de nombre.
- Library: sin cambios; no se compiló ni publicó.
- Casos: TC-26, TC-27, TC-28 en `use-cases.md`.

### Defectos, limitaciones y riesgos

- `ApplicationConfig` no sigue la ubicación `common` de ADR-0026 (I75).
- `ApplicationContextTest` no comprueba beans duplicados por tipo; solo arranque.
- Prohibido y no ejecutado: commit, push, deploy, publicar, AWS, `up.ps1`.

### Archivos creados/modificados

- `generator/components/backend/spring-boot-3.5.16/templates/application-java.scriban`
- `generator/components/backend/spring-boot-3.5.16/templates/application-config-java.scriban`
- `generator/components/backend/spring-boot-3.5.16/component.json`
- `projects/com.quizsmart.app/backend/quizapi/` (salida regenerada, D44)
- `docs/deliverables/obj-004/developer-scriban.md`, `questions.md`, `improvements.md`,
  `use-cases.md`

## Registro developer-scriban: arranque local quizapi (2026-10-08 23:07:37)

- Objetivo: `obj-004`
- Agente/especialidad: `Developer / Scriban`
- Estado: `bloqueado`
- Resumen: sin cambios en templates; `mvn spring-boot:run` no arranca sin perfil `cloud`.
- Bloqueos: I76 abierta (decisión A o B en `questions.md`).
- Alcance y ADR aprobados: obj-004; ADR-0026; ADR-0012 (perfil cloud).

## Cambios

| Archivo/componente | Cambio | Motivo |
|---|---|---|
| Ninguno | Sin cambios | Causa fuera de templates; requiere decisión (I76) |

## Causa raíz

- Error: `Failed to bind properties under 'ai.max-tokens'`.
- Valor: `"${AI_MAX_TOKENS}"` sin resolver (conversión a Integer falla).
- Origen: `templates/application-properties.scriban` líneas 57-61 (`ai.*` sin default).
- Contexto: `AI_*` existen en `generator/target` y en Parameter Store (perfil `cloud`).
- Perfil por defecto no importa Parameter Store (`application-cloud.properties` solo en `cloud`).
- `ai-api-key` (Secrets Manager) no existe en `target`.
- Mismo patrón en `AiProperties` (`ai-properties.scriban`): sin defaults, fail-fast deliberado.

## Decisiones y desviaciones

- No se modifica template ni `component.json`: un default local contradice el fail-fast
  documentado y exigiría inventar `ai-api-key` (prohibido).
- No se regenera `projects/` (sin cambio de fuente).

## Verificaciones y resultados

- `mvn -q spring-boot:run` en `projects/com.quizsmart.app/backend/quizapi`: FALLA.
  - Exit code 1; `UnsatisfiedDependencyException` en `aiHandler` -> `openRouterAdapter`
    -> `aiProperties`.
  - Fallo real: `ai.max-tokens` = `"${AI_MAX_TOKENS}"` (NumberFormatException).
- Tests: no ejecutados (arranque bloqueado; sin cambios que validar).
- No se llamó a AWS, OpenRouter ni `up.ps1`; no se crearon tests.

## Defectos, limitaciones y riesgos

- Arranque local sin perfil `cloud` no funciona por diseño (ADR-0012).
- Opción A requiere credenciales AWS locales (acción AWS: autorización pendiente).
- Opción B: `ai-api-key` real no existe en `target`; el valor lo debe dar el usuario.

## Traspaso

- Reviewer/Tester: `pendiente` decisión de I76 (A o B).

## Archivos creados/modificados

- `docs/deliverables/obj-004/developer-scriban.md`
- `docs/deliverables/obj-004/questions.md` (I76)
- `docs/deliverables/obj-004/improvements.md` (I76)
## Registro developer-scriban D87 (2026-10-09 04:54:56)

- Objetivo: `obj-004`
- Agente/especialidad: `Developer / Scriban`
- Estado: `bloqueado`
- Resumen: D87 aplicado en templates y `component.json` del backend.
  - Generación y compilación OK.
  - Tests 10/10 solo en copia temporal; en `projects/` fallan por salida previa (I78).
- Bloqueos: I78 (borrar `src/**/modules` generado) e I79 (arranque cloud requiere AWS).
- Alcance y ADR aprobados: obj-004; ADR-0026 (D87); D47; D23; D44.

## Cambios

- `templates/*.scriban` backend (128 archivos): `.modules.` eliminado en paquetes,
  imports y `package`. Motivo: D87.
- `templates/hexagonal-architecture-test.scriban`: patrón ArchUnit a
  `{{ PACKAGE }}.(*).(*)..` y comentario Javadoc. Motivo: D87, D1, D34.
- `component.json` backend: claves `files` y `directories` sin segmento `modules`
  (640 reemplazos en 128 archivos). Motivo: D87, D31.
- Tests D23 (`parameter-controller-test`, `hola-mundo-controller-test`,
  `application-context-test`): solo imports y paquetes. Motivo: D23, D87.
- Placeholders usados: `{{ PACKAGE }}`, `{{MICROSERVICE_NAME}}`, `{{APPLICATION_PACKAGE}}`.
- Efecto en salida: `com.quizsmart.app.{domain}.{usecase}.<capa>` (p. ej. `ai.ai.application`).
- Sin cambios en código fuente del generador (`.cs`), `library/`, `up.ps1` ni tests.

## Decisiones y desviaciones

- `hexagonal-architecture-test` se tocó solo en patrón de paquetes y comentario (D87).
- `gitignore.scriban` (`node_modules/`) no se modificó: no es paquete.
- `cloud/terraform/modules` queda fuera: no es paquete Java.
- Arranque cloud no ejecutado: lee SSM y Secrets Manager (acción AWS, I79).

## Verificaciones y resultados

- Grep `modules` en templates y `component.json` backend: sin restos de paquete.
  - Único resto: `node_modules/` en `gitignore.scriban`.
- `component.json`: JSON válido (`python -c "json.load"`).
- Generación: `dotnet run --project Generator.csproj` en `generator/`: OK=1.
- Compilación: `mvn -B -q compile` en `projects/com.quizsmart.app/backend/quizapi`: exit 0.
- Tests en `projects/` (sin modificar): 14 ejecutados, 3 errores; BUILD FAILURE.
  - Causa: 55 archivos previos en `src/**/modules` (no versionados).
  - Error: `ConflictingBeanDefinitionException` de `aiHandler` (`ai.modules.ai` vs `ai.ai`).
- Tests en copia temporal `%TEMP%\opencode\obj004-quizapi` sin `src/**/modules`:
  - 10/10 OK; BUILD SUCCESS; `ApplicationContextTest` 3/3.
- Arranque con `-Dspring-boot.run.profiles=cloud`: no ejecutado (I79).
- Prohibido y no ejecutado: commit, push, deploy, AWS, borrado, `up.ps1`, tests nuevos.

## Defectos, limitaciones y riesgos

- El generador no limpia salida previa; `projects/` conserva directorios `modules` (I78).
- Hasta resolver I78, `mvn test` en `projects/` falla.
- Pendiente de I79: verificación de arranque cloud.

## Traspaso

- Reviewer/Tester: `pendiente` decisión de I78 e I79 en `questions.md`.

## Archivos creados/modificados

- `generator/components/backend/spring-boot-3.5.16/templates/*.scriban` (128)
- `generator/components/backend/spring-boot-3.5.16/component.json`
- `projects/com.quizsmart.app/backend/quizapi/` (salida regenerada, D44)
- `docs/deliverables/obj-004/developer-scriban.md`, `questions.md`, `improvements.md`
## Registro I78 (developer-scriban, 2026-10-09 05:25:09 UTC-5)

- Resultado: I78 cerrada sin borrado; la salida modules ya no existía.
- Verificado en projects/com.quizsmart.app/backend/quizapi:
  - Antes: 0 directorios modules; 0 archivos */modules/* bajo src/.
  - Después de regenerar: 0 directorios modules; 0 archivos */modules/*.
  - Archivos Java bajo src/main/java: 56.
- Generador: dotnet run --project generator\Generator.csproj OK=1, sin errores.
- Tests: mvn -B clean test 10/10 OK (sin modificar tests).
- Ruido: aviso JaCoCo al instrumentar AWS SSM en ApplicationContextTest; no es fallo.
- Restricciones cumplidas: sin perfil cloud, sin commit, push, deploy ni AWS.
- Pendiente: I79 (arranque cloud), abierta en questions.md.
- Dependencias: ninguna nueva.
