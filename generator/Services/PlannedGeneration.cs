using Generator.Models;

namespace Generator.Services;

internal sealed record PlannedGeneration(GenerationPlan Plan, string OutputDirectory);
