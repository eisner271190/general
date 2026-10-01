namespace Generator.Application;

// Puerto de acceso al sistema de archivos y rutas de la plataforma subyacente.
internal interface IFileSystem
{
    char DirectorySeparator { get; }

    bool Exists(string path);

    string ReadAllText(string path);

    string Combine(params string[] segments);

    string? GetDirectoryName(string path);

    string GetFullPath(string path, string basePath);

    string GetRelativePath(string basePath, string path);
}
