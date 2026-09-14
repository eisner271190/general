namespace Generator.Messages;

internal sealed class GeneratorException(string code, string message) : Exception(message)
{
    public string Code { get; } = code;
}