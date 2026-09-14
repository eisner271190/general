namespace Generator.Models;

public sealed record GenerationPlan(string Project, string ApplicationId, string Environment, List<string> Directories, List<PlanFile> Files, List<PlanDefaultFile> DefaultFiles);
public sealed record PlanFile(string Key, string Value);
public sealed record PlanDefaultFile(string Key, string Value);