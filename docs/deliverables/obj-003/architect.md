# Informe de arquitectura — obj-003

## Estado, alcance y método
- Análisis arquitectónico; ninguna decisión ni implementación está aprobada.
- Referencia del objetivo: `.opencode/docs/ideas.txt`, obj-003, líneas 61-71.
- Se leyeron completos `explorer.md`, `researcher.md`, `orchestrator.md` y las fuentes
  locales que esos informes citan, incluyendo README, guías common, POM y AGENTS.
- Se respondió individualmente a las 50 preguntas de Explorer (1-50) y Researcher
  (1-50); las preguntas son idénticas y comparten respuestas más abajo.
- Reviewer no pudo iniciarse: límite de profundidad de subagentes. La revisión requerida
  permanece pendiente; este informe no se presenta como diseño revisado.
- No se encontró template arquitectónico en el workspace. No se crea ADR: no hay decisión
  arquitectónica aprobada que registrar.

## Hechos sustentados
- La idea pide logging estructurado, INFO al inicio de cada método sin excepción, DEBUG
  de parámetros y variables sin excepción, enmascaramiento, interfaz, inyección, uso por
  todos los MS y clase de textos; limita cambios a common y generator y excluye código
  generado (`ideas.txt:61-71`).
- Hay conflicto no resuelto entre «todos los MS» y el límite «solo common y generator»;
  las frases no bastan para inferir alcance funcional (Explorer 10-20; Researcher 72-80).
- `common-log` es Java, usa SLF4J y expone `MdcCorrelation` estático para `requestId`;
  su POM declara `slf4j-api`, sin Spring directo (`README.md:6-16`, POM y clase fuente).
- `common-web` está separado; la guía documenta correlación WebFlux y uso de
  `MdcCorrelation` sin web (`como-usar.md:5-16,51-62`).
- Hay configuración de `StructuredLogEncoder`, pero no prueba que consumidores la carguen
  ni valida un contrato de salida (Explorer/Researcher).
- La documentación indica API congelada / versión 1.0.0, mientras common-log hereda
  parent 1.0.1. No se verificó release efectivo, BOM ni consumidores (README:32-35;
  `como-usar.md:64-67`; POM:7-10).
- La guía de migración describe BOM y automatización en ciertos POM, no un inventario
  completo ni cobertura de todos los microservicios (`como-migrar-un-ms.md:131-146`).
- Generator es .NET 9/Scriban y fuente de verdad; sus instrucciones excluyen artefactos
  generados y requieren declarar plantillas mediante `component.json` (Explorer; generator
  AGENTS:3,17-37). El logger observado es propio/consola, distinto de SLF4J.
- OWASP recomienda excluir, enmascarar o sanear datos sensibles y neutralizar entradas
  no confiables; es guía general, no define datos ni reglas locales (Researcher:51-71).
- No se encontró inventario vigente, interfaz inyectable, política local de máscara,
  esquema estructurado acordado ni evidencia de salida serializada.

## Recomendaciones arquitectónicas — no aprobadas
- Mantener desacoplados `common-log` y `common-web`; evaluar contrato Java aparte del
  logger .NET de generator, sin asumir interoperabilidad ni compartir implementación.
- No elegir firmas, DI, esquema, máscara, propagación, encoder o política de niveles antes
  de decisiones explícitas. No tratar OWASP como requisito aprobado.
- Preservar la exigencia literal INFO/DEBUG en el registro de requisitos. La compatibilidad
  segura, cobertura y costo necesitan definición del usuario; no se rebaja el requisito.
- No declarar adopción transversal hasta recibir alcance, inventario, propietarios y
  criterio de evidencia. Excluir siempre los artefactos generados como fuente de cambio;
  aclarar si se regeneran consumidores.
- Verificar versión efectiva en BOM, historial/release, repositorio de artefactos y
  consumidores antes de decidir compatibilidad.

