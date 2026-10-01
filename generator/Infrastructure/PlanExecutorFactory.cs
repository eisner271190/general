using Generator.Application;

namespace Generator.Infrastructure;

internal sealed class PlanExecutorFactory(string workingDirectory, IJsonFileReader jsonReader, IPathValidator pathValidator) : IPlanExecutorFactory
{
    public IPlanExecutor Create(string outputDirectory) =>
        new PlanExecutor(outputDirectory, workingDirectory, jsonReader, pathValidator);
}
