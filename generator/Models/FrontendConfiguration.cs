namespace Generator.Models;

public sealed record FrontendConfiguration(
    string Name,
    string Framework,
    List<string>? Platforms = null,
    string? Version = null);
