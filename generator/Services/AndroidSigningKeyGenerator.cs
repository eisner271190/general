using System.Diagnostics;
using System.Security.Cryptography;
using Generator.Models;

namespace Generator.Services;

internal interface IAndroidSigningKeyGenerator
{
    AndroidSigningSecrets Generate(string applicationId);
}

internal sealed class AndroidSigningKeyGenerator : IAndroidSigningKeyGenerator
{
    private const int PasswordLength = 32;
    private const string PasswordCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

    public AndroidSigningSecrets Generate(string applicationId)
    {
        var keyAlias = $"upload-{applicationId.Replace('.', '-')}";
        var storePassword = GeneratePassword();
        var keyPassword = GeneratePassword();
        var temporaryDirectory = Path.Combine(Path.GetTempPath(), "epc-signing", Guid.NewGuid().ToString("N"));
        var keystorePath = Path.Combine(temporaryDirectory, "upload-keystore.jks");

        try
        {
            Directory.CreateDirectory(temporaryDirectory);
            CreateKeystore(keystorePath, keyAlias, storePassword, keyPassword, applicationId);
            return new AndroidSigningSecrets(keyAlias, storePassword, keyPassword, File.ReadAllBytes(keystorePath));
        }
        finally
        {
            if (Directory.Exists(temporaryDirectory))
                Directory.Delete(temporaryDirectory, recursive: true);
        }
    }

    private static void CreateKeystore(string keystorePath, string keyAlias, string storePassword, string keyPassword, string applicationId)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = GetKeytoolPath(),
                UseShellExecute = false,
                RedirectStandardInput = true,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            }
        };

        process.StartInfo.ArgumentList.Add("-genkeypair");
        process.StartInfo.ArgumentList.Add("-alias");
        process.StartInfo.ArgumentList.Add(keyAlias);
        process.StartInfo.ArgumentList.Add("-keyalg");
        process.StartInfo.ArgumentList.Add("RSA");
        process.StartInfo.ArgumentList.Add("-keysize");
        process.StartInfo.ArgumentList.Add("2048");
        process.StartInfo.ArgumentList.Add("-validity");
        process.StartInfo.ArgumentList.Add("10000");
        process.StartInfo.ArgumentList.Add("-storetype");
        process.StartInfo.ArgumentList.Add("JKS");
        process.StartInfo.ArgumentList.Add("-keystore");
        process.StartInfo.ArgumentList.Add(keystorePath);
        process.StartInfo.ArgumentList.Add("-dname");
        process.StartInfo.ArgumentList.Add($"CN={applicationId}");

        if (!process.Start())
            throw new InvalidOperationException("No se pudo iniciar keytool.");

        process.StandardInput.WriteLine(storePassword);
        process.StandardInput.WriteLine(storePassword);
        process.StandardInput.WriteLine(keyPassword);
        process.StandardInput.Close();
        process.WaitForExit();

        if (process.ExitCode != 0 || !File.Exists(keystorePath))
            throw new InvalidOperationException("keytool no pudo crear el upload keystore.");
    }

    private static string GeneratePassword()
    {
        var password = new char[PasswordLength];
        for (var index = 0; index < password.Length; index++)
            password[index] = PasswordCharacters[RandomNumberGenerator.GetInt32(PasswordCharacters.Length)];

        return new string(password);
    }

    private static string GetKeytoolPath()
    {
        var javaHome = Environment.GetEnvironmentVariable("JAVA_HOME");
        return string.IsNullOrWhiteSpace(javaHome) ? "keytool" : Path.Combine(javaHome, "bin", "keytool.exe");
    }
}