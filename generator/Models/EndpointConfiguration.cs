namespace Generator.Models;

public sealed record EndpointConfiguration(string Method, string Path, Dictionary<string, string>? Parameters, string? Response);
