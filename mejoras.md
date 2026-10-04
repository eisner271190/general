# Auditoría de `.opencode`

- Solo lectura de la configuración; no se aplicaron las mejoras propuestas.
- Hallazgos priorizados. Las rutas identifican los archivos revisados.

## Prioridad alta

### 1. Permisos de escritura de `integrator` son amplios

- Referencia: `.opencode/agents/integrator.md:8-13`.
- Puede editar cualquier `implementation-*.md` y `question-*.md`.
- Riesgo: editar entregables de otros objetivos o preguntas ajenas.
- Mejora: limitar permisos al objetivo asignado y validar los patrones efectivos.

### 2. El flujo no define gates antes del despliegue

- Referencias: `.opencode/docs/workflow.md:37-44`, `.opencode/agents/developer.md:14,20-23`,
  `.opencode/agents/integrator.md:26-33`.
- Developer no ejecuta tests; Integrator despliega y ejecuta tests antes de Tester.
- No se indica qué validación debe pasar para autorizar el despliegue.
- Mejora: precisar validaciones, gates y retornos por fallo de cada etapa.

### 3. La autorización de operaciones AWS no está unificada

- Referencias: `.opencode/agents/integrator.md:14-16,31,39`,
  `.opencode/opencode.json:5-20`, `.opencode/commands/up-fast.md:8-12`.
- Integrator permite shell; sus reglas piden autorización para AWS. La configuración
  global tiene reglas específicas `ask` y `deny`, incluido Terraform `apply` denegado.
- `up-fast` también exige autorización, pero no aclara cómo proceder ante `deny`.
- Mejora: definir operaciones permitidas, sujetas a autorización o prohibidas, y verificar
  la precedencia real de permisos. No confiar solo en instrucciones de texto.

### 4. El mapa de rutas no cubre las referencias del workflow

- Referencias: `AGENTS.md:8-12`, `.opencode/docs/workflow.md:12,21-27,31,39-45`,
  `.opencode/agent-ai/workspace-map.md:5-11`.
- El workflow repite patrones de rutas que no están todos definidos como símbolos.
- Riesgo: instrucciones desactualizadas si cambia la estructura del workspace.
- Mejora: completar el mapa y usar sus símbolos en las instrucciones operativas.

## Prioridad media

### 5. Developer e Integrator comparten el informe de implementación

- Referencias: `.opencode/agents/developer.md:2,27-33`,
  `.opencode/agents/integrator.md:43-48`,
  `.opencode/docs/templates/implementation.md:1-18`.
- Ambos escriben `implementation-<NNN>.md`; la plantilla no define sección de despliegue.
- Riesgo: responsabilidades ambiguas o que un agente sobrescriba información del otro.
- Mejora: definir qué secciones completa cada rol y alinear la plantilla con ese contrato.

### 6. El orchestrator no explica las transiciones del flujo

- Referencias: `.opencode/agents/orchestrator.md:48-60`,
  `.opencode/docs/workflow.md:30-44,58`.
- Enumera delegaciones, pero no resume gates, retornos ni quién cierra el objetivo.
- Mejora: declarar `WORKFLOW` como fuente canónica y describir cómo seguir sus transiciones.

### 7. Las pruebas se duplican entre Integrator y Tester

- Referencias: `.opencode/agents/integrator.md:33`, `.opencode/agents/tester.md:21-30`.
- Ambos tienen instrucciones para ejecutar pruebas, sin definir el alcance de cada uno.
- Mejora: reservar pruebas de aceptación a Tester y limitar Integrator a checks de despliegue,
  salvo que repetir una suite sea un gate deliberado.

### 8. La ubicación de `workspace-map.md` no es inequívoca

- Referencias: `AGENTS.md:10`, `.opencode/docs/workflow.md:3`,
  `.opencode/agents/taskkeeper.md:16`, `.opencode/agent-ai/workspace-map.md:1`.
- Varias instrucciones nombran el mapa sin indicar su ubicación.
- Mejora: registrar un símbolo para el propio mapa y usarlo al resolver rutas.

### 9. Los comandos de plan necesitan validar su agente y propósito

- Referencias: `.opencode/commands/plan.md:1-6`, `.opencode/commands/plan-builder.md:1-6`,
  `.opencode/skills/plan-builder/SKILL.md:28-32`.
