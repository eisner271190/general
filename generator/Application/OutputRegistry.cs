using Generator.Domain.Messages;

namespace Generator.Application;

// Salidas ya utilizadas en el workspace: impide que dos configuraciones apunten al mismo proyecto.
internal sealed class OutputRegistry(string workspaceDirectory)
{
    // Windows-only (NTFS no distingue mayusculas): mantener OrdinalIgnoreCase.
    private readonly HashSet<string> _usedDirectories = new(StringComparer.OrdinalIgnoreCase);

    public string WorkspaceDirectory { get; } = workspaceDirectory;

    public void EnsureUnique(string outputDirectory, string applicationId)
    {
        if (!_usedDirectories.Add(outputDirectory))
            throw new GeneratorException(ErrorCodes.DuplicateOutput, GeneratorMessages.DuplicateOutput("applicationId", applicationId));
    }
}
