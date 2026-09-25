using Generator.Models;

namespace Generator.Validation;

// Entidad que se valida y el indice de entidades del microservicio para resolver destinos.
internal sealed record EntityScope(EntityConfiguration Entity, Dictionary<string, EntityConfiguration> Entities);
