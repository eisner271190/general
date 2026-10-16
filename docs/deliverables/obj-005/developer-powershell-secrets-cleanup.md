# Implementación

- Objetivo: `obj-005 / Limpieza de restos Secrets Manager en scripts (Q99, opción 2)`
- Agente/especialidad: `Developer / PowerShell`
- Estado: `completo`
- Resumen: `Quitados los 4 restos de Secrets Manager en los dos scripts. Sin borrados reales.`
- Bloqueos: `ninguno identificado`
- Alcance y ADR aprobados: `obj-005 (Q84, Q85, Q99 opción 2); sin ADR nuevo`

## Cambios
| Archivo/componente | Cambio | Motivo |
|---|---|---|
| get-services-aws.ps1 | Quitado parámetro `$SecretPrefix` | Sin uso tras el cambio |
| get-services-aws.ps1 | Quitada entrada `Secrets` de `$awsCalls` | `secretsmanager list-secrets` |
| get-services-aws.ps1 | Quitadas `$secretNames` (2 líneas) | Solo lo usaban las filas eliminadas |
| get-services-aws.ps1 | Quitada fila `Secrets (...)` de la tabla | Salida de servicio |
| get-services-aws.ps1 | Quitada fila `aws_secretsmanager_secret` | Cotejo de desfases |
| delete-all-services-aws.ps1 | Cabecera: quitado "Secrets Manager," | Texto coherente |
| delete-all-services-aws.ps1 | Quitado parámetro `$SecretPrefix` | Sin uso tras el cambio |
| delete-all-services-aws.ps1 | Quitada consulta `Secrets` de `$queryCalls` | `list-secrets` |
| delete-all-services-aws.ps1 | Quitado bloque "Secrets Manager (borrado definitivo)" | `delete-secret` sin recuperación |

## Decisiones y desviaciones
- Sin realinear las columnas de `$checks` tras quitar la clave más larga (solo cambio mínimo).
- Ninguna otra desviación.

## Verificaciones y resultados
- Grep case-insensitive (secretsmanager, secrets manager, delete-secret, list-secrets,
  SecretPrefix, aws_secretsmanager) sobre los dos scripts: 0 coincidencias.
- Parseo PowerShell (`Parser::ParseFile`): 0 errores en ambos scripts.
- `get-services-aws.ps1` (solo lectura, sin parámetros): exit 0, 12 líneas, 0 menciones de Secret.
- `delete-all-services-aws.ps1 -WhatIf`: exit 0; plan de 72 recursos; "no se ha borrado nada".
  Sin ejecución real de `delete-*`.
- Nota: `-WhatIf` escribe log en el directorio temporal (`delete-all-services-aws-*.log`).
- Sin tests creados ni modificados. Sin commit ni push.

## Defectos, limitaciones y riesgos
- `git diff --stat` muestra 115 y 62 líneas: incluye cambios previos sin commit de obj-005
  (keystore). Los cambios propios de este paso son solo las líneas de Secrets listadas arriba.
- Los scripts no se ejecutaron con `-Force`; no hay verificación de borrado real.
- Dudas: ninguna abierta.

## Anexo técnico condicional
- PowerShell: pwsh 7.6.6, Win32NT, `#Requires -Version 7.0`.
- AWS CLI: aws-cli/2.28.6 (Windows, exe/AMD64); región por defecto us-east-1 (sin cambios).
- Módulos: ninguno nuevo.
- Parámetros eliminados: `-SecretPrefix` en ambos scripts (sin uso externo detectado).
- Permisos: lectura en `get-services-aws.ps1`; `delete-all-services-aws.ps1` solo en `-WhatIf`.
- Efectos secundarios: `-WhatIf` crea log temporal; `get-services` solo consulta AWS.
- Logging y errores: sin cambios en `Write-Log`, `Invoke-AwsRaw` ni manejo de errores.
- PSScriptAnalyzer: no ejecutado.

## Traspaso
- Reviewer/Tester: `pendiente` (verificar TC de Secrets en `use-cases.md` y `checklist.md`).

## Archivos creados/modificados
- `.opencode/scripts/get-services-aws.ps1`
- `.opencode/scripts/delete-all-services-aws.ps1`
- `docs/deliverables/obj-005/developer-powershell-secrets-cleanup.md` (este informe)
