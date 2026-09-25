using Generator.Configuration;

namespace Generator.Services;

internal sealed class ProjectDirectoryResolver
{
    public string Resolve()
    {
        var directory = CreateBaseDirectory();
        while (directory is not null)
        {
            if (IsProjectRoot(directory))
                return directory.FullName;

            directory = directory.Parent;
        }

        throw ProjectRootNotFound();
    }

    private static DirectoryInfo CreateBaseDirectory() => new(AppContext.BaseDirectory);

    private static bool IsProjectRoot(DirectoryInfo directory) =>
        Directory.Exists(Path.Combine(directory.FullName, GeneratorConstants.TargetDirectoryName));

    private static DirectoryNotFoundException ProjectRootNotFound() =>
        new($"No se encontro la raiz del proyecto con la carpeta '{GeneratorConstants.TargetDirectoryName}'.");
}
