namespace Generator.Models;

public sealed record EntityConfiguration(string Name, List<FieldConfiguration> Fields, List<RelationConfiguration> Relations);
