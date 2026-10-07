# Exploración — obj-003

## Alcance y método
- Solo lectura de documentación y configuración local; no se modificó producto ni se
  ejecutaron comandos.
- La solicitud exige identificar `common`, `generator`, microservicios, stack, logging
  e informes existentes.
- No se verificaron artefactos publicados, repositorios externos ni despliegues.

## Objetivo y conflicto de alcance
- `.opencode/docs/ideas.txt`, sección `obj-003`, líneas 61-71: pide logging estructurado,
  INFO al inicio de cada método, DEBUG de parámetros/variables, máscara, interfaz,
  inyección, uso por «todos los ms» y clase central de textos.
- La misma sección finaliza «Solo aplica a common y generator» y «No aplica al código
  generado. Se elimina y vuelve a regenerar».
- Ambas frases pueden referirse a la localización de cambios o al alcance funcional;
  no es posible determinarlo con evidencia local. No se resuelve como decisión.
- Dato faltante/pregunta concreta: ¿«todos los ms» significa migrar/validar todos los
  consumidores aunque el código de consumidor generado quede fuera de cambios, o el
  objetivo queda limitado a los componentes `common` y `generator`?

## Hallazgos con evidencia
- `library/common/README.md:3-16`: biblioteca reutilizable para MS Java; enumera
  `common-bom`, `common-log`, `common-error` y `common-web`. `common-log` usa SLF4J,
  y `common-web` está separado como capa web.
- `library/common/pom.xml:14-25`: módulos Maven listados y Java release 17. La lista
  incluye muestras, no inventario de MS desplegados.
- `library/common/common-log/pom.xml:13-15`: descripción limita el módulo a correlación
  MDC sin dependencia web. `library/common/common-log/src/main/java/.../MdcCorrelation.java`
  es el punto de entrada local observado; la muestra de log registra con SLF4J estático
  (`library/common/samples/log-only-sample/src/main/java/.../LogOnlySampleApplication.java`).
- `library/common/common-log/src/main/resources/com/epc/common/log/logback-spring.xml:1-4`
  configura `StructuredLogEncoder` de Spring Boot. Esto prueba presencia de configuración,
  no que cada consumidor la cargue.
- `library/common/common-web/src/main/java/com/epc/common/web/RequestCorrelationFilter.java`
  integra `MdcCorrelation`; la configuración está separada de `common-log` según
  `library/common/README.md:11-16`.
- Versión posiblemente discrepante: `library/common/README.md:21,32-35` documenta 1.0.0;
  `library/common/pom.xml:7-10` declara parent 1.0.1. No se determinó versión publicada
  ni efectiva para consumidores.
- El único POM de aplicación hallado bajo `projects/` fue
  `projects/com.quizsmart.app/backend/quizapi/pom.xml`. No equivale a inventario completo
  de microservicios del objetivo.
- Stack generator: `generator/Generator.csproj:1-10` usa .NET 9 y Scriban 7.4.0.
  `generator/Application/GeneratorLogger.cs:3-17` muestra logger estático propio que escribe
  INFO/DEBUG/ERROR a consola con timestamp; no demuestra relación con `common-log`.
- `generator/AGENTS.md:3,17-38` declara al generador como fuente de verdad y especifica
  que los componentes contienen plantillas declaradas por `component.json`; el código
  generado no es la fuente a cambiar.
- Tecnologías observadas: Java 17/Maven y SLF4J en `common`; .NET 9/Scriban en generator;
  Spring Boot/WebFlux en módulos web; Flutter aparece en el catálogo de componentes, pero
  no se revisó como consumidor de logging.

## Informes obj-003 revisados
- `docs/deliverables/obj-003/orchestrator.md:3-8,18-55`: alcance no autorizado para
  implementación; conflicto «todos los MS»/«solo common y generator» está abierto.
- `docs/deliverables/obj-003/researcher.md:10-49`: evidencia local, vacíos de inventario,
  masking, DI y discrepancia de versión; su sección «Preguntas generadas por grilling»
  contiene 50 preguntas abiertas, reproducidas abajo.
- `docs/deliverables/obj-003/architect.md:12-29,69-87`: hechos preliminares y decisiones
  pendientes; propuesta arquitectónica no aprobada.
- La coherencia entre los tres informes y las fuentes se revisó solo por lectura; no se
  validaron historial de releases ni alcance externo.

## Verificaciones realizadas
- Lectura no modificadora de idea fuente, instrucciones del generador, README y POM de
  common, logger del generator e informes obj-003.
