namespace Generator.Application;

internal interface IPlanExecutorFactory
{
    IPlanExecutor Create(string outputDirectory);
}
