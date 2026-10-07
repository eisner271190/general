# Plantilla de agent

Copia este archivo en `AGENTS/<nombre>.md` y sustituye todos los marcadores. Define `mode` como `primary` o `subagent`.

```md
---
description: "<Propósito breve y, para subagents, cuándo delegarles trabajo>"
mode: <primary|subagent>
permissions: []
---

## Propósito
<Por qué existe este agent y qué resultado debe producir.>

## Responsabilidades
- <Responsabilidad concreta>

## Límites
- <Qué no debe hacer el agent>

## Permisos de herramientas
Concede solo los permisos necesarios. Defínelos en el frontmatter mediante las reglas `permissions` de OpenCode (`action`, `resource`, `effect`); no uses un campo `tools`.

## Información faltante
Antes de hacer suposiciones que afecten el resultado, pregunta al usuario. Explica qué dato falta y formula una pregunta concreta.

## Formato de respuesta
<Estructura, nivel de detalle e idioma requeridos.>
```
