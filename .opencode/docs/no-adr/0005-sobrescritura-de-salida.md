# ADR-0005: El generador sobrescribe la salida sin comprobación previa

- **Fecha:** 2026-09-24
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** —

## Contexto

`PlanExecutor` comprobaba antes de escribir si el destino existía, lo que convertía cualquier segunda ejecución en un fallo y obligaba a borrar el proyecto a mano.

## Decisión

`PlanExecutor` sobrescribe los ficheros existentes sin comprobación previa y se elimina el código muerto `GEN010 ExistingOutput`. Los duplicados internos del plan siguen fallando con `GEN009`.

## Consecuencias

### Positivas

- Regenerar es idempotente; los cambios manuales en `projects/<id>` se regeneran encima.

### Negativas y riesgos

- Las ediciones manuales en la salida se pierden al regenerar: la fuente de verdad es `generator/`, nunca `projects/`.

### Coste

0 USD.
