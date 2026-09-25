# generator/ — Aplicación .NET 9 (fuente de verdad)

## Comandos (requieren autorización)
- `dotnet build` en esta carpeta.
- Ejecutar el generador: `dotnet run --project Generator.csproj`.
- No hay proyecto de tests actualmente.

## Convenciones
- Cargar el skill `dotnet` antes de escribir o refactorizar código aquí (nullable, records, DI, capas, valores).
- Carpetas propias: mensajes fijos en `Domain/Messages/GeneratorMessages.cs`, códigos estables en `ErrorCodes` (ej. `GEN002`); salida CLI: `<error-code>: <message>`; nombres tipo `GenerationPlanFileName`, no `"generation-plan.json"`.

## Reglas del generador
- `epc.json` es entrada de configuración, no artefacto generado.
- Componentes resueltos desde los directorios configurados; `templates/` y `defaults/` dentro de cada componente.
- Un `generation-plan.json` determinista por ambiente; renderizar placeholders antes de escribir.
- Fallar antes de escribir si hay configuración, rutas, duplicados, relaciones o placeholders inválidos.
- Rechazar rutas absolutas y segmentos `..`; detectar rutas de salida duplicadas; no sobrescribir conflictos implícitamente.
- Validar entidades y relaciones bidireccionales; mensajes con archivo/propiedad relevante; parar en el primer estado inválido si produciría salida parcial.

## component.json
- Copia SOLO los archivos listados en `files` (clave de destino → plantilla) y `directories` listados (`Infrastructure/PlanExecutor.cs` usa `File.Copy` por plan). Un archivo no listado NO se genera.
- Al agregar/renombrar una plantilla: actualizar `component.json` en el mismo cambio.

## Estructura de carpetas
- `Program.cs` composición/exit codes (capa de presentación; aquí se ensambla todo).
- `Application/` casos de uso: `GeneratorApplication`, `GenerationPlanBuilder`, estado del plan (`PlanRequest`, `PlanContext`, `PlanState`, `PlannedGeneration`), logger y puertos (`IJsonFileReader`, `ITemplateRenderer`, `IPlanExecutor`, `IPlanExecutorFactory`).
- `Domain/` sin dependencias de Application/Infrastructure: `Domain/Models/` (configuración y plan), `Domain/Validation/` (reglas, estrategias de inversas, `PathValidator`), `Domain/Messages/` (`ErrorCodes`, `GeneratorMessages`, `GeneratorException`).
- `Infrastructure/` implementa los puertos de Application: `JsonFileReader`, `TemplateRenderer`, `PlanExecutor`, `PlanExecutorFactory`, `ProjectDirectoryResolver`.
- `Configuration/` constantes técnicas (`GeneratorConstants`); `components/` y `target/` son datos, no código; `docs/` planes y decisiones del generador.
- Regla de dependencia: Infrastructure → Application (puertos) y ambos → Domain; nunca al revés.
