# Preguntas obj-004

- 2026-10-08: El código fuente del generador, ¿se modifica?
  - Respuesta: no, solo se modifican los templates.
  - Recomendación: dejar código fuente intacto para evitar regresiones.
  - Los proyectos generados salen en vertical slice.
- 2026-10-08: ¿En qué dominio van auth, user, registration, password, admin-user, exchange, sqs, sns y hola-mundo?
  - Respuesta: auth, user, registration, password, admin-user, exchange van en security. sqs, sns y hola-mundo van en dominio "test".
  - Recomendación: listar su dominio; no crear un quinto dominio sin decisión.
- 2026-10-08: Quiz no tiene plantillas propias (solo entidad en target). ¿Crear slice vacío o omitir?
  - Respuesta: omitir hasta que exista una plantilla Quiz.
  - Recomendación: omitir hasta que exista una plantilla Quiz.
- 2026-10-08: obj-004 escribe "Suscription"; el generador usa "Subscription". ¿Cuál se usa?
  - Respuesta: Subscription.
  - Recomendación: Subscription (coincide con el código).
- 2026-10-08: ¿Webhook y RevenueCat van dentro de Subscription?
  - Respuesta: sí, ya dependen de la suscripción.
  - Recomendación: sí, ya dependen de la suscripción.
- 2026-10-08: ¿Paquetes Java en minúscula (subscription) y clases en PascalCase?
  - Respuesta: sí; es la convención Java y no contradice obj-004.
  - Recomendación: sí; es la convención Java y no contradice obj-004.
- 2026-10-08: ¿Sufijo DTO "RequestDto/ResponseDto" (obj-004) o "RequestDTO" (plantillas actuales)?
  - Respuesta: RequestDto/ResponseDto.
  - Recomendación: seguir obj-004 literal (Dto).
- 2026-10-08: ¿Se eliminan los puertos de un solo uso dentro de cada slice?
  - Respuesta: NO, siempre se deben crear los puertos
  - Recomendación: sí; mantener interfaces solo donde haya más de una implementación.
- 2026-10-08: La plantilla HexagonalArchitectureTest queda obsoleta. ¿Se reescribe, se elimina o se
  mantiene?
  - Respuesta: reescribir con regla de ciclos entre slices.
  - Recomendación: reescribir con regla de ciclos entre slices; la decisión es del usuario.
  - Decisión final (2026-10-08): adaptar a vertical slice; no eliminar ni dejar como está.
  - Estado: resuelta. Supera la respuesta anterior y la línea "Se mantienen" de abajo.
- 2026-10-08: No hay permiso de escritura en docs/adr/ para Architect (permission.rejected).
  - Respuesta: conceder permiso.
  - Recomendación: conceder permiso o pedir que el usuario cree ADR-0026 desde architect.md.
  - Estado: resuelta (D10). Permiso concedido; ver I2.
- 2026-10-08: ¿El paquete común será `{{ PACKAGE }}.common`?
  - Respuesta:  sí; `common/infrastructure/{configuration,beans,persistence}`.
  - Recomendación: sí; `common/infrastructure/{configuration,beans,persistence}`.
- 2026-10-08: ¿`HexagonalArchitectureTest` y los `*-test.scriban` se eliminan, mantienen o adaptan?
  - Respuesta: ~~Se mantienen~~ (superada, ver decisión 2026-10-08 de HexagonalArchitectureTest).
  - Decisión final (2026-10-08): `HexagonalArchitectureTest` se adapta a vertical slice;
    las plantillas `*-test.scriban` NO se eliminan. Sus cambios van en el objetivo de
    implementación, no en este objetivo (regla de tests).
  - Recomendación: decidirlo en el ADR; no tocarlos sin autorización (regla de tests).
- 2026-10-08: ¿Quiz tiene plantillas propias o solo se crea el paquete vacío?
  - Respuesta: No crear
  - Recomendación: crear solo el paquete `quiz` si el ADR lo exige; no inventar templates.
- 2026-10-08: `update-all.ps1.scriban` (línea 29) tiene ruta absoluta; ¿se corrige en este objetivo?
  - Respuesta: Corregir, se debe usar el placeholder y con ruta relativa "\target\$ApplicationId\$ApplicationId.json"
  - Recomendación: corregir en objetivo aparte para no ampliar alcance; registrar como riesgo.
- 2026-10-08: ¿`revenuecat-webhook-filter` va a `subscription` o a `common`?
  - Respuesta:  `subscription`, por ser específico del dominio.
  - Recomendación: `subscription`, por ser específico del dominio.
- 2026-10-08: ¿Se aprueba la plantilla `developer.md` para este rol PowerShell?
  - Respuesta:  Se debe crear un agente developer-scriban.md especialista en Scriban
  - Recomendación: sí; usar su anexo PowerShell.

## Decisiones confirmadas por el usuario (2026-10-08)

- D1: `HexagonalArchitectureTest` se adapta a vertical slice (no se elimina ni se deja igual).
- D2: Las plantillas `test.scriban` NO se eliminan.
- D3: Las preguntas contradictorias de `HexagonalArchitectureTest` quedan resueltas por D1.
- D4: `developer-scriban.md` autorizado (agente especialista en Scriban).
- D5: ADR-0026 con estructura vertical slice según obj-004 y `architect.md`; estado `Aceptada`
  por confirmación del usuario.
- D6: Puertos: siempre se crean, incluso de un solo uso.
- D7: Quiz: no crear.
- D8: Subscription, dominio `security` y tests según respuestas anteriores de este archivo.
- D9 (I1): puertos en `{domain}.modules.{usecase}.domain.port.I{Module}Port`.
- D10 (I2): permiso de escritura en `docs/adr/` concedido a Architect.
- D11 (I3): Quiz fuera del criterio de aceptación.
- D12 (I4): Alcance con 5 dominios: Suscription, Ai, Parameter, security, test.
- D13 (I5): paquetes en minúscula; clases en PascalCase.
- D14 (I6): common usa `common/infrastructure/connections/`.
- D15 (I8/I10): estado del ADR-0026 = `Aceptada`.
- D16 (I11): no añadir anexo Scriban a `docs/templates/deliverables/developer.md`.
- D17 (update-all): corregir `update-all.ps1.scriban` en este objetivo, con placeholder y ruta
  relativa `\target\$ApplicationId\$ApplicationId.json`.
- D18 (I7): mantener `0026-vertical-slice-backend.md`.
- D19 (I9): sin tabla de ADR en `docs/adr/README.md`.
- D20 (I13): permiso de edición sobre `generator/**/*.scriban`.
- D21 (I14): `AGENTS.md` corregido por el usuario (`AGENTS: .opencode/agents`).
- D22 (I15): Service y UseCase se fusionan en Handler; se eliminan ServicePort e IService.
- D23 (I16): ajuste mínimo de imports en `parameter-controller-test`,
  `hola-mundo-controller-test` y `application-context-test`.
- D24 (I17): paquetes `adminuser` y `holamundo`; clases `AdminUser*` y `HolaMundo*`.
- D25 (I18): usecases por grupo aprobados (subscription, ai, parameter, test, security).
- D26 (I19): persistencia común en `common/infrastructure/connections/`.
- D27 (I20): modelos, entidades, mappers y DTOs al slice; genéricos en common.
- D28 (I21): beans AWS en common; `SqsReceiver` y `SnsEventPublisher` al slice `test`.
- D29 (I22): ruta de `update-all` con `Join-Path $PSScriptRoot` (refina D17).
- D30 (I23): puertos en `{domain}.modules.{usecase}.domain.port.I{Module}Port` (confirma D9).
- D31 (I25, 2026-10-08): autorizado editar `component.json`, solo claves `directories` y
  `files` del backend `spring-boot-3.5.16`.
- D32 (I26, 2026-10-08): `{Module}` = nombre actual del caso de uso. Confirmado por el usuario
  como "Auth"; interpretación: `{Module}` = `Auth` y la clase resultante es `AuthHandler`.
  - Aplica igual a `{Module}Command`, `{Module}Endpoint`, `{Module}RequestDto`,
    `{Module}ResponseDto` e `I{Module}Port`.
- D33 (I27, 2026-10-08): adaptadores en `{domain}.modules.{usecase}.infrastructure.adapters`;
  persistencia en `{domain}.modules.{usecase}.infrastructure.persistence`.
