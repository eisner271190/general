# Plan: omitir archivos vacíos al generar (condición `Name == "security"`)

Basado en `generator/` (fuente de verdad). **Solo plan; no implementado.**

## 1. Referencias web (buenas prácticas)
- **Fail fast / validación de salida**: el generador debe validar antes de escribir
  (regla propia `codification.md`: "Fail before writing output when configuration,
  paths, duplicates, relations, or placeholders are invalid").
- Los generadores de plantillas (Yeoman, Cookiecutter, Sprig) suelen **omitir archivos
  cuyo render queda vacío** en lugar de emitir archivos de 0 bytes, porque un archivo
  vacío rompe la compilación (Java: "class no encontrada" o clase vacía inválida).
- Logging de artefactos omitidos para trazabilidad (no fallar: el vacío es esperado
  cuando la condición de la plantilla no se cumple).

## 2. Objetivo y estado actual

### Objetivo
Que el generador **no cree archivos cuyo contenido renderizado esté vacío** (o solo
whitespace), causado por plantillas registradas en `component.json` con guardia
`{{ if(Name == "security") }}...{{ end }}` que no se cumple para el micro actual.

### Estado actual
- **77 plantillas** del componente backend tienen la guardia `Name == "security"`
  (ver `agent-ai/docs/templates-sin-registro.md` y grep `{{ if(Name ==`).
- **~60 de ellas están registradas** en `component.json` → para el micro `quizapi`
  (`Name=quizapi`, `GenerationPlanBuilder.cs:41`) renderizan **vacío** y
  `PlanExecutor.cs:26` hace `File.WriteAllText(path, "")` → archivos `.java` de
  0 líneas (ej. `.../application/dto/ChangePasswordRequestDTO.java`).
- No existe ninguna validación de contenido vacío en el flujo
  `GenerationPlanBuilder → GenerationPlan → PlanExecutor`.
- Los archivos en blanco ya generados **permanecen** en `projects/` (no se limpian).

### Causa raíz (flujo actual)
```
component.json (registro, sin condición)
  → ProcessComponent() renderiza plantilla con variables
      (Name = microservice.Name = "quizapi")
  → condición {{ if(Name == "security") }} = false → content = ""
  → files.Add(new PlanFile(target, ""))   ← sin validación
  → PlanExecutor.WriteAllText(target, "") ← crea archivo vacío
```

## 3. Tareas de implementación

### Opción elegida: filtrar en el builder (recomendada)
- **T1.** En `GenerationPlanBuilder.ProcessComponent`, reordenar el loop `foreach (var file in component.Files)`:
  1. `RenderPath` del target.
  2. `ResolveComponentSource` + `templateRenderer.Render(...)`.
  3. **Nuevo:** `if (string.IsNullOrWhiteSpace(content))` → log y `continue`
     (no registrar el path ni agregar el `PlanFile`).
  4. `AddUnique(...)` + `files.Add(...)`.
  ```csharp
  var content = templateRenderer.Render(File.ReadAllText(templatePath), variables, templatePath);
  if (string.IsNullOrWhiteSpace(content))
  {
      GeneratorLogger.Info(GeneratorMessages.EmptyTemplateSkipped(file.Value, target));
      continue;
  }
  AddUnique(files.Select(item => item.Key).ToList(), paths, target, "archivo");
  files.Add(new PlanFile(target, content));
  ```
  > Importante: el `continue` debe ir **antes** de `AddUnique` para no registrar rutas
  > de archivos omitidos (evita falsos `DuplicateOutput` GEN009).

### Alternativas consideradas (no elegidas)
| Opción | Contra |
|---|---|
| Filtrar en `PlanExecutor` al escribir | `generation-plan.json` sigue listando archivos que no existen (plan ≠ realidad) |
| Quitar registros de `component.json` | Pierde la generación si algún micro sí se llama `security` |
| Cambiar la condición en las 77 plantillas | Edita 77 archivos; la condición puede ser intencional |

### T2. Mensaje centralizado
- Agregar método `EmptyTemplateSkipped(template, target)` en
  `Messages/GeneratorMessages.cs` (regla: no hardcodear mensajes en business logic).

### T3. Verificación (sin ejecutar aún — requiere autorización)
```bash
cd generator && dotnet run
# Regenerar y comprobar:
# 1) No aparecen .java de 0 bytes en projects/com.quizsmart.app/backend
# 2) generation-plan.json ya no contiene ChangePasswordRequestDTO.java, JwtProvider, etc.
# 3) Los .java con contenido real (hola-mundo-controller, etc.) siguen existiendo
```
Comando de apoyo para detectar vacíos (PowerShell):
```powershell
Get-ChildItem -Recurse -File projects\com.quizsmart.app\backend | Where-Object Length -eq 0
```

### T4. Limpieza de artefactos existentes (opcional, requiere confirmación)
- Los archivos vacíos actuales en `projects/` no se borran solos; decidir si se
  eliminan manualmente o se regenera desde cero (borrar `projects/com.quizsmart.app/backend`).

## 4. Flujo de datos (después del cambio)
```text
epc.json (entrada)
  → GenerationPlanBuilder.Build()
      → ProcessComponent(): render plantilla
          → ¿contenido vacío? ──sí──> GeneratorLogger.Info(...)  [se omite]
                    │ no
                    ▼
          → GenerationPlan.Files (solo archivos con contenido)
  → PlanExecutor.Execute()
      → File.WriteAllText(...) solo para archivos con contenido
  → generation-plan.json refleja exactamente lo escrito
```
Dato: `Name` sale de `epc.json → microservices[].name` (`GenerationPlanBuilder.cs:41`).

## 5. Archivos a crear
| Archivo | Propósito |
|---|---|
| Ninguno | Cambio mínimo sobre código existente |

## 6. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `generator/Services/GenerationPlanBuilder.cs` | Reordenar loop de `component.Files` y omitir renders vacíos (antes de `AddUnique`) |
| `generator/Messages/GeneratorMessages.cs` | Nuevo mensaje `EmptyTemplateSkipped(template, target)` |

## 7. Preguntas / dudas
1. **¿Contar solo `IsNullOrWhiteSpace` o también comentarios/`package;`?** Recomiendo
   solo vacío/whitespace (KISS).
2. **¿Los directorios vacíos quedan?** Hoy `component.Directories` se crea siempre
   (ej. `application/dtos/` seguirá existiendo vacía). ¿Aceptamos o también filtramos?
3. **¿Borrar los `.java` vacíos ya generados en `projects/`?** El cambio solo evita
   nuevos; la limpieza es manual.
4. **¿Log como INFO o WARNING?** Recomiendo INFO (es comportamiento esperado).
5. **¿Aplica también a `DefaultFiles`?** No: se copian binarios, no se renderizan.

## 8. Costos
- **AWS:** $0 (cambio local en el generador).
- **Riesgo:** bajo — un solo archivo C#; el comportamiento cambia solo para
  plantillas que hoy producen archivos inútiles.
- **Esfuerzo:** ~15 líneas en 2 archivos + verificación manual.

## 9. Definición de terminado (DoD)
- [ ] `dotnet run` sin errores (requiere autorización).
- [ ] Cero archivos de 0 bytes en `projects/**/backend`.
- [ ] `generation-plan.json` no lista los archivos omitidos.
- [ ] Plantillas con contenido (no vacío) se siguen generando igual.
