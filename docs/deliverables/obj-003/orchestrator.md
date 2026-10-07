# Coordinación — obj-003

## Objetivo
- Evaluar logging estructurado en common y generator, con interfaz, inyección,
  enmascaramiento y textos centralizados; el código generado queda excluido y se regenera.
- El requisito también dice «todos los MS», en tensión con «solo common y generator»;
  el alcance no se interpreta ni se amplía sin confirmación.
- Alcance actual: análisis; no se autorizó implementación.

## Roster mínimo y estado
- Explorer: [informe](explorer.md). Ubicó `common-log`, generator y ausencia de inventario
  completo de microservicios.
- Researcher: [informe](researcher.md). Añadió guía OWASP; identifica riesgos de exposición,
  inyección y volumen, sin definir política para este producto.
- Architect: [informe](architect.md). Respondió 50/50 preguntas de Explorer y 50/50 de
  Researcher (listas idénticas); distingue evidencia, recomendaciones y datos/decisiones
  pendientes. No es diseño aprobado.
- Reviewer no asignado: primero deben resolverse decisiones de alcance y contrato.

## Hallazgos
- `common-log` ya existe bajo `library/common`; usa SLF4J y contiene configuración
  para encoder estructurado, además de `MdcCorrelation`.
- `common-web` integra correlación MDC; no se halló inventario de todos los MS.
- El generador es la fuente de verdad de las plantillas; el cambio eventual debe excluir
  los artefactos generados y requerir regeneración, conforme al alcance indicado.
- La documentación y POM presentan discrepancia de versión (1.0.0/1.0.1), pendiente
  de verificar antes de definir compatibilidad.
- Referencia principal: [arquitectura](architect.md). No hay aprobación de diseño.

## Decisiones y bloqueos
- Sin decisión sobre la forma de interfaz, mecanismos DI soportados, campos del log,
  datos sensibles, política INFO/DEBUG, propagación de contexto ni versionado.
- Las 50 preguntas siguen requiriendo decisión o dato del usuario; Architect las contestó
  individualmente con evidencia cuando disponible y marcó las restantes sin respuesta
  verificable. Ver [matriz de respuestas](architect.md#respuestas-a-preguntas-de-explorer-y-researcher).
- Registrar INFO en cada método y DEBUG de parámetros/variables puede filtrar
  información sensible y elevar volumen/costo; no convertirlo en política sin
  aprobación explícita y excepciones seguras.
- «Todos los MS» no es verificable sin definir si abarca solo este workspace,
  aportar inventario y acordar responsables y migración.
- «INFO al principio de cada método, sin excepción» y «DEBUG de parámetros/variables»
  requieren delimitar métodos/variables y conciliarse con el enmascaramiento obligatorio.
- La guía OWASP recomienda excluir, enmascarar o sanear datos sensibles y neutralizar
  inyección; no resuelve qué campos/domínios se aplican ni aprueba logging por método.
- No se crea ni reasigna work item. No se modifica producto ni infraestructura.

## Dudas abiertas / próximos pasos
- Confirmar alcance de microservicios y repositorios incluidos.
- Pregunta prioritaria: ¿«todos los MS» requiere adopción/migración en cada consumidor,
  o los cambios se limitan a common y las plantillas fuente de generator? El código generado
  queda fuera de cambios en ambos casos; confirmar si se deben regenerar consumidores.
- Aprobar o corregir política INFO/DEBUG y enumerar campos/formatos que se enmascaran;
  incluir payloads, excepciones y fallo de la máscara.
- Definir interfaz e inyección objetivo (incluidos servicios no Spring), contexto
  distribuido requerido y contrato/versionado.
- Aportar inventario de consumidores y mecanismo de adopción para verificar cobertura.
- Con respuestas, solicitar revisión de arquitectura; luego decidir si se autoriza
  implementación y validación.

## Cierre de coordinación
- Estado: bloqueado por decisiones de alcance y política; no listo para implementar.
- Recomendación: aceptar este análisis como diagnóstico preliminar, no como ADR ni
  aprobación de plan. Solicitar al usuario confirmación de las decisiones pendientes.
