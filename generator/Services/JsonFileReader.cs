using System.Text.Json;
using Generator.Messages;

namespace Generator.Services;

internal sealed class JsonFileReader : IJsonFileReader
{
    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    public T Read<T>(string path) => Parse<T>(ReadText(path), path);

    public string Serialize<T>(T value) => JsonSerializer.Serialize(value, Options);

    private static T Parse<T>(string content, string path)
    {
        try
        {
            return Deserialize<T>(content, path);
        }
        catch (JsonException exception)
        {
            throw InvalidJson(path, exception);
        }
    }

    private static T Deserialize<T>(string content, string path) =>
        JsonSerializer.Deserialize<T>(content, Options)
            ?? throw new GeneratorException(ErrorCodes.EmptyJson, GeneratorMessages.EmptyJson(path));

    private static GeneratorException InvalidJson(string path, JsonException exception) =>
        new(ErrorCodes.InvalidJson, GeneratorMessages.InvalidJson(path, exception.Message));

    private static string ReadText(string path)
    {
        try
        {
            return File.ReadAllText(path);
        }
        catch (Exception exception) when (IsMissingSourceFile(exception))
        {
            throw MissingSourceFile(path);
        }
    }

    private static bool IsMissingSourceFile(Exception exception) =>
        exception is FileNotFoundException or DirectoryNotFoundException;

    private static GeneratorException MissingSourceFile(string path) =>
        new(ErrorCodes.MissingSourceFile, GeneratorMessages.MissingSourceFile(path));
}
