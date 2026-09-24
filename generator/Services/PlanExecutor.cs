using Generator.Models;
using Generator.Messages;
using Generator.Validation;
using Generator.Configuration;

namespace Generator.Services;

internal interface IPlanExecutor
{
    void Execute(GenerationPlan plan);
}

internal sealed class PlanExecutor(string outputDirectory, string workingDirectory, IJsonFileReader jsonReader, IPathValidator paths) : IPlanExecutor
{
    public void Execute(GenerationPlan plan)
    {
        ValidateOutputPaths(plan);

        foreach (var directory in plan.Directories)
            Directory.CreateDirectory(OutputPath(directory));

        foreach (var file in plan.Files)
        {
            var path = OutputPath(file.Key);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, file.Value);
        }

        foreach (var defaultFile in plan.DefaultFiles)
        {
            var source = Path.GetFullPath(defaultFile.Value, workingDirectory);
            var target = OutputPath(defaultFile.Key);
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            File.Copy(source, target, overwrite: true);
        }

        File.WriteAllText(OutputPath(GeneratorConstants.GenerationPlanFileName), jsonReader.Serialize(plan));
    }

    private void ValidateOutputPaths(GenerationPlan plan)
    {
        var fileTargets = plan.Files
            .Select(file => file.Key)
            .Concat(plan.DefaultFiles.Select(file => file.Key))
            .Append(GeneratorConstants.GenerationPlanFileName)
            .Select(OutputPath)
            .ToList();
        var directoryTargets = plan.Directories.Select(OutputPath).ToList();

        EnsureNoDuplicateTargets(fileTargets);
        EnsureNoPathConflicts(fileTargets, directoryTargets);
    }

    private static void EnsureNoDuplicateTargets(List<string> fileTargets)
    {
        // Windows-only (NTFS no distingue mayusculas): mantener OrdinalIgnoreCase.
        var duplicatePath = fileTargets
            .GroupBy(path => path, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicatePath is not null)
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput("archivo de salida", duplicatePath.Key));
    }

    private void EnsureNoPathConflicts(List<string> fileTargets, List<string> directoryTargets)
    {
        EnsureNoPlanOverlap(fileTargets, directoryTargets);

        var fileTargetSet = new HashSet<string>(fileTargets, StringComparer.OrdinalIgnoreCase);
        foreach (var target in fileTargets.Concat(directoryTargets))
            EnsureNoAncestorConflicts(target, fileTargetSet);

        foreach (var target in fileTargets)
        {
            if (Directory.Exists(target))
                throw PathConflict(target);
        }

        foreach (var directory in directoryTargets)
        {
            if (File.Exists(directory))
                throw PathConflict(directory);
        }
    }

    private static void EnsureNoPlanOverlap(List<string> fileTargets, List<string> directoryTargets)
    {
        var directoryTargetSet = new HashSet<string>(directoryTargets, StringComparer.OrdinalIgnoreCase);
        var overlappingPath = fileTargets.FirstOrDefault(directoryTargetSet.Contains);
        if (overlappingPath is not null)
            throw PathConflict(overlappingPath);
    }

    private void EnsureNoAncestorConflicts(string target, HashSet<string> fileTargetSet)
    {
        var parent = Path.GetDirectoryName(target);
        while (IsInsideOutput(parent))
        {
            if (fileTargetSet.Contains(parent!) || File.Exists(parent))
                throw PathConflict(parent!);
            parent = Path.GetDirectoryName(parent);
        }
    }

    private bool IsInsideOutput(string? path) =>
        path is not null && path.StartsWith(outputDirectory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);

    private static GeneratorException PathConflict(string path) =>
        new(ErrorCodes.InvalidPath, GeneratorMessages.OutputPathConflict(path));

    private string OutputPath(string relativePath) => Path.GetFullPath(paths.NormalizeRelative(relativePath), outputDirectory);
}

internal interface IPlanExecutorFactory
{
    IPlanExecutor Create(string outputDirectory);
}

internal sealed class PlanExecutorFactory(string workingDirectory, IJsonFileReader jsonReader, IPathValidator pathValidator) : IPlanExecutorFactory
{
    public IPlanExecutor Create(string outputDirectory) =>
        new PlanExecutor(outputDirectory, workingDirectory, jsonReader, pathValidator);
}