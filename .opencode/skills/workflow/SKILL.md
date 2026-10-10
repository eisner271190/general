---
name: Workflow de objetivo (obj-NNN)
description: "Usa esta skill cuando el usuario pide iniciar, revisar o continuar un objetivo obj-NNN ya creado en docs/deliverables. Coordina el ciclo completo (análisis con subagentes, respuestas del usuario, nueva revisión, cierre de preguntas, checklist y solicitud de autorización antes de implementar)."
---

## Alcance
- Usa esta skill cuando el usuario pide iniciar, revisar o continuar `obj-NNN`.
- No la uses para crear el objetivo (lo hace el usuario) ni para implementar sin autorización.
- Parametriza `obj-NNN` con el objetivo indicado; el flujo es igual para cualquier objetivo.
- Cada fase se delega en subagentes; tú actúas como coordinador y punto de contacto con el usuario.

## Flujo de trabajo

### Fase 1: Inicio (pasos 1-2)
1. El usuario crea el objetivo en `docs/deliverables/obj-NNN/obj-NNN.md` y pide iniciar.
2. Lee `AGENTS.md` completo y `obj-NNN.md` antes de actuar.
3. Crea la carpeta `docs/deliverables/obj-NNN/` si no existe.
4. Comprueba si existe `checklist.md`; si no, no lo crees aún (se crea en la fase 4).

### Fase 2: Análisis (paso 3)
5. Lanza en paralelo `explorer` y `architect` para leer el objetivo.
6. Cada subagente genera su informe en `docs/deliverables/obj-NNN/{subagente}.md`.
7. Las preguntas van a `docs/deliverables/obj-NNN/questions.md` (fuente única),
   cortas, puntuales y con recomendación.
8. Las dudas se registran en `docs/deliverables/obj-NNN/improvements.md` con causa y tipo.
9. Entrega al usuario la lista de preguntas abiertas y espera sus respuestas.

### Fase 3: Revisión de respuestas (pasos 4-7)
10. Cuando el usuario responda y pida nueva revisión, lanza `reviewer` para validar
    respuestas, alcance y criterios.
11. El reviewer abre nuevas preguntas si queda alguna duda; repite el ciclo de respuesta.
12. Actualiza `questions.md` marcando resueltas las respondidas y abiertas las nuevas.

### Fase 4: Checklist (pasos 8-9)
13. Lanza `taskkeeper` para evaluar si se cumple el checklist y crearlo.
14. Crea `docs/deliverables/obj-NNN/checklist.md` con los criterios de aceptación
    del objetivo y los añadidos durante el proceso.
15. Actualiza el checklist con el estado de cada punto.

### Fase 5: Autorización (paso 10)
16. Si el checklist está completo y no quedan preguntas abiertas, pide por escrito
    la autorización explícita del usuario para implementar.
17. Si quedan preguntas o el checklist está incompleto, no pidas autorización;
    informa de lo que falta.

## Requisitos y límites
- No inicies la implementación sin autorización explícita del usuario.
- No inicies la implementación sin checklist completo.
- No hagas commit ni push sin autorización.
- No crees ni modifiques tests.
- No modifiques nada en `/projects`.
- Siempre que se resuelva una duda, actualiza la documentación del objetivo.
- Si se identifican nuevos criterios de aceptación, añádelos al objetivo y al checklist.
- Añade casos de prueba a `docs/deliverables/obj-NNN/use-cases.md`.
- Si falta información esencial, pregunta al usuario antes de asumir.
- Respeta AGENTS.md: máximo 100 caracteres por línea y listas con `-`.

## Resultado
- Informes por subagente en `docs/deliverables/obj-NNN/{subagente}.md`.
- Preguntas en `questions.md`, dudas en `improvements.md`, casos en `use-cases.md`.
- `checklist.md` creado y actualizado.
- Autorización pedida por escrito solo si checklist completo y sin dudas abiertas.
- Informa al usuario del estado y de lo que falta, en español y con hora.
