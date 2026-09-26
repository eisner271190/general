namespace Generator.Configuration;

internal static class GeneratorConstants
{
    public const string ComponentsDirectory = "components";
    public const string BackendComponentType = "backend";
    public const string FrontendComponentType = "frontend";
    public const string CloudComponentType = "cloud";
    public const string RootComponentType = "root";
    public const string RootComponentName = "workspace";
    public const string TargetDirectoryName = "target";
    public const string OutputDirectoryName = "output";
    public const string ProjectsDirectoryName = "projects";
    public const string GenerationPlanFileName = "generation-plan.json";
    public const string JsonExtension = ".json";
    public const string DefaultsDirectory = "defaults";
    public const string DefaultErrorCode = "GEN000";
    public const string DefaultCloudRegion = "us-east-1";

    public const string ApplicationNameVariable = "APPLICATION_NAME";
    public const string ApplicationIdVariable = "APPLICATION_ID";
    public const string ApplicationPackageVariable = "APPLICATION_PACKAGE";
    public const string EnvironmentVariable = "ENVIRONMENT";
    public const string EnvironmentVariablesHclVariable = "ENVIRONMENT_VARIABLES_HCL";
    public const string MicroserviceNameVariable = "MICROSERVICE_NAME";
    public const string MicroservicePortVariable = "MICROSERVICE_PORT";
    public const string MicroserviceDeployVariable = "MICROSERVICE_DEPLOY";
    public const string BackendVariable = "BACKEND";
    public const string EntitiesVariable = "ENTITIES_JSON";
    public const string EndpointsVariable = "ENDPOINTS_JSON";
    public const string ConsumedEventsVariable = "ConsumedEvents";
    public const string CloudRegionVariable = "CLOUD_REGION";
    public const string TemplateNameVariable = "Name";
    public const string TemplateCompanyVariable = "Company";
    public const string TemplateMicroserviceNameVariable = "MicroserviceName";
    public const string TemplatePortVariable = "Port";
    public const string TemplateGraalvmVariable = "Graalvm";
    public const string FrontendNameVariable = "FRONTEND_NAME";
    public const string FrontendFrameworkVariable = "FRONTEND_FRAMEWORK";
    public const string FrontendVersionVariable = "FRONTEND_VERSION";
    public const string HasAppIconVariable = "HAS_APP_ICON";

    public const string OneToOneRelation = "one-to-one";
    public const string OneToManyRelation = "one-to-many";
    public const string ManyToOneRelation = "many-to-one";
    public const string ManyToManyRelation = "many-to-many";
}