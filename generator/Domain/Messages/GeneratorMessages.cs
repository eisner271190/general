namespace Generator.Domain.Messages;

internal static class GeneratorMessages
{
    public const string ApplicationDataRequired = "applicationName y applicationId son obligatorios.";
    public const string EnvironmentRequired = "Debe existir al menos un ambiente.";
    public const string MicroserviceRequired = "Debe existir al menos un microservicio.";

    public static string EnvironmentNotFound(string name) => $"El ambiente '{name}' no existe.";
    public static string DuplicatePort(int port) => $"El puerto {port} esta repetido.";
    public static string EntityNotFound(string name) => $"La relacion apunta a la entidad inexistente '{name}'.";
    public static string DuplicateEntity(string name) => $"La entidad '{name}' esta duplicada.";
    public static string InvalidRelation(string source, string target) => $"La relacion '{source}' -> '{target}' no tiene una relacion inversa valida.";
    public static string InvalidPath(string path) => $"El path '{path}' debe ser relativo y no puede contener '..'.";
    public static string InvalidFileName(string name) => $"El segmento de ruta '{name}' contiene caracteres no validos.";
    public static string InvalidOutputSegment(string segment) => $"El segmento de salida '{segment}' debe ser un nombre simple, sin separadores de ruta.";
    public static string InvalidDefaultFile(string path) => $"El archivo predeterminado '{path}' debe estar bajo defaults/.";
    public static string DuplicateOutput(string kind, string path) => $"El {kind} '{path}' esta duplicado.";
    public static string OutputPathConflict(string path) => $"La ruta de salida '{path}' esta en conflicto con otra ruta o con un archivo existente.";
    public static string UnresolvedPlaceholder(string key, string path) => $"El placeholder '{key}' no tiene valor en '{path}'.";
    public static string MissingSourceFile(string path) => $"No existe el archivo fuente '{path}'.";
    public static string MissingComponentFile(string path) => $"No existe el archivo fuente '{path}' dentro del componente.";
    public static string EmptyJson(string path) => $"El JSON '{path}' esta vacio.";
    public static string InvalidJson(string path, string error) => $"El JSON '{path}' no es valido: {error}";
    public static string NoInputConfigurations(string path) => $"No se encontraron configuraciones JSON en '{path}'.";
    public static string WorkspaceNotFound(string path) => $"No se encontro la carpeta contenedora de '{path}'.";
    public static string EmptyTemplateSkipped(string template, string target) => $"Plantilla omitida por render vacio: '{template}' -> '{target}'.";
}