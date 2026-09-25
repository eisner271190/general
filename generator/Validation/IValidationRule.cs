using Generator.Models;

namespace Generator.Validation;

internal interface IValidationRule
{
    void Validate(EpcConfiguration configuration);
}
