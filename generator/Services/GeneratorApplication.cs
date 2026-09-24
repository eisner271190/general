using System.Diagnostics;
using Generator.Configuration;
using Generator.Messages;
using Generator.Models;
using Generator.Validation;

namespace Generator.Services;

internal sealed class GeneratorApplication(
    string workingDirectory,
    GenerationPlanBuilder planBuilder,
    IPathValidator pathValidator,
    IPlanExecutorFactory planExecutorFactory)
{
    private sealed record PlannedGeneration(GenerationPlan Plan, string OutputDirectory);

    public void Run()
    {
        var executionTimer = Stopwatch.StartNew();
        GeneratorLogger.Info("Inicio de generacion");

        var targetDirectory = Path.Combine(workingDirectory, GeneratorConstants.TargetDirectoryName);
        // Excluye target/output (salida generada) del escaneo: sus JSON no son configuraciones de entrada.
        var excludedOutputDirectory = Path.Combine(targetDirectory, GeneratorConstants.OutputDirectoryName);

        var inputPaths = DiscoverConfigurations(targetDirectory, excludedOutputDirectory);
        EnsureInputs(inputPaths, targetDirectory);
        GeneratorLogger.Info($"Configuraciones detectadas: {inputPaths.Count}");

        var workspaceDirectory = ResolveWorkspaceDirectory();
        var plannedGenerations = PlanGenerations(inputPaths, workspaceDirectory);
        ExecuteAll(plannedGenerations);

        executionTimer.Stop();
        GeneratorLogger.Info("Generacion finalizada");
        LogSummary(plannedGenerations.Count, executionTimer.Elapsed);
    }

    private List<string> DiscoverConfigurations(string targetDirectory, string excludedRootDirectory)
    {
        GeneratorLogger.Debug($"Workspace: {workingDirectory}");
        GeneratorLogger.Debug($"ConfigPath: {targetDirectory}");

        if (!Directory.Exists(targetDirectory))
            return [];

        return Directory.EnumerateDirectories(targetDirectory, "*", SearchOption.TopDirectoryOnly)
            .SelectMany(appDirectory => Directory.EnumerateFiles(appDirectory, "*" + GeneratorConstants.JsonExtension, SearchOption.TopDirectoryOnly))
            .Where(path => !path.StartsWith(excludedRootDirectory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            .Where(IsConfigurationFile)
            .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    // Entradas validas: epc.json o <nombre-carpeta>.json; el resto de JSON de la carpeta se ignora.
    private static bool IsConfigurationFile(string path)
    {
        var fileName = Path.GetFileName(path);
        var applicationDirectory = Path.GetFileName(Path.GetDirectoryName(path)!);
        return fileName.Equals(GeneratorConstants.ConfigurationFileName, StringComparison.OrdinalIgnoreCase)
            || fileName.Equals($"{applicationDirectory}{GeneratorConstants.JsonExtension}", StringComparison.OrdinalIgnoreCase);
    }

    private static void EnsureInputs(IReadOnlyList<string> inputPaths, string targetDirectory)
    {
        if (inputPaths.Count == 0)
            throw new GeneratorException(ErrorCodes.NoInputConfigurations, GeneratorMessages.NoInputConfigurations(targetDirectory));
    }

    private string ResolveWorkspaceDirectory()
    {
        var trimmedWorkingDirectory = workingDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var workspaceDirectory = IsRoot(trimmedWorkingDirectory)
            ? null
            : Directory.GetParent(trimmedWorkingDirectory)?.FullName;

        return workspaceDirectory
            ?? throw new GeneratorException(ErrorCodes.WorkspaceNotFound, GeneratorMessages.WorkspaceNotFound(workingDirectory));
    }

    private static bool IsRoot(string path) =>
        path.Length == 0 || path.Equals(Path.GetPathRoot(path), StringComparison.OrdinalIgnoreCase);

    private List<PlannedGeneration> PlanGenerations(IReadOnlyList<string> inputPaths, string workspaceDirectory)
    {
        var plannedGenerations = new List<PlannedGeneration>();
        // Windows-only (NTFS no distingue mayusculas): mantener OrdinalIgnoreCase.
        var outputDirectories = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var index = 0;

        foreach (var inputPath in inputPaths)
        {
            index++;
            GeneratorLogger.Info($"({index}/{inputPaths.Count}) Procesando: {Path.GetFileName(inputPath)}");

            var plan = planBuilder.Build(inputPath, requestedEnvironment: null);
            var outputDirectory = ResolveOutputDirectory(plan.ApplicationId, workspaceDirectory);
            if (!outputDirectories.Add(outputDirectory))
                throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput("applicationId", plan.ApplicationId));

            GeneratorLogger.Debug($"OutputPath: {outputDirectory}");
            plannedGenerations.Add(new PlannedGeneration(plan, outputDirectory));
        }

        return plannedGenerations;
    }

    private string ResolveOutputDirectory(string applicationId, string workspaceDirectory)
    {
        var outputSegment = pathValidator.NormalizeOutputSegment(applicationId);
        return Path.Combine(workspaceDirectory, GeneratorConstants.ProjectsDirectoryName, outputSegment);
    }

    private void ExecuteAll(IReadOnlyList<PlannedGeneration> plannedGenerations)
    {
        foreach (var generation in plannedGenerations)
        {
            var planExecutor = planExecutorFactory.Create(generation.OutputDirectory);
            planExecutor.Execute(generation.Plan);
            GeneratorLogger.Info($"Plan generado: {Path.Combine(generation.OutputDirectory, GeneratorConstants.GenerationPlanFileName)}");
        }
    }

    private static void LogSummary(int generatedCount, TimeSpan duration) =>
        GeneratorLogger.Info($"Resumen: OK={generatedCount}, Duracion={duration.TotalSeconds:F1}s");
}
