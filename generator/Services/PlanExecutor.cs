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
        var outputPaths = plan.Files
            .Select(file => file.Key)
            .Concat(plan.DefaultFiles.Select(file => file.Key))
            .Append(GeneratorConstants.GenerationPlanFileName)
            .Select(OutputPath)
            .ToList();

        var duplicatePath = outputPaths
            .GroupBy(path => path, StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicatePath is not null)
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput("archivo de salida", duplicatePath.Key));

    }

    private string OutputPath(string relativePath) => Path.GetFullPath(paths.NormalizeRelative(relativePath), outputDirectory);
}