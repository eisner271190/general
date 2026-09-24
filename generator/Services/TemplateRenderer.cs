using System.Text.RegularExpressions;
using Generator.Messages;
using Scriban;
using Scriban.Runtime;
using Scriban.Syntax;

namespace Generator.Services;

internal interface ITemplateRenderer
{
    string Render(string content, IReadOnlyDictionary<string, object?> variables, string templatePath);
}

internal sealed class TemplateRenderer : ITemplateRenderer
{
    public string Render(string content, IReadOnlyDictionary<string, object?> variables, string templatePath)
    {
        var template = Template.Parse(content, templatePath);
        if (template.HasErrors)
            throw new GeneratorException(ErrorCodes.InvalidTemplate, string.Join(Environment.NewLine, template.Messages));

        var scriptObject = new ScriptObject();
        foreach (var variable in variables)
            scriptObject.Add(variable.Key, variable.Value);

        var context = new TemplateContext { StrictVariables = true };
        context.PushGlobal(scriptObject);

        try
        {
            return template.Render(context);
        }
        catch (ScriptRuntimeException exception)
        {
            throw new GeneratorException(
                ErrorCodes.UnresolvedPlaceholder,
                GeneratorMessages.UnresolvedPlaceholder(ExtractPlaceholder(exception.Message), templatePath));
        }
    }

    private static string ExtractPlaceholder(string message)
    {
        var match = Regex.Match(message, "`([^`]+)`");
        return match.Success ? match.Groups[1].Value : message;
    }
}
