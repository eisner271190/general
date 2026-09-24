namespace Generator.Services;

internal static class GeneratorLogger
{
    public static void Info(string message) => Write("INFO", message, Console.Out);

    public static void Debug(string message) => Write("DEBUG", message, Console.Out);

    public static void Error(string message) => Write("ERROR", message, Console.Error);

    private static void Write(string level, string message, TextWriter output)
    {
        var timestamp = DateTime.Now.ToString("HH:mm:ss");
        output.WriteLine($"[{timestamp}] [{level,-5}] {message}");
    }
}