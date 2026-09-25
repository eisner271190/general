using Generator.Application;
using Generator.Configuration;
using Generator.Domain.Messages;
using Generator.Domain.Validation;
using Generator.Infrastructure;

try
{
    var workingDirectory = ResolveWorkingDirectory();
    var jsonReader = CreateJsonReader();
    var pathValidator = CreatePathValidator();
    var inverseStrategies = CreateInverseStrategies();
    var validationRules = CreateValidationRules(inverseStrategies);
    var configurationValidator = CreateConfigurationValidator(validationRules);
    var templateRenderer = CreateTemplateRenderer();
    var planBuilder = CreatePlanBuilder(workingDirectory, jsonReader, pathValidator, configurationValidator, templateRenderer);
    var planExecutorFactory = CreatePlanExecutorFactory(workingDirectory, jsonReader, pathValidator);
    var application = CreateApplication(workingDirectory, planBuilder, pathValidator, planExecutorFactory);
    application.Run();
    return 0;
}
catch (Exception exception)
{
    var code = exception is GeneratorException generatorException ? generatorException.Code : GeneratorConstants.DefaultErrorCode;
    GeneratorLogger.Error($"{code}: {exception.Message}");
    return 1;
}

static string ResolveWorkingDirectory() => new ProjectDirectoryResolver().Resolve();

static IJsonFileReader CreateJsonReader() => new JsonFileReader();

static IPathValidator CreatePathValidator() => new PathValidator();

static IInverseRelationStrategy[] CreateInverseStrategies() =>
[
    new OneToOneInverseStrategy(),
    new OneToManyInverseStrategy(),
    new ManyToOneInverseStrategy(),
    new ManyToManyInverseStrategy()
];

static IValidationRule[] CreateValidationRules(IInverseRelationStrategy[] inverseStrategies) =>
[
    new RequiredConfigurationRule(),
    new DuplicatePortRule(),
    new EntityRelationRule(inverseStrategies)
];

static IConfigurationValidator CreateConfigurationValidator(IValidationRule[] validationRules) =>
    new ConfigurationValidator(validationRules);

static ITemplateRenderer CreateTemplateRenderer() => new TemplateRenderer();

static GenerationPlanBuilder CreatePlanBuilder(
    string workingDirectory,
    IJsonFileReader jsonReader,
    IPathValidator pathValidator,
    IConfigurationValidator configurationValidator,
    ITemplateRenderer templateRenderer) =>
    new GenerationPlanBuilder(workingDirectory, jsonReader, pathValidator, configurationValidator, templateRenderer);

static IPlanExecutorFactory CreatePlanExecutorFactory(
    string workingDirectory,
    IJsonFileReader jsonReader,
    IPathValidator pathValidator) =>
    new PlanExecutorFactory(workingDirectory, jsonReader, pathValidator);

static GeneratorApplication CreateApplication(
    string workingDirectory,
    GenerationPlanBuilder planBuilder,
    IPathValidator pathValidator,
    IPlanExecutorFactory planExecutorFactory) =>
    new GeneratorApplication(workingDirectory, planBuilder, pathValidator, planExecutorFactory);
