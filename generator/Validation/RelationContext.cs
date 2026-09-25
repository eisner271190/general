using Generator.Models;

namespace Generator.Validation;

// Relacion resuelta: origen, datos de la relacion, destino y tipo inverso esperado (nulo si el tipo es desconocido).
internal sealed record RelationContext(
    EntityConfiguration Source,
    RelationConfiguration Relation,
    EntityConfiguration Target,
    string? InverseType);
