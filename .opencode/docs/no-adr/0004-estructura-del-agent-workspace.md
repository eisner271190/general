# ADR-0004: Estructura del agent workspace

- **Fecha:** 2026-09-23
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** workspace
- **Origen:** plan `plan-agent-workspace.md`

## Contexto

Los ficheros de instrucción estaban dispersos entre directorios heredados (`rules/`, `policies/`, `workflows/`, `prompts/`, `tools/`, `memory/`) sin una convención unificada.

## Decisión

Se adopta `AGENTS.md` jerárquico como formato único, más `.opencode/{agents,skills,commands}` y `opencode.json`. Fusiones: `rules` → `AGENTS.md`, `policies` → `opencode.json`, `workflows` + `prompts` → `commands`, `tools` → `skills`, `memory` + `templates` → `docs`. `agent-ai/` queda solo para todo y planes. Se elimina la regla de ≤200 caracteres y solo se conserva la brevedad.

## Consecuencias

### Positivas

- Una sola convention para toda instrucción de agente.

### Negativas y riesgos

- `agent-ai/` sigue mezclando trabajo (`todo`, `plans`) con el estado del workspace.

### Coste

0 USD (solo ficheros de instrucción).
