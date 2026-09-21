namespace Generator.Models;

public sealed record EpcConfiguration(
    string ApplicationName,
    string ApplicationId,
    List<EnvironmentConfiguration> Environments,
    List<MicroserviceConfiguration> Microservices,
    FrontendConfiguration? Frontend = null,
    CloudConfiguration? Cloud = null);

public sealed record CloudConfiguration(string Provider, string? Name = null);

public sealed record FrontendConfiguration(
    string Name,
    string Framework,
    List<string>? Platforms = null,
    string? Version = null,
    string? SourceProvider = null,
    string? GitHubOwner = null,
    string? GitHubRepo = null,
    string? GitHubBranch = null);

public sealed record EnvironmentConfiguration(string Name, Dictionary<string, string> Variables);
public sealed record MicroserviceConfiguration(string Name, string Backend, string Deploy, List<EntityConfiguration> Entities, List<EndpointConfiguration> Endpoints, int Port)
{
	public List<string> ConsumedEvents { get; init; } = [];
}
public sealed record EntityConfiguration(string Name, List<FieldConfiguration> Fields, List<RelationConfiguration> Relations);
public sealed record FieldConfiguration(string Name, string Datatype);
public sealed record RelationConfiguration(string Entity, string Type);
public sealed record EndpointConfiguration(string Method, string Path, Dictionary<string, string>? Parameters, string? Response);