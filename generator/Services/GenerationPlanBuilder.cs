using Generator.Models;
using Generator.Messages;
using Generator.Validation;
using Generator.Configuration;

namespace Generator.Services;

internal sealed class GenerationPlanBuilder(
    string workingDirectory,
    IJsonFileReader jsonReader,
    IPathValidator pathValidator,
    IConfigurationValidator configurationValidator,
    ITemplateRenderer templateRenderer)
{
    public GenerationPlan Build(string inputPath, string? requestedEnvironment)
    {
        var configuration = jsonReader.Read<EpcConfiguration>(inputPath);
        configurationValidator.Validate(configuration);
        var environment = requestedEnvironment is null
            ? configuration.Environments[0]
            : configuration.Environments.FirstOrDefault(item => item.Name.Equals(requestedEnvironment, StringComparison.OrdinalIgnoreCase))
                ?? throw new GeneratorException(ErrorCodes.EnvironmentNotFound, GeneratorMessages.EnvironmentNotFound(requestedEnvironment));

        var variables = new Dictionary<string, string>(environment.Variables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.ApplicationNameVariable] = configuration.ApplicationName,
            [GeneratorConstants.ApplicationIdVariable] = configuration.ApplicationId,
            [GeneratorConstants.EnvironmentVariable] = environment.Name
        };
        var directories = new List<string>();
        var files = new List<PlanFile>();
        var defaultFiles = new List<PlanDefaultFile>();
        var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var microservice in configuration.Microservices)
        {
            var componentPath = ResolveSource(Path.Combine(
                GeneratorConstants.ComponentsDirectory,
                GeneratorConstants.BackendComponentType,
                microservice.Backend,
                "component.json"));
            var component = jsonReader.Read<BackendComponent>(componentPath);
            var componentDirectory = Path.GetDirectoryName(componentPath)!;
            var componentVariables = new Dictionary<string, string>(variables, StringComparer.OrdinalIgnoreCase)
            {
                [GeneratorConstants.MicroserviceNameVariable] = microservice.Name,
                [GeneratorConstants.MicroservicePortVariable] = microservice.Port.ToString(),
                [GeneratorConstants.MicroserviceDeployVariable] = microservice.Deploy,
                [GeneratorConstants.BackendVariable] = microservice.Backend,
                [GeneratorConstants.EntitiesVariable] = jsonReader.Serialize(microservice.Entities),
                [GeneratorConstants.EndpointsVariable] = jsonReader.Serialize(microservice.Endpoints)
            };

            foreach (var directory in component.Directories)
                AddUnique(directories, paths, directory, "directorio");
            foreach (var file in component.Files)
            {
                var target = pathValidator.NormalizeRelative(file.Key);
                AddUnique(files.Select(item => item.Key).ToList(), paths, target, "archivo");
                var templatePath = ResolveComponentSource(componentDirectory, file.Value);
                var content = File.ReadAllText(templatePath);
                files.Add(new PlanFile(target, templateRenderer.Render(content, componentVariables, templatePath)));
            }
            foreach (var defaultFile in component.DefaultFiles)
            {
                var source = ResolveComponentSource(componentDirectory, defaultFile);
                var target = pathValidator.DefaultOutputPath(defaultFile);
                AddUnique(defaultFiles.Select(item => item.Key).ToList(), paths, target, "archivo predeterminado");
                defaultFiles.Add(new PlanDefaultFile(target, Path.GetRelativePath(workingDirectory, source)));
            }
        }

        return new GenerationPlan(configuration.ApplicationName, configuration.ApplicationId, environment.Name, directories, files, defaultFiles);
    }

    private string ResolveSource(string relativePath)
    {
        var path = Path.GetFullPath(pathValidator.NormalizeRelative(relativePath), workingDirectory);
        if (!File.Exists(path))
            throw new FileNotFoundException(GeneratorMessages.MissingSourceFile(relativePath), path);
        return path;
    }

    private string ResolveComponentSource(string componentDirectory, string relativePath)
    {
        var path = Path.GetFullPath(pathValidator.NormalizeRelative(relativePath), componentDirectory);
        if (!File.Exists(path))
            throw new FileNotFoundException(GeneratorMessages.MissingComponentFile(relativePath), path);
        return path;
    }

    private static void AddUnique(ICollection<string> collection, HashSet<string> allPaths, string path, string kind)
    {
        if (!allPaths.Add(path))
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput(kind, path));
        collection.Add(path);
    }
}