# Implementación

- Objetivo: `obj-005` (cambio puntual en `get-services-aws.ps1`, autorizado por el usuario)
- Agente/especialidad: `Developer / PowerShell`
- Estado: `completo`
- Resumen: salida por defecto simple (SI/NO por servicio); `-Detail` activa la salida completa.
- Bloqueos: `ninguno identificado; dudas Q101 y Q102 en questions.md`
- Alcance y ADR aprobados: solo `.opencode/scripts/get-services-aws.ps1` (excepción Q84, Q85).

## Cambios
| Archivo/componente | Cambio | Motivo |
|---|---|---|
| \get-services-aws.ps1\ | Param \-Simple\ cambiado por \-Detail\ | Simple por defecto |
| Mismo | `$showDetail = $Detail -or $AsJson` | Detalle con `-Detail` y con `-AsJson` |
| Mismo | Sin \\\: omite \Sts\, estados TF y CodeArtifact | Como el antiguo \-Simple\ |
| Mismo | `.EXAMPLE` `-Simple` → `-Detail` | Documentar el nuevo switch |

## Decisiones y desviaciones
- `-Simple` eliminado: sin usos fuera del propio script y su informe previo
  (`developer-powershell-simple.md`). Llamarlo ahora falla con error de parámetro (Q102).
- `-AsJson` implica detalle para no cambiar el JSON existente (Q101).
- Sin cambios de comportamiento en la salida detallada, salvo la marca de tiempo.

## Verificaciones y resultados
- `pwsh -NoProfile -File .opencode/scripts/get-services-aws.ps1`: exit 0, 13 líneas,
  sin bloque CODEARTIFACT.
- `pwsh -NoProfile -File .opencode/scripts/get-services-aws.ps1 -Detail`: exit 0, 53 líneas.
- Comparación con la salida completa previa (53 líneas): solo difiere la marca de tiempo.
- Salidas redirigidas a temporales; no se incluye el log en este informe.
- No se crearon ni modificaron tests. No se hizo commit ni push.
- PSScriptAnalyzer: no ejecutado.

## Defectos, limitaciones y riesgos
- Scripts o automatizaciones que usen `-Simple` dejarán de funcionar (parámetro inexistente).
- Versión de PowerShell: no registrada; el script exige `#Requires -Version 7.0`.

## Anexo técnico
- PowerShell: edición y versión no medidas; `#Requires -Version 7.0`.
- Parámetros nuevos: `-Detail` (switch). Eliminado: `-Simple`.
- Permisos: solo lectura (`aws` y `terraform state list`, igual que antes).
- Efectos secundarios: ninguno; no escribe en AWS ni en Terraform.
- Logging/errores: `Write-Warning` en fallos de AWS CLI; `exit 0` en salida simple.
- Ejemplos:
  - `.opencode/scripts/get-services-aws.ps1`
  - `.opencode/scripts/get-services-aws.ps1 -Detail`
  - `.opencode/scripts/get-services-aws.ps1 -AsJson`

## Traspaso
- Reviewer/Tester: pendiente de revisión del diff y decisión sobre Q101 y Q102.

## Archivos creados/modificados
- `.opencode/scripts/get-services-aws.ps1` (modificado)
- `docs/deliverables/obj-005/questions.md` (Q101, Q102 añadidas)
- `docs/deliverables/obj-005/developer-powershell-default.md` (creado)
