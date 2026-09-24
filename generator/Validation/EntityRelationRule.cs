using Generator.Messages;
using Generator.Models;
using Generator.Configuration;

namespace Generator.Validation;

internal sealed class EntityRelationRule : IValidationRule
{
    public void Validate(EpcConfiguration configuration)
    {
        foreach (var microservice in configuration.Microservices)
        {
            EnsureNoDuplicateEntities(microservice);
            var entities = microservice.Entities.ToDictionary(item => item.Name, StringComparer.OrdinalIgnoreCase);
            foreach (var entity in microservice.Entities)
            foreach (var relation in entity.Relations)
            {
                if (!entities.TryGetValue(relation.Entity, out var target))
                    throw new GeneratorException(ErrorCodes.EntityNotFound, GeneratorMessages.EntityNotFound(relation.Entity));

                var inverseType = InverseRelationType(relation.Type);
                if (inverseType is null || !target.Relations.Any(item => item.Entity.Equals(entity.Name, StringComparison.OrdinalIgnoreCase) && item.Type.Equals(inverseType, StringComparison.OrdinalIgnoreCase)))
                    throw new GeneratorException(ErrorCodes.InvalidRelation, GeneratorMessages.InvalidRelation(entity.Name, relation.Entity));
            }
        }
    }

    private static void EnsureNoDuplicateEntities(MicroserviceConfiguration microservice)
    {
        var duplicatedEntity = microservice.Entities
            .GroupBy(item => item.Name, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicatedEntity is not null)
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.DuplicateEntity(duplicatedEntity.Key));
    }

    private static string? InverseRelationType(string relationType) => relationType.ToLowerInvariant() switch
    {
        GeneratorConstants.OneToOneRelation => GeneratorConstants.OneToOneRelation,
        GeneratorConstants.OneToManyRelation => GeneratorConstants.ManyToOneRelation,
        GeneratorConstants.ManyToOneRelation => GeneratorConstants.OneToManyRelation,
        GeneratorConstants.ManyToManyRelation => GeneratorConstants.ManyToManyRelation,
        _ => null
    };
}