- Ambos comandos declaran `agent: plan`; el inventario local no contiene ese agente.
  Puede ser un agente integrado, por lo que conviene verificarlo en OpenCode.
- El skill crea un objetivo completo, mientras `planner-builder` crea un resumen breve.
- Mejora: confirmar el agente integrado y distinguir claramente plan de implementación
  y definición de objetivo; alinear sus entregables.

### 10. Los permisos de preguntas pueden no coincidir con su ruta

- Referencias: `.opencode/agents/*.md` (`*question-*.md`),
  `.opencode/agent-ai/workspace-map.md:20`, `.opencode/docs/workflow.md:46-54`.
- El patrón de permisos y la ruta documentada incluyen formas distintas.
- Mejora: comprobar cómo resuelven los permisos los patrones y restringirlos al directorio
  de preguntas.

### 11. El límite de coste no define qué se está midiendo

- Referencia: `.opencode/agents/architect.md:44`.
- El máximo de 10 USD/mes no precisa si mide coste nuevo, total, por aplicación o entorno.
- Mejora: definir alcance, periodo y tratamiento de costes variables; presentarlo como
  estimación cuando no pueda garantizarse.

### 12. No se asigna quién archiva objetivos finalizados

- Referencias: `.opencode/docs/workflow.md:14,42`, `.opencode/agents/tester.md:40-43`,
  `.opencode/agents/taskkeeper.md:21-30`.
- El workflow exige mover el objetivo, pero Tester no puede editarlo y Taskkeeper no lo
  modifica.
- Mejora: asignar la acción de cierre y la actualización del índice a un responsable.

## Prioridad baja

### 13. Las reglas EPC pueden fomentar complejidad innecesaria

- Referencias: `.opencode/skills/epc-clean-code/SKILL.md:4-17`,
  `.opencode/skills/clean-code/SKILL.md:1-22`.
- EPC exige extraer cada bloque de control y añadir logs extensos; Clean Code promueve
  KISS/YAGNI. No se indica precedencia ni cuándo aplican las reglas mecánicas.
- Mejora: definir precedencia y limitar esas reglas a casos donde aporten valor.

### 14. Los scripts AWS contienen configuración de una aplicación concreta

- Referencias: `.opencode/scripts/get-services-aws.ps1:20-25`,
  `.opencode/scripts/delete-all-services-aws.ps1:26-38`,
  `.opencode/agent-ai/workspace-map.md:40-49`.
- Los scripts fijan nombres y raíces de recursos; los símbolos de despliegue aceptan
  `{APPLICATION_ID}`. El inventario no recibe ese identificador.
- Mejora: declarar si los scripts son específicos o multiaplicación. Si son genéricos,
  alinear sus parámetros y limitar el conjunto de recursos objetivo.

### 15. La plantilla de pruebas no cubre el reporte exigido

- Referencias: `.opencode/agents/tester.md:29-30`,
  `.opencode/docs/templates/test-report.md:1-23`.
- Tester debe listar comandos y clasificar fallos; la plantilla ofrece un comando y salida,
  pero no una sección de clasificación.
- Mejora: alinear el nivel de detalle de la plantilla y las instrucciones.

### 16. Las reglas de autorización de compilación varían

- Referencias: `AGENTS.md:17-20`, `.opencode/agents/orchestrator.md:57`,
  `.opencode/commands/build.md:5-7`, `.opencode/commands/test.md:5-7`.
- Orchestrator dice no compilar sin autorización; build y test piden autorización según
  el comando. La regla raíz no establece ese requisito general.
- Mejora: definir una regla común según permisos efectivos y efectos del comando.

### 17. Los símbolos de scripts no explican sus argumentos

- Referencia: `.opencode/agent-ai/workspace-map.md:40-49`.
- `UP_ALL`, `UPDATE_ALL` y `DOWN_ALL` incluyen `{APPLICATION_ID}`, pero no se define cómo
  resolver ese parámetro ni desde qué directorio ejecutar cada símbolo.
- Mejora: documentar la base y los argumentos requeridos para esos símbolos.

## Orden sugerido

- Aclarar permisos de escritura y autorización para comandos AWS.
- Definir gates y responsabilidades de Developer, Integrator y Tester.
- Completar el mapa de rutas y precisar el cierre de objetivos.
- Alinear agentes, comandos, skills y plantillas restantes.
