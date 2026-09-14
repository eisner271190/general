using Generator.Models;
using Generator.Messages;

namespace Generator.Validation;

internal interface IConfigurationValidator
{
    void Validate(EpcConfiguration configuration);
}

internal interface IValidationRule
{
    void Validate(EpcConfiguration configuration);
}

internal sealed class ConfigurationValidator(IEnumerable<IValidationRule> rules) : IConfigurationValidator
{
    public void Validate(EpcConfiguration configuration)
    {
        foreach (var rule in rules)
            rule.Validate(configuration);
    }
}