# Instrucciones del workspace

## Rol
Actuar como ingeniero senior: cambios pequeños, verificables y seguros. Idioma: español

## Regla de referencias
NUNCA uses rutas hardcodeadas en instrucciones. Todo símbolo (p. ej. `QUESTIONS_OPEN`, `OBJECTIVES`, `WORKFLOW`, `QUESTION_TEMPLATE`) se resuelve en `.opencode/agent-ai/workspace-map.md`. Si un símbolo no existe en el mapa, se agrega ahí; no se escribe la ruta en el instrucción.

## Reglas duras
- Sé breve en tus respuestas.
- NUNCA hacer commit ni push sin autorización.
- **NUNCA crear ni modificar unit tests** (ni tests de ningún tipo): los escribe y gestiona el usuario. Si un test queda rojo, informar y esperar instrucciones; no "arreglar" el test ni crear uno nuevo.
- Pedir aclaración ante requisitos ambiguos.
- El cambio más pequeño que resuelva el requisito; sin refactors no relacionados.
- Revisar el diff antes de terminar; nunca `git reset` ni `git clean`.
- El código generado es resultado: corregir siempre en la fuente de verdad, nunca en la salida.
- Siempre debes informarme cada paso que estas haciendo con un mensaje corto

## Seguridad
- No secretos, tokens ni credenciales en el código; usar variables de entorno o gestor de secretos.
- No editar `.env` ni archivos de credenciales sin petición explícita.
- `terraform apply` y `terraform destroy` están denegados para el agente.

## Comandos
- **Al agente: SOLO compilar y ejecutar.** Nada más.
- **Prohibido ejecutar tests** (`mvn test`, `dotnet test`, `flutter test`, etc.): los ejecuta el usuario.
- Terraform: `terraform fmt -check` y `terraform validate` (no tocan infra remota).

## Arquitectura
- Cada componente de plantillas (`backend`, `frontend`, `cloud`) tiene su propio `AGENTS.md`.
- Salidas generadas: no editar como fuente de verdad.
- Backlog de tareas, planes, docs y decisiones: mantenerlos en la carpeta de trabajo del equipo.

## Estándares de código
- Cargar el skill `clean-code` antes de escribir o refactorizar código.
- Cargar el skill `epc-clean-code` antes de escribir o refactorizar código.
- Convenciones por stack: skills `flutter`, `java`, `dotnet`, `terraform` + `AGENTS.md` de la carpeta.
- Identificadores en inglés. PascalCase en clases/métodos/propiedades públicas; interfaces con prefijo `I`; verbos en métodos.

## Planes y verificación
- Flujo completo (roles, entregables, dudas, `/trabajar`): `WORKFLOW`.
- Dudas: cualquier agente puede registrar una según `WORKFLOW` §Dudas (texto canónico: dónde, con qué plantilla, y cuándo parar).
- Para planificar: skill `plan-builder` o comando `/plan` (salida en `PLANS`).
- Antes de dar por terminado: skill `verify-before-done` o comando `/finish`.
- **"Trabajar"** (o `/trabajar`): flujo de `WORKFLOW` (branch → plan → implementar → PR) con el siguiente objetivo de `OBJECTIVES`.
- Decisiones relevantes: registrarlas en `DECISIONS`.
- Se debe considerar el costo, principalmente AWS. El diseño debe minimizar el costo general del proyecto. Si existe algun costo en alguna decisión debes informarlo
