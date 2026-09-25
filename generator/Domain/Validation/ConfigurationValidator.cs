using Generator.Domain.Models;

namespace Generator.Domain.Validation;

internal sealed class ConfigurationValidator(IEnumerable<IValidationRule> rules) : IConfigurationValidator
{
    public void Validate(EpcConfiguration configuration)
    {
        foreach (var rule in rules)
            ApplyRule(rule, configuration);
    }

    private static void ApplyRule(IValidationRule rule, EpcConfiguration configuration) =>
        rule.Validate(configuration);
}
