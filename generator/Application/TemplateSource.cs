namespace Generator.Application;

// Contenido de una plantilla y su ruta de origen (la ruta alimenta los mensajes de error).
internal sealed record TemplateSource(string Content, string Path);
