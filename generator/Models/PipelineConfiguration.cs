namespace Generator.Models;

public sealed record PipelineConfiguration(
    string? RepoName = null,
    string? Branch = null,
    string? TfVersion = null);
