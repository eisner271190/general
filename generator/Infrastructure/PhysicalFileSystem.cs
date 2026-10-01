using Generator.Application;

namespace Generator.Infrastructure;

internal sealed class PhysicalFileSystem : IFileSystem
{
    public char DirectorySeparator => Path.DirectorySeparatorChar;

    public bool Exists(string path) => File.Exists(path);

    public string ReadAllText(string path) => File.ReadAllText(path);

    public string Combine(params string[] segments) => Path.Combine(segments);

    public string? GetDirectoryName(string path) => Path.GetDirectoryName(path);

    public string GetFullPath(string path, string basePath) => Path.GetFullPath(path, basePath);

    public string GetRelativePath(string basePath, string path) => Path.GetRelativePath(basePath, path);
}
