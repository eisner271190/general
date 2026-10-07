# Investigación local — obj-003

## Alcance y método
- Reintento enfocado en common-log, contrato/DI, máscara y adopción de microservicios.
- Inspección documental y código local; no se modificó producto ni se ejecutaron comandos.
- Consulta: 2026-10-06. No se requirió fuente externa para describir el estado local.
- La investigación externa sí será necesaria si se decide compatibilidad con estándares
  actuales de trazabilidad, recomendaciones de logging seguro o soporte de framework/SDK.

## Evidencia verificable y aplicabilidad
- `library/common/README.md:6-16`: common-log se limita a `MdcCorrelation` y `slf4j-api`;
  common-web es separado y es la única capa web. Aplica a preservar módulos sin web.
- `common-log/src/main/java/.../MdcCorrelation.java:11-43`: API actual estática;
  opera sobre MDC con única clave `requestId`, ignora valores vacíos y elimina la clave.
- `common-log/pom.xml:7-21`: módulo depende de `common-parent:1.0.1` y declara solo
  `slf4j-api`; no hay dependencia Spring declarada directamente en ese POM.
- `common-log/src/main/resources/.../logback-spring.xml` configura
  `org.springframework.boot.logging.logback.StructuredLogEncoder`; evidencia de
  configuración presente, no demuestra que todos los servicios la carguen.
- `library/common/docs/como-usar.md:5-16,51-73`: common-web integra correlación WebFlux;
  el uso sin web documentado consiste en invocar MdcCorrelation y limpiarlo en finally.
  Documenta API congelada en 1.0.0, contradicha por parent 1.0.1 del POM.
- `library/common/samples/log-only-sample/pom.xml` declara una muestra solo-log;
  su descripción indica que verifica no cargar common-web. La muestra es evidencia de
  intención/escenario, no un inventario de consumidores desplegados.
- `library/common/docs/como-migrar-un-ms.md:3-35,131-146`: migración documentada usa BOM,
  common-web y actualización de import vía automatización; no establece cobertura de
  todos los MS ni lista de repositorios/propietarios.
- `docs/deliverables/obj-003/orchestrator.md:24-42`: faltan decisiones de campos, datos
  sensibles, niveles, contexto, DI, versionado y alcance de “todos los MS”. No está
  autorizado implementar.
- `docs/deliverables/obj-003/architect.md:27-53` contiene propuesta preliminar, no
  aprobada: desacoplar Spring, máscara central, contexto async y no registrar cada
  método indiscriminadamente. Se cita como recomendación, no como hecho/decisión.

## Hallazgos, vacíos y traspaso
- No se encontró interfaz de logger inyectable ni política/mecanismo común de masking en
  los archivos inspeccionados de common-log; estado limitado al API estático observado.
- No hay evidencia suficiente de campos estructurados requeridos ni de la salida real
  serializada para consumidores. Encoder configurado no equivale a contrato validado.
- La contradicción de versión documentada (1.0.0) y parent (1.0.1) impide afirmar cuál
  es la versión efectiva/publicada sin consultar BOM, release y artefacto.
- No existe inventario aportado de microservicios; “todos” no puede verificarse con una
  muestra. Hace falta definir repositorios, servicios activos, excepciones y dueño.
- Riesgo señalado, no hecho medido: registrar argumentos/excepciones puede exponer
  secretos; INFO/DEBUG por método podría incrementar volumen. Requiere política aprobada.
- Para Architect: usar los hechos arriba como límites del contrato actual; confirmar
  audiencia sin Spring, semántica de eventos/campos, política de secretos y versión.
  No asumir compatibilidad estándar ni cobertura transversal antes de investigar.

## Consideraciones técnicas validadas externamente
- Consulta: 2026-10-06. OWASP Logging Cheat Sheet, autoridad: OWASP Cheat Sheet Series;
  guía especializada de seguridad, no estándar normativo:
  https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- En “Data to exclude”, OWASP indica no registrar directamente contraseñas, tokens,
  secretos primarios, datos personales sensibles y otros datos restringidos; según el caso,
  excluir, enmascarar, sanear, resumir o seudonimizar. Sirve como guía de política, pero
  no identifica datos concretos presentes en los MS de este workspace.
