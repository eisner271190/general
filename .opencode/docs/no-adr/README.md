# Notas (`NOTES`)

Documentos que conviven en `docs/adr/` pero **no gobiernan**. Conservan la plantilla del ADR
y su `Estado`, pero un ADR nuevo los sustituyó y aquí quedan solo como histórico.

Un ADR en vigor nunca se archiva: se marca `Obsoleta` con su `Sustituida por`. Estas notas se
archivaron por separado porque documentan conventions del workspace y del agente, no decisiones
de producto.

## Contenido

| Documento | Fecha | Sustituido por |
|-----------|-------|----------------|
| [0002](0002-flujo-trabajar.md) | 2026-09-23 | ADR-0015 |
| [0003](0003-criterio-tarea-grande.md) | 2026-09-23 | vigente como criterio |
| [0004](0004-estructura-del-agent-workspace.md) | 2026-09-23 | vigente como estructura |
| [0005](0005-sobrescritura-de-salida.md) | 2026-09-24 | vigente como regla |
| [0007](0007-auto-approve-por-defecto.md) | 2026-09-27 | vigente como regla |
| [0008](0008-postman-baseurl-tras-apply.md) | 2026-09-27 | vigente como regla |
| [0009](0009-cmd-lambda-clase-cualificada.md) | 2026-09-27 | vigente como regla |
| [0011](0011-ciclo-de-vida-de-secretos.md) | 2026-09-28 | vigente como regla |
| [0014](0014-workspace-map-como-fuente-unica.md) | 2026-10-01 | vigente como regla |
| [0015](0015-flujo-de-trabajo-con-roles.md) | 2026-10-01 | vigente como flujo |
| [0021](0021-precedencia-maven-common-bom.md) | 2026-10-03 | vigente como regla Maven |

## Reglas

- Una decisión en vigor va en `DECISIONS` (`docs/adr/`), no aquí.
- El índice de decisiones es `DECISIONS_INDEX` (`docs/adr/README.md`); cita estas notas desde ahí.
- Símbolo de rutas: `NOTES` en `workspace-map.md`.