## Matriz requisito → decisión → evidencia → verificación
| Requisito | Decisión / estado | Evidencia | Verificación posterior |
|---|---|---|---|
| Estructura, interfaz, inyección, mensajes | Sin contrato aprobado | Objetivo; common-log actual solo MDC/SLF4J | Revisar contrato y muestras una vez decidido |
| Enmascaramiento | Política sin definir; OWASP es recomendación | No hay mecanismo local; OWASP citado por Researcher | Casos aprobados, incluidos anidados/fallo y ausencia de secretos |
| INFO/DEBUG por método | Requisito literal, semántica y aplicación bloqueadas | `ideas.txt:63-64`; no hay cobertura demostrada | Cobertura acordada, redacción y medición de volumen/costo |
| “Todos los MS” | Alcance sin decidir ni inventario | Explorer/Researcher; migración common no demuestra todos | Lista de servicios, excepciones, owners y criterio por servicio |
| Common, generator, generado | Conflicto de alcance pendiente | `ideas.txt:68-71`; generator AGENTS | Confirmación sobre consumidores, generación y repositorios |
| Versión/compatibilidad | No decidir hasta reconciliar 1.0.0/1.0.1 | README, guía de uso y POM | Consultar BOM, release, artefacto y consumidores |

## Respuestas a preguntas de Explorer y Researcher
Todas las preguntas están abiertas en ambos informes. “Sin respuesta verificable” significa
que el repositorio/evidencia consultados no sustenta una decisión. Recomendaciones indicadas
no constituyen aprobación. Para las preguntas abiertas, la pregunta concreta es la misma
que figura en su enunciado.

