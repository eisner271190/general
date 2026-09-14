using Generator.Configuration;

namespace Generator.Services;

internal sealed class ProjectDirectoryResolver
{
    public string Resolve()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, GeneratorConstants.TargetDirectoryName)))
                return directory.FullName;

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException(
            $"No se encontro la raiz del proyecto con la carpeta '{GeneratorConstants.TargetDirectoryName}'.");
    }
}