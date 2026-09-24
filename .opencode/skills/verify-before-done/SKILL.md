---
name: Verify Before Done
description: Gate de verificación antes de declarar terminada una tarea: evidencia fresca de terminal, diff revisado, sin commits
---

## Obligatorio antes de decir "terminado"
1. Ejecutar la verificación del stack (formato/lint + tests/build que apliquen) y mostrar evidencia de ESTA sesión (comando + salida). Usa el skill del stack si está disponible; los comandos que compilan requieren autorización.
2. `git status` y `git diff`: solo cambiaron los archivos pretendidos; sin prints, TODOs, código comentado ni archivos temporales.
3. Sin placeholders `{{ ... }}` sin resolver en plantillas; sin secretos reales en el diff.
4. Si algo falla: arreglar el código (nunca deshabilitar tests) y repetir el paso 1.
5. Resumen final breve: qué cambió, dónde, qué queda pendiente.

## Prohibido
- Declarar terminado sin salida de terminal de esta sesión.
- Commit o push: aplicar la regla dura del `AGENTS.md` raíz (solo con autorización explícita).
- "Arreglar" un test fallándolo, borrándolo o ignorándolo.