| # | Pregunta | Respuesta sustentada / estado |
|---:|---|---|
| 1 | ¿Se conserva `MdcCorrelation` como API pública? | Hecho: existe y la guía la declara congelada en 1.0.0. Sin respuesta verificable sobre cambio futuro; requiere decisión de compatibilidad. |
| 2 | ¿La nueva capacidad será una interfaz logger inyectable? | Objetivo exige interfaz e inyección; forma concreta sin respuesta verificable. Recomendar contrato inyectable es propuesta no aprobada. |
| 3 | ¿El contrato representará eventos tipados, métodos de logger o ambos? | Sin respuesta verificable; requiere decisión de contrato. |
| 4 | ¿Se exige consumir common-log sin Spring? | Hay dependencia SLF4J sin Spring declarado y muestra log-only; alcance futuro no verificable. ¿Debe preservarse como requisito? |
| 5 | ¿Debe seguir siendo posible usar common-log sin common-web? | Hecho: diseño y documentación actuales lo permiten. Requisito futuro sin respuesta verificable; ¿se confirma preservación? |
| 6 | ¿Qué mecanismos DI concretos deben soportarse? | Sin respuesta verificable; requiere especificar frameworks/consumidores. |
| 7 | ¿El consumidor principal será código Java de microservicios? | Common está dirigido a MS Java, pero no acredita consumidor principal exclusivo. ¿Qué consumidores están incluidos? |
| 8 | ¿Qué campos estructurados serán obligatorios? | Sin esquema acordado ni salida validada. ¿Qué campos y formato son obligatorios? |
| 9 | ¿Quién provee el nombre del servicio? | Sin respuesta verificable; requiere identificar fuente de configuración/dueño. |
| 10 | ¿Quién provee ambiente y versión de despliegue? | Sin respuesta verificable; requiere definir fuente por campo. |
| 11 | ¿`requestId` permanece como identificador de correlación? | Hecho: clave actual MDC. Continuidad contractual no aprobada; ¿se mantiene? |
| 12 | ¿Se requiere además `traceId`? | Sin respuesta verificable; requiere decisión de trazabilidad. |
| 13 | ¿Debe propagarse contexto a procesos asíncronos? | Filtro WebFlux no demuestra propagación general. ¿Qué procesos y garantía se requieren? |
| 14 | ¿Qué transportes además de HTTP están dentro del alcance? | La guía cita jobs, SQS y batch como uso sin web, no como alcance aprobado. ¿Qué transportes incluir? |
| 15 | ¿Se requiere propagar contexto por SQS? | Sin respuesta verificable; requiere decisión del responsable. |
| 16 | ¿Qué mecanismo de contexto es compatible con los servicios existentes? | No hay inventario/stack completo. ¿Qué frameworks y versiones deben soportarse? |
| 17 | ¿Los atributos serán pares clave-valor o un modelo tipado? | Sin respuesta verificable; requiere decisión de esquema/API. |
| 18 | ¿El encoder configurado será requisito para consumidores? | Config existe, carga no acreditada. ¿Se hace requisito o solo opción? |
| 19 | ¿Qué formato serializado se espera verificar? | Sin salida contractual validada. ¿JSON u otro formato y qué esquema? |
| 20 | ¿El encoder de Spring Boot puede ser requisito en un módulo sin Spring? | Sin respuesta verificable; recomendación: decidir con requisito de uso sin Spring, no asumirlo. |
| 21 | ¿Todos los MS deben usar exactamente el mismo encoder? | Sin respuesta verificable ni inventario de consumidores. ¿Se exige uniformidad y qué encoder? |
| 22 | ¿Qué campos y valores concretos deben enmascararse? | OWASP da guía general, no lista local. ¿Qué datos/clasificaciones se prohíben? |
| 23 | ¿La máscara cubrirá valores por nombre de clave? | Sin política aprobada. ¿Se requiere y con qué lista de claves? |
| 24 | ¿Debe cubrir estructuras anidadas? | Sin respuesta verificable. ¿Qué tipos/profundidad de estructuras cubre? |
| 25 | ¿Debe cubrir argumentos interpolados del logger? | Sin respuesta verificable. ¿Qué APIs/argumentos deben redactarse? |
| 26 | ¿Debe cubrir mensajes libres? | Sin respuesta verificable. ¿Se prohíben, sanitizan o permiten con reglas? |
| 27 | ¿Debe cubrir excepciones y stack traces? | Guía local registra excepción en un caso, no define máscara. ¿Qué datos de excepciones se admiten? |
| 28 | ¿Debe cubrir payloads completos? | Sin respuesta verificable. ¿Qué payloads y qué transformación se requiere? |
| 29 | ¿Qué ocurre si falla la máscara? | Sin comportamiento acordado. ¿Fallar cerrado, omitir evento u otra conducta? |
| 30 | ¿Se define una lista de claves sensibles por dominio? | Sin catálogo local encontrado. ¿Qué dominio/owner aporta la lista? |
| 31 | ¿Se permitirá sobrescribir reglas por servicio? | Sin respuesta verificable. ¿Quién autoriza excepciones y cómo se auditan? |
| 32 | ¿Hay valores que no deban aparecer nunca, aun en DEBUG? | OWASP aconseja excluir datos sensibles; no determina valores del producto. ¿Qué categorías son absolutas? |
| 33 | ¿Qué eventos deben registrarse en INFO? | Objetivo dice inicio de cada método sin excepción; catálogo adicional no definido. ¿Qué significa método y qué cobertura? |
| 34 | ¿Se requiere entrada/salida de cada método? | Idea solo precisa inicio; salida no establecida. ¿Se requiere también salida? |
| 35 | ¿Se requieren parámetros y variables en DEBUG? | Objetivo lo exige literalmente; alcance de parámetros/variables y redacción sin respuesta. ¿Qué definición y excepciones? |
| 36 | ¿Qué volumen/costo aceptable define la política de logging? | Sin medición ni límite. ¿Qué presupuesto/umbral se acepta y quién lo fija? |
| 37 | ¿Se centralizarán textos de log en clases de mensajes? | Objetivo pide clase de textos; estructura/nombre/propiedad no definidos. ¿Una clase por módulo o catálogo común? |
| 38 | ¿Se centralizarán códigos de evento además de textos? | No lo exige el texto del objetivo ni hay convención hallada. ¿Se requieren códigos? |
| 39 | ¿Hay convención existente de mensajes reutilizable? | No se encontró en archivos revisados; no prueba ausencia en todo el workspace. ¿Hay convención externa/local adicional? |
| 40 | ¿Qué compatibilidad se promete a la API congelada? | Guía declara congelación 1.0.0; promesa futura sin respuesta verificable. ¿Compatibilidad binaria/fuente y política de major? |
| 41 | ¿Qué versión efectiva de common-log debe gobernar el contrato? | Discrepancia documental 1.0.0 / parent 1.0.1; no se verificó artefacto. ¿Qué release/BOM es el vigente? |
| 42 | ¿Debe resolverse la discrepancia 1.0.0/1.0.1 antes de diseñar? | Recomendación no aprobada: verificarla antes de fijar compatibilidad. ¿Se confirma como bloqueo? |
| 43 | ¿Qué consumidores publicados usan la versión actual? | Sin respuesta verificable; requiere BOM, repositorio de artefactos y lista de consumidores. ¿Quién aporta acceso/lista? |
| 44 | ¿Qué repositorios cuentan como microservicios del objetivo? | Sin inventario. ¿Qué repositorios/proyectos incluye obj-003? |
| 45 | ¿Qué servicios están activos y cuáles quedan excluidos? | Sin respuesta verificable. ¿Quién entrega estado y exclusiones vigentes? |
| 46 | ¿Quién mantiene cada servicio y aprobará su migración? | Sin owners identificados. ¿Quién es responsable/aprobador por servicio? |
| 47 | ¿Qué mecanismo comprobará la adopción por servicio? | Guía documenta checks de migración, no criterio transversal aprobado. ¿Qué evidencia cuenta por MS? |
| 48 | ¿La adopción se hará mediante BOM y actualización automatizada? | Existe mecanismo documentado para actualizar import en ciertos POM; adopción de este objetivo no aprobada. ¿Se usará y para qué universo? |
| 49 | ¿Qué configuración de logging debe migrar cada servicio? | Sin inventario/configuración de consumidores. ¿Qué formato, encoder y niveles se migran? |
| 50 | ¿Qué evidencia basta para declarar completada la adopción transversal? | Sin criterio aprobado. ¿Lista de dependencias, configuración, prueba de salida o aceptación por owner? |

