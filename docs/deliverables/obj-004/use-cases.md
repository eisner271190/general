# Casos de prueba obj-004

- Fecha: `2026-10-08`
- Objetivo: `obj-004`

## Casos de prueba

- TC-01 `update-all.ps1` (2026-10-08): desde `projects/{app}/backend/`, `$ConfigPath`
  resuelve a `generator/target/{app}/{app}.json`; `Test-Path` devuelve `True`.
  - Resultado: OK (verificado por resolución de ruta; no se ejecutó el script).
- TC-02 `update-all.ps1` (2026-10-08): no queda ruta absoluta `C:\` en la plantilla generada.
  - Resultado: OK (0 coincidencias en `projects/com.quizsmart.app/backend/update-all.ps1`).
- TC-03 Compilación del backend generado (2026-10-08): `mvn -q -B compile` en `quizapi`.
  - Resultado: OK (exit 0; 0 errores; imports resueltos).
- TC-04 Tests del backend generado (2026-10-08): `mvn -B test` en `quizapi`, sin modificar tests.
  - Resultado: OK (10 tests, 0 fallos; baseline 10/10).
- TC-05 Sin SOAP (2026-10-08): buscar `soap|wsdl|WebService` en templates del componente y en la
  salida generada.
  - Resultado: OK (0 coincidencias).
- TC-06 Placeholders sin resolver (2026-10-08): buscar `{{` en la salida generada.
  - Resultado: OK (0 coincidencias; solo `{{baseUrl}}` de Postman, que no es Scriban).
- TC-07 Imports sin resolver (2026-10-08): la compilación falla si hay import roto.
  - Resultado: OK (compilación exit 0).
- TC-08 Generador sin cambios de código (2026-10-08): `git status` en `generator` sin `.cs`.
  - Resultado: OK (0 archivos `.cs` modificados).
- TC-09 Ciclos entre slices (2026-10-08): `HexagonalArchitectureTest.noCircularDependencies`
  sobre `{{ PACKAGE }}.(*).(*)..` (D87; antes `{{ PACKAGE }}.(*).modules.(*)..`).
  - Resultado: OK (3/3 tests de la clase).
- TC-10 Tests D23 (2026-10-08): solo cambian `package` e imports en `parameter-controller-test`
  y `hola-mundo-controller-test`; `application-context-test` sin cambios.
  - Resultado: OK (comparación con respaldo).
- TC-11 Pendiente: pitest `excludedClasses` con `**` (no ejecutado).
  - Resultado: pendiente.
- TC-12 Pendiente: generar y verificar `security` en otro objetivo (D48).
  - Resultado: pendiente.

- TC-13 Webhook y AI: Handler, Command y puerto
  - Resultado: OK (exit 0). Sin service-port ni usecase antiguos.
- TC-14 Persistencia D53 en `common.persistence`
  - Resultado: OK (compilación exit 0; 0 referencias a `connections.IMapper*`).
- TC-15 I57
  - Resultado: OK (no existían en `component.json`; 0 referencias en otras plantillas).
- TC-16 Tests del backend generado
  - Resultado: OK (10 tests, 0 fallos, BUILD SUCCESS).
- TC-17 Módulos `common-aws` y `common-config`
  - Resultado: pendiente (bloqueado por I59–I62).
- TC-18 Sin SOAP ni `{{` en salida (2026-10-08 21:53:31): búsqueda sobre `src`.
  - Resultado: OK (0 coincidencias).
- TC-19 Módulos library (2026-10-08 22:31): `mvn -B -DskipTests install` de common-parent, BOM,
  log, error, web, common-aws, common-config y common-persistence (local, sin deploy).
  - Resultado: OK (exit 0). Versión 1.1.6.
- TC-20 Compilación de `quizapi` generado (2026-10-08 22:31): `mvn -B clean test`.
  - Resultado: OK (exit 0; imports de com.epc.common.aws/config/persistence resueltos).
- TC-21 Tests de `quizapi` sin cambios (2026-10-08 22:31): 10/10.
  - Resultado: OK (HexagonalArchitectureTest 3/3, ApplicationContextTest 3/3,
    ParameterControllerTest 3/3, HolaMundoControllerTest 1/1). Avisos JaCoCo (SSM), no fallos.
- TC-22 Arranque con beans de library (2026-10-08 22:31): `ApplicationContextTest`.
  - Resultado: OK (3/3; `Application` importa DynamoDBConfig, SnsConfig, MapperClass).
- TC-23 `*_ENDPOINT` y `Endpoint` como clase en salida (2026-10-08 22:31): búsqueda en `src`.
  - Resultado: OK (0 coincidencias de `Endpoint|ENDPOINT` sensible a mayúsculas en `src`).
- TC-24 Referencias a `DomainLogMessages` o `common.infrastructure` en salida (2026-10-08 22:31).
  - Resultado: OK (0 coincidencias).
- TC-25 Pendiente: generar `security` y verificar `CognitoAdapter` (D48, D77; fuera de obj-004).
  - Resultado: pendiente.
- TC-26 Application mínima y configuración en ApplicationConfig (D85, 2026-10-08 22:55).
  - Resultado: OK. `Application` sin `@Import`; `ApplicationConfig` con `@Configuration`
    e `@Import` (DynamoDBConfig, SnsConfig, MapperClass; SqsConfig sin consumidos).
- TC-27 Beans duplicados (D85): búsqueda de `@Bean|@Component|@Service|@Import` en `src`.
  - Resultado: OK. Sin `@Bean` en la app; sin duplicados de tipo.
- TC-28 Compilación y tests tras D85 (sin modificar tests): `mvn -B compile` y `mvn -B test`.
  - Resultado: OK. 10/10; contexto arranca (`ApplicationContextTest` 3/3).
