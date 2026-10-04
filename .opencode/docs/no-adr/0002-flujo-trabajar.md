# ADR-0002: Flujo "Trabajar" con `todo.md`, branch y PR

- **Fecha:** 2026-09-23
- **Estado:** `Obsoleta`
- **Sustituye a:** —
- **Sustituida por:** ADR-0015
- **Alcance:** workspace
- **Origen:** plan `plan-agent-workspace.md`

## Contexto

El trabajo se organizaba en una lista plana de tareas (`T01`–`T16`) sin artefactos intermedios: no había entregable por fase ni forma de revisar antes de tocar código.

## Decisión

Se crea el skill `trabajar` y el comando `/trabajar`: el flujo es branch `feature/<plan-sin-.md>` → plan → implementar → PR. Los PR se abren con `gh pr*` (preguntando antes) y, sin `gh` disponible, se cae a la URL de compare de GitHub.

## Consecuencias

### Positivas

- Cada ciclo deja branch, plan y PR trazables.

### Negativas y riesgos

- `todo.md` quedó sustituido por `objectives/objetivo-NNN.md` (ver ADR-0015), por lo que la referencia a `T01`–`T16` es histórica.

### Coste

0 USD (más sesiones y subagentes = más tokens).
