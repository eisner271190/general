namespace Generator.Validation;

internal interface IInverseRelationStrategy
{
    bool Supports(string relationType);
    string Inverse();
}
