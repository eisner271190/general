# Implementación

- Objetivo: `obj-005` (cambio puntual en `get-services-aws.ps1`, autorizado por el usuario)
- Agente/especialidad: `Developer / PowerShell`
- Fecha: `2026-10-12 00:25:26` (UTC-5)
- Estado: `completo`
- Resumen: nuevo switch `-Simple` que imprime una línea `SI`/`NO` por servicio.
- Bloqueos: `ninguno identificado`
- Alcance y ADR aprobados: solo `.opencode/scripts/get-services-aws.ps1` (excepción Q84);
  requisito del usuario en esta sesión. Sin commit ni push.

## Cambios
| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `param` | Añade `[switch]$Simple` | Nuevo modo de salida |
| `.EXAMPLE` | Ejemplo `-Simple` | Documentar el modo |
| `$awsCalls` | Quita `Sts` si `-Simple` | Solo sirve para cabecera |
| `$tfDirectories` | Sin lectura de estados si `-Simple` | Solo sirve para detalle |
| Salida | Bloque `if ($Simple)` tras `$services`; `exit 0` | Omite detalle y CodeArtifact |

Diff del cambio `-Simple` (solo estas líneas):
```diff
 param(
 ...
-  [switch]$AsJson
+  [switch]$AsJson,
+  [switch]$Simple
 )
 ...
+# -Simple solo necesita existencia: sin identidad (Sts) ni estados de Terraform.
+if ($Simple) { $awsCalls.Remove('Sts') }
+
 # Estados de Terraform locales (solo rutas, sin red)
 $tfDirectories = @()
-if (Test-Path -Path $TerraformRoot) {
+if (-not $Simple -and (Test-Path -Path $TerraformRoot)) {
 ...
+# --- salida simple (-Simple): solo SI/NO por recurso, sin CodeArtifact ------
+
+if ($Simple) {
+  foreach ($row in $services) {
+    Write-Output ('{0}: {1}' -f $row.Servicio, $(if ($row.AWS -gt 0) { 'SI' } else { 'NO' }))
+  }
+  exit 0
+}
+
 # --- desfases estado vs AWS -----
```

## Decisiones y desviaciones
- Con `-Simple` se omiten `Sts`, estados Terraform, desfases y bloque CodeArtifact.
- Existencia: `SI` si el conteo es > 0; `NO` si es 0 (fila de la tabla).
- Las advertencias `Fallos de AWS CLI` siguen en el canal de warning (no en stdout).
  Un fallo de llamada se ve como `NO`; ver riesgos.
- Sin `-Simple` no se cambia ninguna línea de salida (verificado abajo).

## Verificaciones y resultados
- Parseo PowerShell (`Parser::ParseFile`): 0 errores.
- `pwsh -NoProfile -File .opencode/scripts/get-services-aws.ps1 -Simple`: exit 0,
  13 líneas, una por servicio (salida real abajo). Solo lectura.
- Sin `-Simple`: exit 0, 53 líneas. Comparado con la salida previa al cambio: sin diferencias
  salvo la línea de fecha de cabecera.
- No se crearon ni modificaron tests. No se tocó el generador ni `/projects`.

Salida real de `-Simple` (2026-10-12 00:24:40):
```
ECR repositories: SI
Lambda functions: SI
API Gateway (HTTP): SI
SNS topics: SI
SQS queues: SI
Cognito user pools: SI
SSM (/develop/com.quizsmart.app/): SI
Secrets (develop/com.quizsmart.app): NO
IAM roles (proyecto): SI
IAM policies (proyecto): SI
DynamoDB tables: SI
CloudWatch log groups: NO
S3 keystore buckets: SI
```

## Defectos, limitaciones y riesgos
- `NO` también aparece si una llamada AWS falla (credenciales, permisos). Ver preguntas.
- `git diff` del archivo mezcla cambios previos de obj-005; este informe solo cubre `-Simple`.
- PSScriptAnalyzer no ejecutado (no disponible en la verificación).

## Preguntas
- Q-S1: ¿Con `-Simple`, un fallo de AWS CLI debe salir como `ERROR` en lugar de `NO`?
  - rec: mantener `NO` y dejar la advertencia; cambiar solo si se pide.
- Q-S2: ¿`checklist.md` y `obj-005.md` deben registrar el criterio `-Simple`?
  - rec: sí, como criterio nuevo; no se tocó por "Nada más".

## Anexo técnico PowerShell
- Versión: PowerShell 7 (`#Requires -Version 7.0` cumplido; ejecutado con `pwsh`).
- Edición/plataforma: Core, Windows (`win32`).
- Módulos: ninguno; AWS CLI en PATH.
- Parámetros nuevos: `-Simple` (switch). Sin otros cambios de parámetros.
- Permisos: solo lectura (`list-*`, `describe-*`, `get-*`, `head-bucket`).
- Efectos secundarios: ninguno sobre AWS ni Terraform; no escribe archivos.
- Logging/errores: `Write-Warning` para fallos de llamadas; `exit 0` en `-Simple`.
- Ejemplo: `.opencode/scripts/get-services-aws.ps1 -Simple`

## Traspaso
- Reviewer/Tester: pendiente de revisión del diff `-Simple` y decisión sobre Q-S1 y Q-S2.

## Archivos creados/modificados
- `.opencode/scripts/get-services-aws.ps1` (modificado)
- `docs/deliverables/obj-005/developer-powershell-simple.md` (creado)
