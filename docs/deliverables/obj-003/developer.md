# Implementación

- Objetivo: `obj-003 Logs estructurados en common`
- Agente/especialidad: `Developer / Java`
- Estado: `parcial`
- Resumen: Overloads Map ahora emiten key-values SLF4J; common recompila offline.
- Bloqueos: resolución remota de encoder y validación runtime pendientes.
- Alcance y ADR aprobados: Tareas 2 y 3 autorizadas; diseño architect.md y ADR-0025;
  usuario aprobó los campos sensibles en questions.md.

## Cambios
| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `library/common` | Puerto, implementación SLF4J, autoconfiguración, mensajes, JSON, migración web y versionado 1.1.0 | Logging común definido en Tarea 2 |
| `generator/components/backend/spring-boot-3.5.16` | Migración de plantillas, mensajes por servicio, dependencia/runtime hints y retirada Log4j2 | Fuente de verdad para Tarea 3 |
| `logback-base.xml` y `logback.scriban` | Campo temporal `timestamp` en lugar de `@timestamp` | Alinear campo Lambda con ADR-0025 |
| `questions.md` | Añadida duda de resolución de encoder | Verificación externa queda pendiente |

## Decisiones y desviaciones
- Al reintentar, los cambios de producto ya estaban en el árbol de trabajo; no se descartaron.
- No se regeneró `projects/`, no se publicaron artefactos ni se realizaron acciones externas.
- No se modificaron archivos de pruebas.

## Verificaciones y resultados
- `mvn -o -DskipTests clean install` en `library/common`: BUILD SUCCESS; 7 módulos.
- Maven avisó `unknown enum constant ... JsonInclude.Include.NON_NULL` al compilar `common-web`.
- `dotnet build` en `generator`: 0 errores y 0 advertencias.
- `git diff --check`: sin errores de whitespace.
- Búsqueda de `rg` no disponible en PATH; la comprobación amplia quedó pendiente.

## Defectos, limitaciones y riesgos
- Encoder 8.1 administrado en BOM, pero no se verificó descarga/resolución del repositorio remoto.
- No se validaron JSON, enmascarado ni configuración logback en ejecución.
- La compilación Maven se hizo offline y no ejecutó pruebas.
- El árbol de trabajo ya contenía cambios ajenos a este subagente; se dejaron intactos.

## Anexo técnico condicional
- Java: JDK 17.0.12; Maven 3.9.9; compilación satisfactoria con `-o` y `-DskipTests`.
- Framework: Spring Boot; `common-log` declara `spring-boot-starter` como `provided/optional`.
- Logging: SLF4J + Logback; encoder Logstash 8.1 gestionado por `common-bom`.
- Configuración: `ILogService` auto-configurado; JSON usa `timestamp`, `level` y MDC.
- Packaging: jars Maven de `common-log`, `common-web`, módulos comunes y samples.
- Generador: .NET SDK 10.0.401; `dotnet build` satisfactorio.

## Traspaso
- Reviewer/Tester: pendiente; comprobar dependencia en CodeArtifact, salida JSON y masking.

## Archivos creados/modificados
- `docs/deliverables/obj-003/developer.md`
- `docs/deliverables/obj-003/questions.md`
- `library/common/` (cambios de Tarea 2 ya presentes al reintentar)
- `generator/components/backend/spring-boot-3.5.16/` (cambios de Tarea 3 ya presentes al reintentar)

## Continuación: hallazgo alto del reviewer
- Estado: `implementado`; usuario aprobó SLF4J fluent key-value.
- Cambios: `debug/info(String, Map)` usan `atDebug()/atInfo()` y agregan cada entrada como
  key-value, manteniendo intacto el texto del mensaje. Los valores quedan en campos JSON
  independientes para masking por path.
- Verificación de API: `mvn -o -pl common-log help:effective-pom` confirmó `slf4j-api:2.0.16`,
  gestionado por Spring Boot 3.4.0.
- Verificación de compilación: `mvn -o -DskipTests install` en `library/common`: BUILD SUCCESS,
  7 módulos. Maven mantiene advertencia de `JsonInclude.Include.NON_NULL` en `common-web`.
- Límites respetados: sin tests, sin `projects/`, sin commit ni despliegue.
- Anexo técnico: JDK 17, Maven, Spring Boot 3.4.0; SLF4J API 2.0.16; Logstash encoder 8.1
  gestionado en `common-bom`; packaging jar.
- Pendiente de verificación runtime: confirmar JSON emitido y masking de key-values con encoder.

## Continuación: incluir configuración base Logback

- Fecha: `2026-10-07`.
- Estado: `implementado`; elección confirmada por el usuario.
- `component.json` ahora registra `templates/logback.scriban` hacia
  `src/main/resources/logback.xml`.
- La plantilla produce `<configuration><include resource="logback-base.xml"/></configuration>`.
- `common-log/src/main/resources/logback-base.xml` usa raíz `<included>` para que sea un
  fragmento includible. Se deja en `src/main/resources`, empaquetado en el jar Maven; sin
  moverlo ni duplicarlo.
- `dotnet build` en `generator/`: aprobado, 2 proyectos, 0 errores y 0 advertencias.
- `mvn -o -DskipTests install` en `library/common`: `BUILD SUCCESS`, 7 módulos; permanece
  advertencia de `JsonInclude.Include.NON_NULL` en `common-web`.
- Verificación de manifiesto y parseo XML de la plantilla: aprobados. `jar tf` confirmó
  `logback-base.xml` en `common-log-1.1.0.jar`.
- `git diff --check`: sin errores.
- No se regeneró `projects/`, no se ejecutaron tests, publicación, despliegue ni AWS.
- No se declara validado JSON ni masking en runtime.
- Riesgo/limitación: no se ejecutó Logback en runtime; inclusión y masking efectivos quedan
  pendientes de verificación runtime.
- Anexo técnico: JDK 17, Maven, módulos common como jars y generador .NET; no se añaden
  dependencias ni se cambian framework o packaging.
- Archivos: `generator/.../component.json`, `generator/.../templates/logback.scriban`,
  `library/common/common-log/src/main/resources/logback-base.xml`, este informe y
  `questions.md`.

## Corrección: selección de configuración Logback

- Fecha: `2026-10-07`.
- Alcance autorizado: corregir `application.properties` generado para no desviar la búsqueda
  estándar de `logback.xml` hacia `logback-base.xml`.
- Cambio mínimo: eliminada de `application-properties.scriban` la propiedad
  `logging.config=classpath:logback-base.xml`; se conserva el `<include>` del `logback.xml`.
- Verificación: `dotnet build` en `generator/` aprobado: 2 proyectos, 0 errores y 0 advertencias.
- Inspección: grep confirma que la plantilla ya no contiene `logging.config`; `tester.md` recoge
  el hallazgo previo sobre ausencia/configuración de `logback.xml` y salida JSON no verificable.
- Límites: no se regeneró `projects/`, no se tocaron tests ni `tester.md`; sin AWS, publish,
  commit o despliegue.
- Anexo Java: no cambian JDK, Spring Boot, Maven, dependencias, configuración Java ni packaging;
  el cambio afecta solo a la propiedad de configuración generada.
