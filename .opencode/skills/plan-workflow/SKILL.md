---
name: Plan Workflow
description: Crea planes de implementación en .opencode/agent-ai/plans/ siguiendo el lineamiento del workspace (referencias web, tareas, archivos, costos)
---

## Reglas
- Aplicar a la tarea indicada por el usuario o a la más prioritaria de `.opencode/agent-ai/docs/todo.md`.
- Los planes se basan en la fuente de verdad del proyecto, nunca en salidas generadas.
- NO implementar: solo crear el plan.
- **Tarea grande** (evaluar al definir costos): > 5 archivos, o > 2 capas/componentes, o diff estimado > ~400 líneas; **riesgo alto** (esquema de BD, migraciones, renombres masivos) obliga a plan aunque sea pequeña. Si es grande, el plan se realiza **primero** —antes del feature— y la descompone en features más pequeños (una rama/PR por parte). *(Criterio canónico: lo refiere el skill `trabajar`.)*
- Siempre hacer preguntas/dudas con recomendación.

## Pasos
1. Leer `.opencode/agent-ai/docs/todo.md` y elegir la tarea (prioritaria o la indicada).
2. Buscar en la web cómo se implementa y buenas prácticas; resumir lo encontrado con enlaces.
3. Definir **objetivo** y **estado actual** (árbol o snippet).
4. Listar tareas y subtareas con cómo se implementarán (instrucciones, comandos, código fuente).
5. Definir el flujo como lista: de dónde sale cada dato.
6. Archivos a **crear** con su propósito.
7. Archivos a **modificar** con los cambios requeridos.
8. Preguntas/dudas → siempre con recomendación.
9. Crear `.opencode/agent-ai/plans/plan-<nombre-corto>.md`.
10. **Siempre especificar costos** (infra, esfuerzo, impacto de contexto/tokens).

## Plantilla
Usar `.opencode/docs/templates/plan.md` como estructura base: Descripción · Objetivo · Actual vs nuevo · Referencias · Tareas · Flujo de datos · Archivos a crear/modificar · Preguntas · Decisiones · Costos · Fuera de alcance.
