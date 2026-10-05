# Tareas pendientes

Filas con identificador estable: sincronizadas por `taskkeeper`. Filas sin identificador: manuales; el agente las conserva.

## Objetivo 002

- [x] [002-C2] [usuario] Publicar `common` en CodeArtifact y comprobar que un proyecto externo resuelve el BOM.
- [ ] [002-C7] [usuario] Publicar `epc/common-base` en ECR y probar el Dockerfile del piloto.
- [ ] [002-C8] [usuario] Aplicar Terraform y ejecutar el pipeline que usa el buildspec del bucket S3.
- [ ] [002-C9] [usuario] Verificar en AWS el trigger de release y los PRs de actualización de BOM.
- [x] [002-C10] [usuario] Actualizar los imports de tests del piloto y ejecutar la suite para cerrar la migración.
- [x] [002-C11] [usuario] Declarar en Terraform los dos repos de plataforma `common` y `platform` (CodeCommit).
- [x] [002-C12] [usuario] Trabajar sin secretos: token de CodeArtifact pedir por rol IAM y Git con credential-helper.
- [ ] [002-C13] [usuario] Emitir un único PR por release de `common` en `com.quizsmart.app`.
- [x] [002-C14] [usuario] Entregar los scripts de despliegue en PowerShell: `platform/scripts/up.ps1`, `publish-common.ps1` (sin apply) y `publish-buildspecs.ps1`.
- [x] [002-C15] [usuario] Generador: plantilla Terraform del repo en el componente cloud y `up.ps1` que crea el repo, añade el remoto y empuja.
- [ ] [002-C17] [usuario] Conectar los remotos de `common` y `platform` en git: es el único paso manual
  que queda, sin script detrás (`STATUS/status.md`, pendiente 4).
- [ ] [002-C16] [usuario] Añadir `environment` y `application_repository` al `terraform.tfvars` local de `library/platform/terraform/` antes del siguiente `plan`/`apply`: ambas variables han perdido su valor por defecto.

## Notas de alcance

- `[002-C6]` retirada: Renovate queda fuera del objetivo (ADR-0025). La actualización del BOM dentro de
  `common` la hace una persona, por aviso de seguridad; su propagación la hace el trigger por tag.
- Renovate, su CodeBuild programado y su Scheduler semanal se han borrado. No tienen tarea asociada.
- `OBJECTIVES/objetivo-002.md` ya no cita Renovate: contexto, alcance, criterios y fuera del alcance
  están alineados con ADR-0022, ADR-0024 y ADR-0025.
- El criterio de aceptación vigente es **un único PR** por release de `common` en
  `com.quizsmart.app`, no uno por repositorio de microservicio. Lo cubren `[002-C13]` y `[002-C9]`.
- El detalle de fase y los pendientes separados entre agente y usuario están en `STATUS/status.md`,
  que se recreó en 2026-10-05 tras perderse del versionado.
- `[002-C12]`, `[002-C14]` y `[002-C15]` cerradas: código entregado y verificado (`fmt`, `validate`,
  `plan` a 25 recursos, AST y parser de PowerShell, YAML de los 3 buildspecs, dry-run de los scripts).
  Cero secretos: ningún `aws_secretsmanager_secret`, token por rol, sin git push en los builds.
- `[002-C13]` se queda abierta como **entrega de código** cerrada a medias: lo único que falta es la
  ejecución real en AWS, que es `[002-C9]`. Lo cubre el trigger por tag con destino único.
- `[002-C16]` nueva: `application_repository` y `environment` ya no tienen valor por defecto en Terraform
  (ADR-0024), así que el `terraform.tfvars` local es obligatorio antes de cualquier `plan`/`apply`.
- Endurecimiento de calidad de los cinco scripts con `clean-code` y `epc-clean-code`; en el camino se
  corrigieron dos bugs reales.