## Preguntas abiertas prioritarias
- ¿“Todos los MS” significa auditar/adoptar consumidores aunque solo se cambien common y
  plantillas fuente de generator, o limita el alcance a esos componentes? ¿Se regenerarán
  consumidores y qué repositorios incluye?
- ¿Qué contratos, DI, stacks y versiones deben soportarse, incluida compatibilidad sin
  Spring y el estado/versionado efectivo de common-log?
- ¿Qué campos y datos sensibles se excluyen/enmascaran, cómo cubre DEBUG exigido cada
  método, y qué ocurre ante fallo de máscara?
- ¿Qué contexto y transportes se soportan, y cuál es la política aprobada para niveles,
  volumen/costo y evidencia de adopción?
- ¿Quién aporta inventario, estado, owners y consumidores publicados?
- ¿Se confirma la discrepancia de versión como bloqueo previo a diseñar compatibilidad?
- ¿Existe template arquitectónico oficial fuera del workspace accesible? No verificable.

## Riesgos y verificación
- Exposición de secretos/PII y falsificación de eventos: la guía OWASP no reemplaza una
  política local; la exigencia de parámetros/variables amplía el riesgo potencial.
- Volumen/costo y ruido por INFO/DEBUG de cobertura amplia; sin benchmark local.
- Contexto MDC incorrecto en ejecución asíncrona o uso de distintos transportes.
- Ruptura de API o dependencia accidental de Spring por versión/contrato no aclarados.
- Para verificar cuando haya decisiones: probar salida y esquema contractual, datos
  sensibles y entrada hostil, fallos de máscara, uso con/sin web según alcance, propagación
  de contexto, costo/volumen y adopción por servicio con evidencia acordada.

## Trazabilidad de cobertura
- Explorer: 50/50 preguntas respondidas o marcadas sin respuesta verificable; 50/50
  reproducidas por número y asunto. Ninguna se trata como aprobada por recomendación.
- Researcher: 50/50 preguntas respondidas o marcadas sin respuesta verificable; 50/50
  reproducidas por número y asunto. Comparten el mismo listado numerado.
- Preguntas abiertas totales: las 50 siguen requiriendo decisión/dato del usuario, además
  de las preguntas prioritarias de alcance, template y revisión Reviewer.
- Revisión Reviewer: pendiente por límite de profundidad; no se presenta diseño revisado.
