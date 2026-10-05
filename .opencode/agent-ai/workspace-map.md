# Workspace Map

## Regla

NUNCA uses rutas hardcodeadas en instrucciones. Consulta este archivo para resolver cualquier símbolo.

## Base

- Rutas de trabajo: relativas a `.opencode/agent-ai/`
- Rutas de docs/templates: relativas a `.opencode/`
- Rutas de código: relativas a la raíz del repo

## Rutas de trabajo (base `.opencode/agent-ai/`)

| Símbolo | Ruta |
|---------|------|
| OBJECTIVES | `objectives/` |
| OBJECTIVES_DONE | `objectives/resolved-objectives/` |
| OBJECTIVES_INDEX | `objectives/README.md` |
| QUESTIONS_OPEN | `questions/question-NNN.md` |
| DELIVERABLES | `deliverables/` |
| PLANS | `plans/plan-*.md` |
| REVIEWS | `reviews/` |
| STATUS | `status/` (handover entre sesiones: `status.md`) |
| TASKS | `tasks.md` |

Una duda resuelta **no se archiva**: su respuesta, si es una decisión con consecuencias, se registra como ADR (`DECISIONS`) y la duda se cita en el campo `Origen:` del ADR.

## Docs (base `.opencode/`)

| Símbolo | Ruta |
|---------|------|
| WORKFLOW | `docs/workflow.md` |
| DECISIONS | `docs/adr/` (un ADR por decisión: `NNNN-slug.md`) |
| DECISIONS_INDEX | `docs/adr/README.md` |
| NOTES | `docs/no-adr/` (notas y conventions, no son decisiones) |
| TEMPLATES | `docs/templates/` |
| AGENTS_ROOT | `../AGENTS.md` |
| AGENT_ORCHESTRATOR | `agents/orchestrator.md` |
| DELETE_ALL_SERVICES_AWS | `scripts/delete-all-services-aws.ps1` |
| GET_SERVICES_AWS | `scripts/get-services-aws.ps1` |

## Scripts de despliegue (base raíz del repo)

| Símbolo | Ruta |
|---------|------|
| UP_ALL | `projects/{APPLICATION_ID}/up.ps1` (rápido: `-Fast`) |
| UPDATE_ALL | `projects/{APPLICATION_ID}/backend/update-all.ps1` |
| DOWN_ALL | `projects/{APPLICATION_ID}/down.ps1` |
| PLATFORM_REPO | library/platform/ |

## Templates (base `.opencode/`)

| Símbolo | Ruta |
|---------|------|
| OBJECTIVE_TEMPLATE | `docs/templates/objetivo.md` |
| QUESTION_TEMPLATE | `docs/templates/question.md` |
| ADR_TEMPLATE | `docs/templates/adr.md` |
| PLAN_TEMPLATE | `docs/templates/plan.md` |
| RESEARCH_TEMPLATE | `docs/templates/research.md` |
| ARCHITECTURE_TEMPLATE | `docs/templates/architecture.md` |
| IMPLEMENTATION_TEMPLATE | `docs/templates/implementation.md` |
| PLAN_REVIEW_TEMPLATE | `docs/templates/plan-review.md` |
| TEST_REPORT_TEMPLATE | `docs/templates/test-report.md` |
