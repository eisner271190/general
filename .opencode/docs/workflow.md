# Flujo de trabajo

Referencia en `AGENTS.md`. Los símbolos (`OBJECTIVES`, `QUESTIONS_OPEN`, `WORKFLOW`, …) se resuelven en `workspace-map.md`; las bases están allí.

## Inicio de sesión

- La sesión arranca con `orchestrator` (`AGENT_ORCHESTRATOR`; `default_agent` en `opencode.json`).
- Archivos vivos: `OBJECTIVES`, `QUESTIONS_OPEN`, `DELIVERABLES`.

## Objetivos

- Un archivo por objetivo: `OBJECTIVES/objetivo-<NNN>.md` (plantilla `OBJECTIVE_TEMPLATE`), con código `NNN` (001, 002, …).
- El usuario define el objetivo → crea el archivo.
- Al finalizar → mover el archivo a `OBJECTIVES_DONE`.
- Índice de pendientes: `OBJECTIVES_INDEX`.

## Roles y entregables (obligatorio por objetivo)

| Rol | Entregable |
| --- | --- |
| Planner-builder | `OBJECTIVES/objetivo-<NNN>.md` |
| Researcher | `DELIVERABLES/objetivo-<NNN>/research-<NNN>.md` |
| Architect | `DELIVERABLES/objetivo-<NNN>/architecture-<NNN>.md` |
| Reviewer-plan | `DELIVERABLES/objetivo-<NNN>/plan-review-<NNN>.md` |
| Developer | código fuente + `DELIVERABLES/objetivo-<NNN>/implementation-<NNN>.md` |
| Integrator | despliegue y verificación AWS → actualiza `DELIVERABLES/objetivo-<NNN>/implementation-<NNN>.md` |
| Tester | `DELIVERABLES/objetivo-<NNN>/test-report-<NNN>.md` |

## Flujo

1. **Yo** → defino el objetivo → **planner-builder** crea `OBJECTIVES/objetivo-001.md`.
2. **Researcher** → investiga → `research-001.md`. Si tiene dudas → `QUESTIONS_OPEN`.
3. **Architect** → diseña → `architecture-001.md`. Si recibe observaciones → actualiza `architecture-001.md`.
4. **Reviewer-plan** → revisa (carga el skill `grill-me`) → `plan-review-001.md`.
   - Sin observaciones → pasa a Developer.
   - Con observaciones → vuelve a Architect.
5. **Developer** → implementa → código fuente + `implementation-001.md`.
   - Si el problema requiere cambio de arquitectura → vuelve a Architect.
6. **Integrator** → despliega (`up.ps1` según caso) y verifica AWS → actualiza `implementation-001.md`.
   - Comandos con efectos AWS → autorización explícita.
7. **Tester** → prueba → `test-report-001.md`.
   - Pasan → finaliza: mover `objetivo-001.md` a `OBJECTIVES_DONE`.
   - Falla por implementación → vuelve a Developer.
   - Falla por arquitectura/requisito → vuelve a Architect.

## Dudas (cualquier agente puede crear una)

Texto canónico: los agentes con línea `Dudas → WORKFLOW §Dudas` obedecen esto.

- Registrar en `QUESTIONS_OPEN` siguiendo `QUESTION_TEMPLATE`: encabezado con `Agente` / `Tarea` / `Fecha` / `Estado: OPEN` / `Bloqueante: BLOCKING|NON_BLOCKING`, y las secciones `## Pregunta`, `## Contexto`, `## Tarea`, `## Solución propuesta` (la sección `## Respuesta` se rellena al resolver).
- Al resolver: rellenar `Estado: RESOLVED` y `## Respuesta` con la respuesta y la fecha. **La duda resuelta no se archiva ni se mueve**: si la respuesta es una decisión con consecuencias, se registra como ADR en `DECISIONS` siguiendo `ADR_TEMPLATE` y se anota `question-NNN.md` en el campo `Origen:`. Si no es decisión, la duda se borra: el hilo ya está en el entregable y en la decisión que lo citaba. El ADR es la fuente; no dupliques el texto.
- `NON_BLOCKING`: duda → registrar → continuar con la siguiente tarea.
- `BLOCKING`: duda → registrar → buscar otra tarea ejecutable → continuar; **solo detener si no queda trabajo posible**.
- El orchestrator revisa `QUESTIONS_OPEN` al inicio de cada fase, resuelve lo que pueda y, al cerrar la sesión, muestra las dudas abiertas.

## Delegación

- Objetivo nuevo → `planner-builder` · Investigación → `researcher` · Diseño/arquitectura → `architect` · Revisión de arquitectura → `reviewer-plan` · Código → `developer` · Despliegue y verificación AWS → `integrator` · Pruebas → `tester` · Revisión de cambios → `reviewer` · Explorar código → `explore`.
- Si un subagente no puede escribir (`explore`), devuelve la duda al orchestrator, que la registra.