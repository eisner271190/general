# ADR-0026: Backend generado en vertical slice por feature

- Estado: `Aceptada` (confirmado por el usuario)
- Fecha: `2026-10-08`
- Objetivo: `obj-004`
- Informe de arquitectura: `docs/deliverables/obj-004/architect.md`
- Origen: `obj-004` (migrar de hexagonal horizontal a vertical slice)

## Contexto y requisitos

- El `generator` produce hoy hexagonal horizontal: `application/`, `domain/`, `infrastructure/`
  por tipo de clase.
- Se requiere organizar el backend por feature (vertical slice).
- `generator` sigue siendo la única fuente de verdad; solo cambian plantillas y `component.json`.
- Sin SOAP si el microservicio no lo usa; sin migrar proyectos ya generados.
- Coste: 0 USD/mes.

## Decisión

### Estructura por feature

- `{{ PACKAGE }}.{domain}.{usecase}.domain`: `{Module}Command` (record por operación,
  D41; p. ej. `GenerateTokenCommand`).
- `{{ PACKAGE }}.{domain}.{usecase}.application`: `{Module}Handler`.
- `{{ PACKAGE }}.{domain}.{usecase}.domain.port`: `I{Module}Port` (siempre, D6, D9, D30).
  - En `webhook` y `ai`, `I{Module}Port` lo implementa el Handler (D59).
- `{{ PACKAGE }}.{domain}.{usecase}.infrastructure.rest`:
  - `{Module}Controller`: mapea DTO <-> Command/modelo (D43).
  - Un DTO por operación: `{Operation}RequestDto`, `{Operation}ResponseDto` (D58;
    p. ej. `TokenRequestDto`, `ExchangeRequestDto`).
- `{{ PACKAGE }}.{domain}.{usecase}.infrastructure.configuration`:
  configuración de feature (D39) y `{Module}LogMessages` por slice (D55, D73).
- `{{ PACKAGE }}.{domain}.{usecase}.infrastructure.adapters` y `.persistence` (D33).
- `{{ PACKAGE }}.{domain}.{usecase}.infrastructure.webfilters` (D37).
- Naming: paquetes en minúscula; clases en PascalCase; sufijo `Dto` (no `DTO`).

### Dominios y usecases

- `subscription`:
  - `subscription`: Subscription (modelo y puerto).
  - `webhook`: strategies, RevenueCat, `RevenueCatWebhookFilter` (D37).
- `ai`: `ai`.
- `parameter`: `parameter`.
- `security`: auth, user, registration, password, adminuser, exchange.
  - `CognitoAdapter` (D77; antes `CognitoClient`) va en
    `security.auth.infrastructure.adapters`, con guard `security` (D70, D48).
  - Fuera de obj-004 (D48, D56).
- `test`: sqs, sns, holamundo.
- `quiz`: no se crea (no existen plantillas propias).

### Common (`{{ PACKAGE }}.common`)

- Sin `.infrastructure` en paquetes comunes (D52).
- Lo agnóstico al feature; configuración por feature no va aquí (D39).
- `ApplicationConfig` va en el paquete raíz `{{ PACKAGE }}`, junto a `Application` (D86, I75).
  - Contiene los beans `@Configuration`; `Application` solo tiene `@SpringBootApplication`
    y `main()` (D85).
  - No va en `common`: el escaneo de `@SpringBootApplication` parte del paquete raíz.
- `library/common/common-config` (nuevo módulo, D68, I58), paquete `com.epc.common.config`:
  `CorsConfig` (constantes de log locales, D72), `GraalHints`.
- `library/common/common-persistence` (nuevo módulo, D69), paquete `com.epc.common.persistence`:
  `MapperClass`, `MapperInfo`, `IMapperDynamo`, `IMapperEntity`, `IProviderPersistence`,
  `DynamoDbGenericPersistence`. Supera D53 y D65 para estas clases.
  - Depende de `common-aws` (D78). `MapperInfo` incluida (D76).
- Módulo `library/common/common-aws` (nuevo, D64, D65), paquete `com.epc.common.aws` (D67):
  - `SqsConfig` (D64).
  - `DynamoDBConfig`, `DynamoTable`, `SnsConfig` (D65).
  - `CognitoAdapter` no va aquí (D70, D77).
  - Supera D52 (ubicación y paquete) para estas clases.
- Versión de módulos library: `1.1.6` (D71).
- `SqsReceiver` y `SnsEventPublisher` van al slice `test` (D28).
- Modelos, entidades, mappers y DTOs van al slice (D27).

### Flujo

- Controller -> Handler -> Command -> puerto (`domain.port`) -> adaptador (`common` o slice).

### Tests

