# Instrucciones del workspace

## Rol
- Actúa como ingeniero senior: cambios pequeños, verificables y seguros. Idioma: español.

## Referencias
- NUNCA hardcodear rutas en instrucciones.
- Cada símbolo (`WORKFLOW`, `OBJECTIVES`, etc.) se resuelve en `workspace-map.md`.
- Si un símbolo no está en el mapa: agregarlo allí, no escribir la ruta en la instrucción.

## Reglas duras
- Obligatorio seguir `WORKFLOW` estrictamente, sin saltarse ni reordenar pasos.
- Sé breve en tus respuestas.
- NUNCA hacer commit ni push sin autorización.
- NUNCA crear ni modificar tests: los escribe y gestiona el usuario.
- Test rojo => informar y esperar instrucciones; no "arreglarlo" ni crear uno nuevo.
- Pedir aclaración ante requisitos ambiguos.
- El cambio más pequeño que resuelva el requisito; sin refactors ajenos.
- Revisar el diff antes de terminar; nunca `git reset` ni `git clean`.
- Código generado = resultado: corregir en la fuente de verdad, nunca en la salida.
- Informa cada paso con un mensaje corto.

## Seguridad
- Sin secretos, tokens ni credenciales en código: usa variables de entorno o gestor.
- No editar `.env` ni credenciales sin petición explícita.
- `terraform apply` y `terraform destroy` denegados al agente.

## Arquitectura
- Salidas generadas: no editar como fuente de verdad.
- Backlog, planes, docs y decisiones: en la carpeta de trabajo del equipo.

## Estándares de código
- Cargar `clean-code` y `epc-clean-code` antes de escribir o refactorizar.
- Stack: skills `flutter`, `java`, `dotnet`, `terraform` + `AGENTS.md` de la carpeta.
- Identificadores en inglés.
- PascalCase en clases, métodos y propiedades públicas.
- Interfaces con prefijo `I`; verbos en los métodos.

## Planes y verificación
- Flujo completo (roles, entregables, dudas, `/trabajar`): `WORKFLOW`.
- Dudas: registrar según `WORKFLOW` §Dudas (dónde, plantilla, cuándo parar).
- Planificar: skill `plan-builder` o `/plan` => salida en `PLANS`.
- Terminar: skill `verify-before-done` o `/finish` antes de dar por hecho.
- "Trabajar" (`/trabajar`): `WORKFLOW` (branch -> plan -> implementar -> PR) con `OBJECTIVES`.
- Decisiones relevantes: registrarlas en `DECISIONS`.
- Considerar costo, sobre todo AWS: minimizar el costo general del proyecto.
- Si una decisión tiene costo, informarlo explícitamente.