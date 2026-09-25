using System.Text.Json;
using Generator.Domain.Models;
using Generator.Domain.Messages;
using Generator.Domain.Validation;
using Generator.Configuration;

namespace Generator.Application;

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
        var environment = ResolveEnvironment(configuration, requestedEnvironment);
        var variables = BuildVariables(configuration, environment);
        var context = CreateContext(configuration, inputPath, variables);

        AddRootComponent(context);
        AddBackendComponents(context);
        AddFrontendComponent(context);
        AddCloudComponents(context);

        return CreatePlan(configuration, environment, context.State);
    }

    private static PlanContext CreateContext(
        EpcConfiguration configuration,
        string inputPath,
        IReadOnlyDictionary<string, object?> variables) =>
        new PlanContext(configuration, inputPath, variables, CreateState());

    private static PlanState CreateState() => new PlanState();

    private static GenerationPlan CreatePlan(
        EpcConfiguration configuration,
        EnvironmentConfiguration environment,
        PlanState state) =>
        new GenerationPlan(
            configuration.ApplicationName,
            configuration.ApplicationId,
            environment.Name,
            state.Directories,
            state.Files,
            state.DefaultFiles);

    private static ComponentRef CreateComponentRef(string componentType, string componentName) =>
        new ComponentRef(componentType, componentName);

    private static TemplateSource CreateTemplateSource(string content, string templatePath) =>
        new TemplateSource(content, templatePath);

    private static EnvironmentConfiguration ResolveEnvironment(EpcConfiguration configuration, string? requestedEnvironment)
    {
        if (requestedEnvironment is null)
            return configuration.Environments[0];

        return FindEnvironment(configuration, requestedEnvironment)
            ?? throw new GeneratorException(ErrorCodes.EnvironmentNotFound, GeneratorMessages.EnvironmentNotFound(requestedEnvironment));
    }

    private static EnvironmentConfiguration? FindEnvironment(EpcConfiguration configuration, string requestedEnvironment) =>
        configuration.Environments.FirstOrDefault(item => item.Name.Equals(requestedEnvironment, StringComparison.OrdinalIgnoreCase));

    private static Dictionary<string, object?> BuildVariables(EpcConfiguration configuration, EnvironmentConfiguration environment)
    {
        var variables = MergeEnvironmentVariables(configuration, environment);
        variables[GeneratorConstants.EnvironmentVariablesHclVariable] = SerializeEnvironmentVariables(variables);
        return variables;
    }

    private static Dictionary<string, object?> MergeEnvironmentVariables(EpcConfiguration configuration, EnvironmentConfiguration environment)
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

    private static string SerializeEnvironmentVariables(IReadOnlyDictionary<string, object?> variables) =>
        "{ " + string.Join(", ", variables.Select(item => $"{JsonSerializer.Serialize(item.Key)} = {JsonSerializer.Serialize(item.Value)}")) + " }";

    // Componente raíz: los scripts que orquestan el resto (up.ps1 / down.ps1).
    private void AddRootComponent(PlanContext context)
    {
        var rootContext = context with
        {
            Component = CreateComponentRef(GeneratorConstants.RootComponentType, GeneratorConstants.RootComponentName)
        };
        ProcessComponent(rootContext);
    }

    private void AddBackendComponents(PlanContext context)
    {
        var backendContext = context with { OutputPrefix = "backend" };
        foreach (var microservice in context.Configuration.Microservices)
            AddBackendComponent(microservice, backendContext);
    }

    private void AddBackendComponent(MicroserviceConfiguration microservice, PlanContext context)
    {
        var componentContext = context with
        {
            Component = CreateComponentRef(GeneratorConstants.BackendComponentType, microservice.Backend),
            Variables = CreateBackendVariables(microservice, context)
        };
        ProcessComponent(componentContext);
    }

    private Dictionary<string, object?> CreateBackendVariables(MicroserviceConfiguration microservice, PlanContext context)
    {
        var microserviceVariables = new Dictionary<string, object?>(context.Variables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.TemplateNameVariable] = microservice.Name,
            [GeneratorConstants.TemplateCompanyVariable] = GetCompanyName(context.Configuration.ApplicationId),
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
        return microserviceVariables;
    }

    private void AddFrontendComponent(PlanContext context)
    {
        var frontend = context.Configuration.Frontend;
        if (frontend is null)
            return;

        var componentContext = context with
        {
            Component = CreateComponentRef(GeneratorConstants.FrontendComponentType, frontend.Framework),
            DefaultFilePrefix = Path.Combine("frontend", frontend.Name),
            Variables = CreateFrontendVariables(frontend, context)
        };
        ProcessComponent(componentContext);
        AddAppIcon(frontend, context);
    }

    private Dictionary<string, object?> CreateFrontendVariables(FrontendConfiguration frontend, PlanContext context)
    {
        var hasAppIcon = File.Exists(AppIconPath(context));
        return new Dictionary<string, object?>(context.Variables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.TemplateNameVariable] = frontend.Name,
            [GeneratorConstants.TemplateCompanyVariable] = GetCompanyName(context.Configuration.ApplicationId),
            [GeneratorConstants.FrontendNameVariable] = frontend.Name,
            [GeneratorConstants.FrontendFrameworkVariable] = frontend.Framework,
            [GeneratorConstants.FrontendVersionVariable] = frontend.Version ?? "1.0.0+1",
            [GeneratorConstants.HasAppIconVariable] = hasAppIcon
        };
    }

    private void AddAppIcon(FrontendConfiguration frontend, PlanContext context)
    {
        var appIconPath = AppIconPath(context);
        if (File.Exists(appIconPath))
            context.State.AddDefaultFile(AppIconTarget(frontend), appIconPath);
    }

    private string AppIconPath(PlanContext context) =>
        Path.Combine(Path.GetDirectoryName(context.InputPath) ?? workingDirectory, "app_icon.png");

    private static string AppIconTarget(FrontendConfiguration frontend) =>
        Path.Combine("frontend", frontend.Name, "assets", "icon", "app_icon.png");

    private void AddCloudComponents(PlanContext context)
    {
        var cloud = context.Configuration.Cloud;
        if (cloud is null)
            return;

        var cloudContext = context with
        {
            Component = CreateComponentRef(GeneratorConstants.CloudComponentType, cloud.Provider),
            Variables = CreateCloudVariables(cloud, context)
        };
        foreach (var microservice in context.Configuration.Microservices)
            AddCloudComponent(microservice, cloudContext);
    }

    private void AddCloudComponent(MicroserviceConfiguration microservice, PlanContext context)
    {
        var componentContext = context with { Variables = CreateMicroserviceCloudVariables(microservice, context.Variables) };
        ProcessComponent(componentContext);
    }

    private static Dictionary<string, object?> CreateCloudVariables(CloudConfiguration cloud, PlanContext context)
    {
        var cloudName = cloud.Name ?? cloud.Provider;
        return new Dictionary<string, object?>(context.Variables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.TemplateNameVariable] = cloudName,
            [GeneratorConstants.TemplateCompanyVariable] = GetCompanyName(context.Configuration.ApplicationId),
            [GeneratorConstants.CloudRegionVariable] = cloud.Region ?? GeneratorConstants.DefaultCloudRegion
        };
    }

    private static Dictionary<string, object?> CreateMicroserviceCloudVariables(
        MicroserviceConfiguration microservice,
        IReadOnlyDictionary<string, object?> cloudVariables)
    {
        return new Dictionary<string, object?>(cloudVariables, StringComparer.OrdinalIgnoreCase)
        {
            [GeneratorConstants.MicroserviceNameVariable] = microservice.Name,
            [GeneratorConstants.MicroservicePortVariable] = microservice.Port.ToString(),
            [GeneratorConstants.TemplateMicroserviceNameVariable] = microservice.Name,
            [GeneratorConstants.ConsumedEventsVariable] = microservice.ConsumedEvents
        };
    }

    // Solo se invoca con contextos que definen Component (los cuatro Add*Component).
    private void ProcessComponent(PlanContext context)
    {
        var component = context.Component!;
        var componentPath = ResolveSource(Path.Combine(
            GeneratorConstants.ComponentsDirectory,
            component.Type,
            component.Name,
            "component.json"));
        var definition = jsonReader.Read<ComponentDefinition>(componentPath);
        GeneratorLogger.Info($"Componente '{component.Type}' seleccionado: {component.Name}");
        var componentContext = context with { ComponentDirectory = Path.GetDirectoryName(componentPath)! };

        AddDirectories(definition, componentContext);
        AddFiles(definition, componentContext);
        AddDefaultFiles(definition, componentContext);
    }

    private void AddDirectories(ComponentDefinition definition, PlanContext context)
    {
        foreach (var directory in definition.Directories)
            AddDirectory(directory, context);
    }

    private void AddDirectory(string directory, PlanContext context) =>
        context.State.AddDirectory(ResolveTarget(directory, context));

    private void AddFiles(ComponentDefinition definition, PlanContext context)
    {
        foreach (var file in definition.Files)
            AddFile(file, context);
    }

    private void AddFile(ComponentFile file, PlanContext context)
    {
        var target = ResolveTarget(file.Key, context);
        var content = RenderFile(file, context);
        if (IsEmptyContent(content))
            LogSkippedTemplate(file, target);
        else
            context.State.AddFile(target, content);
    }

    private string RenderFile(ComponentFile file, PlanContext context)
    {
        var templatePath = ResolveComponentSource(file.Value, context);
        var source = CreateTemplateSource(File.ReadAllText(templatePath), templatePath);
        return templateRenderer.Render(source, context.Variables);
    }

    private static bool IsEmptyContent(string content) => string.IsNullOrWhiteSpace(content);

    private static void LogSkippedTemplate(ComponentFile file, string target) =>
        GeneratorLogger.Debug(GeneratorMessages.EmptyTemplateSkipped(file.Value, target));

    private void AddDefaultFiles(ComponentDefinition definition, PlanContext context)
    {
        foreach (var defaultFile in definition.DefaultFiles)
            AddDefaultFile(defaultFile, context);
    }

    private void AddDefaultFile(string defaultFile, PlanContext context)
    {
        var source = ResolveComponentSource(defaultFile, context);
        var target = ResolveDefaultTarget(defaultFile, context);
        context.State.AddDefaultFile(target, Path.GetRelativePath(workingDirectory, source));
    }

    private string ResolveDefaultTarget(string defaultFile, PlanContext context)
    {
        var prefix = context.DefaultFilePrefix ?? context.OutputPrefix;
        var normalized = pathValidator.DefaultOutputPath(defaultFile);
        return prefix is not null ? Path.Combine(prefix, normalized) : normalized;
    }

    private string ResolveTarget(string key, PlanContext context) =>
        context.OutputPrefix is not null
            ? RenderPath(Path.Combine(context.OutputPrefix, key), context.Variables)
            : RenderPath(key, context.Variables);

    private string ResolveSource(string relativePath)
    {
        var path = Path.GetFullPath(pathValidator.NormalizeRelative(relativePath), workingDirectory);
        EnsureSourceExists(path, relativePath);
        return path;
    }

    private static void EnsureSourceExists(string path, string relativePath)
    {
        if (!File.Exists(path))
            throw new FileNotFoundException(GeneratorMessages.MissingSourceFile(relativePath), path);
    }

    private string ResolveComponentSource(string relativePath, PlanContext context)
    {
        // El directorio del componente se define en ProcessComponent antes de resolver sus archivos.
        var path = Path.GetFullPath(pathValidator.NormalizeRelative(relativePath), context.ComponentDirectory!);
        EnsureComponentSourceExists(path, relativePath);
        return path;
    }

    private static void EnsureComponentSourceExists(string path, string relativePath)
    {
        if (!File.Exists(path))
            throw new FileNotFoundException(GeneratorMessages.MissingComponentFile(relativePath), path);
    }

    private string RenderPath(string path, IReadOnlyDictionary<string, object?> variables)
    {
        var renderedPath = templateRenderer.Render(CreateTemplateSource(path, path), variables);
        return pathValidator.NormalizeRelative(renderedPath);
    }

    private static string GetCompanyName(string applicationId)
    {
        var segments = applicationId.Split('.', StringSplitOptions.RemoveEmptyEntries);
        return segments.Length >= 2 ? segments[^2] : applicationId;
    }
}
