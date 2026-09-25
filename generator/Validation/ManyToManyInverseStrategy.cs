using Generator.Configuration;

namespace Generator.Validation;

internal sealed class ManyToManyInverseStrategy : IInverseRelationStrategy
{
    public bool Supports(string relationType) =>
        relationType.Equals(GeneratorConstants.ManyToManyRelation, StringComparison.OrdinalIgnoreCase);

    public string Inverse() => GeneratorConstants.ManyToManyRelation;
}