- En “Event collection”, OWASP recomienda sanear datos contra inyección (incluidos CR/LF
  y delimitadores), codificar según el formato de salida y validar datos externos. En
  “Verification” recomienda probar inyección, efectos secundarios, fallos y agotamiento
  de recursos. JSON/estructura por sí solos no garantizan seguridad: importa el encoding
  del encoder/sumidero. No hay evidencia de vulnerabilidad actual en common-log/generator.
- OWASP señala que el contenido y nivel de logging deben ser proporcionales al riesgo y
  que registrar demasiado puede ocultar señales útiles. INFO en cada método y DEBUG de
  cada parámetro/variable puede aumentar volumen y exposición; medirlo aquí es inferencia,
  no resultado de benchmark.
- Estructurar logs facilita consistencia/correlación, pero no define por sí solo el esquema
  ni elimina exposición, falsificación o abuso. La guía no prescribe una clase central de
  mensajes. Un catálogo puede estandarizar textos/códigos, pero no reemplaza campos,
  sanitización ni reglas de redacción: esto es una distinción analítica, no una decisión.
- “Todos los MS” podría significar adopción/validación transversal con cambios solo en
  common y plantillas fuente de generator, o cambios directos en cada MS. “No aplica al
  código generado” excluye los artefactos generados como fuente de cambio; no resuelve si
  hay que regenerar o inventariar/migrar consumidores. La evidencia no permite elegir.
- No se hallaron interfaz inyectable ni política compartida de redacción en los artefactos
  examinados; el logger generator observado es consola/estático, en contraste con Java/
  SLF4J. Esto no prueba ausencia en el repositorio completo. Architect debe mantener
  abiertas frontera Java/.NET, sumideros, política de secretos, fallo de redacción y
  definición/verificación de adopción; no se elige mecanismo técnico aquí.

## Preguntas generadas por grilling
Todas se derivan exclusivamente de evidencia y vacíos locales descritos arriba.
Estado: abiertas (requieren decisión o dato que no está en el repo inspeccionado).

1. ¿Se conserva `MdcCorrelation` como API pública? — Abierta.
2. ¿La nueva capacidad será una interfaz logger inyectable? — Abierta.
3. ¿El contrato representará eventos tipados, métodos de logger o ambos? — Abierta.
4. ¿Se exige consumir common-log sin Spring? — Abierta.
5. ¿Debe seguir siendo posible usar common-log sin common-web? — Abierta.
6. ¿Qué mecanismos DI concretos deben soportarse? — Abierta.
7. ¿El consumidor principal será código Java de microservicios? — Abierta.
8. ¿Qué campos estructurados serán obligatorios? — Abierta.
9. ¿Quién provee el nombre del servicio? — Abierta.
10. ¿Quién provee ambiente y versión de despliegue? — Abierta.
11. ¿`requestId` permanece como identificador de correlación? — Abierta.
12. ¿Se requiere además `traceId`? — Abierta.
13. ¿Debe propagarse contexto a procesos asíncronos? — Abierta.
14. ¿Qué transportes además de HTTP están dentro del alcance? — Abierta.
15. ¿Se requiere propagar contexto por SQS? — Abierta.
16. ¿Qué mecanismo de contexto es compatible con los servicios existentes? — Abierta.
17. ¿Los atributos serán pares clave-valor o un modelo tipado? — Abierta.
18. ¿El encoder configurado será requisito para consumidores? — Abierta.
19. ¿Qué formato serializado se espera verificar? — Abierta.
20. ¿El encoder de Spring Boot puede ser requisito en un módulo sin Spring? — Abierta.
21. ¿Todos los MS deben usar exactamente el mismo encoder? — Abierta.
22. ¿Qué campos y valores concretos deben enmascararse? — Abierta.
23. ¿La máscara cubrirá valores por nombre de clave? — Abierta.
24. ¿Debe cubrir estructuras anidadas? — Abierta.
25. ¿Debe cubrir argumentos interpolados del logger? — Abierta.
26. ¿Debe cubrir mensajes libres? — Abierta.
27. ¿Debe cubrir excepciones y stack traces? — Abierta.
28. ¿Debe cubrir payloads completos? — Abierta.
29. ¿Qué ocurre si falla la máscara? — Abierta.
30. ¿Se define una lista de claves sensibles por dominio? — Abierta.
31. ¿Se permitirá sobrescribir reglas por servicio? — Abierta.
32. ¿Hay valores que no deban aparecer nunca, aun en DEBUG? — Abierta.
33. ¿Qué eventos deben registrarse en INFO? — Abierta.
34. ¿Se requiere entrada/salida de cada método? — Abierta.
35. ¿Se requieren parámetros y variables en DEBUG? — Abierta.
36. ¿Qué volumen/costo aceptable define la política de logging? — Abierta.
37. ¿Se centralizarán textos de log en clases de mensajes? — Abierta.
38. ¿Se centralizarán códigos de evento además de textos? — Abierta.
39. ¿Hay convención existente de mensajes reutilizable? — Abierta.
40. ¿Qué compatibilidad se promete a la API congelada? — Abierta.
41. ¿Qué versión efectiva de common-log debe gobernar el contrato? — Abierta.
42. ¿Debe resolverse la discrepancia 1.0.0/1.0.1 antes de diseñar? — Abierta.
43. ¿Qué consumidores publicados usan la versión actual? — Abierta.
44. ¿Qué repositorios cuentan como microservicios del objetivo? — Abierta.
45. ¿Qué servicios están activos y cuáles quedan excluidos? — Abierta.
46. ¿Quién mantiene cada servicio y aprobará su migración? — Abierta.
47. ¿Qué mecanismo comprobará la adopción por servicio? — Abierta.
48. ¿La adopción se hará mediante BOM y actualización automatizada? — Abierta.
49. ¿Qué configuración de logging debe migrar cada servicio? — Abierta.
50. ¿Qué evidencia basta para declarar completada la adopción transversal? — Abierta.

