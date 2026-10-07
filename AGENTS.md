# Instrucciones del workspace

# Rutas
- TEMPLATES: `.opencode/docs/templates`
- AGENTS: `.opencode/agents/templates`
- COMMANDS: `.opencode/commands/templates`
- SKILLS: `.opencode/skills/templates`
- DELIVERABLES: `.opencode/docs/deliverables`
- DECISIONS: `.opencode/docs/adr`
- GENERATOR: `generator`

## Referencias
- Haz el cambio mínimo necesario, sin refactors ajenos.

## Reglas duras
- Antes de iniciar cualquier tarea, vuelve a leer AGENTS.md completo.
- Nunca hagas commit ni push sin autorización.
- Nunca crees ni modifiques tests.
- Solo modificar el generador que es la fuente de verdad.
- No hardcodees rutas.
- No escribas rutas directamente.

## Estándares de código
- Siempre cargar skills `clean-code`.

## Estilo de redacción
- Prioriza listas sobre párrafos.
- Máximo 100 caracteres por línea.
- Usa siempre - para las listas.

## Output
- Debes responder en <= 50 palabras

## Subagentes
- Los templates se encuentra en `TEMPLATES`
- Antes de crear un agent, lee y sigue `TEMPLATES/agent.md`.
- Antes de crear un command, lee y sigue `TEMPLATES/command.md`.
- Antes de crear una skill, lee y sigue `TEMPLATES/skill.md`.
- Obligatorio crear un informe con el template correspondiente al rol en `DELIVERABLES/obj-NNN/{subagent}.md`. 
- Si la carpeta no existe, crearla.