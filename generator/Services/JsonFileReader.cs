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
    private static readonly JsonSerializerOptions Options = new() { PropertyNameCaseInsensitive = true, WriteIndented = true };

    public T Read<T>(string path) => JsonSerializer.Deserialize<T>(File.ReadAllText(path), Options)
        ?? throw new GeneratorException(ErrorCodes.EmptyJson, GeneratorMessages.EmptyJson(path));

    public string Serialize<T>(T value) => JsonSerializer.Serialize(value, Options);
}