using Generator.Domain.Models;

namespace Generator.Domain.Validation;

internal interface IValidationRule
{
    void Validate(EpcConfiguration configuration);
}
