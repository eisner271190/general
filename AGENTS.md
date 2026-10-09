# Instrucciones del workspace

# Rutas
- TEMPLATES: `docs/templates`
- AGENTS: `.opencode/agents`
- COMMANDS: `.opencode/commands`
- SKILLS: `.opencode/skills`
- DELIVERABLES: `docs/deliverables`
- DECISIONS: `docs/adr`
- GENERATOR: `generator`
- UP: `projects/com.quizsmart.app/up.ps1`
- UPDATEALL: `projects/com.quizsmart.app/backend/update-all.ps1`
- GETAWS: `.opencode/scripts/get-services-aws.ps1`
- DELETEALL: `.opencode/scripts/delete-all-services-aws.ps1`

## Referencias
- Haz el cambio mínimo necesario, sin refactors ajenos.

## Reglas duras
- Antes de iniciar cualquier tarea, vuelve a leer AGENTS.md completo.
- Obligatorio crear un informe con el template correspondiente al rol en `DELIVERABLES/obj-NNN/{subagent}.md`. 
- Si la carpeta no existe, crearla.
- Nunca hagas commit ni push sin autorización.
- Nunca crees ni modifiques tests.
- Solo modificar el generador que es la fuente de verdad.
- No hardcodees rutas.
- No escribas rutas directamente.

## Preguntas y dependencias
- Fuente única: `DELIVERABLES/obj-NNN/questions.md`. Si no existe, crearlo.
- Todo subagente lee `DELIVERABLES/obj-NNN/obj-NNN.md` antes de actuar.
- Cada pregunta se agrega a `questions.md`, corta, puntual y con recomendación.
- Las dependencias van a la seccion `Dependencias` del mismo archivo.

## Estándares de código
- Siempre cargar skills `clean-code`, `checklist`.

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
- Todos los subagentes deben leer `DELIVERABLES/obj-NNN/obj-NNN.md`.
- Queda fuera del alcance hacer modificaciones en /projects. Agregarlo en todos los obj-NNN.

## Durante el proceso
- Si se identifican nuevos criterios de aceptación se deben ir agregando.
- Se deben ir agregando casos de prueba en `DELIVERABLES/obj-NNN/use-cases.md`.
- Por cada duda, registrar su causa y el tipo de problema para que no se repita. Registrarlo en `DELIVERABLES/obj-NNN/improvements.md`.
- Siempre que se resuelta una duda se debe actualizar la documentación del objetivo `DELIVERABLES/obj-NNN/*.md`.
- Se debe crear y actualizar `DELIVERABLES/obj-NNN/checklist.md`.

## Restricciones
- No se puede iniciar la implementar sin la autorización explicita del usuario
- No se puede iniciar la implementación, sin cumplir el checklist