- Búsqueda textual local de logging bajo `library/common` y enumeración de POMs bajo
  `projects/`.
- No se ejecutó build, generación, pruebas ni inspección de servicios remotos.

## Preguntas abiertas y recomendaciones no técnicas
- Recomendación: pedir definición explícita del alcance antes de afirmar cobertura o
  planificar migraciones; no inferir que una muestra representa «todos».
- Recomendación: solicitar inventario vigente de MS, repositorio, propietario y exclusiones.
- Recomendación: aclarar si el logging de generator es un logger independiente o solo una
  manifestación de logging a contemplar en su propio proceso.
- Recomendación: dejar las propuestas del informe de arquitectura como propuestas hasta
  que el responsable las apruebe.

## Preguntas generadas por grilling
Estado de todas: abiertas; las recomendaciones no son acuerdos.
1. ¿Se conserva `MdcCorrelation` como API pública?
2. ¿La nueva capacidad será una interfaz logger inyectable?
3. ¿El contrato representará eventos tipados, métodos de logger o ambos?
4. ¿Se exige consumir common-log sin Spring?
5. ¿Debe seguir siendo posible usar common-log sin common-web?
6. ¿Qué mecanismos DI concretos deben soportarse?
7. ¿El consumidor principal será código Java de microservicios?
8. ¿Qué campos estructurados serán obligatorios?
9. ¿Quién provee el nombre del servicio?
10. ¿Quién provee ambiente y versión de despliegue?
11. ¿`requestId` permanece como identificador de correlación?
12. ¿Se requiere además `traceId`?
13. ¿Debe propagarse contexto a procesos asíncronos?
14. ¿Qué transportes además de HTTP están dentro del alcance?
15. ¿Se requiere propagar contexto por SQS?
16. ¿Qué mecanismo de contexto es compatible con los servicios existentes?
17. ¿Los atributos serán pares clave-valor o un modelo tipado?
18. ¿El encoder configurado será requisito para consumidores?
19. ¿Qué formato serializado se espera verificar?
20. ¿El encoder de Spring Boot puede ser requisito en un módulo sin Spring?
21. ¿Todos los MS deben usar exactamente el mismo encoder?
22. ¿Qué campos y valores concretos deben enmascararse?
23. ¿La máscara cubrirá valores por nombre de clave?
24. ¿Debe cubrir estructuras anidadas?
25. ¿Debe cubrir argumentos interpolados del logger?
26. ¿Debe cubrir mensajes libres?
27. ¿Debe cubrir excepciones y stack traces?
28. ¿Debe cubrir payloads completos?
29. ¿Qué ocurre si falla la máscara?
30. ¿Se define una lista de claves sensibles por dominio?
31. ¿Se permitirá sobrescribir reglas por servicio?
32. ¿Hay valores que no deban aparecer nunca, aun en DEBUG?
33. ¿Qué eventos deben registrarse en INFO?
34. ¿Se requiere entrada/salida de cada método?
35. ¿Se requieren parámetros y variables en DEBUG?
36. ¿Qué volumen/costo aceptable define la política de logging?
37. ¿Se centralizarán textos de log en clases de mensajes?
38. ¿Se centralizarán códigos de evento además de textos?
39. ¿Hay convención existente de mensajes reutilizable?
40. ¿Qué compatibilidad se promete a la API congelada?
41. ¿Qué versión efectiva de common-log debe gobernar el contrato?
42. ¿Debe resolverse la discrepancia 1.0.0/1.0.1 antes de diseñar?
43. ¿Qué consumidores publicados usan la versión actual?
44. ¿Qué repositorios cuentan como microservicios del objetivo?
45. ¿Qué servicios están activos y cuáles quedan excluidos?
46. ¿Quién mantiene cada servicio y aprobará su migración?
47. ¿Qué mecanismo comprobará la adopción por servicio?
48. ¿La adopción se hará mediante BOM y actualización automatizada?
49. ¿Qué configuración de logging debe migrar cada servicio?
50. ¿Qué evidencia basta para declarar completada la adopción transversal?

## Límites y traspaso
- No se establece diseño, política de logging, prioridad, contrato ni aprobación.
- La afirmación «todos los MS» queda sin verificar: hace falta alcance e inventario.
- Entregable al Orchestrator: evidencia del stack y del logger local, rutas relevantes,
  informes existentes y las 50 preguntas anteriores.
- Estado: análisis local completado; entendimiento compartido no cerrado hasta confirmación
  explícita del responsable sobre las dudas abiertas.
