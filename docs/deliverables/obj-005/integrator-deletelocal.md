# DELETELOCAL - projects\com.quizsmart.app

- Fecha: 2026-10-11
- Autorizacion: usuario, DELETELOCAL (AGENTS.md)
- Alcance: borrar `projects\com.quizsmart.app` unicamente

## Inventario previo (antes de borrar)

- Ruta base: `C:\epc\general\projects\`
- Contenido de primer nivel:
  - `com.quizsmart.app\` (directorio)
  - `README.md` (153 bytes, se conserva)
- Recuento: 551 ficheros, 384 directorios, 3.785.415 bytes
- Contenido de primer nivel de `com.quizsmart.app\`:
  - `backend\`
  - `cloud\`
  - `frontend\`
  - `down.ps1`
  - `generation-plan.json`
  - `up.ps1`
- Sin ficheros versionados (projects/ en .gitignore), sin recuperacion por git.

## Accion ejecutada

- Script: no aplica. Operacion puntual autorizada DELETELOCAL.
- Comando: `Remove-Item -LiteralPath 'C:\epc\general\projects\com.quizsmart.app' -Recurse -Force`
- Resultado: OK, sin errores.
- No se ejecuto regeneracion del generador, terraform ni llamadas AWS.

## Verificacion final

- `Test-Path 'projects\com.quizsmart.app'` -> False
- Contenido restante en `projects\`: unicamente `README.md` (153 bytes)
- Sin restos ni carpetas huerfanas.
- `projects\` se conserva como carpeta.

## Notas y pendientes

- El proyecto puede regenerarse con el generador cuando se autorice.
- `up.ps1` y `UPDATEALL` quedaron sin destino hasta regenerar.
- Sin commit ni push realizados.