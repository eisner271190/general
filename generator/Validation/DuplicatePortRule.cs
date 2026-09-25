using Generator.Messages;
using Generator.Models;

namespace Generator.Validation;

internal sealed class DuplicatePortRule : IValidationRule
{
    public void Validate(EpcConfiguration configuration) => EnsureNoDuplicatePort(configuration);

    private static void EnsureNoDuplicatePort(EpcConfiguration configuration)
    {
        var duplicatePorts = FindDuplicatePort(configuration.Microservices);
        if (duplicatePorts is not null)
            throw new GeneratorException(ErrorCodes.DuplicatePort, GeneratorMessages.DuplicatePort(duplicatePorts.Key));
    }

    private static IGrouping<int, MicroserviceConfiguration>? FindDuplicatePort(List<MicroserviceConfiguration> microservices) =>
        microservices
            .GroupBy(item => item.Port)
            .FirstOrDefault(group => group.Count() > 1);
}
