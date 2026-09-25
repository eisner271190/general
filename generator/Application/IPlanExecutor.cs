using Generator.Domain.Models;

namespace Generator.Application;

internal interface IPlanExecutor
{
    void Execute(GenerationPlan plan);
}
