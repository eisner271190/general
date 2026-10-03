# ADR-0011: Ciclo de vida del secreto y parámetros en `down.ps1`, y `up.ps1 -Fast`

- **Fecha:** 2026-09-28
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** —

## Contexto

El `apply` del día falló con `InvalidRequestException: a secret with this name is already scheduled for deletion`: el `destroy` anterior había programado el borrado con la ventana de 30 días y no se podía volver a crear el secreto. Además el usuario pidió un arranque rápido y que `android-signing` se firmara siempre.

## Decisión

- `cloud/down.ps1` borra el secreto `<entorno>/<applicationId>` con `--force-delete-without-recovery` **antes** del `destroy` (si está programado para borrado, antes `restore-secret`), lee `environment_parameter_path` **antes** del `destroy` y borra con `ssm delete-parameters` en lotes de 10 lo que quede bajo la ruta del microservicio. Aborta al inicio si no está el `aws` CLI.
- El `up.ps1` de la raíz gana `-Fast`, que pasa `-SkipBuild -SkipRun` al frontend; hay comando `/up-fast` (frase "up fast") en `.opencode/commands/up-fast.md`.
- `frontend/up.ps1` extrae `Sync-AndroidSigningSecret`, que garantiza el bloque `android-signing` en el secreto con o sin `-Sign`: sin `-Sign` y sin secreto, solo aviso y se continúa; con `-Sign` sigue siendo error de secuencia. README actualizado.

## Consecuencias

### Positivas

- El borrado inmediato del secreto evita el bloqueo de recreación.
- `-Fast` permite arrancar sin reconstruir el frontend.

### Negativas y riesgos

- `--force-delete-without-recovery` hace el borrado irreversible; es el precio de desbloquear el ciclo.
- Los parámetros que no caen bajo `environment_parameter_path` quedan huérfanos en SSM.

### Coste

Sin cambios: sigue el coste del secreto único (ver ADR-0010).
