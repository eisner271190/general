using Generator.Validation;

namespace Generator.Services;

internal sealed class PlanExecutorFactory(string workingDirectory, IJsonFileReader jsonReader, IPathValidator pathValidator) : IPlanExecutorFactory
{
    public IPlanExecutor Create(string outputDirectory) =>
        new PlanExecutor(outputDirectory, workingDirectory, jsonReader, pathValidator);
}
