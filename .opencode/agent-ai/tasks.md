# Tareas pendientes

Filas con identificador estable: sincronizadas por `taskkeeper`. Filas sin identificador: manuales; el agente las conserva.

## Objetivo 002

- [ ] [002-C2] [usuario] Publicar `common` en CodeArtifact y comprobar que un proyecto externo resuelve el BOM.
- [ ] [002-C6] [usuario] Verificar con Renovate que el BOM se actualiza y los cambios llegan a los microservicios.
- [ ] [002-C7] [usuario] Publicar `epc/common-base` en ECR y probar el Dockerfile del piloto.
- [ ] [002-C8] [usuario] Aplicar Terraform y ejecutar el pipeline que usa el buildspec del bucket S3.
- [ ] [002-C9] [usuario] Verificar en AWS el trigger de release y los PRs de actualización de BOM.
- [ ] [002-C10] [usuario] Actualizar los imports de tests del piloto y ejecutar la suite para cerrar la migración.
