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
        var targetDirectory = Path.Combine(workingDirectory, GeneratorConstants.TargetDirectoryName);
        var legacyOutputDirectory = Path.Combine(targetDirectory, GeneratorConstants.OutputDirectoryName);
        var inputPaths = DiscoverConfigurations(targetDirectory, legacyOutputDirectory);

        if (inputPaths.Count == 0)
            throw new GeneratorException(ErrorCodes.NoInputConfigurations, GeneratorMessages.NoInputConfigurations(targetDirectory));

        GeneratorLogger.Info($"Configuraciones encontradas: {inputPaths.Count}");
        foreach (var inputPath in inputPaths)
            Generate(inputPath);
    }

    private List<string> DiscoverConfigurations(string targetDirectory, string outputRootDirectory)
    {
        GeneratorLogger.Debug($"Directorio de trabajo: {workingDirectory}");
        GeneratorLogger.Debug($"Directorio de configuraciones: {targetDirectory}");

        return Directory.Exists(targetDirectory)
            ? Directory.EnumerateFiles(targetDirectory, "*.json", SearchOption.AllDirectories)
                .Where(path => !path.StartsWith(outputRootDirectory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                .Where(path => !Path.GetFileName(path).Equals(GeneratorConstants.GenerationPlanFileName, StringComparison.OrdinalIgnoreCase))
                .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
                .ToList()
            : [];
    }

    private void Generate(string inputPath)
    {
        GeneratorLogger.Info($"Procesando: {inputPath}");
        var plan = planBuilder.Build(inputPath, requestedEnvironment: null);
        var workspaceDirectory = Directory.GetParent(workingDirectory)?.FullName
            ?? throw new DirectoryNotFoundException($"No se encontro la carpeta contenedora de '{workingDirectory}'.");
        var outputDirectory = Path.Combine(workspaceDirectory, GeneratorConstants.ProjectsDirectoryName, plan.ApplicationId);
        GeneratorLogger.Debug($"Directorio de salida: {outputDirectory}");

        var planExecutor = new PlanExecutor(outputDirectory, workingDirectory, jsonReader, pathValidator);
        planExecutor.Execute(plan);
        GeneratorLogger.Info($"Generacion completada: {Path.Combine(outputDirectory, GeneratorConstants.GenerationPlanFileName)}");
    }
}