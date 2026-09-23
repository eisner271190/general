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
            var microserviceVariables = new Dictionary<string, object?>(variables, StringComparer.OrdinalIgnoreCase)
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

            ProcessComponent(
                GeneratorConstants.BackendComponentType,
                microservice.Backend,
                "backend",
                null,
                microserviceVariables,
                directories, files, defaultFiles, paths);
        }

        if (configuration.Frontend is not null)
        {
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

            ProcessComponent(
                GeneratorConstants.FrontendComponentType,
                configuration.Frontend.Framework,
                null,
                Path.Combine("frontend", configuration.Frontend.Name),
                frontendVariables,
                directories, files, defaultFiles, paths);

            if (hasAppIcon)
            {
                var appIconTarget = Path.Combine("frontend", configuration.Frontend.Name, "assets", "icon", "app_icon.png");
                AddUnique(defaultFiles.Select(item => item.Key).ToList(), paths, appIconTarget, "archivo predeterminado");
                defaultFiles.Add(new PlanDefaultFile(appIconTarget, appIconPath));
            }
        }

        if (configuration.Cloud is not null)
        {
            var cloudName = configuration.Cloud.Name ?? configuration.Cloud.Provider;
            var cloudVariables = new Dictionary<string, object?>(variables, StringComparer.OrdinalIgnoreCase)
            {
                [GeneratorConstants.TemplateNameVariable] = cloudName,
                [GeneratorConstants.TemplateCompanyVariable] = GetCompanyName(configuration.ApplicationId)
            };

            foreach (var microservice in configuration.Microservices)
            {
                var microserviceCloudVariables = new Dictionary<string, object?>(cloudVariables, StringComparer.OrdinalIgnoreCase)
                {
                    [GeneratorConstants.MicroserviceNameVariable] = microservice.Name,
                    [GeneratorConstants.MicroservicePortVariable] = microservice.Port.ToString(),
                    [GeneratorConstants.TemplateMicroserviceNameVariable] = microservice.Name
                };

                ProcessComponent(
                    GeneratorConstants.CloudComponentType,
                    configuration.Cloud.Provider,
                    null,
                    null,
                    microserviceCloudVariables,
                    directories, files, defaultFiles, paths);
            }
        }

        return new GenerationPlan(configuration.ApplicationName, configuration.ApplicationId, environment.Name, directories, files, defaultFiles);
    }

    private void ProcessComponent(
        string componentType,
        string componentName,
        string? outputPrefix,
        string? defaultFilePrefix,
        IReadOnlyDictionary<string, object?> variables,
        List<string> directories,
        List<PlanFile> files,
        List<PlanDefaultFile> defaultFiles,
        HashSet<string> paths)
    {
        var componentPath = ResolveSource(Path.Combine(
            GeneratorConstants.ComponentsDirectory,
            componentType,
            componentName,
            "component.json"));
        var component = jsonReader.Read<ComponentDefinition>(componentPath);
        GeneratorLogger.Info($"Componente '{componentType}' seleccionado: {componentName}");
        var componentDirectory = Path.GetDirectoryName(componentPath)!;

        foreach (var directory in component.Directories)
        {
            var target = outputPrefix is not null
                ? RenderPath(Path.Combine(outputPrefix, directory), variables)
                : RenderPath(directory, variables);
            AddUnique(directories, paths, target, "directorio");
        }
        foreach (var file in component.Files)
        {
            var target = outputPrefix is not null
                ? RenderPath(Path.Combine(outputPrefix, file.Key), variables)
                : RenderPath(file.Key, variables);
            var templatePath = ResolveComponentSource(componentDirectory, file.Value);
            var content = templateRenderer.Render(File.ReadAllText(templatePath), variables, templatePath);
            if (string.IsNullOrWhiteSpace(content))
            {
                GeneratorLogger.Debug(GeneratorMessages.EmptyTemplateSkipped(file.Value, target));
                continue;
            }
            AddUnique(files.Select(item => item.Key).ToList(), paths, target, "archivo");
            files.Add(new PlanFile(target, content));
        }
        foreach (var defaultFile in component.DefaultFiles)
        {
            var source = ResolveComponentSource(componentDirectory, defaultFile);
            var prefix = defaultFilePrefix ?? outputPrefix;
            var target = prefix is not null
                ? Path.Combine(prefix, pathValidator.DefaultOutputPath(defaultFile))
                : pathValidator.DefaultOutputPath(defaultFile);
            AddUnique(defaultFiles.Select(item => item.Key).ToList(), paths, target, "archivo predeterminado");
            defaultFiles.Add(new PlanDefaultFile(target, Path.GetRelativePath(workingDirectory, source)));
        }
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
