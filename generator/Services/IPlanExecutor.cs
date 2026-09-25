using Generator.Models;

namespace Generator.Services;

internal interface IPlanExecutor
{
    void Execute(GenerationPlan plan);
}
