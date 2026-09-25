using Generator.Configuration;

namespace Generator.Domain.Validation;

internal sealed class OneToOneInverseStrategy : IInverseRelationStrategy
{
    public bool Supports(string relationType) =>
        relationType.Equals(GeneratorConstants.OneToOneRelation, StringComparison.OrdinalIgnoreCase);

    public string Inverse() => GeneratorConstants.OneToOneRelation;
}
