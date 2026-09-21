namespace Generator.Services;

internal interface IRepositoryProvider
{
    Task<string> CreateRepositoryAsync(string repoName, string branchName, CancellationToken cancellationToken = default);
    string GetSourceActionProvider();
    Dictionary<string, string> GetSourceConfiguration(string repoName, string branchName, string? connectionArn = null);
}