## Fuentes consultadas
- Autoridad: código fuente y documentación versionados del workspace; consulta 2026-10-06.
- OWASP Cheat Sheet Series, “Logging Cheat Sheet”, secciones “Data to exclude”, “Event
  collection” y “Verification”; consulta 2026-10-06. Guía de seguridad, inferior en
  autoridad a estándares formales; no se usaron fuentes secundarias. No valida versiones
  específicas de SLF4J, Spring Boot, encoder ni .NET.

## Revisión de dudas vigentes — 2026-10-06
- Contraste realizado con `architect.md` y `orchestrator.md`; no se modificó código.
- Las 50 preguntas de grilling arriba siguen abiertas. No son 50 preguntas que
  requieran investigación web: muchas requieren decisión del responsable o datos del
  inventario del proyecto.
- Dudas que requieren resolución interna antes de avanzar: contrato/API e inyección;
  uso sin Spring; campos y reglas de máscara; aplicación de INFO/DEBUG por método;
  tolerancia a volumen/costo; alcance, propietarios y verificación de adopción; política
  de compatibilidad/versionado.
- La versión 1.0.0/1.0.1 se debe verificar primero en el BOM, historial de publicación,
  repositorios de artefactos y consumidores del proyecto. La discrepancia no se resuelve
  investigando documentación pública de terceros.
- Investigación externa no es necesaria para contestar qué está abierto ni para tomar
  las decisiones anteriores. Sí será necesaria si el contrato aprobado requiere validar
  interoperabilidad con un estándar vigente (por ejemplo, W3C Trace Context), garantías
  de seguridad de logging o compatibilidad con versiones específicas de SLF4J,
  Spring Boot/encoder o SDK. Esos productos/versiones aún no están delimitados.
- Se consultó OWASP para criterios generales de seguridad; no se validaron estándares ni
  versiones concretas de productos. Si el contrato aprobado requiere compatibilidad, deberá
  investigarse documentación oficial/estándares primarios contra las dependencias reales.
- Traspaso a Architect: conservar la propuesta como preliminar; solicitar definición de
  alcance y versiones a los responsables. Después, especificar preguntas externas
  concretas y verificar evidencia oficial antes de incorporar requisitos de compatibilidad.
- Falta información: versión del framework/SDK objetivo, inventario de servicios,
  artefacto publicado y sus consumidores, estándar de trazas requerido y política de
  datos sensibles aprobada.
