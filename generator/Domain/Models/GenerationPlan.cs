namespace Generator.Domain.Models;

public sealed record GenerationPlan(string Project, string ApplicationId, string Environment, List<string> Directories, List<PlanFile> Files, List<PlanDefaultFile> DefaultFiles);
