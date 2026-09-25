namespace Generator.Application;

// Entrada a planificar y su posicion dentro del lote (para el log indice/total).
internal sealed record PlanRequest(string InputPath, int Index, int Total);
