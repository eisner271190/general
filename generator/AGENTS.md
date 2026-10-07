# Generador .NET 9

`generator/` es la fuente de verdad del generador.

## Comandos

- `dotnet build` y `dotnet run --project Generator.csproj`.
- Actualmente no existe un proyecto de tests.

## Cambios de código

- Cargar skill `clean-code`
- Mensajes en `Domain/Messages/GeneratorMessages.cs`.
- Valores constantes en `Configuration\GeneratorConstants.cs`.
- Valores literales son constantes

## Contrato de generación

- La configuración JSON bajo `target/` es entrada, no un artefacto generado.
- Resuelve componentes desde los directorios configurados; cada uno puede incluir
  `templates/` y `defaults/`.
- Los tipos de componente son `backend`, `frontend`, `cloud` y `root`.
- El componente `root` (`components/root/workspace`) se agrega una sola vez mediante
  `GenerationPlanBuilder.AddRootComponent` y genera `up.ps1` y `down.ps1` en la raíz.
- Genera un plan determinista por ambiente y renderiza placeholders antes de escribir.
- Valida toda la configuración antes de escribir para evitar salidas parciales.
- Rechaza rutas absolutas, segmentos `..`, rutas de salida duplicadas y conflictos
  de sobrescritura implícita.
- Valida entidades y relaciones bidireccionales. Los errores deben señalar el archivo
  y la propiedad pertinentes.

## Manifiesto `component.json`

- Solo se copian archivos y directorios declarados en `files` y `directories`.
- `files` mapea la ruta destino a la plantilla; `PlanExecutor` copia los archivos.
- Los archivos no declarados no se generan.
- Al agregar o renombrar una plantilla, actualiza `component.json` en el mismo cambio.

## Arquitectura

- `Program.cs`: composición de dependencias y códigos de salida.
- `Application/`: casos de uso, estado del plan, logger y puertos.
- Application accede al sistema de archivos solo mediante sus puertos; no usa
  directamente `File`, `Path` ni `Directory`.
- `Domain/`: modelos, validación y mensajes; no depende de Application ni Infrastructure,
  y no usa `System.IO`.
- `Infrastructure/`: implementaciones de los puertos de Application.
- `Configuration/`: constantes técnicas. `components/` y `target/` son datos;
  `docs/` contiene planes y decisiones.
- Dependencias permitidas: Infrastructure → Application → Domain, y Application → Domain.
  Domain no depende de las otras capas.
