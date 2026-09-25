using System.Text.RegularExpressions;
using Generator.Application;
using Generator.Domain.Messages;
using Scriban;
using Scriban.Runtime;
using Scriban.Syntax;

namespace Generator.Infrastructure;

internal sealed class TemplateRenderer : ITemplateRenderer
{
    public string Render(TemplateSource source, IReadOnlyDictionary<string, object?> variables)
    {
        var context = CreateContext(variables);
        return RenderTemplate(source, context);
    }

    private static string RenderTemplate(TemplateSource source, TemplateContext context)
    {
        var template = Parse(source);
        try
        {
            return template.Render(context);
        }
        catch (ScriptRuntimeException exception)
        {
            throw UnresolvedPlaceholder(exception, source.Path);
        }
    }

    private static Template Parse(TemplateSource source)
    {
        var template = Template.Parse(source.Content, source.Path);
        if (template.HasErrors)
            throw new GeneratorException(ErrorCodes.InvalidTemplate, string.Join(Environment.NewLine, template.Messages));
        return template;
    }

    private static TemplateContext CreateContext(IReadOnlyDictionary<string, object?> variables)
    {
        var context = new TemplateContext { StrictVariables = true };
        context.PushGlobal(CreateScriptObject(variables));
        return context;
    }

    private static ScriptObject CreateScriptObject(IReadOnlyDictionary<string, object?> variables)
    {
        var scriptObject = new ScriptObject();
        AddVariables(scriptObject, variables);
        return scriptObject;
    }

    private static void AddVariables(ScriptObject scriptObject, IReadOnlyDictionary<string, object?> variables)
    {
        foreach (var variable in variables)
            scriptObject.Add(variable.Key, variable.Value);
    }

    private static GeneratorException UnresolvedPlaceholder(ScriptRuntimeException exception, string templatePath) =>
        new(
            ErrorCodes.UnresolvedPlaceholder,
            GeneratorMessages.UnresolvedPlaceholder(ExtractPlaceholder(exception.Message), templatePath));

    private static string ExtractPlaceholder(string message)
    {
        var match = Regex.Match(message, "`([^`]+)`");
        return match.Success ? match.Groups[1].Value : message;
    }
}
