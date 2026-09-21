using Amazon.CodeCommit;
using Amazon.CodeCommit.Model;

namespace Generator.Services;

internal interface ICodeCommitService
{
    Task PushFilesAsync(string projectDirectory, string repositoryName, string branchName, CancellationToken cancellationToken = default);
}

internal sealed class CodeCommitService : ICodeCommitService
{
    private readonly IAmazonCodeCommit _codeCommitClient;

    public CodeCommitService(string region)
    {
        var endpoint = Amazon.RegionEndpoint.GetBySystemName(region);
        _codeCommitClient = new AmazonCodeCommitClient(endpoint);
    }

    public async Task PushFilesAsync(string projectDirectory, string repositoryName, string branchName, CancellationToken cancellationToken = default)
    {
        var defaultBranch = "main";
        
        string parentCommitId;
        try
        {
            var branchResponse = await _codeCommitClient.GetBranchAsync(new GetBranchRequest
            {
                RepositoryName = repositoryName,
                BranchName = defaultBranch
            }, cancellationToken);
            parentCommitId = branchResponse.Branch.CommitId;
        }
        catch (BranchDoesNotExistException)
        {
            parentCommitId = null!;
        }

        var excludePatterns = new[] { ".git", ".dart_tool", ".pub-cache", ".pub", "key.properties", "upload-keystore.jks", ".jks", "codepipeline.yml", ".idea", ".vscode", "pubspec.lock", "local.properties" };
        var excludeDirPatterns = new[] { $"{Path.DirectorySeparatorChar}.gradle{Path.DirectorySeparatorChar}", $"/.gradle/" };
        var excludeDirs = new[] { "\\build\\", "/build/", "\\build/", "/build\\" };
        
        var files = Directory.GetFiles(projectDirectory, "*", SearchOption.AllDirectories)
            .Where(f => !excludePatterns.Any(pattern => f.Contains(pattern, StringComparison.OrdinalIgnoreCase))
                      && !excludeDirs.Any(d => f.Contains(d, StringComparison.OrdinalIgnoreCase))
                      && !excludeDirPatterns.Any(p => f.Contains(p, StringComparison.OrdinalIgnoreCase)))
            .ToList();

        GeneratorLogger.Info($"Total de archivos a subir: {files.Count}");

        const int batchSize = 50;
        int batchNumber = 0;
        
        for (int i = 0; i < files.Count; i += batchSize)
        {
            batchNumber++;
            var batch = files.Skip(i).Take(batchSize).ToList();
            var putFiles = new List<PutFileEntry>();
            
            foreach (var file in batch)
            {
                try
                {
                    var relativePath = Path.GetRelativePath(projectDirectory, file).Replace("\\", "/");
                    var content = await System.IO.File.ReadAllBytesAsync(file, cancellationToken);
                    
                    if (content.Length == 0)
                        continue;

                    putFiles.Add(new PutFileEntry
                    {
                        FilePath = relativePath,
                        FileContent = new MemoryStream(content, 0, content.Length, false, true)
                    });
                }
                catch (Exception ex)
                {
                    GeneratorLogger.Error($"Error leyendo archivo {file}: {ex.Message}");
                }
            }

            if (putFiles.Count > 0)
            {
                var retries = 3;
                for (int attempt = 1; attempt <= retries; attempt++)
                {
                    try
                    {
                        var commitResponse = await _codeCommitClient.CreateCommitAsync(new CreateCommitRequest
                        {
                            RepositoryName = repositoryName,
                            BranchName = parentCommitId is null ? defaultBranch : branchName,
                            CommitMessage = batchNumber == 1 ? "Initial commit from EPC Generator" : $"Update batch {batchNumber}",
                            ParentCommitId = parentCommitId,
                            PutFiles = putFiles
                        }, cancellationToken);

                        parentCommitId = commitResponse.CommitId;
                        GeneratorLogger.Info($"Batch {batchNumber} subido: {putFiles.Count} archivos");
                        break;
                    }
                    catch (Exception ex)
                    {
                        if (attempt == retries)
                        {
                            var inner = ex.InnerException?.Message ?? ex.Message;
                            GeneratorLogger.Error($"Error en batch {batchNumber} tras {retries} intentos: {inner}");
                        }
                        else
                        {
                            await Task.Delay(2000 * attempt, cancellationToken);
                        }
                    }
                }
            }
        }

        GeneratorLogger.Info("Proceso de subida completado");
    }
}
