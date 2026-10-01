# Project — contexto del workspace para agentes

Monorepo `general`: una aplicación .NET 9 (`generator/`) produce proyectos por componente (Spring Boot + Maven, Flutter, Terraform AWS) a partir del JSON de configuración de cada app (`generator/target/<applicationId>/<applicationId>.json`).

- **Fuente de verdad:** `generator/` — código .NET + `components/**/component.json` + plantillas Scriban.
- **Salida:** apps en `projects/` y `generator/target/` — resultados; corregir siempre en el generador.
- **Backlog:** `OBJECTIVES`. **Terminados:** `OBJECTIVES_DONE`. **Dudas:** `QUESTIONS_OPEN` / `QUESTIONS_RESOLVED`. **Entregables:** `DELIVERABLES`. **Planes:** `PLANS`. **Rutas y símbolos:** `workspace-map.md`.
- **Instrucciones de agente:** `AGENTS.md` (raíz y por componente). Skills en `.opencode/skills/`, comandos en `.opencode/commands/`.
- **Referencias:** `.opencode/knowledge/{architecture,domain,api}` registradas en `.opencode/opencode.json`.
