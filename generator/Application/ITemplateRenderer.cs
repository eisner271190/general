namespace Generator.Application;

internal interface ITemplateRenderer
{
    string Render(TemplateSource source, IReadOnlyDictionary<string, object?> variables);
}
