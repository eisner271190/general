namespace Generator.Models;

public sealed record EpcConfiguration(
    string ApplicationName,
    string ApplicationId,
    List<EnvironmentConfiguration> Environments,
    List<MicroserviceConfiguration> Microservices,
    FrontendConfiguration? Frontend = null,
    CloudConfiguration? Cloud = null);
