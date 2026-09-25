using Generator.Domain.Messages;
using Generator.Domain.Models;

namespace Generator.Domain.Validation;

internal sealed class RequiredConfigurationRule : IValidationRule
{
    public void Validate(EpcConfiguration configuration)
    {
        EnsureApplicationData(configuration);
        EnsureEnvironmentExists(configuration);
        EnsureMicroserviceExists(configuration);
    }

    private static void EnsureApplicationData(EpcConfiguration configuration)
    {
        if (string.IsNullOrWhiteSpace(configuration.ApplicationName) || string.IsNullOrWhiteSpace(configuration.ApplicationId))
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.ApplicationDataRequired);
    }

    private static void EnsureEnvironmentExists(EpcConfiguration configuration)
    {
        if (configuration.Environments.Count == 0)
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.EnvironmentRequired);
    }

    private static void EnsureMicroserviceExists(EpcConfiguration configuration)
    {
        if (configuration.Microservices.Count == 0)
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.MicroserviceRequired);
    }
}
