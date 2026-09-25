# Decisiones (ADR-lite)

Formato: `fecha — decisión — contexto — consecuencias`.

- **2026-09-25** — Estructura por capas del generador: `Application/` + `Domain/{Models,Validation,Messages}` + `Infrastructure/` + `Configuration/` (antes `Models/`, `Services/`, `Validation/`, `Messages/` planos); namespaces `Generator.Domain.*`, `Generator.Application`, `Generator.Infrastructure`. Contexto: `Services/` era un cajón de sastre con 19 archivos (casos de uso + FS + render + logging mezclados). Consecuencias: dependencia unidireccional `Infrastructure → Application → Domain` (con `GeneratorLogger` y `OutputRegistry` en Application, no en Infrastructure, para no invertirla); `dotnet build` 0 errores; docs del generador → `generator/docs/`; fuente de verdad de la estructura en `generator/AGENTS.md`.

- **2026-09-24** — Sobreescritura de salida permitida: `PlanExecutor` sobrescribe archivos existentes sin comprobación previa; `GEN010 ExistingOutput` (código muerto) eliminado. Contexto: decisión explícita del usuario ("está bien que sobreescriba"); los duplicados internos del plan siguen fallando con `GEN009`. Consecuencias: ediciones manuales en `projects/<id>` se regeneran encima; los conflictos ruta/archivo (archivo donde debe haber directorio, viceversa) se validan antes de escribir con `GEN007`.
- **2026-09-23** — Flujo "Trabajar": `todo.md` con IDs T01–T16; skill `trabajar` + comando `/trabajar`; branch `feature/<plan-sin-.md>` → plan → implementar → PR (`gh pr*` = ask; sin `gh`, fallback a URL de compare de GitHub).
- **2026-09-23** — Criterio "tarea grande": >5 archivos, o >2 capas/componentes, o diff estimado >400 líneas; riesgo alto (BD/migraciones/renombres) obliga a plan **primero** aunque sea pequeña. Vigente en los skills `plan-workflow` (fuente canónica) y `trabajar`.

- **2026-09-23** — Estructura del agent workspace: `AGENTS.md` jerárquicos + `.opencode/{agents,skills,commands}` + `opencode.json`; fusiones (`rules`→`AGENTS.md`, `policies`→`opencode.json`, `workflows+prompts`→`commands`, `tools`→`skills`, `memory+templates`→`docs`); `agent-ai/` queda solo para todo/plans; regla ≤200 caracteres eliminada (solo brevedad). Plan: `.opencode/agent-ai/plans/plan-agent-workspace.md`.
- **2026-09-21** — Terraform vive en `cloud/terraform/<microservicio>/`, registrado en `components/cloud/aws/component.json`. Plan: `.opencode/agent-ai/plans/plan-move-terraform-to-cloud.md`.
- **Estado** — Java backend: Maven (`pom.scriban`), Spring Boot parent 3.4.0, Java 17, hexagonal con `HexagonalArchitectureTest`.
- **Estado** — Flutter: `provider` + `http` (sin BLoC/riverpod); lints `flutter_lints`.
- **Estado** — Fase 1 de agents: `orchestrator`, `architect`, `reviewer`. Fase 2 pendiente: `researcher`, `developer`, `tester`, skills `testing/research/github/database/browser`, vendor de `flutter/agent-plugins`, `dotnet/skills`, `antonbabenko/terraform-skill`.
