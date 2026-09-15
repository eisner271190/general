using Generator.Configuration;
using Generator.Messages;
using Generator.Validation;

namespace Generator.Services;

internal sealed class GeneratorApplication(
    string workingDirectory,
    GenerationPlanBuilder planBuilder,
    IJsonFileReader jsonReader,
    IPathValidator pathValidator)
{
    public void Run()
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
            Generate(inputPath, i + 1, totalCount);
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

        return Directory.Exists(targetDirectory)
            ? Directory.EnumerateFiles(targetDirectory, "*.json", SearchOption.AllDirectories)
                .Where(path => !path.StartsWith(outputRootDirectory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                .Where(path => !Path.GetFileName(path).Equals(GeneratorConstants.GenerationPlanFileName, StringComparison.OrdinalIgnoreCase))
                .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
                .ToList()
            : [];
    }

    private void Generate(string inputPath, int index, int total)
    {
        GeneratorLogger.Info($"({index}/{total}) Procesando: {Path.GetFileName(inputPath)}");
        var plan = planBuilder.Build(inputPath, requestedEnvironment: null);
        var workspaceDirectory = Directory.GetParent(workingDirectory)?.FullName
            ?? throw new DirectoryNotFoundException($"No se encontro la carpeta contenedora de '{workingDirectory}'.");
        var outputDirectory = Path.Combine(workspaceDirectory, GeneratorConstants.ProjectsDirectoryName, plan.ApplicationId);
        GeneratorLogger.Debug($"OutputPath: {outputDirectory}");

        var planExecutor = new PlanExecutor(outputDirectory, workingDirectory, jsonReader, pathValidator);
        planExecutor.Execute(plan);
        GeneratorLogger.Info($"Plan generado: {Path.Combine(outputDirectory, GeneratorConstants.GenerationPlanFileName)}");
    }
}