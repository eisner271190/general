namespace Generator.Models;

internal sealed record AndroidSigningSecretReferences(
    string Keystore,
    string StorePassword,
    string KeyPassword,
    string KeyAlias);