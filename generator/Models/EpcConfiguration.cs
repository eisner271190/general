namespace Generator.Models;

public sealed record EpcConfiguration(string ApplicationName, string ApplicationId, List<EnvironmentConfiguration> Environments, List<MicroserviceConfiguration> Microservices);
public sealed record EnvironmentConfiguration(string Name, Dictionary<string, string> Variables);
public sealed record MicroserviceConfiguration(string Name, string Backend, string Deploy, List<EntityConfiguration> Entities, List<EndpointConfiguration> Endpoints, int Port);
public sealed record EntityConfiguration(string Name, List<FieldConfiguration> Fields, List<RelationConfiguration> Relations);
public sealed record FieldConfiguration(string Name, string Datatype);
public sealed record RelationConfiguration(string Entity, string Type);
public sealed record EndpointConfiguration(string Method, string Path, Dictionary<string, string>? Parameters, string? Response);