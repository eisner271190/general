using Generator.Models;

namespace Generator.Services;

internal interface ISecretsManager
{
    Task EnsureNamesAvailableAsync(AndroidSigningSecretReferences references, CancellationToken cancellationToken);
    Task StoreAsync(AndroidSigningSecretReferences references, AndroidSigningSecrets secrets, CancellationToken cancellationToken);
    Task<AndroidSigningSecrets?> GetAsync(AndroidSigningSecretReferences references, CancellationToken cancellationToken);
}