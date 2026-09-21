using Amazon.CodeConnections;
using Amazon.CodeConnections.Model;

namespace Generator.Services;

internal sealed class GitHubProvider : IRepositoryProvider
{
    private readonly IAmazonCodeConnections _codeConnectionsClient;
    private readonly string _region;

    public GitHubProvider(string region)
    {
        _region = region;
        var endpoint = Amazon.RegionEndpoint.GetBySystemName(region);
        _codeConnectionsClient = new AmazonCodeConnectionsClient(endpoint);
    }

    public async Task<string> CreateRepositoryAsync(string repoName, string branchName, CancellationToken cancellationToken = default)
    {
        var connectionName = $"{repoName}-github";

        try
        {
            var response = await _codeConnectionsClient.CreateConnectionAsync(new CreateConnectionRequest
            {
                ConnectionName = connectionName,
                ProviderType = ProviderType.GitHub
            }, cancellationToken);
            GeneratorLogger.Info($"Conexión GitHub {connectionName} creada");
            return response.ConnectionArn;
        }
        catch (ResourceNotFoundException)
        {
            var connections = await _codeConnectionsClient.ListConnectionsAsync(new ListConnectionsRequest(), cancellationToken);
            var existing = connections.Connections.FirstOrDefault(c => c.ConnectionName == connectionName);
            if (existing is not null)
            {
                GeneratorLogger.Info($"Conexión GitHub {connectionName} ya existe");
                return existing.ConnectionArn;
            }
            throw;
        }
    }

    public string GetSourceActionProvider() => "CodeStarSourceConnection";

    public Dictionary<string, string> GetSourceConfiguration(string repoName, string branchName, string? connectionArn = null)
    {
        return new Dictionary<string, string>
        {
            { "ConnectionArn", connectionArn ?? "" },
            { "FullRepositoryId", repoName },
            { "BranchName", branchName },
            { "DetectChanges", "true" }
        };
    }
}
