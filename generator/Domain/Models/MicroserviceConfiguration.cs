namespace Generator.Domain.Models;

public sealed record MicroserviceConfiguration(string Name, string Backend, string Deploy, List<EntityConfiguration> Entities, List<EndpointConfiguration> Endpoints, int Port)
{
    public List<string> ConsumedEvents { get; init; } = [];
}
