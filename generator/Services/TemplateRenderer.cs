using Generator.Messages;
using Scriban;
using Scriban.Runtime;

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
        {
            throw new GeneratorException(ErrorCodes.InvalidTemplate, string.Join(Environment.NewLine, template.Messages));
        }

        var scriptObject = new ScriptObject();
        foreach (var variable in variables)
            scriptObject.Add(variable.Key, variable.Value);

        var context = new TemplateContext();
        context.PushGlobal(scriptObject);
        var rendered = template.Render(context);
        var unresolvedPlaceholder = rendered
            .Split("{{", StringSplitOptions.None)
            .Skip(1)
            .Select(part => part.Split("}}", 2, StringSplitOptions.None)[0])
            .FirstOrDefault();

        if (unresolvedPlaceholder is not null)
            throw new GeneratorException(ErrorCodes.UnresolvedPlaceholder, GeneratorMessages.UnresolvedPlaceholder(unresolvedPlaceholder.Trim(), templatePath));

        return rendered;
    }
}