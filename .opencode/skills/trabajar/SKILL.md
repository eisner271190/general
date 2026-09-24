---
name: Trabajar
description: Flujo "Trabajar" — por cada tarea de todo.md: crear branch feature/<plan>, generar el plan, implementarlo y crear el pull-request
---

## Trigger
El usuario dice "Trabajar". Procesar UNA tarea por ciclo: la siguiente pendiente de `.opencode/agent-ai/docs/todo.md` (orden del archivo) o la indicada ("Trabajar T07"). Tras cada PR: preguntar si continúa con la siguiente.

## Precondiciones
- Rama base `main` y árbol limpio (`git status`). Si hay cambios sin commitear o estás en otra rama → detener y reportar.

## Flujo por tarea

1. **Branch** — `git checkout -b feature/<slug>` donde `<slug>` = nombre del plan sin `.md` (ej. plan `plan-auth-login.md` → branch `feature/plan-auth-login`).
   - Si el branch ya existe → retomar el flujo en el paso que falte (idempotente; no repetir pasos hechos).
2. **Plan** — si no existe `.opencode/agent-ai/plans/plan-<slug>.md`, aplicar el skill `plan-workflow` para esa tarea. El plan se congela al implementar: cambios de alcance ⇒ actualizar plan antes de continuar.
   - **Tarea grande o de riesgo alto:** el criterio canónico vive en el skill `plan-workflow`. Si aplica, el plan se genera **primero** (antes del branch/paso 1) y se descompone en features más pequeños; una rama/PR por feature.
3. **Implementar** — ejecutar el plan con cambios pequeños y verificables. Aplicar `verify-before-done` antes del paso 4. Los prompts de permisos (build/test) son la autorización: si se deniegan, detener y reportar.
4. **Pull request**
   - `git add` solo archivos del alcance → `git commit` (mensaje: `plan-<slug>: <resumen>`) → `git push -u origin feature/<slug>` (permiso `ask`).
   - PR: con `gh` disponible → `gh pr create --base main --head feature/<slug> --title "plan-<slug>: <tarea>" --body-file <plantilla .opencode/docs/templates/report.md rellenada>`. Sin `gh` → entregar al usuario la URL de compare del repositorio (`https://github.com/<owner>/<repo>/compare/main...feature/<slug>?expand=1`) y no simular el PR.
   - Actualizar `.opencode/agent-ai/docs/todo.md`: `- [x] <id> — <tarea> (PR #n o URL)`.
5. **Al fusionar** (decisión del usuario): mover la tarea a `.opencode/agent-ai/docs/done.md`.

## Reglas
- Un branch = un plan = un PR; sin tareas ajenas en el mismo PR.
- Las reglas duras (compilar/commit/push solo con autorización) las fija el `AGENTS.md` raíz; si un permiso se deniega, detener.
- Resumen breve en español tras cada paso completado.
