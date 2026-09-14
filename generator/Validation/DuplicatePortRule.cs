using Generator.Messages;
using Generator.Models;

namespace Generator.Validation;

internal sealed class DuplicatePortRule : IValidationRule
{
    public void Validate(EpcConfiguration configuration)
    {
        var duplicatePorts = configuration.Microservices
            .GroupBy(item => item.Port)
            .FirstOrDefault(group => group.Count() > 1);

        if (duplicatePorts is not null)
            throw new GeneratorException(ErrorCodes.DuplicatePort, GeneratorMessages.DuplicatePort(duplicatePorts.Key));
    }
}