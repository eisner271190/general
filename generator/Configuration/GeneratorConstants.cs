namespace Generator.Configuration;

internal static class GeneratorConstants
{
    public const string ComponentsDirectory = "components";
    public const string BackendComponentType = "backend";
    public const string TargetDirectoryName = "target";
    public const string OutputDirectoryName = "output";
    public const string GenerationPlanFileName = "generation-plan.json";
    public const string DefaultsDirectory = "defaults";
    public const string DefaultErrorCode = "GEN000";

    public const string ApplicationNameVariable = "APPLICATION_NAME";
    public const string ApplicationIdVariable = "APPLICATION_ID";
    public const string ApplicationPackageVariable = "APPLICATION_PACKAGE";
    public const string EnvironmentVariable = "ENVIRONMENT";
    public const string MicroserviceNameVariable = "MICROSERVICE_NAME";
    public const string MicroservicePortVariable = "MICROSERVICE_PORT";
    public const string MicroserviceDeployVariable = "MICROSERVICE_DEPLOY";
    public const string BackendVariable = "BACKEND";
    public const string EntitiesVariable = "ENTITIES_JSON";
    public const string EndpointsVariable = "ENDPOINTS_JSON";
    public const string TemplateNameVariable = "Name";
    public const string TemplateCompanyVariable = "Company";
    public const string TemplateMicroserviceNameVariable = "MicroserviceName";
    public const string TemplatePortVariable = "Port";
    public const string TemplateGraalvmVariable = "Graalvm";

    public const string OneToOneRelation = "one-to-one";
    public const string OneToManyRelation = "one-to-many";
    public const string ManyToOneRelation = "many-to-one";
    public const string ManyToManyRelation = "many-to-many";
}