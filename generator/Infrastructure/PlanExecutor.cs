using Generator.Application;
using Generator.Domain.Models;
using Generator.Domain.Messages;
using Generator.Domain.Validation;
using Generator.Configuration;

namespace Generator.Infrastructure;

internal sealed class PlanExecutor(string outputDirectory, string workingDirectory, IJsonFileReader jsonReader, IPathValidator paths) : IPlanExecutor
{
    public void Execute(GenerationPlan plan)
    {
        ValidateOutputPaths(plan);
        CreateDirectories(plan);
        WriteFiles(plan);
        CopyDefaultFiles(plan);
        WritePlanFile(plan);
    }

    private void CreateDirectories(GenerationPlan plan)
    {
        foreach (var directory in plan.Directories)
            CreateDirectory(directory);
    }

    private void CreateDirectory(string directory) => Directory.CreateDirectory(OutputPath(directory));

    private void WriteFiles(GenerationPlan plan)
    {
        foreach (var file in plan.Files)
            WriteFile(file);
    }

    private void WriteFile(PlanFile file)
    {
        var path = OutputPath(file.Key);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, file.Value);
    }

    private void CopyDefaultFiles(GenerationPlan plan)
    {
        foreach (var defaultFile in plan.DefaultFiles)
            CopyDefaultFile(defaultFile);
    }

    private void CopyDefaultFile(PlanDefaultFile defaultFile)
    {
        var source = Path.GetFullPath(defaultFile.Value, workingDirectory);
        var target = OutputPath(defaultFile.Key);
        Directory.CreateDirectory(Path.GetDirectoryName(target)!);
        File.Copy(source, target, overwrite: true);
    }

    private void WritePlanFile(GenerationPlan plan) =>
        File.WriteAllText(OutputPath(GeneratorConstants.GenerationPlanFileName), jsonReader.Serialize(plan));

    private void ValidateOutputPaths(GenerationPlan plan)
    {
        var fileTargets = ResolveFileTargets(plan);
        var directoryTargets = ResolveDirectoryTargets(plan);
        EnsureNoDuplicateTargets(fileTargets);
        EnsureNoPathConflicts(fileTargets, directoryTargets);
    }

    private List<string> ResolveFileTargets(GenerationPlan plan) =>
        plan.Files
            .Select(file => file.Key)
            .Concat(plan.DefaultFiles.Select(file => file.Key))
            .Append(GeneratorConstants.GenerationPlanFileName)
            .Select(OutputPath)
            .ToList();

    private List<string> ResolveDirectoryTargets(GenerationPlan plan) =>
        plan.Directories.Select(OutputPath).ToList();

    private static void EnsureNoDuplicateTargets(List<string> fileTargets)
    {
        // Windows-only (NTFS no distingue mayusculas): mantener OrdinalIgnoreCase.
        var duplicatePath = FindDuplicateTarget(fileTargets);
        if (duplicatePath is not null)
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput("archivo de salida", duplicatePath.Key));
    }

    private static IGrouping<string, string>? FindDuplicateTarget(List<string> fileTargets) =>
        fileTargets
            .GroupBy(path => path, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);

    private void EnsureNoPathConflicts(List<string> fileTargets, List<string> directoryTargets)
    {
        EnsureNoPlanOverlap(fileTargets, directoryTargets);
        EnsureNoAncestorConflicts(fileTargets, directoryTargets);
        EnsureNoDirectoryWhereFileExpected(fileTargets);
        EnsureNoFileWhereDirectoryExpected(directoryTargets);
    }

    private static void EnsureNoPlanOverlap(List<string> fileTargets, List<string> directoryTargets)
    {
        var overlappingPath = FindPlanOverlap(fileTargets, directoryTargets);
        if (overlappingPath is not null)
            throw PathConflict(overlappingPath);
    }

    private static string? FindPlanOverlap(List<string> fileTargets, List<string> directoryTargets)
    {
        var directoryTargetSet = CreateDirectoryTargetSet(directoryTargets);
        return fileTargets.FirstOrDefault(directoryTargetSet.Contains);
    }

    private void EnsureNoAncestorConflicts(List<string> fileTargets, List<string> directoryTargets)
    {
        var fileTargetSet = CreateFileTargetSet(fileTargets);
        foreach (var target in fileTargets.Concat(directoryTargets))
            EnsureAncestorsAreUsable(target, fileTargetSet);
    }

    private void EnsureAncestorsAreUsable(string target, HashSet<string> fileTargetSet)
    {
        var parent = Path.GetDirectoryName(target);
        while (IsInsideOutput(parent, outputDirectory))
            parent = MoveToParent(parent!, fileTargetSet);
    }

    private static string? MoveToParent(string parent, HashSet<string> fileTargetSet)
    {
        EnsureUsableAncestor(parent, fileTargetSet);
        return Path.GetDirectoryName(parent);
    }

    private static void EnsureUsableAncestor(string ancestor, HashSet<string> fileTargetSet)
    {
        if (IsBlockedByPlanFile(ancestor, fileTargetSet))
            throw PathConflict(ancestor);
    }

    private static bool IsBlockedByPlanFile(string ancestor, HashSet<string> fileTargetSet) =>
        fileTargetSet.Contains(ancestor) || File.Exists(ancestor);

    private static HashSet<string> CreateDirectoryTargetSet(List<string> directoryTargets) =>
        new HashSet<string>(directoryTargets, StringComparer.OrdinalIgnoreCase);

    private static HashSet<string> CreateFileTargetSet(List<string> fileTargets) =>
        new HashSet<string>(fileTargets, StringComparer.OrdinalIgnoreCase);

    private static void EnsureNoDirectoryWhereFileExpected(List<string> fileTargets)
    {
        foreach (var target in fileTargets)
            EnsureNotDirectory(target);
    }

    private static void EnsureNotDirectory(string target)
    {
        if (Directory.Exists(target))
            throw PathConflict(target);
    }

    private static void EnsureNoFileWhereDirectoryExpected(List<string> directoryTargets)
    {
        foreach (var directory in directoryTargets)
            EnsureNotFile(directory);
    }

    private static void EnsureNotFile(string directory)
    {
        if (File.Exists(directory))
            throw PathConflict(directory);
    }

    private static bool IsInsideOutput(string? path, string outputDirectory) =>
        path is not null && path.StartsWith(outputDirectory + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);

    private static GeneratorException PathConflict(string path) =>
        new(ErrorCodes.InvalidPath, GeneratorMessages.OutputPathConflict(path));

    private string OutputPath(string relativePath) => Path.GetFullPath(paths.NormalizeRelative(relativePath), outputDirectory);
}
