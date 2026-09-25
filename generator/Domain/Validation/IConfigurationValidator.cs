using Generator.Domain.Models;

namespace Generator.Domain.Validation;

internal interface IConfigurationValidator
{
    void Validate(EpcConfiguration configuration);
}
