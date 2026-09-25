using Generator.Messages;
using Generator.Models;

namespace Generator.Validation;

internal sealed class EntityRelationRule(IEnumerable<IInverseRelationStrategy> inverseStrategies) : IValidationRule
{
    public void Validate(EpcConfiguration configuration)
    {
        foreach (var microservice in configuration.Microservices)
            ValidateMicroservice(microservice);
    }

    private void ValidateMicroservice(MicroserviceConfiguration microservice)
    {
        EnsureNoDuplicateEntities(microservice);
        var entities = BuildEntityIndex(microservice);
        foreach (var entity in microservice.Entities)
            ValidateEntityRelations(entity, entities);
    }

    private void ValidateEntityRelations(EntityConfiguration entity, Dictionary<string, EntityConfiguration> entities)
    {
        var scope = CreateScope(entity, entities);
        foreach (var relation in entity.Relations)
            ValidateRelation(relation, scope);
    }

    private void ValidateRelation(RelationConfiguration relation, EntityScope scope)
    {
        var context = CreateRelationContext(relation, scope);
        EnsureInverseExists(context);
    }

    private RelationContext CreateRelationContext(RelationConfiguration relation, EntityScope scope) =>
        new RelationContext(
            scope.Entity,
            relation,
            FindTarget(scope.Entities, relation),
            ResolveInverseType(relation.Type));

    private static EntityScope CreateScope(EntityConfiguration entity, Dictionary<string, EntityConfiguration> entities) =>
        new EntityScope(entity, entities);

    private static EntityConfiguration FindTarget(Dictionary<string, EntityConfiguration> entities, RelationConfiguration relation) =>
        entities.TryGetValue(relation.Entity, out var target)
            ? target
            : throw new GeneratorException(ErrorCodes.EntityNotFound, GeneratorMessages.EntityNotFound(relation.Entity));

    private void EnsureInverseExists(RelationContext context)
    {
        if (!HasInverseRelation(context))
            throw new GeneratorException(ErrorCodes.InvalidRelation, GeneratorMessages.InvalidRelation(context.Source.Name, context.Relation.Entity));
    }

    private static bool HasInverseRelation(RelationContext context)
    {
        if (context.InverseType is null)
            return false;
        return context.Target.Relations.Any(item => IsInverseMatch(item, context));
    }

    private static bool IsInverseMatch(RelationConfiguration item, RelationContext context) =>
        item.Entity.Equals(context.Source.Name, StringComparison.OrdinalIgnoreCase)
            && string.Equals(item.Type, context.InverseType, StringComparison.OrdinalIgnoreCase);

    private string? ResolveInverseType(string relationType)
    {
        var strategy = inverseStrategies.FirstOrDefault(item => item.Supports(relationType));
        return strategy?.Inverse();
    }

    private static void EnsureNoDuplicateEntities(MicroserviceConfiguration microservice)
    {
        var duplicatedEntity = FindDuplicatedEntity(microservice);
        if (duplicatedEntity is not null)
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.DuplicateEntity(duplicatedEntity.Key));
    }

    private static IGrouping<string, EntityConfiguration>? FindDuplicatedEntity(MicroserviceConfiguration microservice) =>
        microservice.Entities
            .GroupBy(item => item.Name, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);

    private static Dictionary<string, EntityConfiguration> BuildEntityIndex(MicroserviceConfiguration microservice) =>
        microservice.Entities.ToDictionary(item => item.Name, StringComparer.OrdinalIgnoreCase);
}
