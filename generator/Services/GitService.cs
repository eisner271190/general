using System.Diagnostics;

namespace Generator.Services;

internal interface IGitService
{
    Task PushToCodeCommitAsync(string projectDirectory, string repositoryName, string branchName, CancellationToken cancellationToken = default);
}

internal sealed class GitService : IGitService
{
    private readonly string _region;

    public GitService(string region)
    {
        _region = region;
    }

    public async Task PushToCodeCommitAsync(string projectDirectory, string repositoryName, string branchName, CancellationToken cancellationToken = default)
    {
        var remoteUrl = $"https://git-codecommit.{_region}.amazonaws.com/v1/repos/{repositoryName}";

        GeneratorLogger.Info($"Inicializando repositorio git en {projectDirectory}");
        await RunGitCommandAsync(projectDirectory, "init", cancellationToken);
        await RunGitCommandAsync(projectDirectory, $"remote add codecommit {remoteUrl}", cancellationToken);

        GeneratorLogger.Info("Agregando archivos al repositorio");
        await RunGitCommandAsync(projectDirectory, "add .", cancellationToken);

        GeneratorLogger.Info("Creando commit inicial");
        await RunGitCommandAsync(projectDirectory, "commit -m \"Initial commit from EPC Generator\"", cancellationToken);

        GeneratorLogger.Info($"Push a CodeCommit: {repositoryName}");
        await RunGitCommandAsync(projectDirectory, $"push codecommit {branchName} --force", cancellationToken);

        GeneratorLogger.Info("Código subido exitosamente a CodeCommit");
    }

    private async Task RunGitCommandAsync(string workingDirectory, string arguments, CancellationToken cancellationToken)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = "git",
                Arguments = arguments,
                WorkingDirectory = workingDirectory,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        process.Start();
        await process.WaitForExitAsync(cancellationToken);

        if (process.ExitCode != 0)
        {
            var error = await process.StandardError.ReadToEndAsync(cancellationToken);
            if (!string.IsNullOrWhiteSpace(error))
                GeneratorLogger.Error($"Git error: {error}");
        }
    }
}
