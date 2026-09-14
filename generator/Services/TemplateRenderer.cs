using System.Text.RegularExpressions;
using Generator.Messages;

namespace Generator.Services;

internal interface ITemplateRenderer
{
    string Render(string content, IReadOnlyDictionary<string, string> variables, string templatePath);
}

internal sealed class TemplateRenderer : ITemplateRenderer
{
    private static readonly Regex PlaceholderRegex = new(@"\{\{([A-Za-z0-9_.-]+)\}\}", RegexOptions.Compiled);

    public string Render(string content, IReadOnlyDictionary<string, string> variables, string templatePath)
    {
        return PlaceholderRegex.Replace(content, match =>
        {
            var key = match.Groups[1].Value;
            return variables.TryGetValue(key, out var value)
                ? value
                : throw new GeneratorException(ErrorCodes.UnresolvedPlaceholder, GeneratorMessages.UnresolvedPlaceholder(key, templatePath));
        });
    }
}