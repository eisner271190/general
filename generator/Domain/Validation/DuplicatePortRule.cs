using Generator.Domain.Messages;
using Generator.Domain.Models;

namespace Generator.Domain.Validation;

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
