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

        var variables = environment.Variables.ToDictionary(item => item.Key, item => (object?)item.Value, StringComparer.OrdinalIgnoreCase);
        variables = new Dictionary<string, object?>(variables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.ApplicationNameVariable] = configuration.ApplicationName,
            [GeneratorConstants.ApplicationIdVariable] = configuration.ApplicationId,
            [GeneratorConstants.ApplicationPackageVariable] = configuration.ApplicationId.Replace('.', Path.DirectorySeparatorChar),
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
            GeneratorLogger.Info($"Backend seleccionado para '{microservice.Name}': {microservice.Backend}");
            var componentDirectory = Path.GetDirectoryName(componentPath)!;
            var componentVariables = new Dictionary<string, object?>(variables, StringComparer.OrdinalIgnoreCase)
            {
                [GeneratorConstants.TemplateNameVariable] = microservice.Name,
                [GeneratorConstants.TemplateCompanyVariable] = GetCompanyName(configuration.ApplicationId),
                [GeneratorConstants.TemplateMicroserviceNameVariable] = microservice.Name,
                [GeneratorConstants.TemplatePortVariable] = microservice.Port.ToString(),
                [GeneratorConstants.TemplateGraalvmVariable] = "false",
                [GeneratorConstants.MicroserviceNameVariable] = microservice.Name,
                [GeneratorConstants.MicroservicePortVariable] = microservice.Port.ToString(),
                [GeneratorConstants.MicroserviceDeployVariable] = microservice.Deploy,
                [GeneratorConstants.BackendVariable] = microservice.Backend,
                [GeneratorConstants.EntitiesVariable] = jsonReader.Serialize(microservice.Entities),
                [GeneratorConstants.EndpointsVariable] = jsonReader.Serialize(microservice.Endpoints),
                ["ConsumedEvents"] = microservice.ConsumedEvents
            };

            foreach (var directory in component.Directories)
            {
                var target = RenderPath(Path.Combine("backend", directory), componentVariables);
                AddUnique(directories, paths, target, "directorio");
            }
            foreach (var file in component.Files)
            {
                var target = RenderPath(Path.Combine("backend", file.Key), componentVariables);
                AddUnique(files.Select(item => item.Key).ToList(), paths, target, "archivo");
                var templatePath = ResolveComponentSource(componentDirectory, file.Value);
                var content = File.ReadAllText(templatePath);
                files.Add(new PlanFile(target, templateRenderer.Render(content, componentVariables, templatePath)));
            }
            foreach (var defaultFile in component.DefaultFiles)
            {
                var source = ResolveComponentSource(componentDirectory, defaultFile);
                var target = Path.Combine("backend", pathValidator.DefaultOutputPath(defaultFile));
                AddUnique(defaultFiles.Select(item => item.Key).ToList(), paths, target, "archivo predeterminado");
                defaultFiles.Add(new PlanDefaultFile(target, Path.GetRelativePath(workingDirectory, source)));
            }
        }

        if (configuration.Frontend is not null)
        {
            var componentPath = ResolveSource(Path.Combine(
                GeneratorConstants.ComponentsDirectory,
                GeneratorConstants.FrontendComponentType,
                configuration.Frontend.Framework,
                "component.json"));
            var component = jsonReader.Read<ComponentDefinition>(componentPath);
            GeneratorLogger.Info($"Frontend seleccionado: '{configuration.Frontend.Framework}' ({configuration.Frontend.Name})");
            var componentDirectory = Path.GetDirectoryName(componentPath)!;
            var appIconPath = Path.Combine(Path.GetDirectoryName(inputPath) ?? workingDirectory, "app_icon.png");
            var hasAppIcon = File.Exists(appIconPath);
            var frontendVariables = new Dictionary<string, object?>(variables, StringComparer.OrdinalIgnoreCase)
            {
                [GeneratorConstants.TemplateNameVariable] = configuration.Frontend.Name,
                [GeneratorConstants.TemplateCompanyVariable] = GetCompanyName(configuration.ApplicationId),
                ["FRONTEND_NAME"] = configuration.Frontend.Name,
                ["FRONTEND_FRAMEWORK"] = configuration.Frontend.Framework,
                ["FRONTEND_VERSION"] = configuration.Frontend.Version ?? "1.0.0+1",
                ["HAS_APP_ICON"] = hasAppIcon
            };

            foreach (var directory in component.Directories)
            {
                var target = RenderPath(directory, frontendVariables);
                AddUnique(directories, paths, target, "directorio");
            }
            foreach (var file in component.Files)
            {
                var target = RenderPath(file.Key, frontendVariables);
                AddUnique(files.Select(item => item.Key).ToList(), paths, target, "archivo");
                var templatePath = ResolveComponentSource(componentDirectory, file.Value);
                var content = File.ReadAllText(templatePath);
                files.Add(new PlanFile(target, templateRenderer.Render(content, frontendVariables, templatePath)));
            }
            foreach (var defaultFile in component.DefaultFiles)
            {
                var source = ResolveComponentSource(componentDirectory, defaultFile);
                var target = Path.Combine("frontend", frontendVariables["FRONTEND_NAME"]?.ToString() ?? string.Empty, pathValidator.DefaultOutputPath(defaultFile));
                AddUnique(defaultFiles.Select(item => item.Key).ToList(), paths, target, "archivo predeterminado");
                defaultFiles.Add(new PlanDefaultFile(target, Path.GetRelativePath(workingDirectory, source)));
            }

            if (hasAppIcon)
            {
                var appIconTarget = Path.Combine("frontend", frontendVariables["FRONTEND_NAME"]?.ToString() ?? string.Empty, "assets", "icon", "app_icon.png");
                AddUnique(defaultFiles.Select(item => item.Key).ToList(), paths, appIconTarget, "archivo predeterminado");
                defaultFiles.Add(new PlanDefaultFile(appIconTarget, appIconPath));
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

    private string RenderPath(string path, IReadOnlyDictionary<string, object?> variables)
    {
        var renderedPath = templateRenderer.Render(path, variables, path);
        return pathValidator.NormalizeRelative(renderedPath);
    }

    private static string GetCompanyName(string applicationId)
    {
        var segments = applicationId.Split('.', StringSplitOptions.RemoveEmptyEntries);
        return segments.Length >= 2 ? segments[^2] : applicationId;
    }

    private static void AddUnique(ICollection<string> collection, HashSet<string> allPaths, string path, string kind)
    {
        if (!allPaths.Add(path))
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput(kind, path));
        collection.Add(path);
    }
}