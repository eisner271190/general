Lee `agent-ai/docs/todo.md`

Nota: aplicar este lineamiento únicamente a la tarea más prioritaria del TODO.

Por cada tarea pendiente del TODO:

1. Buscar referencias en la web sobre cómo se implementa y buenas practicas.
2. Agregar una descripción de lo que encontraste en la web.
3. Define claramente el **objetivo** y el **estado actual**.
4. Crea un listado de **tareas de implementación, sub-tareas y como se implementarán (instrucciones, comandos, código fuente)**.
5. Definir el flujo como una lista. Debe mostrar de donde sale cada dato.
6. Lista los **archivos a crear** indicando su propósito.
7. Lista los **archivos a modificar** indicando qué cambios requieren.
8. Hacer preguntas, dudas sobre la implementación.
9. Crea un archivo `agent-ai/plans/plan-XXXX.md`.
10. Siempre especificar los costos

Importante: los planes deben basarse en el generador (archivos en `generator/`), no en aplicaciones generadas (archivos en `projects/`). El generador es la fuente de verdad; las apps generadas son el resultado.

No implementes ninguna tarea. Solo crea los `plan-XXXX.md`.