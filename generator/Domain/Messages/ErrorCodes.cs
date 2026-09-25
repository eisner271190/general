namespace Generator.Domain.Messages;

internal static class ErrorCodes
{
    public const string InvalidConfiguration = "GEN002";
    public const string EnvironmentNotFound = "GEN003";
    public const string DuplicatePort = "GEN004";
    public const string EntityNotFound = "GEN005";
    public const string InvalidRelation = "GEN006";
    public const string InvalidPath = "GEN007";
    public const string InvalidDefaultFile = "GEN008";
    public const string DuplicateOutput = "GEN009";
    public const string UnresolvedPlaceholder = "GEN011";
    public const string MissingSourceFile = "GEN012";
    public const string EmptyJson = "GEN013";
    public const string NoInputConfigurations = "GEN014";
    public const string InvalidTemplate = "GEN015";
    public const string WorkspaceNotFound = "GEN016";
    public const string InvalidJson = "GEN017";
}