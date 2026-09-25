namespace Generator.Domain.Models;

public sealed record ComponentDefinition(string Name, string Type, List<string> Directories, List<ComponentFile> Files, List<string> DefaultFiles);
