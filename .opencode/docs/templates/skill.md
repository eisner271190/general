# Plantilla de skill

Crea el directorio `SKILLS/<id-de-skill>/` y guarda allí este archivo como `SKILL.md`. Usa un id único en minúsculas y kebab-case que coincida con el nombre del directorio. Sustituye todos los marcadores. Añade archivos auxiliares solo si la skill los necesita; usa rutas relativas a `SKILL.md` para referenciarlos.

```md
---
name: <Nombre legible de la skill>
description: <Cuándo usar esta skill y qué ayuda a conseguir>
---

## Alcance
Usa esta skill cuando <desencadenante o tarea concreta>. No la uses para <tarea similar fuera de su alcance>.

## Flujo de trabajo
1. <Primer paso necesario>
2. <Paso siguiente>
3. <Resultado esperado o traspaso>

## Requisitos y límites
- <Restricción, validación o aprobación importante>
- Si falta información esencial, pregunta al usuario antes de asumir.

## Resultado
<Qué producir, en qué formato y qué informar al terminar>
```

Mantén la skill enfocada en un procedimiento reutilizable. No añadas scripts, referencias ni plantillas hasta que el procedimiento realmente los necesite.
