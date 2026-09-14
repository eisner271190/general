using Generator.Messages;
using Generator.Models;

namespace Generator.Validation;

internal sealed class RequiredConfigurationRule : IValidationRule
{
    public void Validate(EpcConfiguration configuration)
    {
        if (string.IsNullOrWhiteSpace(configuration.ApplicationName) || string.IsNullOrWhiteSpace(configuration.ApplicationId))
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.ApplicationDataRequired);
        if (configuration.Environments.Count == 0)
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.EnvironmentRequired);
        if (configuration.Microservices.Count == 0)
            throw new GeneratorException(ErrorCodes.InvalidConfiguration, GeneratorMessages.MicroserviceRequired);
    }
}