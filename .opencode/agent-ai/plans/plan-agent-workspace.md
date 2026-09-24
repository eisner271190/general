# Plan: Reorganizar el Agent workspace (agents, skills, workflows)

**Tarea del TODO:** N/A — solicitado directamente (clean code para Flutter, Java, .NET y Terraform)

**Fecha:** 2026-09-23

**Alcance:** Solo este repo (`C:\epc\general`). Nada en `~/.config/opencode/`.

---

## 1. Descripción

El workspace del agente hoy vive en `agent-ai/` (`AGENT.md`, `codification.md`, `docs/planner.md`), pero OpenCode V2 no lo descarga automáticamente: solo carga `AGENTS.md` (raíz y anidados). Además no existen `.opencode/` (agents, skills, commands) ni `opencode.json` (permisos, formatters, references).

Este plan crea la estructura fusionada acordada, respetando nombres cortos y migrando el contenido existente sin duplicarlo.

## 2. Objetivo

- `AGENTS.md` jerárquicos (raíz + 4 por stack) como fuente única de instrucciones.
- `.opencode/` con agents, skills y commands descubribles por OpenCode V2.
- `opencode.json` con permisos efectivos (reglas "nunca compilar/commit sin autorización").
- `agent-ai/` queda solo como workspace humano (todo + plans); su contenido normativo se migra y deja stubs.

## 3. Estado actual vs. nuevo

**Actual:**
```
C:\epc\general\
├── (sin AGENTS.md)                    ← OpenCode no carga nada al iniciar
├── (sin .opencode/)                   ← sin agents, skills ni commands
├── agent-ai\AGENT.md                  ← reglas de comportamiento (incluye ≤200 chars, a eliminar)
├── agent-ai\codification.md           ← 148 líneas .NET-centric, no se carga nunca
├── agent-ai\docs\planner.md           ← flujo de planes, no invocable
└── .github\copilot-instructions.md    ← enlaza a agent-ai/ (fuente no estándar)
```

**Nuevo:**
```
C:\epc\general\
├── AGENTS.md                                   # raíz: rol, reglas duras, comandos, enlaces
├── .opencode\
│   ├── opencode.json                           # permissions + formatters + references
│   ├── agents\{orchestrator,architect,reviewer}.md
│   ├── skills\
│   │   ├── clean-code\{SKILL.md,references\checklist.md}
│   │   ├── flutter\SKILL.md
│   │   ├── java\SKILL.md
│   │   ├── dotnet\SKILL.md
│   │   ├── terraform\SKILL.md
│   │   ├── plan-workflow\SKILL.md              # ← migra agent-ai/docs/planner.md
│   │   └── verify-before-done\SKILL.md
│   └── commands\{plan,review,test,build,finish}.md
├── knowledge\{architecture,domain,api}\README.md   # registrados como reference
├── docs\{project.md,decisions.md,templates\{plan,review,report}.md}
├── generator\AGENTS.md                         # .NET + reglas del generador
├── generator\components\backend\spring-boot-3.5.16\AGENTS.md    # Java/Spring
├── generator\components\frontend\flutter3.47.2\AGENTS.md         # Flutter
├── generator\components\cloud\aws\AGENTS.md                      # Terraform (templates)
├── agent-ai\                                   # solo humano: todo.md, plans/, stubs
└── .github\copilot-instructions.md             # → "Follow AGENTS.md"
```

Fusiones aplicadas: `workflows+prompts+commands` → `commands/` · `rules/` → `AGENTS.md` · `policies/` → `opencode.json` · `tools/` → `skills/` · `memory+templates` → `docs/` · `evals/` → fase 2.

## 4. Referencias web

