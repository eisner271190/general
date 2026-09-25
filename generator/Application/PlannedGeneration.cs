using Generator.Domain.Models;

namespace Generator.Application;

internal sealed record PlannedGeneration(GenerationPlan Plan, string OutputDirectory);
