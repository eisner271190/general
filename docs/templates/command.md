# Plantilla de command

Copia este archivo en `COMMANDS/<nombre>.md` y sustituye todos los marcadores. Mantén el prompt centrado en una tarea repetible.

```md
---
description: <Descripción breve que aparece en la lista de commands>
# Opcional: elige el agent que ejecutará este command.
# agent: <id-del-agent>
# Opcional: usa true para ejecutarlo en una sesión secundaria en segundo plano.
# subagent: true
---

<Instrucción de la tarea>. Usa $ARGUMENTS como entrada del usuario.

## Requisitos
- <Comportamiento o restricción requerida>
- Si falta información esencial, pregunta al usuario antes de asumir.

## Resultado
<Resultado y formato esperados>
```

Usa `$1`, `$2`, etc. en lugar de `$ARGUMENTS` si el command necesita argumentos posicionales. Evita bloques de shell (`!`\`...\``) salvo que sean necesarios; se ejecutan fuera del flujo de permisos de herramientas del agent.
