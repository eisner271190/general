namespace Generator.Validation;

internal interface IPathValidator
{
    string NormalizeRelative(string path);
    string NormalizeOutputSegment(string segment);
    string DefaultOutputPath(string sourcePath);
}
