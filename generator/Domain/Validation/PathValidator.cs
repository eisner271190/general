using Generator.Domain.Messages;
using Generator.Configuration;

namespace Generator.Domain.Validation;

internal sealed class PathValidator : IPathValidator
{
    private static readonly HashSet<char> InvalidFileNameCharacters = new(Path.GetInvalidFileNameChars());

    public string NormalizeRelative(string path)
    {
        EnsureRelative(path);
        var normalized = ReplaceSeparators(path);
        EnsureNoParentSegment(normalized, path);
        EnsureValidSegments(normalized);
        return normalized;
    }

    public string NormalizeOutputSegment(string segment)
    {
        var normalized = NormalizeRelative(segment);
        EnsureSimpleSegment(normalized, segment);
        return normalized;
    }

    public string DefaultOutputPath(string sourcePath)
    {
        var normalized = NormalizeRelative(sourcePath);
        EnsureUnderDefaults(normalized, sourcePath);
        return RemoveDefaultsPrefix(normalized);
    }

    private static void EnsureRelative(string path)
    {
        if (IsMissingOrRooted(path))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidPath(path));
    }

    private static bool IsMissingOrRooted(string path) =>
        string.IsNullOrWhiteSpace(path) || Path.IsPathRooted(path);

    private static string ReplaceSeparators(string path) =>
        path.Replace('/', Path.DirectorySeparatorChar).Replace('\\', Path.DirectorySeparatorChar);

    private static void EnsureNoParentSegment(string normalizedPath, string originalPath)
    {
        if (HasParentSegment(normalizedPath))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidPath(originalPath));
    }

    private static bool HasParentSegment(string normalizedPath) =>
        normalizedPath.Split(Path.DirectorySeparatorChar).Any(part => part == "..");

    private static void EnsureValidSegments(string normalizedPath)
    {
        var invalidSegment = FindInvalidSegment(normalizedPath);
        if (invalidSegment is not null)
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidFileName(invalidSegment));
    }

    private static string? FindInvalidSegment(string normalizedPath) =>
        normalizedPath
            .Split(Path.DirectorySeparatorChar)
            .FirstOrDefault(segment => segment.Any(InvalidFileNameCharacters.Contains));

    private static void EnsureSimpleSegment(string normalized, string segment)
    {
        if (IsNonSimpleName(normalized))
            throw new GeneratorException(ErrorCodes.InvalidPath, GeneratorMessages.InvalidOutputSegment(segment));
    }

    private static bool IsNonSimpleName(string normalized) =>
        normalized == "." || normalized.Contains(Path.DirectorySeparatorChar);

    private static void EnsureUnderDefaults(string normalized, string sourcePath)
    {
        if (!normalized.StartsWith(DefaultsPrefix(), StringComparison.OrdinalIgnoreCase))
            throw new GeneratorException(ErrorCodes.InvalidDefaultFile, GeneratorMessages.InvalidDefaultFile(sourcePath));
    }

    private static string DefaultsPrefix() => GeneratorConstants.DefaultsDirectory + Path.DirectorySeparatorChar;

    private static string RemoveDefaultsPrefix(string normalized) => normalized[DefaultsPrefix().Length..];
}
