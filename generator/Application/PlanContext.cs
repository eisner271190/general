using Generator.Domain.Models;

namespace Generator.Application;

// Contexto de construccion del plan: configuracion de entrada, variables de plantilla y estado
// acumulado. Los contextos de componente añaden componente, prefijos de salida y directorio.
internal sealed record PlanContext(
    EpcConfiguration Configuration,
    string InputPath,
    IReadOnlyDictionary<string, object?> Variables,
    PlanState State,
    ComponentRef? Component = null,
    string? OutputPrefix = null,
    string? DefaultFilePrefix = null,
    string? ComponentDirectory = null);
