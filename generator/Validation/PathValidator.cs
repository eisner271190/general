using Generator.Messages;

using Generator.Configuration;

namespace Generator.Validation;

internal interface IPathValidator
{
    string NormalizeRelative(string path);
    string DefaultOutputPath(string sourcePath);
}

internal sealed class PathValidator : IPathValidator
{
    public string NormalizeRelative(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidPath(path));

        var normalized = path.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);
        if (normalized.Split(Path.DirectorySeparatorChar).Any(part => part == ".."))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidPath(path));

        return normalized;
    }

    public string DefaultOutputPath(string sourcePath)
    {
        var normalized = NormalizeRelative(sourcePath);
        var prefix = GeneratorConstants.DefaultsDirectory + Path.DirectorySeparatorChar;
        if (!normalized.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            throw new GeneratorException(ErrorCodes.InvalidDefaultFile, GeneratorMessages.InvalidDefaultFile(sourcePath));

        return normalized[prefix.Length..];
    }
}