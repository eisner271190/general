# Implementación

- Objetivo: `OBJ-004: Migrar backend generado de hexagonal horizontal a vertical slice`
- Agente/especialidad: `Developer / PowerShell`
- Estado: `bloqueado`
- Resumen: `Análisis completado (solo lectura). Sin cambios en templates ni en código del generador.`
- Bloqueos: `ADR de vertical slice (architect) no aprobado; templates no se modifican hasta aprobación.`
- Alcance y ADR aprobados: `obj-004.md (Dependencias); ADR pendiente (architect).`

## Cambios
| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `docs/deliverables/obj-004/developer-powershell.md` | Creado: este informe | Obligatorio por AGENTS.md |
| `docs/deliverables/obj-004/questions.md` | Preguntas añadidas | Fuente única de dudas |

Ningún archivo de `generator/` fue modificado.

## Análisis

### Fuente de la estructura hexagonal
- La estructura horizontal NO está en código `.cs`; está en
  `generator/components/backend/spring-boot-3.5.16/component.json`.
- `directories` (≈55 entradas) y `files` (≈150 entradas) declaran rutas con
  `{{APPLICATION_PACKAGE}}` (`domain/`, `application/`, `infrastructure/`).
- `Configuration/GeneratorConstants.cs` solo define la variable `APPLICATION_PACKAGE`.
- Búsqueda en `*.cs` de `infrastructure|domain/|application/|usecase|controllers|rest`:
  sin rutas hexagonales hardcodeadas. Solo comentarios y namespaces propios del generador.

### Templates que producen hexagonal horizontal (agrupados por capa)
- Dominio (`domain/model`, `domain/ports`, `domain/servicePorts`, `domain/usecase`):
  - Auth/Registration/Password/AdminUser/User: `auth-*`, `registration-*`, `password-*`,
    `admin-user-*`, `user-*`, `iuserport`, `iuserserviceport`.
  - Exchange: `exchange-usecase`, `exchange-port`, `exchange-service-port`.
  - Subscription/Webhook: `subscription-*`, `webhook-*`, `*-strategy`, `isubscription-*`,
    `iwebhook-service-port`.
  - AI: `ai-usecase`, `ai-generation`, `ia-provider-port`, `iai-service-port`.
  - Parameter: no tiene dominio propio en `domain/`; solo controller y properties.
- Aplicación (`application/services`, `application/dto`, `application/mappers`):
  - `*Service`, `I*Service`, `*RequestDTO`, `*MapperDto` de auth, registration, password,
    admin-user, user, change/confirm/force/recover-password, register-user, token/exchange.
- Infraestructura (`infrastructure/controllers`, `adapters`, `persistence`, `rest`):
  - Controllers: `*-controller`, `controller`, `hola-mundo-controller`, `sns-controller`,
    `sqs-controller`, `ai-controller`, `subscription-controller`.
  - Adapters: `*-adapter`, `revenuecat-*`, `openrouter-*`, `exchange-adapter`.
  - Persistence: `entity`, `subscription-entity`, `webhook-event-entity`, `*-table-schema`,
    `dynamo*`, `imapper*`, `mapper*`, `persistence-model`.

### Código agnóstico candidato a common
- Conexiones y clientes AWS: `cognito-client`, `dynamodb-config`, `sns-config`, `sqs-config`,
  `sns-event-publisher`, `sqs-receiver`.
- Persistencia genérica: `dynamodb-generic-persistence`, `dynamo-table`, `iproviderpersistence`,
  `mapper-class`, `mapper-info`, `dynamo-schema`, `DynamoBean`.
- Configuración transversal: `cors-config`, `domain-log-messages`, `graalvm-hints`,
  `graalvm-runtime-hints`, `application-*.scriban`, `logback`, `pom`, `Dockerfile`, `bootstrap`,
  `Application.java`, `LambdaHandler`, `security-config`, `jwt-*`, `security-context-repository`.
- Ambiguos (decisión pendiente): `revenuecat-webhook-filter` (webfilter de subscription o common).

### Archivos a cambiar al migrar (si ADR aprueba)
- `component.json` (spring-boot): reescribir rutas `directories` y `files`; el número de
  entradas cambia, pero la lista sigue siendo la única fuente.
- Cada template con `package {{ PACKAGE }}.infrastructure...` o `.domain...`: cambiar
  declaración `package` e `import` a `{{ PACKAGE }}.{domain}.modules.{usecase}.<capa>`.
- Templates de common: cambiar a `{{ PACKAGE }}.common...`.
- `hexagonal-architecture-test.scriban`: codifica reglas hexagonales; NO modificar sin
  autorización (regla: no crear ni modificar tests).
- `postman-collection.scriban`: sin cambio de contrato de endpoints (solo rutas de paquete).
- Templates `*-test.scriban` (controller, service, adapter, application-context): NO tocar.

### Restricciones de generador
- Sin cambios en `.cs`: el generador resuelve componentes y copia lo declarado en `files`.
- Requisito "sin SOAP si no se usa": grep `soap|wsdl` sin resultados en spring-boot; OK.
- Condicionales por microservicio (`Name == "security"`, `Name == "quizapi"`) ya existen y
  se conservan; no requieren cambio de generador.

## Decisiones y desviaciones
- Modo análisis: no se editó ningún template ni `component.json`.
- Dominio Quiz: no existe plantilla dedicada; solo condicional `quizapi` en `postman`/tests.

## Verificaciones y resultados
- Lectura de AGENTS.md (raíz, generator, backend, spring-boot), obj-004.md, questions.md.
- Carga de skill `clean-code`.
- Grep en `generator/**/*.cs` y `spring-boot-3.5.16/templates`: resultados en esta sección.
- No se ejecutó build ni generación (no pedido en modo análisis).

## Defectos, limitaciones y riesgos
- `update-all.ps1.scriban` línea 29 contiene ruta absoluta
  `C:\epc\general\generator\target\...`; viola "No hardcodees rutas". Fuera de alcance;
  requiere decisión.
- Templates `*-test.scriban` y `hexagonal-architecture-test.scriban` generan tests de
  arquitectura hexagonal; quedan incompatibles con vertical slice.
- Plantilla `DynamoBean.scriban` y otras no están todas registradas en `files`; no verificado
  cuáles son huérfanas.
- No leí `Domain/Validation` ni `PlanExecutor` completos; afirmación de "sin cambios en .cs"
  se basa en grep y en `AGENTS.md`.

## Anexo técnico condicional
- PowerShell: versión 5.1/7 no verificada; sin scripts ejecutados.
- Efectos secundarios: ninguno (solo lectura y escritura de este informe y questions.md).
- Errores/logging: no aplica en este análisis.

## Traspaso
- Reviewer/Tester: `pendiente` tras aprobación del ADR (architect).

## Archivos creados/modificados
- `docs/deliverables/obj-004/developer-powershell.md`
- `docs/deliverables/obj-004/questions.md`
