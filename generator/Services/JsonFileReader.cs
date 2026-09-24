using System.Text.Json;
using Generator.Messages;

namespace Generator.Services;

internal interface IJsonFileReader
{
    T Read<T>(string path);
    string Serialize<T>(T value);
}

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
            return JsonSerializer.Deserialize<T>(content, Options)
                ?? throw new GeneratorException(ErrorCodes.EmptyJson, GeneratorMessages.EmptyJson(path));
        }
        catch (JsonException exception)
        {
            throw new GeneratorException(ErrorCodes.InvalidJson, GeneratorMessages.InvalidJson(path, exception.Message));
        }
    }

    private static string ReadText(string path)
    {
        try
        {
            return File.ReadAllText(path);
        }
        catch (Exception exception) when (exception is FileNotFoundException or DirectoryNotFoundException)
        {
            throw new GeneratorException(ErrorCodes.MissingSourceFile, GeneratorMessages.MissingSourceFile(path));
        }
    }
}
