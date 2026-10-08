# Revisión

- Objetivo: `obj-003 Logs estructurados en common`
- Agente: `Reviewer`
- Estado: `parcial`
- Resumen: El hallazgo alto previo queda corregido en código estático; masking runtime pendiente.
- Bloqueos: No se pudo obtener `git status` ni `git diff`; diffs no confirmados.
- Alcance/artefactos revisados: Tareas 2/3 en `library/common/` y plantillas Spring Boot.
  No se revisaron tests ni `projects/` generado.
- Criterios: `architect.md`, ADR-0025, respuesta aprobatoria de los 23 campos sensibles,
  interfaz, autoconfiguración, dependencias, JSON, migración, documentación y manifiesto.

## Hallazgos
| Severidad | Evidencia | Observado/esperado | Criterio | Recomendación | Hecho/inferencia |
|---|---|---|---|---|---|
| alta | `library/common/common-log/src/main/java/com/epc/common/log/Slf4jLogService.java:33-35, 48-50, 87-95`; `logback-base.xml:29-54` | Los `Map` se concatenan dentro de `message` como texto plano. El decorator enmascara paths JSON, no el contenido textual de `message`; claves/valores sensibles así registrados no quedan estructuralmente enmascarados. Se esperaba protección central para datos sensibles independientemente del overload utilizado. | ADR-0025, masking centralizado; campos sensibles aprobados en `questions.md:118-119`. | No serializar campos confidenciales como texto sin tratamiento. Revisar contrato/implementación para emitir campos JSON enmascarables o excluir/mascarar explícitamente los mapas antes de loguearlos; validar runtime antes de aprobar. | Hecho: el método concatena pares al mensaje; paths están configurados. Inferencia: un secreto en el texto no lo alcanza el path decorator. |
| informativa | `library/common/common-log/src/main/resources/logback-base.xml:16-25`; `generator/components/backend/spring-boot-3.5.16/templates/logback.scriban:16-25` | Se configura la salida `timestamp`, `level`, `message`, `logger`, `thread` y `stack_trace`; MDC activado. No se verificó la serialización real con encoder 8.1 ni Lambda. | ADR-0025 exige `timestamp` RFC 3339 para indexación Lambda; decisión de renombrar confirmada en `questions.md:112-114`. | Mantener pendiente prueba runtime de RFC 3339, `level` y masking; no inferir eficacia desde XML estático. | Hecho: configuración estática renombra el campo. No comprobado: formato y comportamiento del encoder en runtime. |

## Revisado sin defectos y límites
- Sin defectos identificados: los 23 nombres sensibles aprobados coinciden en el XML común y
  la plantilla; `timestamp` está configurado en ambos. El contrato `ILogService`, bean
  condicional/imports, `common-log` y versión `common-bom` 1.1.0 se inspeccionaron parcialmente.
- Límites/bloqueos: No se pudo ejecutar `git status`/`git diff` con las herramientas disponibles;
  por tanto no se certifica el alcance efectivo del diff ni su exclusión de tests/`projects/`.
  No se validaron resolución CodeArtifact, JSON/logback en ejecución, hints nativos o despliegue.
  La afirmación de builds satisfactorios solo consta en `developer.md`, no fue reproducida.

## Veredicto
- `requiere cambios`

## Seguimiento del hallazgo alto
- Alcance: solo el hallazgo de `Map` concatenados al mensaje; no se revisaron tests ni
  `projects/`. Sin ejecución, publicación, regeneración ni despliegue.
- Criterios: aprobación de SLF4J fluent key-value en `questions.md:123-125`, masking central en
  ADR-0025/arquitectura y versión SLF4J documentada por developer.
- Evidencia: `library/common/common-log/src/main/java/com/epc/common/log/Slf4jLogService.java:29-31`
  llama `logWithFields(logger.atDebug(), message, fields)`; `:44-46` hace lo mismo para `info`.
  El helper en `:83-89` agrega cada entrada con `fields.forEach(event::addKeyValue)` y termina
  con `event.log(message)`: no concatena claves/valores al mensaje.
- Evidencia: `library/common/common-log/src/main/resources/logback-base.xml:29-55` configura
  `MaskingJsonGeneratorDecorator`, máscara `***` y los 23 paths aprobados (`:32-54`). La plantilla
  fuente `generator/components/backend/spring-boot-3.5.16/templates/logback.scriban:30-32` incluye
  el mismo decorator y el primer path.
- Compatibilidad declarada: `developer.md:54-65` registra aprobación del API fluent, SLF4J API
  `2.0.16` según `effective-pom` y compilación común satisfactoria. Esto es evidencia reportada
  por developer, no verificación reproducida en este seguimiento.
- Hecho: la emisión estática conserva el mensaje y genera key-values con nombres de campo que
  corresponden a los paths configurados. No comprobado: que Logstash encoder materialice dichos
  key-values y que el decorator los enmascare en salida real.
- Recomendación: validar en runtime un evento con claves sensibles y no sensibles antes de declarar
  cerrado el masking.
- No se añade pregunta nueva: la autorización técnica y los campos sensibles constan en
  `questions.md:118-125`.
- Veredicto de seguimiento: `aprobado con observaciones`; el defecto de concatenación no se reproduce
  en el código actual, pero no se declara cierre completo del criterio de masking.

## Revisión estática final: configuración Logback

- Fecha: `2026-10-07`.
- Alcance: revisión de los dos últimos cambios de configuración en el generator y el recurso
  común; sin ejecución de build, generator, tests, empaquetado nuevo ni runtime.
- Criterios: respuesta de `questions.md:126-128`, plantilla/manifiesto, fragmento de common y
  diseño/criterios de ADR-0025. ADR-0025 permanece con estado `propuesto`.

### Hallazgos

- Sin defectos estáticos identificados en el alcance revisado.
- Evidencia: `component.json:76` declara `templates/logback.scriban` para producir
  `src/main/resources/logback.xml`.
- Evidencia: `logback.scriban:1-4` tiene únicamente la declaración XML y
  `<configuration><include resource="logback-base.xml" /></configuration>`.
- Evidencia: `common-log/src/main/resources/logback-base.xml:12` usa raíz `<included>` y
  contiene la configuración base de encoder, esquema y masking descrita por ADR-0025.
- Evidencia: `application-properties.scriban:33-35` configura el nivel AWS SDK, pero no fija
  `logging.config`; búsqueda estática del término en el componente no halló coincidencias.
- Paquetado: el recurso está bajo `src/main/resources`, convención de recurso Maven; además,
  `developer.md:81-82` reporta `jar tf` con `logback-base.xml` dentro de
  `common-log-1.1.0.jar`. No se repitió ni verificó ese comando en esta revisión.
- Hecho: las fuentes revisadas cumplen el formato mínimo de include y evitan redirigir
  `logging.config` a `logback-base.xml`. No se afirma que Logback resuelva el include al arrancar.

### Revisado sin defecto y límites

- Manifiesto registra la salida generada; el XML de microservicio delega en el recurso común;
  el recurso común es un fragmento `<included>`.
- ADR-0025 propone Logback, encoder JSON, nombres de campo y masking; no se evaluó su validez
  operacional ni se considera aprobada la ADR por esta revisión.
- No se probó contenido del JAR independientemente, resolución de dependencia, formato JSON,
  enmascarado, inicialización de Logback, regeneración ni salida runtime.

### Veredicto

- Configuración estática: `aprobado con observaciones`.
- Observación: runtime pendiente explícito; comprobar que Spring/Logback descubre `logback.xml`,
  incluye el recurso del JAR y emite JSON con masking antes de cerrar OBJ-003.
