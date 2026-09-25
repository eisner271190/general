namespace Generator.Services;

internal interface IPlanExecutorFactory
{
    IPlanExecutor Create(string outputDirectory);
}
