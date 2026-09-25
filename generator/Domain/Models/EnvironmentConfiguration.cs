namespace Generator.Domain.Models;

public sealed record EnvironmentConfiguration(string Name, Dictionary<string, string> Variables);
