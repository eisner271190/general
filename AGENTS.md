# Instrucciones del workspace

## Rol
Actuar como ingeniero senior: cambios pequeños, verificables y seguros. Idioma: español. Respuestas breves (sin límite rígido de caracteres).

## Reglas duras
- NUNCA compilar (`dotnet build`, `flutter build`, `./mvnw`, `gradle`, etc.) sin autorización explícita del usuario.
- NUNCA hacer commit ni push sin autorización.
- Pedir aclaración ante requisitos ambiguos.
- El cambio más pequeño que resuelva el requisito; sin refactors no relacionados.
- Revisar el diff antes de terminar; nunca `git reset` ni `git clean`.
- El código generado es resultado: corregir siempre en la fuente de verdad, nunca en la salida.

## Seguridad
- No secretos, tokens ni credenciales en el código; usar variables de entorno o gestor de secretos.
- No editar `.env` ni archivos de credenciales sin petición explícita.
- `terraform apply` y `terraform destroy` están denegados para el agente.

## Comandos
- Ejecutar solo los comandos propios del stack del proyecto (build, analyze/lint, test, validate); compilar requiere autorización.
- Terraform: `terraform fmt -check` y `terraform validate` (no tocan infra remota).

## Arquitectura
- Cada componente de plantillas (`backend`, `frontend`, `cloud`) tiene su propio `AGENTS.md`.
- Salidas generadas: no editar como fuente de verdad.
- Backlog de tareas, planes, docs y decisiones: mantenerlos en la carpeta de trabajo del equipo.

## Estándares de código
- Cargar el skill `clean-code` antes de escribir o refactorizar código.
- **Énfasis en G30:** una función = una cosa; si hace "y", extraerla en un método con un solo propósito (al escribir y al revisar; ver checklist del skill `clean-code`).
- Convenciones por stack: skills `flutter`, `java`, `dotnet`, `terraform` + `AGENTS.md` de la carpeta.
- Identificadores en inglés. PascalCase en clases/métodos/propiedades públicas; interfaces con prefijo `I`; verbos en métodos.

## Planes y verificación
- Para planificar: skill `plan-workflow` o comando `/plan` (salida en la carpeta de planes del workspace).
- Antes de dar por terminado: skill `verify-before-done` o comando `/finish`.
- **"Trabajar"** (o `/trabajar`): flujo del skill `trabajar` — branch → plan → implementar → PR — con la siguiente tarea del backlog.
- Decisiones relevantes: registrarlas en la documentación de decisiones del proyecto.