- D34 (I28, 2026-10-08): `HexagonalArchitectureTest` SE ADAPTA EN ESTE OBJETIVO (obj-004).
  Reemplaza la recomendación previa de I28. Los `*-test.scriban` siguen sin eliminarse (D2)
  y solo se ajusta lo necesario según D1.

## Incógnitas abiertas

- I9: `docs/adr/README.md` no tiene tabla de ADR (solo tabla de estados, 14 líneas).
  - Respuesta: No crear tabla de ADR
  - Recomendación: no añadir índice; el ADR-0026 se referencia por nombre de archivo.
  - Respuesta: No crear tabla de ADR; referenciar por nombre de archivo.
  - Estado: resuelta (D19).
- I10: ADR-0026 escrito (2026-10-08) con estado `Aceptada`; README usa `Propuesta/Aceptada`.
  - Recomendación: añadir `Aprobada` a la tabla de estados de README, o dejar ADR en `aprobado`.

- I1: Ubicación de los puertos.
  - Respuesta: `{domain}.modules.{usecase}.domain.port.I{Module}Port`.
  - Estado: resuelta (D9).
  - Recomendación: `{domain}.modules.{usecase}.application.port.I{Module}Port` (prefijo I).
- I2: ADR-0026 no escrito en `docs/adr/` (permiso rechazado).
  - Respuesta: conceder permiso de escritura a Architect en `docs/adr/`.
  - Estado: resuelta (D10). Pendiente crear el archivo.
  - Recomendación: conceder permiso a Architect o crear el archivo desde `architect.md`.
- I3: Conflicto de criterio: obj-004 exige dominio Quiz; decisión D7 lo omite.
  - Respuesta: quitar Quiz del criterio de aceptación.
  - Estado: resuelta (D11).
  - Recomendación: actualizar el criterio de aceptación de obj-004.
- I4: obj-004 lista 4 dominios; respuestas añaden `security` y `test`.
  - Respuesta: Alcance con 5 dominios: Suscription, Ai, Parameter, security, test.
  - Estado: resuelta (D12).
  - Recomendación: actualizar Alcance de obj-004 con 5 dominios.
- I5: obj-004 pide PascalCase para `domain/usecase/module`; respuesta permite paquetes minúscula.
  - Respuesta: paquetes en minúscula; clases en PascalCase.
  - Estado: resuelta (D13).
- I6: Plantillas `common` difieren: architect propuso `connections/`; usuario fijó `persistence/`.
  - Respuesta: `common/infrastructure/connections/`.
  - Estado: resuelta (D14). Reemplaza la respuesta previa de `persistence/`.
- I7: Nombre de archivo ADR: obj-004 usa `0026-vertical-slice-backend.md`; el usuario pide
  `ADR-0026`. Se usa la convención de `docs/adr/README.md`.
  - Respuesta: mantener `0026-vertical-slice-backend.md`.
  - Estado: resuelta (D18).
- I8: Estado ADR: README usa `Propuesta/Aceptada`; plantilla usa `propuesto/aceptado`;
  el usuario pide `aprobado`.
  - Respuesta: `Aceptada`.
  - Estado: resuelta (D15).
- I11 (developer-scriban): El template `developer.md` no tiene anexo Scriban.
  - Respuesta: no añadir anexo Scriban a `docs/templates/deliverables/developer.md`.
  - Contexto: es plantilla de informe, usada por `developer-scriban.md` (línea 16).
  - Estado: resuelta (D16).
- I12 (developer-scriban): `Dependencias` dice que ADR-0026 NO está escrito, pero
  `docs/adr/0026-vertical-slice-backend.md` existe.
  - Pregunta: ¿actualizo `Dependencias` a "escrito" y reviso el ADR?
  - Recomendación: sí, confirmar y actualizar `Dependencias`.
  - Respuesta: Actualizado en obj-004.md Dependencias.
  - Estado: resuelta (2026-10-08).
- I13 (developer-scriban): `permissions: []` como agentes hermanos; la escritura en
  `docs/adr/` fue rechazada antes (permission.rejected).
  - Pregunta: ¿se concede permiso de edición sobre `generator/**/*.scriban`?
  - Recomendación: conceder permiso explícito de edición solo sobre templates Scriban.
  - Respuesta: conceder edición sobre `generator/**/*.scriban`.
  - Estado: resuelta (D20).
- I14 (developer-scriban): La ruta `.opencode/agents/templates` de AGENTS no existe.
  - Uso `docs/templates/agent.md`, única plantilla de agente encontrada.
  - Recomendación: corregir la ruta TEMPLATES/AGENTS en `AGENTS.md` o confirmar.
  - Respuesta: el usuario ya corrigió `AGENTS.md` (AGENTS: `.opencode/agents`).
  - Estado: resuelta (D21).

## Dudas developer-scriban (2026-10-08, bloquean la migración de plantillas)

- I15 (developer-scriban): ¿Handler sustituye a Service + UseCase?
  - Contexto: hoy Controller -> ServicePort -> IService/Service -> UseCase -> Port -> Adapter.
  - ADR-0026: Controller -> Handler -> Command -> Port -> Adapter.
  - Pregunta: ¿se fusionan Service + UseCase en Handler y se eliminan ServicePort/IService?
  - Recomendación: sí; cambia la lógica Java generada, requiere confirmación.
  - Respuesta: sí, fusionar en Handler; se eliminan ServicePort e IService.
  - Estado: resuelta (D22).
- I16 (developer-scriban): Tests generados con imports que cambian de paquete.
  - Afectados en component.json: parameter-controller-test (`infrastructure.configuration`),
    hola-mundo-controller-test y application-context-test.
  - Regla: no crear ni modificar tests; `*-test.scriban` se mantienen (D2).
  - Pregunta: ¿se autoriza ajustar solo imports/paquetes en esos test.scriban?
  - Recomendación: sí, ajuste mínimo de imports; sin cambiar lógica ni asserts.
  - Respuesta: sí, solo imports y paquetes; sin cambiar lógica ni asserts.
  - Estado: resuelta (D23).
- I17 (developer-scriban): Segmentos de paquete con guion (`admin-user`, `hola-mundo`).
  - Java no admite guiones en paquetes.
  - Recomendación: paquetes `adminuser` y `holamundo`; clases `AdminUser*` y `HolaMundo*`.
  - Respuesta: paquetes `adminuser` y `holamundo`; clases `AdminUser*` y `HolaMundo*`.
  - Estado: resuelta (D24).
- I18 (developer-scriban): Lista de `{usecase}` por dominio no definida.
  - Recomendación: un usecase por grupo actual:
    - subscription: `subscription`, `webhook` (strategies y RevenueCat).
    - ai: `ai`. parameter: `parameter`.
    - test: `sqs`, `sns`, `holamundo`.
    - security: `auth`, `user`, `registration`, `password`, `adminuser`, `exchange`.
  - Respuesta: lista aprobada tal cual.
  - Estado: resuelta (D25).
- I19 (developer-scriban): Carpeta común de persistencia: `persistence` o `connections`.
  - ADR-0026 (Aceptada) dice `common/infrastructure/persistence`.
  - D14 (posterior) dice `common/infrastructure/connections`.
  - Recomendación: `connections` (D14 es posterior) y corregir ADR-0026.
  - Respuesta: `connections`; corregir ADR-0026 para que coincida.
  - Estado: resuelta (D26).
- I20 (developer-scriban): Ubicación de modelos, entidades, mappers y DTOs.
  - Afecta: `domain/model` (Subscription, AiGeneration, Token*, Exchange*),
    entidades, `*TableSchema`, `IMapper*`, `*MapperDto` y `WebhookEventDTO`.
  - Recomendación: modelos y DTO al slice; genéricos DynamoDB y `IProviderPersistence`
    en la carpeta común de I19.
  - Respuesta: modelos, entidades, mappers y DTOs al slice; genéricos DynamoDB e
    IProviderPersistence en common.
  - Estado: resuelta (D27).
- I21 (developer-scriban): Beans AWS (`SqsConfig`, `SnsConfig`, `CognitoClient`, `DynamoDBConfig`).
  - Recomendación: en common (beans/conexiones); `SqsReceiver` y `SnsEventPublisher` al slice
    `test`.
  - Respuesta: beans AWS en common; `SqsReceiver` y `SnsEventPublisher` al slice `test`.
  - Estado: resuelta (D28).
