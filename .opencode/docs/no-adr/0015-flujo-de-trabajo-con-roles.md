# ADR-0015: Flujo de trabajo con roles y entregables

- **Fecha:** 2026-10-01
- **Estado:** `Aceptada`
- **Sustituye a:** ADR-0002
- **Sustituida por:** —
- **Alcance:** workspace
- **Origen:** —

## Contexto

El flujo anterior (ADR-0002) usaba `todo.md` con IDs `T01`–`T16` y no dejaba artefacto por fase: no había forma de revisar el diseño antes de tocar código ni de documentar por qué se implementó algo.

## Decisión

`.opencode/docs/workflow.md` es la fuente de verdad del flujo (referenciada desde `AGENTS.md`), con `default_agent: orchestrator` en `.opencode/opencode.json`.

- Objetivos con código `NNN` en `objectives/objetivo-NNN.md` (migrados de `todo.md`, 001–022); terminados en `objectives/resolved-objectives/`.
- Dudas en `questions/question-NNN.md` (un archivo por pregunta, numeración secuencial) con `Solución propuesta:`; resueltas en `questions/resolved-questions/`; estados `NON_BLOCKING` / `BLOCKING`.
- Entregables por rol en `deliverables/<rol>/`.
- Agentes nuevos: `planner-builder`, `researcher`, `reviewer-plan` (obligado a usar el skill `grill-me`), `developer`, `tester`.

## Consecuencias

### Positivas

- Cada fase deja un entregable revisable; la revisión ocurre antes del código.

### Negativas y riesgos

- `/trabajar` y el skill `trabajar` quedan solo como trigger hacia `workflow.md`, no como fuente de reglas.
- Las decisiones históricas y los planes antiguos que citan `todo.md` no se tocan: quedan referencias obsoletas de forma deliberada.

### Coste

0 USD (solo ficheros de instrucción; más sesiones y subagentes = más tokens).
