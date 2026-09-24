using Generator.Services;
using Generator.Validation;
using Generator.Messages;
using Generator.Configuration;

try
{
    var workingDirectory = new ProjectDirectoryResolver().Resolve();
    var jsonReader = new JsonFileReader();
    var pathValidator = new PathValidator();
    var validationRules = new IValidationRule[]
    {
        new RequiredConfigurationRule(),
        new DuplicatePortRule(),
        new EntityRelationRule()
    };
    var configurationValidator = new ConfigurationValidator(validationRules);
    var templateRenderer = new TemplateRenderer();
    var planBuilder = new GenerationPlanBuilder(
        workingDirectory,
        jsonReader,
        pathValidator,
        configurationValidator,
        templateRenderer);
    var planExecutorFactory = new PlanExecutorFactory(workingDirectory, jsonReader, pathValidator);
    var application = new GeneratorApplication(workingDirectory, planBuilder, pathValidator, planExecutorFactory);
    application.Run();
    return 0;
}
catch (Exception exception)
{
    var code = exception is GeneratorException generatorException ? generatorException.Code : GeneratorConstants.DefaultErrorCode;
    GeneratorLogger.Error($"{code}: {exception.Message}");
    return 1;
}
