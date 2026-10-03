# ADR-0007: `up.ps1` y `down.ps1` ejecutan con auto-approve por defecto

- **Fecha:** 2026-09-27
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** plan `plan-up-down-scripts.md` (pregunta 8)

## Contexto

`plan-up-down-scripts.md` dejaba `AutoApprove` en `no`, lo que hacía que cada despliegue exigiera una confirmación interactiva. El usuario pidió lo contrario.

## Decisión

`[switch]$AutoApprove = $true` en `up.ps1`/`down.ps1` (raíz y `cloud/`). Para pedir confirmación hay que pasar `-AutoApprove:$false` explícitamente. Se actualiza la ayuda y los ejemplos de las 4 plantillas.

## Consecuencias

### Positivas

- `up.ps1` es utilizable en pipelines y sesiones no interactivas sin tocar flags.

### Negativas y riesgos

- `apply` y `destroy` se ejecutan sin confirmación por defecto. Invertir el comportamiento requiere la sintaxis explícita `:$false`; un `-AutoApprove` a secas ya no lo distingue.

### Coste

0 USD.
