using Generator.Models;

namespace Generator.Validation;

internal interface IConfigurationValidator
{
    void Validate(EpcConfiguration configuration);
}
