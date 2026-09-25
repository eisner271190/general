namespace Generator.Application;

internal static class GeneratorLogger
{
    public static void Info(string message) => Write(FormatLine("INFO", message), Console.Out);

    public static void Debug(string message) => Write(FormatLine("DEBUG", message), Console.Out);

    public static void Error(string message) => Write(FormatLine("ERROR", message), Console.Error);

    private static void Write(string line, TextWriter output)
    {
        var timestamp = DateTime.Now.ToString("HH:mm:ss");
        output.WriteLine($"[{timestamp}] {line}");
    }

    private static string FormatLine(string level, string message) => $"[{level,-5}] {message}";
}
