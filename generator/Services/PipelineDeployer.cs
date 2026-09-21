using Amazon.CodePipeline;
using Amazon.CodePipeline.Model;
using Amazon.CodeBuild;
using Amazon.CodeBuild.Model;
using Amazon.IdentityManagement;
using Amazon.IdentityManagement.Model;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.SecurityToken;
using Generator.Configuration;
using Generator.Messages;

namespace Generator.Services;

internal interface IPipelineDeployer
{
    Task DeployAsync(string applicationId, string outputDirectory, string? gitHubOwner = null, string? gitHubRepo = null, string? gitHubBranch = null, CancellationToken cancellationToken = default);
}

internal sealed class PipelineDeployer : IPipelineDeployer
{
    private readonly string _region;
    private readonly IAmazonCodePipeline _pipelineClient;
    private readonly IAmazonCodeBuild _codeBuildClient;
    private readonly IAmazonIdentityManagementService _iamClient;
    private readonly IAmazonS3 _s3Client;
    private readonly IAmazonSecurityTokenService _stsClient;
    private readonly IRepositoryProvider _repositoryProvider;

    public PipelineDeployer(string region, IRepositoryProvider repositoryProvider)
    {
        _region = region;
        _repositoryProvider = repositoryProvider;
        var endpoint = Amazon.RegionEndpoint.GetBySystemName(region);
        _pipelineClient = new AmazonCodePipelineClient(endpoint);
        _codeBuildClient = new AmazonCodeBuildClient(endpoint);
        _iamClient = new AmazonIdentityManagementServiceClient(endpoint);
        _s3Client = new AmazonS3Client(endpoint);
        _stsClient = new AmazonSecurityTokenServiceClient(endpoint);
    }

    public async Task DeployAsync(string applicationId, string outputDirectory, string? gitHubOwner = null, string? gitHubRepo = null, string? gitHubBranch = null, CancellationToken cancellationToken = default)
    {
        var safeName = applicationId.Replace('.', '-').ToLowerInvariant();
        var bucketName = $"{safeName}-aab-artifacts";
        var codebuildRoleName = $"{safeName}-codebuild-role";
        var codepipelineRoleName = $"{safeName}-codepipeline-role";
        var codebuildProjectName = $"{safeName}-flutter-aab";
        var pipelineName = $"{safeName}-aab-pipeline";
        var repoName = gitHubRepo ?? safeName;
        var branchName = gitHubBranch ?? "main";

        try
        {
            GeneratorLogger.Info($"Creando bucket S3: {bucketName}");
            await CreateBucketAsync(bucketName, cancellationToken);

            GeneratorLogger.Info($"Creando repositorio: {repoName}");
            var connectionArn = await _repositoryProvider.CreateRepositoryAsync(repoName, branchName, cancellationToken);

            GeneratorLogger.Info($"Creando IAM Role para CodeBuild: {codebuildRoleName}");
            var codebuildRoleArn = await CreateCodeBuildRoleAsync(codebuildRoleName, bucketName, repoName, cancellationToken);

            GeneratorLogger.Info($"Creando IAM Role para CodePipeline: {codepipelineRoleName}");
            var codepipelineRoleArn = await CreateCodePipelineRoleAsync(codepipelineRoleName, bucketName, repoName, cancellationToken);

            GeneratorLogger.Info($"Creando proyecto CodeBuild: {codebuildProjectName}");
            await CreateCodeBuildProjectAsync(codebuildProjectName, codebuildRoleArn, applicationId, cancellationToken);

            GeneratorLogger.Info($"Creando pipeline: {pipelineName}");
            await CreatePipelineAsync(pipelineName, codepipelineRoleArn, bucketName, codebuildProjectName, repoName, branchName, connectionArn, cancellationToken);

            GeneratorLogger.Info($"Pipeline desplegado exitosamente: {pipelineName}");
        }
        catch (Exception ex)
        {
            var caused = ex.InnerException is not null ? $" Caused by: {ex.InnerException.Message}" : string.Empty;
            GeneratorLogger.Error($"Error al desplegar pipeline para '{applicationId}': {ex.Message}{caused}");
            throw new GeneratorException(ErrorCodes.PipelineDeploymentFailed, $"Error al desplegar pipeline: {ex.Message}");
        }
    }

    private async Task CreateBucketAsync(string bucketName, CancellationToken cancellationToken)
    {
        try
        {
            await _s3Client.PutBucketAsync(new PutBucketRequest { BucketName = bucketName }, cancellationToken);
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)
        {
            GeneratorLogger.Info($"Bucket {bucketName} ya existe");
        }
    }

