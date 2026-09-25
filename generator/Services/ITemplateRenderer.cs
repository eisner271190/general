namespace Generator.Services;

internal interface ITemplateRenderer
{
    string Render(TemplateSource source, IReadOnlyDictionary<string, object?> variables);
}
