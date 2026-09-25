using Generator.Domain.Messages;
using Generator.Domain.Models;

namespace Generator.Application;

internal sealed class PlanState
{
    public List<string> Directories { get; } = [];
    public List<PlanFile> Files { get; } = [];
    public List<PlanDefaultFile> DefaultFiles { get; } = [];
    public HashSet<string> Paths { get; } = new(StringComparer.OrdinalIgnoreCase);

    public void AddDirectory(string target)
    {
        EnsureUniquePath(target, "directorio");
        Directories.Add(target);
    }

    public void AddFile(string target, string content)
    {
        EnsureUniquePath(target, "archivo");
        Files.Add(new PlanFile(target, content));
    }

    public void AddDefaultFile(string target, string source)
    {
        EnsureUniquePath(target, "archivo predeterminado");
        DefaultFiles.Add(new PlanDefaultFile(target, source));
    }

    private void EnsureUniquePath(string path, string kind)
    {
        if (!Paths.Add(path))
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput(kind, path));
    }
}