    private async Task<string> CreateCodeBuildRoleAsync(string roleName, string bucketName, string repoName, CancellationToken cancellationToken)
    {
        var trustPolicy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"codebuild.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}";

        Role role;
        try
        {
            var getRoleResponse = await _iamClient.GetRoleAsync(new GetRoleRequest { RoleName = roleName }, cancellationToken);
            role = getRoleResponse.Role;
            await _iamClient.UpdateAssumeRolePolicyAsync(new UpdateAssumeRolePolicyRequest
            {
                RoleName = roleName,
                PolicyDocument = trustPolicy
            }, cancellationToken);
        }
        catch (NoSuchEntityException)
        {
            var createRoleResponse = await _iamClient.CreateRoleAsync(new CreateRoleRequest { RoleName = roleName, AssumeRolePolicyDocument = trustPolicy }, cancellationToken);
            role = createRoleResponse.Role;
        }

        var secretsPolicy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"secretsmanager:GetSecretValue\",\"Resource\":\"arn:aws:secretsmanager:" + _region + ":*:secret:/epc/*\"}]}";
        await _iamClient.PutRolePolicyAsync(new PutRolePolicyRequest { RoleName = roleName, PolicyName = "SecretsManagerAccess", PolicyDocument = secretsPolicy }, cancellationToken);

        var logsPolicy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"logs:CreateLogGroup\",\"logs:CreateLogStream\",\"logs:PutLogEvents\"],\"Resource\":\"*\"}]}";
        await _iamClient.PutRolePolicyAsync(new PutRolePolicyRequest { RoleName = roleName, PolicyName = "CloudWatchLogs", PolicyDocument = logsPolicy }, cancellationToken);

        var s3Policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:GetObjectVersion\",\"s3:GetBucketVersioning\",\"s3:PutObject\"],\"Resource\":[\"arn:aws:s3:::" + bucketName + "/*\",\"arn:aws:s3:::" + bucketName + "\"]}]}";
        await _iamClient.PutRolePolicyAsync(new PutRolePolicyRequest { RoleName = roleName, PolicyName = "S3ArtifactsAccess", PolicyDocument = s3Policy }, cancellationToken);

        return role.Arn;
    }

    private async Task<string> CreateCodePipelineRoleAsync(string roleName, string bucketName, string repoName, CancellationToken cancellationToken)
    {
        var trustPolicy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"codepipeline.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}";

        Role role;
        try
        {
            var getRoleResponse = await _iamClient.GetRoleAsync(new GetRoleRequest { RoleName = roleName }, cancellationToken);
            role = getRoleResponse.Role;
        }
        catch (NoSuchEntityException)
        {
            var createRoleResponse = await _iamClient.CreateRoleAsync(new CreateRoleRequest { RoleName = roleName, AssumeRolePolicyDocument = trustPolicy }, cancellationToken);
            role = createRoleResponse.Role;
        }

        var pipelinePolicy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:*\",\"codebuild:*\",\"codecommit:*\",\"codestar-connections:UseConnection\"],\"Resource\":\"*\"}]}";
        await _iamClient.PutRolePolicyAsync(new PutRolePolicyRequest { RoleName = roleName, PolicyName = "CodePipelineAccess", PolicyDocument = pipelinePolicy }, cancellationToken);

        return role.Arn;
    }

    private async Task CreateCodeBuildProjectAsync(string projectName, string serviceRoleArn, string applicationId, CancellationToken cancellationToken)
    {
        try
        {
            await _codeBuildClient.DeleteProjectAsync(new DeleteProjectRequest { Name = projectName }, cancellationToken);
        }
        catch (Exception) { }

        await _codeBuildClient.CreateProjectAsync(new CreateProjectRequest
        {
            Name = projectName,
            Description = $"Build signed AAB for {applicationId}",
            ServiceRole = serviceRoleArn,
            Artifacts = new ProjectArtifacts { Type = ArtifactsType.CODEPIPELINE },
            Environment = new ProjectEnvironment
            {
                Type = EnvironmentType.LINUX_CONTAINER,
                ComputeType = ComputeType.BUILD_GENERAL1_MEDIUM,
                Image = "ghcr.io/gmeligio/flutter-android:3.47.2",
                ImagePullCredentialsType = ImagePullCredentialsType.SERVICE_ROLE
            },
            Source = new ProjectSource { Type = SourceType.CODEPIPELINE },
            TimeoutInMinutes = 30
        }, cancellationToken);
    }

    private async Task CreatePipelineAsync(string pipelineName, string roleArn, string bucketName, string codebuildProjectName, string repoName, string branchName, string? connectionArn, CancellationToken cancellationToken)
    {
        try
        {
            await _pipelineClient.DeletePipelineAsync(new DeletePipelineRequest { Name = pipelineName }, cancellationToken);
        }
        catch (Exception) { }

        var sourceConfig = _repositoryProvider.GetSourceConfiguration(repoName, branchName, connectionArn);

        await _pipelineClient.CreatePipelineAsync(new CreatePipelineRequest
        {
            Pipeline = new PipelineDeclaration
            {
                Name = pipelineName,
                RoleArn = roleArn,
                ArtifactStore = new ArtifactStore { Type = ArtifactStoreType.S3, Location = bucketName },
                Stages = new List<StageDeclaration>
                {
                    new StageDeclaration
                    {
                        Name = "Source",
                        Actions = new List<ActionDeclaration>
                        {
                            new ActionDeclaration
                            {
                                Name = "Source",
                                ActionTypeId = new ActionTypeId
                                {
                                    Category = ActionCategory.Source,
                                    Owner = "AWS",
                                    Provider = _repositoryProvider.GetSourceActionProvider(),
                                    Version = "1"
                                },
                                Configuration = sourceConfig,
                                OutputArtifacts = new List<OutputArtifact> { new OutputArtifact { Name = "SourceOutput" } }
                            }
                        }
                    },
                    new StageDeclaration
                    {
                        Name = "Build",
                        Actions = new List<ActionDeclaration>
                        {
                            new ActionDeclaration
                            {
                                Name = "BuildAAB",
                                ActionTypeId = new ActionTypeId
                                {
                                    Category = ActionCategory.Build,
                                    Owner = "AWS",
                                    Provider = "CodeBuild",
                                    Version = "1"
                                },
                                Configuration = new Dictionary<string, string> { { "ProjectName", codebuildProjectName } },
                                InputArtifacts = new List<InputArtifact> { new InputArtifact { Name = "SourceOutput" } },
                                OutputArtifacts = new List<OutputArtifact> { new OutputArtifact { Name = "BuildOutput" } }
                            }
                        }
                    }
                }
            }
        }, cancellationToken);
    }
}
