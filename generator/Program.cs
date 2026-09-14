using Generator.Services;
using Generator.Validation;
using Generator.Messages;
using Generator.Configuration;

if (args.Length is < 1 or > 3)
{
    Console.Error.WriteLine(GeneratorMessages.Usage);
    return 1;
}

try
{
    var workingDirectory = Directory.GetCurrentDirectory();
    var inputPath = Path.GetFullPath(args[0], workingDirectory);
    var environmentName = args.Length >= 2 ? args[1] : null;
    var outputDirectory = Path.GetFullPath(args.Length == 3 ? args[2] : workingDirectory, workingDirectory);

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
    var planExecutor = new PlanExecutor(outputDirectory, workingDirectory, jsonReader, pathValidator);
    var plan = planBuilder.Build(inputPath, environmentName);
    planExecutor.Execute(plan);

    Console.WriteLine($"Generacion completada: {Path.Combine(outputDirectory, GeneratorConstants.GenerationPlanFileName)}");
    return 0;
}
catch (Exception exception)
{
    var code = exception is GeneratorException generatorException ? generatorException.Code : GeneratorConstants.DefaultErrorCode;
    Console.Error.WriteLine($"{code}: {exception.Message}");
    return 1;
}

