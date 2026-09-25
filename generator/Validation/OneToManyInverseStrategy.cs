using Generator.Configuration;

namespace Generator.Validation;

internal sealed class OneToManyInverseStrategy : IInverseRelationStrategy
{
    public bool Supports(string relationType) =>
        relationType.Equals(GeneratorConstants.OneToManyRelation, StringComparison.OrdinalIgnoreCase);

    public string Inverse() => GeneratorConstants.ManyToOneRelation;
}