| Referencia | Aporte |
|---|---|
| https://opencode.ai/v2/docs/agents/ | Formato Markdown de agents (frontmatter `mode`, `permissions`, `description`) |
| https://opencode.ai/v2/docs/skills/ | `SKILL.md` por directorio; ID = directorio contenedor (sin prefijo de grupo) |
| https://opencode.ai/v2/docs/commands/ | `/comando` con `$ARGUMENTS`, frontmatter `agent`, `subagent` |
| https://opencode.ai/v2/docs/instructions/ | `AGENTS.md` raíz + anidados; V2 ignora `CLAUDE.md` |
| https://opencode.ai/v2/docs/config/ y /formatters/ y /references/ | Shapes de `permissions`, `formatter`, `references` (**fetch antes de escribir opencode.json**) |
| [flutter/agent-plugins](https://github.com/flutter/agent-plugins) | Skills oficiales Flutter (26); fase 2: copiar selección |
| [dotnet/skills](https://github.com/dotnet/skills) | Skills oficiales Microsoft (16 plugins); fase 2 |
| [antonbabenko/terraform-skill](https://github.com/antonbabenko/terraform-skill) | Terraform/OpenTofu best practices (2.3k★); fase 2 |
| [obra/superpowers](https://github.com/obra/superpowers) | `verification-before-completion`, `writing-plans`; patrón inline <50 líneas |
| [dev.to: Clean Code como skills](https://dev.to/gde/skills-not-vibes-teaching-ai-agents-to-write-clean-code-3l9e) | Checklist G1–G30 → `clean-code/references/checklist.md` |
| [agentsmd/agents.md](https://agents.md) + [gist best practices](https://gist.github.com/0xfauzi/7c8f65572930a21efa62623557d83f6e) | Anidado por dominio, raíz ≤150-200 líneas, enlazar ≠ duplicar |
| [Google Java Style](https://google.github.io/styleguide/javaguide.html) | Base de `java/SKILL.md` |
| [Gruntwork IaC + agentes](https://www.gruntwork.io/blog/ai-coding-assistants-and-infrastructure-as-code-velocity-without-losing-control) | `fmt/validate/tflint/checkov` como verificación obligatoria |

## 5. Tareas de implementación

### Tarea 1 — `AGENTS.md` raíz
Crear con (versión corta, ~70 líneas):
- Rol: ingeniero senior, cambios pequeños/verificables/seguros; español; ser breve (**sin** límite de 200 caracteres — regla eliminada).
- Reglas duras: NUNCA compilar / commit / push sin autorización; pedir aclaración ante ambigüedad; no refactors no relacionados; revisar el diff; no hacer reset.
- Seguridad: no secretos en código; no editar `.env`/credenciales.
- Comandos: `dotnet build` (generator/), `flutter analyze`/`flutter test`, `terraform fmt -check`/`validate` (en `cloud/terraform/<ms>/`), Java (según build tool, ver Tarea 2).
- Arquitectura: `generator/` = fuente de verdad; `projects/` = resultado; planes en `agent-ai/plans/`.
- Estándares: cargar skill `clean-code` antes de codificar; convenciones por stack → AGENTS.md de la carpeta; naming en inglés.

### Tarea 2 — `AGENTS.md` anidados (4)
| Archivo | Contenido |
|---|---|
| `generator/AGENTS.md` | Sección .NET de `codification.md` (nullable, records, DI, Options Pattern, `GEN001:`, MessageCatalog) + reglas Generator (plan determinista, rutas relativas, fallar antes de escribir) |
| `generator/components/backend/spring-boot-3.5.16/AGENTS.md` | Java/Spring: hexagonal actual (adapter/port/usecase), Google Java Style, **confirmar Maven vs Gradle** buscando `pom.scriban`/`build.gradle.scriban` |
| `generator/components/frontend/flutter3.47.2/AGENTS.md` | Flutter: Effective Dart, estructura de plantillas, `flutter analyze` antes de dar por terminado |
| `generator/components/cloud/aws/AGENTS.md` | Terraform: `fmt`/`validate` obligatorios, layout `cloud/terraform/<ms>/`, un archivo por recurso, sin estado en git |

**Sub-tarea 2.1:** verificar en `component.json` que los archivos se copian por lista explícita y que `AGENTS.md` NO se emite a los proyectos generados (lectura estática; no compilar). Si se emite: decidir si es deseable o renombrar.

### Tarea 3 — `.opencode/opencode.json`
Primero **fetch de /v2/docs/config/ y /v2/docs/formatters/** para no adivinar shapes. Contenido:
- `permissions` (última regla gana → globales primero):
  ```jsonc
  "permissions": [
    { "action": "shell", "resource": "*",        "effect": "allow" },
    { "action": "shell", "resource": "git commit*", "effect": "ask" },
    { "action": "shell", "resource": "git push*",   "effect": "ask" },
    { "action": "shell", "resource": "git reset*",  "effect": "deny" },
    { "action": "shell", "resource": "dotnet build*", "effect": "ask" },
    { "action": "shell", "resource": "dotnet run*",   "effect": "ask" },
    { "action": "shell", "resource": "dotnet test*",  "effect": "ask" },
    { "action": "shell", "resource": "flutter build*", "effect": "ask" },
    { "action": "shell", "resource": "mvn*",  "effect": "ask" },
    { "action": "shell", "resource": "gradle*", "effect": "ask" },
    { "action": "shell", "resource": "terraform apply*", "effect": "deny" }
  ]
  ```
- `references`: `architecture`, `domain`, `api` → `./knowledge/<x>` con `description` (sin description no se anuncia).
- `formatter`/`lsp`: según docs; dart → `dart format`, C# → `dotnet format` (verificar disponibilidad), HCL → `terraform fmt` (solo si el binario existe; si no, documentar en AGENTS.md).

### Tarea 4 — Agents (3, fase 1)
| Archivo | mode | Permisos | Propósito |
|---|---|---|---|
| `orchestrator.md` | `primary` | `subagent`: deny `*` + allow `architect`, `reviewer`, `explore`, `general` | Orquesta con lista corta de hijos |
| `architect.md` | `subagent` | `edit` deny, `shell` deny | Diseño y revisión de planes, solo lectura |
| `reviewer.md` | `subagent` | `edit` deny, `shell` deny | Reporta hallazgos por severidad con `archivo:línea` |

Fase 2: `researcher`, `developer`, `tester`.

### Tarea 5 — Skills (7, fase 1)
Todos planos: `.opencode/skills/<id>/SKILL.md` (ID = directorio; nada de `skills/grupo/x`). Inline ≤50-70 líneas; detalle en `references/`.

| ID | Contenido base | Fuente |
|---|---|---|
| `clean-code` | SRP/OCP/LSP/ISP/DRY/KISS/YAGNI/fail-fast + naming + change discipline | `codification.md` + dev.to G1–G30 → `references/checklist.md` |
| `flutter` | Effective Dart, arquitectura, tests, JSON serializable, rutas; enlace a `flutter/agent-plugins` | docs Dart/Flutter |
| `java` | Google Java Style, Spring hexagonal, naming, tests JUnit | google style + plantillas reales del componente |
| `dotnet` | nullable, records, DI, `System.Text.Json`, `GEN001:`, Options Pattern | `codification.md` sección .NET |
| `terraform` | fmt/validate/tflint/checkov, módulos, `cloud/terraform/<ms>/`, HashiCorp style | Gruntwork + VoltAgent list |
| `plan-workflow` | Los 10 pasos de `planner.md` + costos obligatorios + "plan basado en generator/, no projects/" | `agent-ai/docs/planner.md` |
| `verify-before-done` | Evidencia fresca de terminal (fmt/analyze/test), revisar diff, resumen; sin commit | superpowers `verification-before-completion` |

### Tarea 6 — Commands (5, fase 1)
| Archivo | Frontmatter | Cuerpo |
|---|---|---|
| `plan.md` | `agent: plan` | "Aplica el skill `plan-workflow` para planificar: $ARGUMENTS" |
| `review.md` | `agent: reviewer`, `subagent: true` | "Revisa $ARGUMENTS. Severidad + archivo:línea." |
| `build.md` | — | "Compila $ARGUMENTS (o el stack detectado); pedir autorización si no se invocó por comando" |
| `test.md` | — | "Ejecuta la suite del stack afectado y reporta evidencia" |
| `finish.md` | — | "Gate: fmt/analyze/test + `git status`/`git diff` + resumen. No commit." |

Sin bloques `!`backtick`` para compilar (corren fuera del flujo de permisos). Fase 2: `feature`, `bugfix`, `research`, `summary`.

### Tarea 7 — `knowledge/` + `docs/`
- `knowledge/{architecture,domain,api}/README.md`: 5-10 líneas de qué va en cada uno (necesario para que la reference se anuncie).
- `docs/project.md`: qué es este repo (generador multi-stack).
- `docs/decisions.md`: ADR-lite; primer registro: "estructura del agent workspace".
- `docs/templates/{plan,review,report}.md`: plantillas referenciadas por `plan-workflow` y `finish`.

### Tarea 8 — Migración y stubs
| Archivo | Acción |
|---|---|
| `agent-ai/AGENT.md` | Reemplazar por stub de 2 líneas: "Migrado a `AGENTS.md` (raíz). Regla ≤200 chars eliminada." |
| `agent-ai/codification.md` | Stub con enlaces: principios → skill `clean-code`; .NET → `generator/AGENTS.md`; stacks → AGENTS.md por componente |
| `agent-ai/docs/planner.md` | Stub: "Migrado al skill `plan-workflow`." |
| `.github/copilot-instructions.md` | "Follow `AGENTS.md` at repo root (and nested `AGENTS.md` files). Do not duplicate instructions here." |

### Tarea 9 — Verificación (sin compilar)
1. Nueva sesión OpenCode en `C:\epc\general` → arranca sin errores de config.
2. `/plan`, `/review`, `/build`, `/test`, `/finish` visibles en el catálogo.
3. Pedir "lista tus skills" → 7 con descripción.
4. "Usa el subagente `reviewer`" → spawn OK y rechaza editar.
5. Leer `generator/AGENTS.md` desde una sesión → el anidado se inyecta (discovery).
6. `grep` de AGENTS.md en `component.json` + lectura del servicio de copia → confirmar sin emisión a proyectos generados (estático, sin build).

## 6. Flujo de datos

1. Usuario invoca `/plan X` → command `plan.md` (`.opencode/commands/`) → frontmatter `agent: plan` → cuerpo pide skill `plan-workflow` → skill lee `docs/templates/plan.md` + `agent-ai/docs/todo.md` → escribe `agent-ai/plans/plan-XXXX.md`.
2. Agente edita código → `AGENTS.md` raíz (siempre) + `AGENTS.md` del área leída (discovery) → convoca `clean-code`/`<stack>` bajo demanda → corre `formatter`/tests según `opencode.json` → permisos `ask` disparan autorización al usuario.
3. Revisión → `/review` → hijo con `agent: reviewer` → hallazgos → `developer` (humano o build) corrige.
4. `knowledge/*` → `references` en `opencode.json` → description anunciada → agente lee la carpeta solo si aplica.

## 7. Archivos a crear

| Archivo | Propósito |
|---|---|
| `AGENTS.md` | Instrucciones raíz siempre cargadas |
| `.opencode/opencode.json` | Permisos, formatters, references |
| `.opencode/agents/orchestrator.md` | Primary con allow-list de subagentes |
| `.opencode/agents/architect.md` | Subagente read-only de diseño |
| `.opencode/agents/reviewer.md` | Subagente read-only de revisión |
| `.opencode/skills/clean-code/SKILL.md` + `references/checklist.md` | Estándares transversales |
| `.opencode/skills/flutter/SKILL.md` | Convenciones Flutter/Dart |
| `.opencode/skills/java/SKILL.md` | Convenciones Java/Spring |
| `.opencode/skills/dotnet/SKILL.md` | Convenciones .NET (sección .NET de codification) |
| `.opencode/skills/terraform/SKILL.md` | Convenciones Terraform/IaC |
| `.opencode/skills/plan-workflow/SKILL.md` | Flujo de planes (migra planner.md) |
| `.opencode/skills/verify-before-done/SKILL.md` | Gate de terminado |
| `.opencode/commands/plan.md` | `/plan` |
| `.opencode/commands/review.md` | `/review` (subagente) |
| `.opencode/commands/build.md` | `/build` |
| `.opencode/commands/test.md` | `/test` |
| `.opencode/commands/finish.md` | `/finish` |
| `knowledge/{architecture,domain,api}/README.md` | Cuerpo de las 3 references |
| `docs/project.md` | Contexto del repo para agentes |
| `docs/decisions.md` | Registro de decisiones (ADR-lite) |
| `docs/templates/{plan,review,report}.md` | Plantillas usadas por skills/commands |
| `generator/AGENTS.md` | Reglas .NET + generator |
| `generator/components/backend/spring-boot-3.5.16/AGENTS.md` | Reglas Java/Spring |
| `generator/components/frontend/flutter3.47.2/AGENTS.md` | Reglas Flutter |
| `generator/components/cloud/aws/AGENTS.md` | Reglas Terraform |

## 8. Archivos a modificar

| Archivo | Cambio |
|---|---|
| `agent-ai/AGENT.md` | → stub de 2 líneas (enlace a `AGENTS.md`) |
| `agent-ai/codification.md` | → stub con enlaces por destino |
| `agent-ai/docs/planner.md` | → stub (enlace a skill `plan-workflow`) |
| `.github/copilot-instructions.md` | → apuntar a `AGENTS.md` (una sola fuente) |

## 9. Preguntas y recomendaciones

1. **Maven vs Gradle** en el componente Spring → *Recomendación:* confirmar leyendo los templates (`pom.scriban` vs `build.gradle.scriban`) y documentar el existente; no migrar nada.
2. **¿Borrar o stubbear `AGENT.md`/`codification.md`?** → *Recomendación:* stubs con enlace (hay referencias viejas y otros agentes pueden leerlos).
3. **¿Vendor de skills de terceros (flutter/agent-plugins, dotnet/skills, terraform-skill) ahora?** → *Recomendación:* fase 2 — por ahora solo enlazar desde nuestros skills (KISS, cero mantenimiento).
4. **¿`terraform apply` deny total?** → *Recomendación:* sí, deny; aplicar infra exige autorización explícita del usuario fuera del agente.
5. **¿`evals/` desde ya?** → *Recomendación:* no, fase 2 (no hay runner nativo; serían tests manuales de skills).

## 10. Decisiones tomadas

1. Alcance = este repo; no tocar `~/.config/opencode/`.
2. Regla ≤200 caracteres: **eliminada**; mantener solo brevedad.
3. Terraform = `cloud/terraform/<ms>/` (generado por el generador) → convenciones en `generator/components/cloud/aws/AGENTS.md` + skill `terraform`.
4. Estructura fusionada: `agents/skills/commands` bajo `.opencode/`; `rules→AGENTS.md`; `policies→opencode.json`; `tools→skills`; `memory+templates→docs`; `workflows+prompts→commands`.
5. Skills planos por ID (sin grupos anidados) para evitar colisiones.
6. Agents fase 1: `orchestrator`, `architect`, `reviewer` (los otros 3 en fase 2).
7. `generator/` es la fuente de verdad; `projects/` no recibe cambios de este plan.

## 11. Costos

- **Infraestructura:** $0 (sin MCPs de pago, sin servicios cloud).
- **Implementación fase 1:** ~26 archivos Markdown/JSON, 1 sesión, sin compilación ni commits.
- **Costo continuo en contexto:** raíz `AGENTS.md` ~70 líneas (~800-1.000 tokens) siempre cargado; anidados solo al explorar su carpeta; 7 skills = 0 tokens hasta cargarse (~500-800 tokens cada uno bajo demanda). `codification.md` (148 líneas) deja de ocupar contexto muerto.
- **Fase 2 (estimada):** 4 skills + 4 commands + 3 agents + vendor skills ≈ otra sesión.

## 12. Fuera de alcance (fase 2)

`skills/{testing,research,github,database,browser}` · `commands/{feature,bugfix,research,summary}` · `agents/{researcher,developer,tester}` · `evals/` · vendor de `flutter/agent-plugins`, `dotnet/skills`, `antonbabenko/terraform-skill` con ATTRIBUTION · emitir `AGENTS.md` a proyectos generados (requiere plan propio al generador).
