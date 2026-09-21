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
    var signingKeyGenerator = new AndroidSigningKeyGenerator();
    var region = Environment.GetEnvironmentVariable(GeneratorConstants.AwsRegionVariable);
    var secretsManager = string.IsNullOrWhiteSpace(region) ? null : new AwsSecretsManager(region);
    
    var application = new GeneratorApplication(workingDirectory, planBuilder, jsonReader, pathValidator, signingKeyGenerator, secretsManager, null, null, region);
    await application.RunAsync();
    return 0;
}
catch (Exception exception)
{
    var code = exception is GeneratorException generatorException ? generatorException.Code : GeneratorConstants.DefaultErrorCode;
    GeneratorLogger.Error($"{code}: {exception.Message}");
    return 1;
}
