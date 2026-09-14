namespace Generator.Models;

public sealed record BackendComponent(string Name, string Type, List<string> Directories, List<ComponentFile> Files, List<string> DefaultFiles);
public sealed record ComponentFile(string Key, string Value);