- `HexagonalArchitectureTest` se adapta a reglas de slice (sin ciclos entre slices; D1, D34).
- `adapter-test`, `controller-test`, `service-test` y `usecase-test`: se eliminan si no se
  usan (D66).
  - Criterio "no usada" (I57, confirmada): no listada en `component.json` ni referenciada
    por otra plantilla.
- Las demás `*-test.scriban` se mantienen (D2).
- Sus cambios se ejecutan en `obj-004` (D34), solo con imports y paquetes (D23).

### Otros

- `update-all.ps1.scriban`: se corrige en el mismo objetivo con placeholder y
  `Join-Path $PSScriptRoot` con `..\..\..\generator\target\...` (D17, D29).
- Implementación: `developer-scriban`.

### Decisiones 2026-10-08 (D76–D84)

- D76: `MapperInfo` va en `common-persistence`.
- D77: `CognitoClient` se renombra a `CognitoAdapter` en
  `{{ PACKAGE }}.security.auth.infrastructure.adapters`.
- D78: `common-persistence` depende de `common-aws`.
- D79: constantes de seguridad de `DomainLogMessages` pasan a `{Module}LogMessages` en
  security (D48).
- D80: `USER_CONFIRMED` y `USER_CONFIRM_FAILED` van en `AuthLogMessages`.
- D81: beans de library se registran con `@Import` en `Application`; sin escaneo de
  `com.epc.common`. Razón: evitar cargar beans no pedidos.
- D82: `mvn install` local autorizado; sin deploy ni publicación.
- D83: "Endpoint" no se renombra en nombres técnicos; solo clases y prosa (D61).
- D84: ADR actualizado por architect; docs de `library/` quedan en el objetivo library.
- D86 (I75): `ApplicationConfig` en paquete raíz `{{ PACKAGE }}`, no en `common`.

### Decisiones 2026-10-09 (D87)

- D87: la estructura de paquetes por feature pasa de `{domain}.modules.{usecase}` a
  `{domain}.{usecase}`. Se elimina el nivel `modules`. Supera la estructura por feature de
  este ADR en todas sus referencias de paquete.

## Motivos

- Cambios localizados por feature: un caso de uso agrupa su contrato, lógica y adaptador REST.
- `common` concentra lo agnóstico al feature: conexiones, beans e infraestructura reusable.
- Puertos siempre presentes: contrato uniforme para todos los slices (D6).
- Dominios y nombres confirmados por el usuario (D1–D84 en `questions.md`).

## Alternativas

- Hexagonal horizontal (actual): descartada; obliga a tocar varias carpetas por feature.
- Puertos solo con más de una implementación: descartada por decisión del usuario (D6).
- Eliminar `HexagonalArchitectureTest`: descartada; se adapta (D1).
- Slice vacío `quiz`: descartada; sin plantillas (D7).
- Módulos Maven por feature: descartada; sin requisito y con más coste de build.
- Migrar proyectos ya generados: fuera de alcance.

## Consecuencias y trade-offs

- Beneficios: cambios acotados por feature; estructura uniforme; reglas de ciclos entre slices.
- Costes: más puertos de un solo uso; regla ArchUnit nueva por adaptar.
- Riesgos:
  - Divergencia entre plantillas horizontales y verticales durante la migración.
    Mitigación: un solo ADR y revisión conjunta de plantillas.
  - Extracción de dominios que rompa proyectos existentes. Mitigación: no tocar proyectos
    ya generados.
  - Reglas ArchUnit hexagonales que no cubren la nueva estructura. Mitigación: adaptarlas (D1).
  - Seguridad, JWT y persistencia sin registro fuera de obj-004 (D62). Mitigación: objetivo
    aparte.

## Evidencia y aprobación

- Fuentes:
  - `docs/deliverables/obj-004/obj-004.md`
  - `docs/deliverables/obj-004/questions.md` (D1–D86, I1–I75)
  - `docs/deliverables/obj-004/architect.md` (sección ADR)
  - `docs/adr/0025-logs-json-con-logstash-logback-encoder.md` (formato de referencia)
- Revisión: `pendiente` (Reviewer).
- Decisión del usuario: `aprobada` (2026-10-08).
- Incógnitas: I66–I74 cerradas (`questions.md`).
  - Cerradas: I36 (D63), I49 (D64, D68), I54 (D65), I55 (D66),
    I56 (D67), I57 (confirmada), I58 (opción A, D68).
  - Cerradas (2026-10-08): I59 (D69), I60 (D72), I61 (D70), I62 (D71), I63 (D73),
    I64 (D74), I65 (D75).
  - Confirmadas por usuario (2026-10-08): D65, D67, I57, I58.
  - Cerradas (2026-10-08): I69 (D79), I70 (D80), I71 (D81), I72 (D82), I73 (D83), I74 (D84).
  - Cerrada (2026-10-08): I75 (D86).

### Coste

0 USD/mes.
