using Generator.Messages;

using Generator.Configuration;

namespace Generator.Validation;

internal interface IPathValidator
{
    string NormalizeRelative(string path);
    string NormalizeOutputSegment(string segment);
    string DefaultOutputPath(string sourcePath);
}

internal sealed class PathValidator : IPathValidator
{
    private static readonly HashSet<char> InvalidFileNameCharacters = new(Path.GetInvalidFileNameChars());

    public string NormalizeRelative(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidPath(path));

        var normalized = path.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);
        if (normalized.Split(Path.DirectorySeparatorChar).Any(part => part == ".."))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidPath(path));

        var invalidSegment = normalized
            .Split(Path.DirectorySeparatorChar)
            .FirstOrDefault(segment => segment.Any(InvalidFileNameCharacters.Contains));
        if (invalidSegment is not null)
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidFileName(invalidSegment));

        return normalized;
    }

    public string NormalizeOutputSegment(string segment)
    {
        var normalized = NormalizeRelative(segment);
        if (normalized == "." || normalized.Contains(Path.DirectorySeparatorChar))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidOutputSegment(segment));
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