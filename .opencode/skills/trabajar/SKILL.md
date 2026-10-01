---
name: Trabajar
description: Trigger del flujo Trabajar — una tarea por ciclo (branch → plan → implementar → PR)
---

## Trigger

El usuario dice "Trabajar" (o `/trabajar NNN`): aplica el flujo completo de `WORKFLOW` (sección **Trabajar**) con el objetivo indicado o el siguiente abierto de `OBJECTIVES`. Una tarea por ciclo; tras cada PR, preguntar si continúa con la siguiente.
