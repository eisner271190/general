namespace Generator.Models;

internal sealed record AndroidSigningSecrets(
    string KeyAlias,
    string StorePassword,
    string KeyPassword,
    byte[] KeystoreBytes);