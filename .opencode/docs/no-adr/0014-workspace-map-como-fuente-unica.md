# ADR-0014: `workspace-map.md` como fuente única de rutas

- **Fecha:** 2026-10-01
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** workspace
- **Origen:** —

## Contexto

El usuario cambiaba nombres de carpeta con frecuencia y cada cambio obligaba a editar ~10 ficheros de instrucción. El problema se agravaba con `questions.md` → `question-NNN.md` y con el movimiento de `resolved-objectives/` dentro de `objectives/`.

## Decisión

Los ficheros de instrucción ya no llevan rutas literales: usan símbolos (`OBJECTIVES`, `QUESTIONS_OPEN`, `WORKFLOW`, `QUESTION_TEMPLATE`, `DELIVERABLES`, `PLANS`, `REVIEWS`, `STATUS`, `DECISIONS`, …) que se resuelven en `.opencode/agent-ai/workspace-map.md`, junto con las bases de cada grupo y la nomenclatura de entregables. Si falta un símbolo, se **agrega al mapa**; nunca se escribe la ruta en la instrucción.

## Consecuencias

### Positivas

- Renombrar una carpeta es una edición en un fichero de ~50 líneas.

### Negativas y riesgos

- Los permisos de escritura de los agentes pasaron de `*questions*.md` a `*question-*.md`; un patrón mal escrito deja al agente sin permiso y el error aparece como `Permission denied`, no como ruta mala.
- Se creó `docs/templates/question.md` (`QUESTION_TEMPLATE`) y se añadió la base de código al mapa para no colisionar con `generator/components/**` y `components/`.
- Estructuras reorganizadas: un archivo por objetivo en `objectives/`, terminados en `objectives/resolved-objectives/`, un archivo por duda en `questions/`, resueltas en `questions/resolved-questions/`.

### Coste

0 USD (solo ficheros de instrucción).
