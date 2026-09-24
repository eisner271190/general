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
    private sealed class PlanState
    {
        public List<string> Directories { get; } = [];
        public List<PlanFile> Files { get; } = [];
        public List<PlanDefaultFile> DefaultFiles { get; } = [];
        public HashSet<string> Paths { get; } = new(StringComparer.OrdinalIgnoreCase);
    }

    public GenerationPlan Build(string inputPath, string? requestedEnvironment)
    {
        var configuration = jsonReader.Read<EpcConfiguration>(inputPath);
        configurationValidator.Validate(configuration);
        var environment = ResolveEnvironment(configuration, requestedEnvironment);
        var variables = BuildVariables(configuration, environment);
        var state = new PlanState();

        AddBackendComponents(configuration, variables, state);
        AddFrontendComponent(configuration, inputPath, variables, state);
        AddCloudComponents(configuration, variables, state);

        return new GenerationPlan(configuration.ApplicationName, configuration.ApplicationId, environment.Name, state.Directories, state.Files, state.DefaultFiles);
    }

    private static EnvironmentConfiguration ResolveEnvironment(EpcConfiguration configuration, string? requestedEnvironment)
    {
        if (requestedEnvironment is null)
            return configuration.Environments[0];

        return configuration.Environments.FirstOrDefault(item => item.Name.Equals(requestedEnvironment, StringComparison.OrdinalIgnoreCase))
            ?? throw new GeneratorException(ErrorCodes.EnvironmentNotFound, GeneratorMessages.EnvironmentNotFound(requestedEnvironment));
    }

    private static Dictionary<string, object?> BuildVariables(EpcConfiguration configuration, EnvironmentConfiguration environment)
    {
        var environmentVariables = environment.Variables.ToDictionary(item => item.Key, item => (object?)item.Value, StringComparer.OrdinalIgnoreCase);
        return new Dictionary<string, object?>(environmentVariables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.ApplicationNameVariable] = configuration.ApplicationName,
            [GeneratorConstants.ApplicationIdVariable] = configuration.ApplicationId,
            [GeneratorConstants.ApplicationPackageVariable] = configuration.ApplicationId.Replace('.', Path.DirectorySeparatorChar),
            [GeneratorConstants.EnvironmentVariable] = environment.Name
        };
    }

    private void AddBackendComponents(EpcConfiguration configuration, IReadOnlyDictionary<string, object?> variables, PlanState state)
    {
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
                [GeneratorConstants.ConsumedEventsVariable] = microservice.ConsumedEvents
            };

            ProcessComponent(GeneratorConstants.BackendComponentType, microservice.Backend, "backend", null, microserviceVariables, state);
        }
    }

    private void AddFrontendComponent(EpcConfiguration configuration, string inputPath, IReadOnlyDictionary<string, object?> variables, PlanState state)
    {
        if (configuration.Frontend is null)
            return;

        var appIconPath = Path.Combine(Path.GetDirectoryName(inputPath) ?? workingDirectory, "app_icon.png");
        var hasAppIcon = File.Exists(appIconPath);
        var frontendVariables = new Dictionary<string, object?>(variables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.TemplateNameVariable] = configuration.Frontend.Name,
            [GeneratorConstants.TemplateCompanyVariable] = GetCompanyName(configuration.ApplicationId),
            [GeneratorConstants.FrontendNameVariable] = configuration.Frontend.Name,
            [GeneratorConstants.FrontendFrameworkVariable] = configuration.Frontend.Framework,
            [GeneratorConstants.FrontendVersionVariable] = configuration.Frontend.Version ?? "1.0.0+1",
            [GeneratorConstants.HasAppIconVariable] = hasAppIcon
        };

        ProcessComponent(
            GeneratorConstants.FrontendComponentType,
            configuration.Frontend.Framework,
            null,
            Path.Combine("frontend", configuration.Frontend.Name),
            frontendVariables,
            state);

        if (hasAppIcon)
        {
            var appIconTarget = Path.Combine("frontend", configuration.Frontend.Name, "assets", "icon", "app_icon.png");
            EnsureUniquePath(state.Paths, appIconTarget, "archivo predeterminado");
            state.DefaultFiles.Add(new PlanDefaultFile(appIconTarget, appIconPath));
        }
    }

    private void AddCloudComponents(EpcConfiguration configuration, IReadOnlyDictionary<string, object?> variables, PlanState state)
    {
        if (configuration.Cloud is null)
            return;

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
                [GeneratorConstants.TemplateMicroserviceNameVariable] = microservice.Name,
                [GeneratorConstants.ConsumedEventsVariable] = microservice.ConsumedEvents
            };

            ProcessComponent(GeneratorConstants.CloudComponentType, configuration.Cloud.Provider, null, null, microserviceCloudVariables, state);
        }
    }

    private void ProcessComponent(
        string componentType,
        string componentName,
        string? outputPrefix,
        string? defaultFilePrefix,
        IReadOnlyDictionary<string, object?> variables,
        PlanState state)
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
            EnsureUniquePath(state.Paths, target, "directorio");
            state.Directories.Add(target);
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
            EnsureUniquePath(state.Paths, target, "archivo");
            state.Files.Add(new PlanFile(target, content));
        }

        foreach (var defaultFile in component.DefaultFiles)
        {
            var source = ResolveComponentSource(componentDirectory, defaultFile);
            var prefix = defaultFilePrefix ?? outputPrefix;
            var target = prefix is not null
                ? Path.Combine(prefix, pathValidator.DefaultOutputPath(defaultFile))
                : pathValidator.DefaultOutputPath(defaultFile);
            EnsureUniquePath(state.Paths, target, "archivo predeterminado");
            state.DefaultFiles.Add(new PlanDefaultFile(target, Path.GetRelativePath(workingDirectory, source)));
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

    private static void EnsureUniquePath(HashSet<string> allPaths, string path, string kind)
    {
        if (!allPaths.Add(path))
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput(kind, path));
    }
}
