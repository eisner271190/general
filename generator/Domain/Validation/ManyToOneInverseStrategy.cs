using Generator.Configuration;

namespace Generator.Domain.Validation;

internal sealed class ManyToOneInverseStrategy : IInverseRelationStrategy
{
    public bool Supports(string relationType) =>
        relationType.Equals(GeneratorConstants.ManyToOneRelation, StringComparison.OrdinalIgnoreCase);

    public string Inverse() => GeneratorConstants.OneToManyRelation;
}
