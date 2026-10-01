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
6. **Tester** → prueba → `test-report-001.md`.
   - Pasan → finaliza: mover `objetivo-001.md` a `OBJECTIVES_DONE`.
   - Falla por implementación → vuelve a Developer.
   - Falla por arquitectura/requisito → vuelve a Architect.

## Dudas (cualquier agente puede crear una)

Texto canónico: los agentes con línea `Dudas → WORKFLOW §Dudas` obedecen esto.

- Registrar en `QUESTIONS_OPEN` (plantilla `QUESTION_TEMPLATE`): `- [ ] [agente] Pregunta` + `Contexto:` / `Tarea: NNN` / `Solución propuesta:`.
- Al resolver: **mover** el archivo a `QUESTIONS_RESOLVED` con `- [x]` + `Respuesta:` + fecha.
- `NON_BLOCKING`: duda → registrar → continuar con la siguiente tarea.
- `BLOCKING`: duda → registrar → buscar otra tarea ejecutable → continuar; **solo detener si no queda trabajo posible**.
- El orchestrator revisa `QUESTIONS_OPEN` al inicio de cada fase, resuelve lo que pueda y, al cerrar la sesión, muestra las dudas abiertas.

## Delegación

- Objetivo nuevo → `planner-builder` · Investigación → `researcher` · Diseño/arquitectura → `architect` · Revisión de arquitectura → `reviewer-plan` · Código → `developer` · Pruebas → `tester` · Revisión de cambios → `reviewer` · Explorar código → `explore`.
- Si un subagente no puede escribir (`explore`), devuelve la duda al orchestrator, que la registra.

## Trabajar (`/trabajar [NNN]`)

- Una tarea por ciclo: el objetivo indicado o el siguiente abierto de `OBJECTIVES` (orden del índice). Tras cada PR, preguntar si continúa con la siguiente.
- Precondiciones: rama base `main` y árbol limpio (`git status`); si no, detener y reportar.
1. **Branch** — `git checkout -b feature/<slug>`, donde `<slug>` = nombre del plan sin `.md`. Si el branch ya existe → retomar el paso que falte (idempotente).
2. **Plan base** — si no existe `PLANS/plan-<slug>.md`, skill `plan-builder`.
3. **Plan detallado** — usar `PLAN_TEMPLATE` como estructura base. El plan se congela al implementar: cambios de alcance ⇒ actualizar el plan antes de continuar.
4. **Implementar** — cambios pequeños y verificables + `verify-before-done`. Los prompts de permisos (build/test) son la autorización: si se deniegan, detener y reportar.
5. **PR** — `git add` solo archivos del alcance → `git commit` (`plan-<slug>: <resumen>`) → `git push -u origin feature/<slug>` (ask) → `gh pr create --base main --head feature/<slug>` (ask) con `REPORT_TEMPLATE`; sin `gh` → URL de compare. Marcar el `**Estado:**` del `objetivo-NNN.md` con el PR.
6. **Al fusionar** — mover `objetivo-NNN.md` a `OBJECTIVES_DONE` y actualizar `OBJECTIVES_INDEX`.
