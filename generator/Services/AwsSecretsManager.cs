using Amazon;
using Amazon.SecretsManager;
using Amazon.SecretsManager.Model;
using Generator.Models;

namespace Generator.Services;

internal sealed class AwsSecretsManager : ISecretsManager
{
    private readonly IAmazonSecretsManager client;

    public AwsSecretsManager(string region)
    {
        client = new AmazonSecretsManagerClient(RegionEndpoint.GetBySystemName(region));
    }

    public async Task EnsureNamesAvailableAsync(AndroidSigningSecretReferences references, CancellationToken cancellationToken)
    {
        foreach (var name in GetNames(references))
        {
            try
            {
                await client.DescribeSecretAsync(new DescribeSecretRequest { SecretId = name }, cancellationToken);
                GeneratorLogger.Info($"Secret already exists: {name}");
            }
            catch (ResourceNotFoundException)
            {
                GeneratorLogger.Info($"Secret does not exist (will create if needed): {name}");
            }
        }
    }

    public async Task StoreAsync(AndroidSigningSecretReferences references, AndroidSigningSecrets secrets, CancellationToken cancellationToken)
    {
        var createdNames = new List<string>();

        try
        {
            if (!await ExistsAsync(references.Keystore, cancellationToken))
            {
                await CreateBinarySecretAsync(references.Keystore, secrets.KeystoreBytes, cancellationToken);
                createdNames.Add(references.Keystore);
            }
            else
            {
                GeneratorLogger.Info($"Skipping creation, secret exists: {references.Keystore}");
            }

            if (!await ExistsAsync(references.StorePassword, cancellationToken))
            {
                await CreateTextSecretAsync(references.StorePassword, secrets.StorePassword, cancellationToken);
                createdNames.Add(references.StorePassword);
            }
            else
            {
                GeneratorLogger.Info($"Skipping creation, secret exists: {references.StorePassword}");
            }

            if (!await ExistsAsync(references.KeyPassword, cancellationToken))
            {
                await CreateTextSecretAsync(references.KeyPassword, secrets.KeyPassword, cancellationToken);
                createdNames.Add(references.KeyPassword);
            }
            else
            {
                GeneratorLogger.Info($"Skipping creation, secret exists: {references.KeyPassword}");
            }

            if (!await ExistsAsync(references.KeyAlias, cancellationToken))
            {
                await CreateTextSecretAsync(references.KeyAlias, secrets.KeyAlias, cancellationToken);
                createdNames.Add(references.KeyAlias);
            }
            else
            {
                GeneratorLogger.Info($"Skipping creation, secret exists: {references.KeyAlias}");
            }
        }
        catch
        {
            foreach (var name in createdNames)
                await client.DeleteSecretAsync(new DeleteSecretRequest { SecretId = name, ForceDeleteWithoutRecovery = true }, cancellationToken);

            throw;
        }
    }

    public async Task<AndroidSigningSecrets?> GetAsync(AndroidSigningSecretReferences references, CancellationToken cancellationToken)
    {
        try
        {
            if (!await ExistsAsync(references.Keystore, cancellationToken))
                return null;

            if (!await ExistsAsync(references.StorePassword, cancellationToken))
                return null;

            if (!await ExistsAsync(references.KeyPassword, cancellationToken))
                return null;

            if (!await ExistsAsync(references.KeyAlias, cancellationToken))
                return null;

            byte[] keystoreBytes;
            string storePassword;
            string keyPassword;
            string keyAlias;

            var keystoreResp = await client.GetSecretValueAsync(new GetSecretValueRequest { SecretId = references.Keystore }, cancellationToken);
            if (keystoreResp.SecretBinary is null)
                return null;
            using (keystoreResp.SecretBinary)
            {
                keystoreBytes = ((MemoryStream)keystoreResp.SecretBinary).ToArray();
            }

            var storeResp = await client.GetSecretValueAsync(new GetSecretValueRequest { SecretId = references.StorePassword }, cancellationToken);
            storePassword = storeResp.SecretString ?? string.Empty;

            var keyResp = await client.GetSecretValueAsync(new GetSecretValueRequest { SecretId = references.KeyPassword }, cancellationToken);
            keyPassword = keyResp.SecretString ?? string.Empty;

            var aliasResp = await client.GetSecretValueAsync(new GetSecretValueRequest { SecretId = references.KeyAlias }, cancellationToken);
            keyAlias = aliasResp.SecretString ?? string.Empty;

            return new AndroidSigningSecrets(keyAlias, storePassword, keyPassword, keystoreBytes);
        }
        catch (Exception)
        {
            return null;
        }
    }

    private async Task<bool> ExistsAsync(string name, CancellationToken cancellationToken)
    {
        try
        {
            await client.DescribeSecretAsync(new DescribeSecretRequest { SecretId = name }, cancellationToken);
            return true;
        }
        catch (ResourceNotFoundException)
        {
            return false;
        }
    }

    private async Task CreateBinarySecretAsync(string name, byte[] value, CancellationToken cancellationToken) =>
        await client.CreateSecretAsync(new CreateSecretRequest { Name = name, SecretBinary = new MemoryStream(value) }, cancellationToken);

    private async Task CreateTextSecretAsync(string name, string value, CancellationToken cancellationToken) =>
        await client.CreateSecretAsync(new CreateSecretRequest { Name = name, SecretString = value }, cancellationToken);

    private static IEnumerable<string> GetNames(AndroidSigningSecretReferences references) =>
    [
        references.Keystore,
        references.StorePassword,
        references.KeyPassword,
        references.KeyAlias
    ];

    private async Task EnsureDoesNotExistAsync(string name, CancellationToken cancellationToken)
    {
        try
        {
            await client.DescribeSecretAsync(new DescribeSecretRequest { SecretId = name }, cancellationToken);
            throw new InvalidOperationException($"Ya existe el secreto '{name}'.");
        }
        catch (ResourceNotFoundException)
        {
        }
    }
}