namespace Generator.Domain.Models;

public sealed record CloudConfiguration(
    string Provider,
    string? Name = null,
    Dictionary<string, string>? Secrets = null,
    PipelineConfiguration? Pipeline = null);
