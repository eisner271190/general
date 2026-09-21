using Amazon.CodeCommit;
using Amazon.CodeCommit.Model;

namespace Generator.Services;

internal sealed class CodeCommitProvider : IRepositoryProvider
{
    private readonly IAmazonCodeCommit _codeCommitClient;

    public CodeCommitProvider(string region)
    {
        var endpoint = Amazon.RegionEndpoint.GetBySystemName(region);
        _codeCommitClient = new AmazonCodeCommitClient(endpoint);
    }

    public async Task<string> CreateRepositoryAsync(string repoName, string branchName, CancellationToken cancellationToken = default)
    {
        try
        {
            await _codeCommitClient.GetRepositoryAsync(new GetRepositoryRequest { RepositoryName = repoName }, cancellationToken);
            GeneratorLogger.Info($"Repositorio CodeCommit {repoName} ya existe");
        }
        catch (RepositoryDoesNotExistException)
        {
            await _codeCommitClient.CreateRepositoryAsync(new CreateRepositoryRequest
            {
                RepositoryName = repoName
            }, cancellationToken);
            GeneratorLogger.Info($"Repositorio CodeCommit {repoName} creado");
        }

        return repoName;
    }

    public string GetSourceActionProvider() => "CodeCommit";

    public Dictionary<string, string> GetSourceConfiguration(string repoName, string branchName, string? connectionArn = null)
    {
        return new Dictionary<string, string>
        {
            { "RepositoryName", repoName },
            { "BranchName", branchName },
            { "PollForSourceChanges", "false" }
        };
    }
}
