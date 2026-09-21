using Generator.Configuration;
using Generator.Messages;
using Generator.Models;
using Generator.Validation;
using System.Linq;

namespace Generator.Services;

internal sealed class GeneratorApplication(
    string workingDirectory,
    GenerationPlanBuilder planBuilder,
    IJsonFileReader jsonReader,
    IPathValidator pathValidator,
    IAndroidSigningKeyGenerator signingKeyGenerator,
    ISecretsManager? secretsManager,
    IPipelineDeployer? pipelineDeployer,
    IGitService? gitService,
    string? region = null)
{
    public async Task RunAsync()
    {
        var executionTimer = System.Diagnostics.Stopwatch.StartNew();
        var targetDirectory = Path.Combine(workingDirectory, GeneratorConstants.TargetDirectoryName);
        var legacyOutputDirectory = Path.Combine(targetDirectory, GeneratorConstants.OutputDirectoryName);

        GeneratorLogger.Stage("Inicio de generacion");
        var inputPaths = DiscoverConfigurations(targetDirectory, legacyOutputDirectory);

        if (inputPaths.Count == 0)
            throw new GeneratorException(ErrorCodes.NoInputConfigurations, GeneratorMessages.NoInputConfigurations(targetDirectory));

        GeneratorLogger.Info($"Configuraciones detectadas: {inputPaths.Count}");

        var successCount = 0;
        var totalCount = inputPaths.Count;
        for (var i = 0; i < totalCount; i++)
        {
            var inputPath = inputPaths[i];
            await GenerateAsync(inputPath, i + 1, totalCount);
            successCount++;
        }

        executionTimer.Stop();
        GeneratorLogger.Stage("Generacion finalizada");
        GeneratorLogger.Info($"Resumen: OK={successCount}, Error={totalCount - successCount}, Duracion={executionTimer.Elapsed.TotalSeconds:F1}s");
    }

    private List<string> DiscoverConfigurations(string targetDirectory, string outputRootDirectory)
    {
        GeneratorLogger.Debug($"Workspace: {workingDirectory}");
        GeneratorLogger.Debug($"ConfigPath: {targetDirectory}");

        if (!Directory.Exists(targetDirectory))
            return [];

        return Directory.EnumerateDirectories(targetDirectory, "*", SearchOption.TopDirectoryOnly)
            .SelectMany(appDirectory => Directory.EnumerateFiles(appDirectory, "*.json", SearchOption.TopDirectoryOnly))
            .Where(path => !path.StartsWith(outputRootDirectory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            .Where(path => !Path.GetFileName(path).Equals(GeneratorConstants.GenerationPlanFileName, StringComparison.OrdinalIgnoreCase))
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private async Task GenerateAsync(string inputPath, int index, int total)
    {
        GeneratorLogger.Info($"({index}/{total}) Procesando: {Path.GetFileName(inputPath)}");
        var plan = planBuilder.Build(inputPath, requestedEnvironment: null);
        var configuration = jsonReader.Read<EpcConfiguration>(inputPath);
        var workspaceDirectory = Directory.GetParent(workingDirectory)?.FullName
            ?? throw new DirectoryNotFoundException($"No se encontro la carpeta contenedora de '{workingDirectory}'.");
        var outputDirectory = Path.Combine(workspaceDirectory, GeneratorConstants.ProjectsDirectoryName, plan.ApplicationId);
        GeneratorLogger.Debug($"OutputPath: {outputDirectory}");

        var planExecutor = new PlanExecutor(outputDirectory, workingDirectory, jsonReader, pathValidator);
        planExecutor.Execute(plan);
        GeneratorLogger.Info($"Plan generado: {Path.Combine(outputDirectory, GeneratorConstants.GenerationPlanFileName)}");

        if (configuration.Frontend?.Framework.StartsWith("flutter", StringComparison.OrdinalIgnoreCase) == true)
        {
            await CreateAndroidSigningSecretsAsync(plan.ApplicationId, outputDirectory);
            var deployer = await CreatePipelineDeployerAsync(configuration.Frontend);
            if (deployer is not null)
            {
                await deployer.DeployAsync(plan.ApplicationId, outputDirectory, configuration.Frontend.GitHubOwner, configuration.Frontend.GitHubRepo, configuration.Frontend.GitHubBranch);
            }
            
            var sourceProvider = configuration.Frontend.SourceProvider?.ToLowerInvariant() ?? "codecommit";
            if (sourceProvider == "codecommit" && !string.IsNullOrWhiteSpace(region))
            {
                // Copiar buildspec.yml a la raíz del proyecto para que CodeBuild lo encuentre
                var buildspecSource = Path.Combine(outputDirectory, "frontend", configuration.Frontend.Name, "buildspec.yml");
                var buildspecDest = Path.Combine(outputDirectory, "buildspec.yml");
                if (File.Exists(buildspecSource) && !File.Exists(buildspecDest))
                {
                    File.Copy(buildspecSource, buildspecDest);
                    GeneratorLogger.Info("buildspec.yml copiado a la raíz del proyecto");
                }

                var repoName = configuration.Frontend.GitHubRepo ?? plan.ApplicationId.Replace('.', '-').ToLowerInvariant();
                var branchName = configuration.Frontend.GitHubBranch ?? "main";
                var codeCommitService = new CodeCommitService(region);
                GeneratorLogger.Info($"Subiendo código a CodeCommit: {repoName}");
                await codeCommitService.PushFilesAsync(outputDirectory, repoName, branchName);
            }
        }
    }

    private async Task CreateAndroidSigningSecretsAsync(string applicationId, string outputDirectory)
    {
        var region = Environment.GetEnvironmentVariable(GeneratorConstants.AwsRegionVariable);
        if (string.IsNullOrWhiteSpace(region) || secretsManager is null)
            throw new GeneratorException(ErrorCodes.MissingAwsRegion, GeneratorMessages.MissingAwsRegion(GeneratorConstants.AwsRegionVariable));

        var prefix = $"{GeneratorConstants.AndroidSigningSecretPrefix}/{applicationId}/{GeneratorConstants.AndroidSigningSecretDirectory}";
        var references = new AndroidSigningSecretReferences(
            $"{prefix}/keystore",
            $"{prefix}/store-password",
            $"{prefix}/key-password",
            $"{prefix}/key-alias");
        

        AndroidSigningSecrets? secrets = null;

        try
        {
            GeneratorLogger.Info($"Intentando recuperar secretos existentes para '{applicationId}' en region {region}");
            secrets = await secretsManager.GetAsync(references, CancellationToken.None);
        }
        catch (Exception ex)
        {
            var caused = ex.InnerException is not null ? $" Caused by: {ex.InnerException.Message}" : string.Empty;
            GeneratorLogger.Error($"Error al recuperar secretos para '{applicationId}': {ex.Message}{caused}");
            // proceed to generation flow
        }

        if (secrets is not null)
        {
            GeneratorLogger.Info($"Se encontraron secretos existentes para '{applicationId}', asignando variables de entorno");
            Environment.SetEnvironmentVariable(GeneratorConstants.AndroidKeyAliasVariableFor(applicationId), secrets.KeyAlias, EnvironmentVariableTarget.User);
            Environment.SetEnvironmentVariable(GeneratorConstants.AndroidStorePasswordVariableFor(applicationId), secrets.StorePassword, EnvironmentVariableTarget.User);
            Environment.SetEnvironmentVariable(GeneratorConstants.AndroidKeyPasswordVariableFor(applicationId), secrets.KeyPassword, EnvironmentVariableTarget.User);

            // Write keystore bytes to a temp file and expose its path via env var
            var keystoreTemp = Path.Combine(Path.GetTempPath(), "epc-upload-keystore", applicationId.Replace('.', '-'));
            Directory.CreateDirectory(keystoreTemp);
            var keystorePath = Path.Combine(keystoreTemp, "upload-keystore.jks");
            await File.WriteAllBytesAsync(keystorePath, secrets.KeystoreBytes);
            Environment.SetEnvironmentVariable(GeneratorConstants.AndroidKeystoreFileVariableFor(applicationId), keystorePath, EnvironmentVariableTarget.User);
            GeneratorLogger.Info($"Keystore escrito temporalmente en: {keystorePath}");
            // Try to copy keystore and write key.properties into generated android project
            try
            {
                var androidDir = Directory.EnumerateDirectories(outputDirectory, "android", SearchOption.AllDirectories).FirstOrDefault();
                if (!string.IsNullOrEmpty(androidDir))
                {
                    var destKeystore = Path.Combine(androidDir, "upload-keystore.jks");
                    File.Copy(keystorePath, destKeystore, overwrite: true);
                    var keyProps = Path.Combine(androidDir, "key.properties");
                    var content = $"storePassword={secrets.StorePassword}\nkeyPassword={secrets.KeyPassword}\nkeyAlias={secrets.KeyAlias}\nstoreFile=upload-keystore.jks";
                    await File.WriteAllTextAsync(keyProps, content);
                    GeneratorLogger.Info($"Wrote key.properties to {keyProps}");
                }
            }
            catch (Exception ex)
            {
                GeneratorLogger.Error($"No se pudo escribir key.properties en output: {ex.Message}");
            }
            return;
        }

        // No existing secrets found -> generate new, set env vars and store
        try
        {
            GeneratorLogger.Info($"No se encontraron secretos; generando nuevos para '{applicationId}'");
            secrets = signingKeyGenerator.Generate(applicationId);
            GeneratorLogger.Info($"Keystore temporal generado, tamaño={secrets.KeystoreBytes.Length} bytes");
        }
        catch (Exception ex)
        {
            var caused = ex.InnerException is not null ? $" Caused by: {ex.InnerException.Message}" : string.Empty;
            GeneratorLogger.Error($"Error al generar upload keystore para '{applicationId}': {ex.Message}{caused}");
            throw new GeneratorException(ErrorCodes.SigningKeyCreationFailed, GeneratorMessages.SigningKeyCreationFailed(applicationId));
        }

        if (secrets.KeystoreBytes.Length > GeneratorConstants.MaximumSecretSizeInBytes)
            throw new GeneratorException(ErrorCodes.SigningSecretTooLarge, GeneratorMessages.SigningSecretTooLarge(GeneratorConstants.MaximumSecretSizeInBytes));

        try
        {
            GeneratorLogger.Info($"Almacenando secretos de firma en Secrets Manager para '{applicationId}' (region={region})");
            await secretsManager.StoreAsync(references, secrets, CancellationToken.None);
            GeneratorLogger.Info($"Secretos almacenados con éxito para '{applicationId}'");
        }
        catch (Exception ex)
        {
            var caused = ex.InnerException is not null ? $" Caused by: {ex.InnerException.Message}" : string.Empty;
            GeneratorLogger.Error($"Error al almacenar secretos para '{applicationId}': {ex.Message}{caused}");
            throw new GeneratorException(ErrorCodes.SigningSecretPersistenceFailed, GeneratorMessages.SigningSecretPersistenceFailed(applicationId));
        }

        // Set env vars and write keystore file for the new secrets
        Environment.SetEnvironmentVariable(GeneratorConstants.AndroidKeyAliasVariableFor(applicationId), secrets.KeyAlias, EnvironmentVariableTarget.User);
        Environment.SetEnvironmentVariable(GeneratorConstants.AndroidStorePasswordVariableFor(applicationId), secrets.StorePassword, EnvironmentVariableTarget.User);
        Environment.SetEnvironmentVariable(GeneratorConstants.AndroidKeyPasswordVariableFor(applicationId), secrets.KeyPassword, EnvironmentVariableTarget.User);
        var tempDir = Path.Combine(Path.GetTempPath(), "epc-upload-keystore", applicationId.Replace('.', '-'));
        Directory.CreateDirectory(tempDir);
        var tempKeystorePath = Path.Combine(tempDir, "upload-keystore.jks");
        await File.WriteAllBytesAsync(tempKeystorePath, secrets.KeystoreBytes);
        Environment.SetEnvironmentVariable(GeneratorConstants.AndroidKeystoreFileVariableFor(applicationId), tempKeystorePath, EnvironmentVariableTarget.User);
        GeneratorLogger.Info($"Keystore escrito temporalmente en: {tempKeystorePath}");

        // Try to copy keystore and write key.properties into generated android project
        try
        {
            var androidDir = Directory.EnumerateDirectories(outputDirectory, "android", SearchOption.AllDirectories).FirstOrDefault();
            if (!string.IsNullOrEmpty(androidDir))
            {
                var destKeystore = Path.Combine(androidDir, "upload-keystore.jks");
                File.Copy(tempKeystorePath, destKeystore, overwrite: true);
                var keyProps = Path.Combine(androidDir, "key.properties");
                var content = $"storePassword={secrets.StorePassword}\nkeyPassword={secrets.KeyPassword}\nkeyAlias={secrets.KeyAlias}\nstoreFile=upload-keystore.jks";
                await File.WriteAllTextAsync(keyProps, content);
                GeneratorLogger.Info($"Wrote key.properties to {keyProps}");
            }
        }
        catch (Exception ex)
        {
            GeneratorLogger.Error($"No se pudo escribir key.properties en output: {ex.Message}");
        }
    }

    private async Task<IPipelineDeployer?> CreatePipelineDeployerAsync(FrontendConfiguration frontend)
    {
        if (string.IsNullOrWhiteSpace(region))
        {
            GeneratorLogger.Info("AWS_REGION no configurado, saltando despliegue del pipeline");
            return null;
        }

        var sourceProvider = frontend.SourceProvider?.ToLowerInvariant() ?? "codecommit";
        IRepositoryProvider repositoryProvider = sourceProvider switch
        {
            "github" => new GitHubProvider(region),
            _ => new CodeCommitProvider(region)
        };

        GeneratorLogger.Info($"Usando proveedor de repositorio: {sourceProvider}");
        return new PipelineDeployer(region, repositoryProvider);
    }
}