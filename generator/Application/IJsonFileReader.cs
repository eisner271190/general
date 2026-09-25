namespace Generator.Application;

internal interface IJsonFileReader
{
    T Read<T>(string path);
    string Serialize<T>(T value);
}