- I22 (developer-scriban): Base de la ruta relativa en `update-all.ps1.scriban` (D17).
  - La ruta `\target\...` no indica base.
  - Recomendación: `Join-Path $PSScriptRoot` con `..\..\..\generator\target\...`
    (desde `projects/{app}/backend/`); confirmar.
  - Respuesta: `Join-Path $PSScriptRoot` con `..\..\..\generator\target\...`
    (refina D17).
  - Estado: resuelta (D29).
- I23 (architect, 2026-10-08): Ubicación del puerto en ADR-0026 vs D9.
  - ADR-0026 (`Aceptada`) dice `{domain}.modules.{usecase}.application.port.I{Module}Port`.
  - D9 dice `{domain}.modules.{usecase}.domain.port.I{Module}Port`.
  - Pregunta: ¿cuál ubicación es la vigente? ¿Se corrige el ADR?
  - Recomendación: `domain.port` (D9 es posterior); corregir ADR-0026 tras confirmación.
  - Respuesta: `domain.port`, confirma D9 (D30).
  - Estado: resuelta (D30). ADR-0026 corregido.
- I24: persistence → connections aplicado en obj-004/*.md (2026-10-08).

## Dependencias

- developer-scriban desbloqueado: I15–I22 resueltas (D22–D29).
- I23 resuelta (D30): puertos en `domain.port`. Desbloquea templates de puertos.
- ADR-0026: puerto en `domain.port` aplicado (D30). `connections` ya estaba en el ADR (D26).

## Bloqueos developer-scriban (2026-10-08 18:28:48)

- I25 (developer-scriban): ¿Se autoriza editar `component.json`?
  - Contexto: el generador solo copia lo declarado en `files` y `directories`.
  - Contexto: migrar a slices exige cambiar casi todas las rutas de `files`.
  - Contexto: D20 autoriza solo `*.scriban`; el AGENTS del componente exige actualizarlo.
  - Recomendación: sí, solo claves `directories` y `files` del backend spring-boot-3.5.16.
- I26 (developer-scriban): ¿Qué valor toma `{Module}` en `{Module}Handler`, `{Module}Command`?
  - Contexto: hoy existen `AuthService/AuthUseCase`, `ExchangeUseCase`, etc.
  - Recomendación: `{Module}` = nombre actual del caso de uso (p. ej. `AuthHandler`).
  - Recomendación: `Command` = `{Module}Command` por operación; confirmar.
- I27 (developer-scriban): ¿Dónde van adaptadores y persistencia dentro de cada slice?
  - Contexto: ADR dice "adaptadores en su `infrastructure/`"; no define subpaquetes.
  - Contexto: D27 manda modelos, entidades, mappers y DTOs "al slice" sin subpaquete.
  - Recomendación: `{domain}.modules.{usecase}.infrastructure.adapters` y
    `infrastructure.persistence`; confirmar.
- I28 (developer-scriban): ¿`HexagonalArchitectureTest` (D1) se adapta en este objetivo?
  - Contexto: D2 dice que los cambios de tests van en el objetivo de implementación.
  - Contexto: la regla de tests de este rol solo permite imports en 3 tests.
  - Pregunta: ¿se adapta en obj-004 (reescritura) o en un objetivo de implementación?
  - Recomendación: objetivo de implementación aparte; aquí solo registrar la regla.
  - Estado: resuelta (D34): se adapta en obj-004.

- Estado I25–I28: resueltas (D31–D34).
- D35 (I29, 2026-10-08): MANTENER que `IUserPort` extienda `AuthPort`, `RegistrationPort`,
  `PasswordPort` y `AdminUserPort`. Decisión del usuario, distinta a la recomendación de I29.
- D36 (I30, 2026-10-08): MANTENER. `AuthHandler` depende de
  `{exchange}.domain.port.IExchangePort`.
- D37 (I31, 2026-10-08): SÍ. `RevenueCatWebhookFilter` en
  `subscription.modules.webhook.infrastructure.webfilters`.
- D38 (I32, 2026-10-08): SÍ. `SubscriptionEndpoint` y `WebhookEndpoint`, mismo path base
  `/api/v1/subscriptions`.
- D39 (I33, 2026-10-08): SÍ. Configuración de feature en
  `{domain}.modules.{usecase}.infrastructure.configuration`; `common` solo transversal.
- Estado I29–I33: resueltas (D35–D39).



## Bloqueos developer-scriban fase 2 (2026-10-08)

- I29 (developer-scriban): ¿IUserPort debe seguir extendiendo AuthPort, RegistrationPort,
  PasswordPort y AdminUserPort?
  - Contexto: UserAdapter implementa IUserPort y duplica lógica de Auth/Registration.
  - Contexto: en vertical slice, extender puertos de otros slices crea dependencias cruzadas.
  - Pregunta: ¿cada slice expone solo su puerto y UserHandler usa sus propios puertos?
  - Recomendación: sí; eliminar la herencia cruzada de IUserPort.
- I30 (developer-scriban): ¿AuthHandler delega el intercambio de código en el puerto de
  xchange?
  - Contexto: AuthService usa ExchangeServicePort; el endpoint /exchange está en Auth.
  - Pregunta: ¿AuthHandler depende de {exchange}.domain.port.IExchangePort?
  - Recomendación: sí; dependencia unidireccional auth → exchange, sin ciclo.
- I31 (developer-scriban): ¿RevenueCatWebhookFilter va en el slice webhook?
  - Contexto: el filtro valida la firma del endpoint /subscriptions/webhook.
  - Pregunta: ¿subscription.modules.webhook.infrastructure.webfilters?
  - Recomendación: sí; el filtro pertenece al caso de uso webhook.
- I32 (developer-scriban): ¿Dónde vive SubscriptionController y su endpoint?
  - Contexto: expone /webhook (webhook), /status y /sync (subscription).
  - Pregunta: ¿un controller por slice (SubscriptionController y WebhookController)?
  - Recomendación: sí; el mismo path base /api/v1/subscriptions, rutas separadas por slice.
  - Contexto: Subscription (modelo y puerto) lo usan subscription y webhook.
  - Recomendación: modelo y puerto en subscription.modules.subscription; webhook depende de él.
- I33 (developer-scriban): ¿Configuración específica de feature en el slice?
  - Contexto: AiProperties, AiConstants, AiMessages y ParameterProperties.
  - Pregunta: ¿van a {domain}.modules.{usecase}.infrastructure.configuration?
  - Recomendación: sí; common queda solo para configuración transversal (D14, ADR-0026).
- Estado: resueltas (D35–D39); migración de plantillas reanudada (2026-10-08).

## Bloqueo developer-scriban fase 3 (2026-10-08 18:42:01)

- I34 (developer-scriban): ¿Ejecutar la migración completa en una sola sesión o por fases?
  - Contexto: 108 plantillas Java; 252 líneas `import {{ PACKAGE }}...`; ~150 entradas en
    `component.json`; Handler reemplaza Service+UseCase (D22) en ~20 plantillas.
  - Contexto: sin compilación/generación verificada, un corte parcial deja imports rotos.
  - Recomendación: por fases, cada una verificable: F1 `component.json` + mover
    modelos/puertos/adaptadores/config/persistencia (sin lógica); F2 Handler por usecase
    (D22); F3 `HexagonalArchitectureTest` + imports de los 3 tests (D23, D34).
  - Verificación por fase: generar proyecto de muestra y buscar imports sin resolver.
  - Espera: autorización de fase F1 y confirmación de verificación (generación de muestra).

## Decisión fase 3 (2026-10-08 18:45:28)

- D40 (I34, 2026-10-08): migración completa en una sola fase, con compilación, ejecución
  y verificación de los archivos generados. Reemplaza la recomendación por fases.
  - Estado I34: resuelta (D40).
- D41 (I35): {Module}Command es un record por operación (p. ej. GenerateTokenCommand).
- D42 (I36): conservar ParameterController y HolaMundoController en el cuerpo de los tests.
- D43 (I37): Endpoint mapea DTO <-> Command/modelo; Handler no importa infrastructure.
- D44 (I38): muestra generada directamente en projects/<appId>, aceptando sobrescritura.
- D45 (I39): eliminar service-port, usecase e IService al migrar.
- D46 (I40): ExchangeUseCase se mantiene (no se elimina en este objetivo).
- D49 (2026-10-08): reemplazar el sufijo `Endpoint` por `Controller` en clases REST, porque
  - se usa la anotación `@RestController`.
  - Archivos actualizados: architect.md, developer-scriban.md, obj-004.md, questions.md.
  - Reemplaza el sufijo `Endpoint` de ADR-0026, D32, D38 (`SubscriptionEndpoint`,
    `WebhookEndpoint`) y D43.
  - D24 no cita `Endpoint` (solo paquetes y clases `AdminUser*`/`HolaMundo*`); se mantiene.
  - D42 queda coherente: `ParameterController` y `HolaMundoController`.
  - Nota: I42 cita "D49" con otro significado (eliminar plantillas); revisar esa referencia.

## Bloqueo developer-scriban fase 4 (2026-10-08 18:49:08)

- I35 (developer-scriban): ¿{Module}Command es un record por caso de uso o por operación?
  - Contexto: auth tiene 2 operaciones (token, exchange); user, registration, password y
    adminuser tienen varias. D32 dice {Module}Command por caso de uso.
  - Recomendación: un record por operación (p. ej. GenerateTokenCommand) en {usecase}.domain.
  - Respuesta: por operación (D41).
  - Estado: resuelta (D41).
- I36 (developer-scriban): ParameterController y HolaMundoController se referencian en el
  cuerpo de sus tests (new ParameterController(...), @InjectMocks).
  - Contexto: D23 solo permite cambiar imports y paquetes; D24/ADR piden {Module}Controller.
  - Recomendación: conservar esos dos nombres hasta autorizar cambio de nombre en el test.
  - Respuesta: conservar ambos nombres (D42).
  - Estado: resuelta (D42).
- I37 (developer-scriban): ¿Dónde se mapea RequestDto a Command y model a ResponseDto?
  - Contexto: hoy el Service recibe y devuelve DTO; ADR: Controller -> Handler -> Command.
  - Recomendación: Controller mapea DTO <-> Command/modelo; Handler no importa infrastructure.
  - Respuesta: Endpoint mapea DTO <-> Command/modelo; Handler no importa infrastructure (D43).
  - Estado: resuelta (D43).
- I38 (developer-scriban): ¿Generar la muestra en copia temporal fuera del workspace?
  - Contexto: el generador escribe en projects/<appId> y sobrescribe archivos existentes.
  - Contexto: projects/com.quizsmart.app es un proyecto ya generado (fuera de alcance).
  - Recomendación: copia temporal en %TEMP%\opencode, sin tocar projects/.
  - Respuesta: generar directamente en projects/<appId>, aceptando sobrescritura (D44).
  - Estado: resuelta (D44).
- I39 (developer-scriban): ¿Eliminar plantillas reemplazadas (service-port, usecase, IService)?
  - Contexto: no están en component.json; no se generan.
  - Recomendación: eliminarlas al migrar; git conserva el historial.
  - Respuesta: eliminarlas al migrar (D45).
  - Estado: resuelta (D45).
- I40 (developer-scriban): ¿ExchangeUseCase se elimina y AuthHandler usa IExchangePort?
  - Contexto: D36 fija la dependencia; el usecase de exchange solo delega en el puerto.
  - Recomendación: sí; eliminar ExchangeServicePort y ExchangeUseCase.
  - Respuesta: no; mantener ExchangeUseCase (D46).
  - Estado: resuelta (D46).

## Dependencias

- I35–I40 resueltas (D41–D46).
- Pendiente de la verificación de muestra: generar en projects/<appId> (D44).

## Registro developer-scriban (2026-10-08 19:00:23)

- I36 abierta (2026-10-08): pendiente de confirmación del usuario.
- D47 (2026-10-08): `appId` tomado de `target` (`com.quizsmart.app`). Decisión del usuario.
- I41 (developer-scriban): `security` no se genera con el target actual.
  - Contexto: templates `auth-*`, `user-*`, `registration-*`, `password-*`, `admin-user-*`
    y `exchange-*` usan `{{ if(Name == "security") }}`.
  - Contexto: `Name` = `quizapi` (nombre del microservicio); no coincide con `security`.
  - Contexto: el dominio security no se compila ni ejecuta en la verificación.
  - Recomendación: mantener el guard; validar security con un objetivo aparte.
  - Respuesta: sí, generar security en otro objetivo.
  - Estado: resuelta (D48).
- I42 (developer-scriban): Plantillas no listadas en `component.json` con nombres antiguos.
  - Contexto: `iauthservice`, `iservice`, `servicePort`, `usecase`, `dto`, `port`, `adapter`,
    `model`, `router`, `handler`, `mapperDto`, `mapperDynamo`, `mapperEntity`, `DynamoBean`,
    `adapter-test`, `controller-test`, `service-test`, `usecase-test`, `mapperPersistenceModel`.
  - Contexto: no se generan; contienen referencias a paquetes antiguos.
  - Respuesta: eliminar 15 plantillas (no-test); las 4 `*-test.scriban` se mantienen (D2).
  - Estado: resuelta (D57); ver I55 para los `*-test.scriban`.
- I43 (developer-scriban): ¿Un DTO por operación o `{Module}RequestDto` único?
  - Contexto: Auth tiene token y exchange; Subscription tiene status y sync.
  - Recomendación: un DTO por operación (`TokenRequestDto`, `ExchangeRequestDto`).
  - Estado: resuelta (D58).
- I44 (developer-scriban): ¿Puerto `I{Module}Port` en módulos sin adaptador (webhook, ai)?
  - Contexto: D6 exige `I{Module}Port`; webhook no tiene adaptador propio.
  - Recomendación: crear `I{Module}Port` y que el Handler lo implemente.
  - Estado: resuelta (D59).
- I45 (developer-scriban): ¿Continuar paso 2 (webhook y ai) en este objetivo?
  - Contexto: paso 1 y subscription listos; webhook y ai pendientes (security sale por D48).
  - Recomendación: sí, en este objetivo (D40, migración en una fase).
  - Estado: resuelta (D60).

## Registro developer-scriban D49 (2026-10-08 19:40:29)

- D49 aplicado: `*-endpoint.scriban` a `*-controller.scriban`; `SubscriptionController`
  y `WebhookController`. Compila; 10/10 tests OK.
- Pendientes abiertos (no implementados en esta orden):
  - I42: plantillas antiguas no listadas. Recomendación: eliminar las no-test; confirmar
    `adapter-test`, `controller-test`, `service-test`, `usecase-test` (contradice D2).
  - I43: un DTO por operación. Recomendación: sí (`TokenRequestDto`, `ExchangeRequestDto`).
  - I44: puerto `I{Module}Port` sin adaptador (webhook, ai). Recomendación: crearlo.
  - I45: paso 2 (webhook y ai) en este objetivo. Recomendación: sí.
  - I36: el registro marca cerrada; el usuario la pide abierta. ¿Confirmas estado?
  - D48: security fuera de este objetivo. ¿Lo dejo abierto en obj-004 o en otro objetivo?

- I46 (developer-scriban, 2026-10-08 19:44:26): ¿Se renombra prosa y nombres de función "Endpoint"?
  - Ejemplos: comentario en `ai-controller`, `Get-CodeArtifactEndpoint` (up.ps1), `tokenEndpoint`.
  - Recomendación: no renombrar; no son clases `{Module}Endpoint` y ampliaría alcance.
  - Estado: resuelta (D61).

## Registro developer-scriban D50 (2026-10-08 19:47:37)

- D50 (2026-10-08, usuario): "common" = `library\common`, NO
  `{{ PACKAGE }}.common.infrastructure` de quizapi. Corregir imports de configuración, beans y
  conexiones hacia el paquete de `library\common`.
- Verificación previa (solo lectura):
  - `library\common` existe: `C:\epc\general\library\common` (multi-módulo Maven).
  - Paquetes Java reales: `com.epc.common.error`, `com.epc.common.log`, `com.epc.common.web`.
  - No existe `configuration`, `beans` ni `connections` dentro de `library\common`.
  - `library\common\docs\como-usar.md` dice que `DomainLogMessages` vive en
    `infrastructure.configuration` del microservicio (generado por plantilla).
- Estado: bloqueado en I47. No se modificaron templates en esta orden.
- I47 (developer-scriban): ¿Qué paquete de `library\common` sustituye a
  `{{ PACKAGE }}.common.infrastructure.{configuration,beans,connections}`?
  - Contexto: `library\common` solo trae `com.epc.common.{error,log,web}`.
  - Contexto: `DomainLogMessages`, `MapperClass`, `MapperInfo`, `CognitoClient`, `DynamoDBConfig`,
    `SnsConfig`, `IMapperDynamo`, `IProviderPersistence` y genéricos DynamoDB no existen allí.
  - Contexto: `quizapi` ya importa `com.epc.common.*` (ApiResponse, ILogService, etc.).
  - Opción A (recomendada): mantener estas clases en `{{ PACKAGE }}.common.infrastructure`
    (D14, ADR-0026) y que `library\common` solo aporte `com.epc.common.*` (ya usado). Requiere
    confirmar que D50 sólo aplica a las clases de `library\common`.
  - Opción B: mover `configuration/beans/connections` a un nuevo módulo de `library\common`
    (`com.epc.common.infrastructure.*`). Amplía alcance (cambio en `library\common`, fuera de
    `generator`); requiere autorización explícita.
  - Estado: abierta. Pregunta al usuario antes de cambiar imports.

## Registro D51 (2026-10-08)

- D51 (2026-10-08, usuario): `dynamodb-generic-persistence` y `dynamo-table` son AWS y
  van a `common-aws`.
  - Efecto en architect.md (Inventario common): destino `common-aws`; AWS = sí.
  - I50 resuelta solo para estas dos clases; el resto de I50 queda abierto.
  - I48 sigue abierta: `common-aws` no tiene paquete definido.

## Registro D52–D54 (2026-10-08, usuario)

- D52 (2026-10-08, usuario): paquete `{{ PACKAGE }}.common.aws` para `CognitoClient`,
  `DynamoDBConfig`, `SnsConfig`, `SqsConfig`, `DynamoDbGenericPersistence` y `DynamoTable`.
  - Se elimina `.infrastructure` de los paquetes comunes.
  - Cierra I48 (paquete `common-aws`) y la duda de paquetes `common.config`/`.infrastructure`.
  - Cierra I50 (`DynamoDbGenericPersistence` y `DynamoTable`, junto con D51).
- D53 (2026-10-08, usuario): paquete `{{ PACKAGE }}.common.persistence` para `MapperClass`,
  `MapperInfo`, `IMapperDynamo`, `IMapperEntity` e `IProviderPersistence`.
  - Opción A. Reemplaza D26 solo para estas clases.
  - Cierra I50 (resto de clases).
- D54 (2026-10-08, usuario): paquete `{{ PACKAGE }}.common.config` para `CorsConfig` y
  `GraalHints`.
  - `DomainLogMessages` se divide por `module` y va al microservicio, no a `library\common`.
  - Cierra I51 (división de `DomainLogMessages`) y la duda de paquetes `common.config`.
  - Abre I53 (subpaquete de destino de cada parte de `DomainLogMessages`).
- Efecto en `architect.md` (Inventario common): destinos actualizados a D52–D54.
- Sin cambios en templates, `generator/`, `library/` ni tests.
- Pendiente (no tocado en esta orden): ADR-0026 y `architect.md` (Diseño, ADR) siguen con
  `common/infrastructure/{configuration,beans,connections}`. Requiere actualizar a D52–D54.
- I49 y I52 siguen abiertas.

## Dudas inventario common (architect, 2026-10-08)

- I48 (architect): ¿Qué es `common-aws`?
  - Contexto: D28 y ADR-0026 ubican beans AWS en `common.infrastructure.beans`.
  - Contexto: no existe paquete ni módulo `common-aws` en el repo.
  - Pregunta: ¿se crea un paquete `{{ PACKAGE }}.common.aws` o se mantiene `CI.beans`?
  - Recomendación: mantener `CI.beans`; `common-aws` solo como etiqueta lógica.
  - Estado: cerrada (D52): paquete `{{ PACKAGE }}.common.aws`.
- I49 (architect): ¿Las clases con guarda (`CognitoClient`, `CorsConfig`, `SqsConfig`) se generan
  en quizapi?
  - Contexto: guardas `Name == "security"` y `ConsumedEvents.size > 0`.
  - Contexto: no están en `projects/com.quizsmart.app/.../common/infrastructure`.
  - Pregunta: ¿se confirma que la guarda es correcta para quizapi?
  - Recomendación: sí; no cambiar la guarda en obj-004 (depende de I41/D48).
  - Estado: cerrada (D-I49, D64, D68).
- I50 (architect): ¿Se conservan o eliminan clases sin consumidores fuera de common?
  - Contexto: `DynamoDbGenericPersistence`, `DynamoTable`, `IMapperDynamo`, `IMapperEntity`,
    `IProviderPersistence`, `MapperClass` y `MapperInfo` solo se referencian entre sí.
  - Contexto: `adapter-test` importa `IProviderPersistence` por una ruta obsoleta (I42).
  - Pregunta: ¿eliminar (YAGNI) o conservar como base de persistencia futura?
  - Recomendación: conservar en `CI.connections` y `CI.configuration` sin mover; confirmar.
  - Actualización (D51): `DynamoDbGenericPersistence` y `DynamoTable` pasan a `common-aws`.
  - Actualización (D52): ambas pasan a `{{ PACKAGE }}.common.aws`.
  - Estado: cerrada. D52 (`common.aws`) y D53 (`common.persistence`).
- I51 (architect): ¿`DomainLogMessages` se divide por slice?
  - Contexto: mezcla mensajes de ai, subscription, webhook, test (sns/sqs) y security.
  - Contexto: tiene más de 10 consumidores; R11 pide centralizar mensajes.
  - Pregunta: ¿se mantiene centralizado en `CI.configuration` o se divide por slice?
  - Recomendación: mantener centralizado en `CI.configuration`; no dividir.
  - Respuesta (D54): se divide por `module` y va al microservicio, no a `library\common`.
  - Estado: cerrada (D54). Subpaquete de destino: ver I53.
- I52 (architect): ¿Qué hacer con plantillas de seguridad, JWT y persistencia sin registro?
  - Contexto: `security-config`, `security-context-repository`, `jwt-*`, `dynamo`,
    `dynamo-schema`, `persistence-model`, `repository`, `entity`, `datasource`,
    `path-constants` no están en `component.json`.
  - Contexto: ADR-0026 exige seguridad, CORS y JWT en `common/configuration`.
  - Pregunta: ¿se registran en `CI.configuration` (requiere seguridad, D48) o se eliminan?
  - Recomendación: no registrar en obj-004; decidir con I42 y D48.
  - Estado: resuelta (D62).
- I53 (architect, 2026-10-08): ¿Subpaquete de destino de `DomainLogMessages` por módulo?
  - Contexto: D54 la divide por `module` y la lleva al microservicio.
  - Contexto: D39 ubica la configuración de feature en
    `{domain}.modules.{usecase}.infrastructure.configuration`.
  - Pregunta: ¿cada parte va a `{domain}.modules.{usecase}.infrastructure.configuration`?
  - Recomendación: sí; aplica D39.
  - Estado: resuelta (D55).

## Dependencias

- D52–D54 registradas (2026-10-08). Cierran I48, I50 y I51.
- Pendiente: actualizar ADR-0026 y `architect.md` (Diseño y ADR) a `common.config`,
  `common.aws` y `common.persistence`.
- Pendiente: I53 para dividir `DomainLogMessages`.
- Abiertas: I36, I49 (CorsConfig), I54, I55, I56.

## Registro D55–D62 (2026-10-08, usuario)

- D55 (I53): cada parte de `DomainLogMessages` va a
  `{domain}.modules.{usecase}.infrastructure.configuration`. Cierra I53.
- D56 (D48): `security` queda fuera de obj-004.
- D57 (I42): eliminar plantillas con nombres antiguos. Cierra I42, salvo `*-test` (ver I55).
- D58 (I43): un DTO por operación (`TokenRequestDto`, `ExchangeRequestDto`). Cierra I43.
- D59 (I44): `I{Module}Port` en `webhook` y `ai`, implementado por el Handler. Cierra I44.
- D60 (I45): webhook y ai continúan en este objetivo. Cierra I45.
- D61 (I46): prosa y funciones `Endpoint` pasan a `Controller`. Cierra I46.
- D62 (I52): plantillas de seguridad, JWT y persistencia sin registro quedan fuera de obj-004.
  Cierra I52.
- D-I49 (I49, usuario): `CognitoClient` y `SqsConfig` van a `library/common/common-aws`
  (nuevo módulo, no en quizapi). `CorsConfig` no decidido; queda abierta en I49.
- I36: cerrada (D63).
- I54 (architect): ¿Destino de `DynamoDbGenericPersistence`, `DynamoTable`, `DynamoDBConfig` y
  `SnsConfig`?
  - Contexto: D51 dice `common-aws`; D52 dice `{{ PACKAGE }}.common.aws` (quizapi).
  - Contexto: D-I49 solo mueve `CognitoClient` y `SqsConfig` a library.
  - Recomendación: quedan en `{{ PACKAGE }}.common.aws` (quizapi), literal D52.
  - Estado: cerrada (D65).
- I55 (architect): ¿`adapter-test`, `controller-test`, `service-test` y `usecase-test` se eliminan?
  - Contexto: D57 elimina plantillas con nombres antiguos; D2 mantiene `*-test.scriban`.
  - Recomendación: mantenerlas (D2); eliminar solo las no-test.
  - Estado: cerrada (D66); ver I57.
- I56 (architect): ¿Paquete Java de `library/common/common-aws`?
  - Contexto: `CognitoClient` y `SqsConfig` salen de quizapi; D52 usa `{{ PACKAGE }}.common.aws`.
  - Contexto: `library/common` usa `com.epc.common.*`.
  - Recomendación: `com.epc.common.aws`, alineado con los paquetes existentes.
  - Estado: cerrada (D67).
- Efecto: ADR-0026 y `obj-004.md` (Dependencias) actualizados (2026-10-08).
- Sin cambios en templates, `generator/`, `library/` ni tests.

## Registro D63–D68 (2026-10-08, usuario)

- D63 (I36): `ParameterController` y `HolaMundoController` se mantienen. Sin cambios.
  - Cierra I36.
- D64 (I49): `CognitoClient` y `SqsConfig` van a `library/common/common-aws` (nuevo módulo).
  - Cierra la parte AWS de I49.
- D65 (I54): `DynamoDbGenericPersistence`, `DynamoTable`, `DynamoDBConfig` y `SnsConfig` van a
  `library/common/common-aws`.
  - Supera D52 para estas clases.
  - Cierra I54.
- D66 (I55): eliminar `adapter-test`, `controller-test`, `service-test` y `usecase-test`
  si no se usan.
  - Supera D2 solo para estas cuatro plantillas. Las demás `*-test.scriban` se mantienen.
  - Cierra I55. Ver I57 (criterio "no se usan").
- D67 (I56): paquete `com.epc.common.aws` para `library/common/common-aws`.
  - Cierra I56.
- D68: `CorsConfig` y `GraalHints` van a `library/common/common-config`, paquete
  `com.epc.common.config` (I58, opción A, confirmada por el usuario, 2026-10-08). Supera D54.
  - Cierra I49 (`CorsConfig`) y D68.

## Incógnitas nuevas (2026-10-08)

- I57 (architect): ¿Qué significa "si no se usan" en D66?
  - Contexto: D66 condiciona la eliminación de cuatro `*-test.scriban`.
  - Contexto: I42 indica que no están en `component.json` y no se generan.
  - Contexto: D2 y D57 las tratan como tests; la regla de tests impide tocarlas sin autorización.
  - Recomendación: "no usadas" = no listadas en `component.json` ni referenciadas por otra
    plantilla.
  - Estado: abierta.

## Estado I36, I49, I54, I55, I56

- Cerradas: I36 (D63), I49 (D64, D68), I54 (D65), I55 (D66), I56 (D67).
- Abierta: I57.

## Dependencias

- D63–D68 registradas (2026-10-08). Cierran I36, I49, I54, I55 e I56.
- I58 cerrada (opción A): `CorsConfig` y `GraalHints` en `library/common/common-config`
  (paquete `com.epc.common.config`). Cierra D68.
- Nuevo módulo `library/common/common-config`: implementación fuera de este objetivo.
- ADR-0026 y `obj-004.md` (Dependencias) actualizados a D63–D68.
- Paquetes AWS (D64, D65, D67): `com.epc.common.aws` en `library/common/common-aws`.
  - Requiere nuevo módulo Maven y dependencias AWS SDK en `library/common`;
    implementación fuera de este objetivo.
- Pendiente: `docs/deliverables/obj-004/architect.md` (Inventario common) a D63–D68.
- Pendiente: I57 para eliminar las cuatro `*-test.scriban` (D66).

## Registro 2026-10-08 (confirmaciones y pendiente)

- D65 confirmado: `DynamoDbGenericPersistence`, `DynamoTable`, `DynamoDBConfig` y
  `SnsConfig` van a `library/common/common-aws`.
- D67 confirmado: paquete `com.epc.common.aws`.
- I57 confirmada: "no usada" = no listada en `component.json` ni referenciada por otra
  plantilla.
  - Eliminar `adapter-test`, `controller-test`, `service-test` y `usecase-test` si cumplen
    esa condición (D66).
- D68 CERRADA (2026-10-08): `CorsConfig` y `GraalHints` en `library/common/common-config`,
  paquete `com.epc.common.config`. Ver I58 (opción A confirmada por el usuario).

## Incógnitas nuevas (2026-10-08)

- I58 (architect): ¿Destino de `CorsConfig` y `GraalHints`?
  - Contexto: D68 y D54 indican `{{ PACKAGE }}.common.config` (microservicio).
  - Contexto: el usuario indica `library/common/common-config` con `{{ PACKAGE }}.common.config`.
  - Contexto: `library/common` usa `com.epc.common.*` (D67).
  - Opción A: `library/common/common-config`, paquete `com.epc.common.config`.
  - Opción B: `{{ PACKAGE }}.common.config` en el microservicio (D54).
  - Recomendación: A, alineado con D67.
  - Respuesta: opción A confirmada por el usuario (2026-10-08). `library/common/common-config`,
    paquete `com.epc.common.config`; cierra D68.
  - Estado: cerrada (D68).


## Bloqueos developer-scriban paso 2 y library (2026-10-08 21:53:21)

- I59 (developer-scriban): ¿Cómo se resuelve la dependencia de DynamoDbGenericPersistence?
  - Contexto: D65 la lleva a `library/common/common-aws`.
  - Contexto: usa `MapperClass`, `IProviderPersistence` e `IMapperDynamo`, que D53 deja en la app.
  - Contexto: una librería no puede importar `{{ PACKAGE }}`.
  - Opción A: mover también esas 5 clases a `com.epc.common.*` (supera D53 para ellas).
  - Opción B: dejar `DynamoDbGenericPersistence` en `{{ PACKAGE }}.common.persistence` (supera D65).
  - Recomendación: A; son genéricas y no usan tipos de la app.
  - Estado: abierta. Sin cambios en esta orden.
- I60 (developer-scriban): CorsConfig (D68) usa `DomainLogMessages` de la app.
  - Opción A: constantes de log locales en la clase de librería.
  - Opción B: `CorsConfig` queda en la app hasta decidir D55.
  - Recomendación: A.
  - Estado: abierta. Sin cambios en esta orden.
- I61 (developer-scriban): CognitoClient (D64) usa modelos de `security` y `DomainLogMessages`.
  - Opción A: mantener en la app con el guard `security` hasta el objetivo de security (D48).
  - Opción B: refactor a tipos genéricos dentro de la librería.
  - Recomendación: A; no amplía alcance.
  - Estado: abierta. Sin cambios en esta orden.
- I62 (developer-scriban): ¿Versión de los módulos nuevos `common-aws` y `common-config`?
  - Contexto: `library/common/docs/como-versionar.md` fija una versión única (1.1.5).
  - Contexto: el generador (`pom.scriban`) importa `common-bom` 1.1.5 desde `~/.m2`.
  - Opción A: subir a 1.1.6 en parent, módulos, BOM y `pom.scriban`.
  - Opción B: mantener 1.1.5 y reinstalar local; sobrescribe el artefacto (no reversible).
  - Recomendación: A. Publicar sigue fuera de alcance (sin CodeArtifact ni deploy).
  - Estado: abierta. Módulos library no creados en esta orden.
- I63 (developer-scriban): ¿Nombre de clase de cada parte de `DomainLogMessages` (D55)?
  - Contexto: 127 líneas; 31 plantillas la usan.
  - Pregunta: ¿`{Module}LogMessages` en `{domain}.modules.{usecase}.infrastructure.configuration`?
  - Recomendación: sí (p. ej. `WebhookLogMessages`, `AiLogMessages`).
  - Estado: abierta. Sin cambios en esta orden.
- I64 (developer-scriban): ¿Confirmas los nombres de Command y puerto de webhook y ai?
  - Aplicado: `ProcessWebhookCommand(WebhookEventDto event)`,
    en `subscription.modules.webhook.domain`.
  - Aplicado: `GenerateAiCommand(String prompt)` en `ai.modules.ai.domain`.
  - Aplicado: puertos `IWebhookPort` e `IAiPort`; Handlers `WebhookHandler` y `AiHandler`.
  - Recomendación: confirmar; sigue `{Operation}{Module}Command` de subscription.
  - Estado: aplicada; pendiente de confirmación.
- I65 (developer-scriban): ¿Renombrar constantes `*_ENDPOINT` de DomainLogMessages?
  - Ejemplos: `SUBSCRIPTION_STATUS_ENDPOINT`, `SNS_PUBLISH_ENDPOINT`.
  - Contexto: D61 cubre prosa y funciones, no constantes.
  - Recomendación: no renombrar; cambiaría nombres sin decisión explícita.
  - Estado: abierta.

## Dependencias developer-scriban (2026-10-08 21:53:21)

- Aplicado: D53 (`common.persistence`), D59, D60, D22, D41, D43, D58 en webhook y ai.
- Aplicado: I57 (eliminar `adapter-test`, `controller-test`, `service-test`, `usecase-test`).
- Bloqueado: módulos `library/common/common-aws` y `common-config` (I59–I62).
- Bloqueado: D55 `DomainLogMessages` por módulo (I63).
- Pendiente: confirmar I64 e I65.

## Registro D69–D75 (2026-10-08, usuario)

- D69 (I59): módulo nuevo `library/common/common-persistence`, paquete `com.epc.common.persistence`.
  - Clases: `MapperClass`, `MapperInfo`, `IMapperDynamo`, `IMapperEntity`,
    `IProviderPersistence`, `DynamoDbGenericPersistence`.
  - Supera D53 y D65 para estas clases. Cierra I59.
- D70 (I61): `CognitoClient` va en `security` (no en `common-aws`).
  - Supera D64 para esta clase. Mantiene guard `security` (D48). Cierra I61.
- D71 (I62): versión `1.1.6` en parent, módulos, BOM y `pom.scriban`. Cierra I62.
- D72 (I60): `CorsConfig` usa constantes de log locales en la clase de librería
  (`library/common/common-config`). Cierra I60.
- D73 (I63): `{Module}LogMessages` por slice en
  `{domain}.modules.{usecase}.infrastructure.configuration`. Cierra I63.
- D74 (I64): confirmados `ProcessWebhookCommand`, `GenerateAiCommand`, `IWebhookPort`,
  `IAiPort`, `WebhookHandler`, `AiHandler`. Cierra I64.
- D75 (I65): constantes `*_ENDPOINT` de `DomainLogMessages` pasan a `*_CONTROLLER`.
  Cierra I65.

## Incógnitas nuevas (2026-10-08, architect)

- I66 (architect): ¿`MapperInfo` va en `common-persistence`?
  - Contexto: D69 no la lista; la instrucción de registro sí.
  - Recomendación: sí; va con `MapperClass` (D53).
  - Estado: cerrada (D76).
- I67 (architect): ¿Paquete exacto de `CognitoClient` dentro de `security`?
  - Contexto: D70 indica solo `security`; no define subpaquete.
  - Recomendación: slice `auth` (`...modules.auth.infrastructure.configuration`, D39); confirmar.
  - Estado: cerrada (D77). Adaptador en `auth.infrastructure.adapters` (D77).
- I68 (architect): ¿`common-persistence` depende de `common-aws` o directamente del SDK DynamoDB?
  - Contexto: `DynamoDbGenericPersistence` usa DynamoDB; `DynamoTable` queda en `common-aws`.
  - Recomendación: depender solo del SDK DynamoDB; confirmar.
  - Estado: cerrada (D78).

## Dependencias

- D69–D75 registradas (2026-10-08). Cierran I59–I65.
- Pendiente: crear `common-persistence`; ajustar `common-aws` y `common-config` (D69–D71).
- Pendiente: I66–I68.
- ADR-0026 y `obj-004.md` (Dependencias) actualizados a D69–D75.

## Registro D76–D78 (2026-10-08 22:23:21, usuario)

- D76 (I66): `MapperInfo` va en `library/common/common-persistence`.
  - Cierra I66.
- D77 (I67): `CognitoClient` se renombra a `CognitoAdapter` y va en
  `{{ PACKAGE }}.security.modules.auth.infrastructure.adapters` (adaptador, D27/D33).
  - Cierra I67. Supera D70 solo en nombre y subpaquete.
- D78 (I68): `common-persistence` depende de `common-aws` (reutiliza `DynamoTable` y
  `DynamoDBConfig`).
  - Cierra I68.

## Dependencias

- D76–D78 registradas (2026-10-08). Cierran I66–I68.
- Aplicar D1–D78 en templates y `component.json`; sin cambios en `generator/**/*.cs`.

## Dudas developer-scriban (2026-10-08 22:31:00)

- I69 (developer-scriban): ¿Dónde migran las constantes de seguridad de `DomainLogMessages`?
  - Contexto: `domain-log-messages.scriban` queda sin registrar con USER_*, PASSWORD_*, JWT.
  - Contexto: `admin-user-adapter`, `password-adapter` y `registration-adapter` (guard security)
    siguen usando `DomainLogMessages`.
  - Recomendación: migrar a `{Module}LogMessages` en el objetivo de security (D48, D62).
  - Estado: cerrada (D79).
- I70 (developer-scriban): ¿`USER_CONFIRMED` y `USER_CONFIRM_FAILED` van en `AuthLogMessages`?
  - Contexto: los usa `CognitoAdapter` (auth, D77) y `registration-adapter` (registration).
  - Recomendación: sí, en `AuthLogMessages`, por ser del adaptador auth.
  - Estado: cerrada (D80).
- I71 (developer-scriban): ¿Los beans de library se registran con `@Import` en `Application`?
  - Aplicado: `@Import` (DynamoDBConfig, SnsConfig, MapperClass; SqsConfig y CorsConfig con guard).
  - Contexto: no hay escaneo de `com.epc.common`; la app solo escanea su paquete.
  - Recomendación: mantener `@Import`; el escaneo registraría beans no pedidos.
  - Estado: cerrada (D81).
- I72 (developer-scriban): ¿Se instala `1.1.6` en `~/.m2` para compilar `quizapi`?
  - Aplicado: `mvn install` local (sin deploy) de parent, BOM, log, error, web, aws, config y
    persistence.
  - Contexto: `quizapi` resuelve `common-bom` desde `~/.m2`; 1.1.5 no se sobrescribe.
  - Recomendación: aceptar; publicar en CodeArtifact queda fuera de alcance.
  - Estado: cerrada (D82).
- I73 (developer-scriban): ¿Qué hacer con "Endpoint" en nombres técnicos (D61 literal)?
  - Ejemplos: `Get-CodeArtifactEndpoint` (up.ps1), `tokenEndpoint` (cognito), `_logCallingEndpoint`.
  - Recomendación: no renombrar; no son clases REST y D61 habla de clases y prosa.
  - Estado: cerrada (D83).
- I74 (architect): ADR-0026 y docs de library sin D76–D78.
  - Contexto: ADR-0026 cita `CognitoClient` (D70) y no lista `MapperInfo` ni `CognitoAdapter`.
  - Contexto: `library/common/docs/como-usar.md` y `README.md` no listan los módulos nuevos.
  - Recomendación: architect actualiza ADR-0026; docs de library, en objetivo library.
  - Estado: cerrada (D84).

## Dependencias developer-scriban (2026-10-08 22:31:00)

- Aplicado: D69–D78 en `library/common` (common-aws, common-config, common-persistence) y templates.
- Pendiente: I69–I74.
- Pendiente de security (D48): constantes y adaptadores con `DomainLogMessages` y guard `security`.

## Registro D79–D84 (2026-10-08, usuario)

- D79 (I69): constantes de seguridad de `DomainLogMessages` pasan a `{Module}LogMessages` en el
  objetivo security (D48). Cierra I69.
- D80 (I70): `USER_CONFIRMED` y `USER_CONFIRM_FAILED` van en `AuthLogMessages`. Cierra I70.
- D81 (I71): beans de library se registran con `@Import` en `Application`; sin escaneo de
  `com.epc.common`. Razón: evitar cargar beans no pedidos. Cierra I71.
- D82 (I72): autorizado `mvn install` local (sin deploy, sin publicar). Cierra I72.
- D83 (I73): no renombrar "Endpoint" en nombres técnicos; solo clases y prosa (D61). Cierra I73.
- D84 (I74): architect actualiza ADR-0026. Docs de library (`como-usar.md`, `README.md`) con
  módulos nuevos quedan en el objetivo library; architect no edita `library/` en esta orden.
  Cierra I74.
- Estado: I69–I74 cerradas. Sin cambios en templates, `generator/`, `library/` ni tests.

## Registro D85 (2026-10-08 22:48:38, usuario)

- D85 (supera D81): Application.java solo tiene @SpringBootApplication y main().
  - Los beans de configuración se centralizan en ApplicationConfig.java con @Configuration.
  - Sin beans duplicados; escaneo automático de Spring Boot cuando baste.
  - Respetar la arquitectura existente.
- Verificación previa (solo lectura):
  - common-aws, common-config y common-persistence usan com.epc.common.*.
  - Sus beans no están en el paquete de la app: el escaneo no basta; se usa @Import.
  - common-log y common-web se cargan por AutoConfiguration.imports; no se importan.
- Aplicación: @Import en ApplicationConfig, no en Application.

### Dudas developer-scriban (D85, 2026-10-08 22:48:38)

- I75 (developer-scriban): ¿Dónde va ApplicationConfig.java?
  - Contexto: ADR-0026 dice configuración transversal en common.
  - Contexto: D85 no fija paquete; @SpringBootApplication escanea el paquete raíz.
  - Opción A (aplicada): paquete raíz {{ PACKAGE }}, junto a Application.
  - Opción B: {{ PACKAGE }}.common.configuration.
  - Recomendación: A; mínimo cambio y sin paquete nuevo. Confirmar.
  - Respuesta: opción A confirmada por el usuario (2026-10-08).
  - Estado: cerrada (D86).

## Registro D86 (I75, 2026-10-08, usuario)

- D86 (I75): `ApplicationConfig.java` va en el paquete raíz `{{ PACKAGE }}`, junto a
  `Application`. Opción A confirmada. Supera la ubicación `common` de ADR-0026.
  - Cierra I75.
- Efecto: ADR-0026 actualizado (ubicación de `ApplicationConfig` en raíz, no en `common`).
- Sin cambios en templates, `generator/`, `library/` ni tests.
- Pendiente: `developer-scriban.md` (líneas 346, 368, 385) sigue citando I75 abierta.

## Dependencias

- D86 registrada (2026-10-08). Cierra I75.
- ADR-0026 actualizado con la ubicación de `ApplicationConfig` (raíz).
- Sin dependencias nuevas abiertas por I75.

## Bloqueo developer-scriban arranque local (2026-10-08 23:07:37)

- I76 (developer-scriban): `mvn spring-boot:run` falla al arrancar sin perfil `cloud`.
  - Error: `Failed to bind 'ai.max-tokens'`; valor literal `"${AI_MAX_TOKENS}"` sin resolver.
  - Causa: `application.properties` (perfil por defecto) exige `AI_*` y `ai-api-key`.
  - Contexto: esos valores vienen de Parameter Store/Secrets Manager solo en perfil `cloud`
    (ADR-0012, `SPRING_PROFILES_ACTIVE=cloud` en la Lambda).
  - Contexto: `ai-api-key` no existe en `target`; el secreto lo siembra el usuario en AWS.
  - Opción A (recomendada): arrancar con `-Dspring-boot.run.profiles=cloud`. Sin cambio en
    plantillas. Requiere credenciales AWS locales y lectura SSM/Secrets (acción AWS: autorizar).
  - Opción B: nuevo perfil `local` (plantilla + `component.json` + ADR-0012) con valores de
    `target` y `ai-api-key` ficticia. Requiere tu valor de `ai-api-key` o aceptar placeholder,
    y relajar el fail-fast de `application.properties` (cambio de criterio, D-decisión).
  - Recomendación: A para arrancar ahora; B solo si necesitas arranque local sin AWS.
  - Estado: abierta. Sin cambios en templates ni `component.json`.

## Dependencias

- I76 abierta: bloquea el arranque local de `quizapi`. Requiere decisión A o B.

## Registro D87 (2026-10-09, usuario)

- D87: estructura de paquetes por feature `{domain}.modules.{usecase}` pasa a
  `{domain}.{usecase}`. Se elimina el nivel `modules`.
  - Supera la estructura por feature de obj-004 en todas las referencias de paquete.
- Efecto: ADR-0026 actualizado (rutas y ejemplos); mantiene estado `Aceptada`.
- Efecto: `obj-004.md` (requisitos y dependencias) actualizado.
- Efecto: `improvements.md` I77 (validar niveles de paquete antes de aprobar ADR).
- Sin cambios en templates, `generator/`, `library/` ni tests.
- Pendiente: referencias `modules` en `architect.md`, `developer-scriban.md`,
  `developer-powershell.md`, `use-cases.md` y en secciones D9–D86 de este archivo.
  - Recomendación: actualizar en el siguiente paso antes de implementar.

## Dependencias

- D87 registrada (2026-10-09).
- Implementación de templates (`developer-scriban`) y scripts (`developer-powershell`) usa
  `{domain}.{usecase}.<capa>` tras D87.


## Bloqueo developer-scriban D87 (2026-10-09 04:54:56)

- I78 (developer-scriban): ¿Se autoriza borrar salida previa con paquete `modules`?
  - Contexto: D87 aplicado en templates y `component.json`; grep de `modules` sin restos Java.
  - Contexto: `dotnet run` regenera pero no borra.
  - Contexto: quedan 55 archivos en `*/modules/` (no versionados).
  - Contexto: `mvn test` en `projects/com.quizsmart.app/backend/quizapi`: 14 tests, 3 errores.
  - Contexto: `ConflictingBeanDefinitionException` `aiHandler` (`ai.modules.ai` vs `ai.ai`).
  - Contexto: copia temporal sin esos directorios: 10/10 OK; tests no modificados.
  - Pregunta: ¿borrar solo `src/**/modules` de `projects/com.quizsmart.app/backend/quizapi`?
  - Recomendación: sí; borrado acotado a esos directorios, sin tocar otros.
  - Estado: abierta. No se borró nada.
- I79 (developer-scriban): ¿Se autoriza arranque con perfil `cloud` (I76 opción A)?
  - Contexto: el perfil lee SSM y Secrets Manager; es acción AWS fuera de mis permisos.
  - Pregunta: ¿autorizas arranque `-Dspring-boot.run.profiles=cloud` con credenciales de lectura?
  - Recomendación: sí, solo tras resolver I78; sin escritura en AWS.
  - Estado: abierta. No ejecutado.

## Dependencias developer-scriban (2026-10-09 04:54:56)

- Aplicado: D87 en `templates` (backend) y `component.json` (backend).
- Bloqueado: tests en `projects/` por I78; arranque cloud por I79.
## Cierre I78 (developer-scriban, 2026-10-09 05:25:09 UTC-5)

- I78 CERRADA. Autorizada por usuario: borrar src/**/modules de quizapi.
- Verificación previa (05:23:23): 0 directorios modules y 0 archivos bajo src/ con modules.
- Borrado: no ejecutado; no había archivos que borrar. Los 55 citados ya no existían.
- Regeneración dotnet run --project generator\Generator.csproj (05:24:12): OK=1, sin errores.
- Post-regeneración: 0 modules en src/; el generador no recrea esos archivos.
- Tests mvn -B clean test (05:24:56): 10/10, 0 fallos, 0 errores, BUILD SUCCESS.
- Pendiente: I79 (arranque cloud), sin ejecutar. Sin commit, push, deploy ni AWS.
- Duda: origen de la discrepancia de 55 archivos (¿borrados antes por otro proceso?).
  - Recomendación: no bloquea; confirmar si se quiere trazabilidad en improvements.md.
