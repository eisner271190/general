# Pipeline de publicacion de `common`: valida (java-ci.yml) y publica (buildspec inline).
#
# El buildspec de publicacion va inline a proposito: hace falta en cada release y anadir un
# quinto fichero al bucket seria una dependencia mas que subir a mano. El de validacion si
# viene del bucket, referenciado por ARN, para que los ms consuman el mismo fichero.

locals {
  build_project_name   = "${var.pipeline_name}-build"
  publish_project_name = "${var.pipeline_name}-publish"

  # El token viaja por Secrets Manager; el endpoint es un valor plano y se lee en el log.
  token_secret = {
    name  = "CODEARTIFACT_AUTH_TOKEN"
    value = "${var.codeartifact_secret_arn}:token"
  }

  # `$${}` sale como `${}`: el shell expande las variables del build y Maven resuelve
  # `${env.CODEARTIFACT_AUTH_TOKEN}` desde el entorno. El heredoc va entre comillas
  # simples para que el shell no toque el contenido.
  publish_buildspec = <<-BUILDSPEC
    version: 0.2

    env:
      variables:
        MAVEN_OPTS: "-Xmx3072m"
        ECR_REPOSITORY: "${var.ecr_repository_url}"

    phases:
      install:
        runtime-versions:
          java: corretto17
      pre_build:
        commands:
          - 'echo "CODEARTIFACT_AUTH_TOKEN presente: $${CODEARTIFACT_AUTH_TOKEN:+si}"'
          - 'echo "CODEARTIFACT_URL: $${CODEARTIFACT_URL}"'
          - |
            mkdir -p "$${HOME}/.m2"
            cat > "$${HOME}/.m2/settings.xml" <<'SETTINGS'
            <?xml version="1.0" encoding="UTF-8"?>
            <settings>
              <servers>
                <server>
                  <!-- El id debe coincidir con el distributionManagement de common/pom.xml. -->
                  <id>codeartifact</id>
                  <username>aws</username>
                  <password>$${env.CODEARTIFACT_AUTH_TOKEN}</password>
                </server>
              </servers>
            </settings>
            SETTINGS
          - 'test -n "$${CODEARTIFACT_URL}" || { echo "CODEARTIFACT_URL vacia"; exit 1; }'
          # La version sale del POM raiz: es la unica fuente de verdad del numero.
          - 'VERSION="$(mvn -B -ntp -N help:evaluate -Dexpression=project.version -DforceStdout -q | tr -d "\r")"'
          - 'test -n "$${VERSION}" || { echo "No se pudo leer project.version"; exit 1; }'
      build:
        commands:
          - 'mvn -B -ntp deploy -Depc.codeartifact.url="$${CODEARTIFACT_URL}"'
      post_build:
        commands:
          - |
            aws ecr get-login-password --region "$${AWS_REGION}" \
              | docker login --username AWS --password-stdin "$${ECR_REPOSITORY%%/*}"
            docker build -f docker/Dockerfile -t "$${ECR_REPOSITORY}:$${VERSION}" "$${CODEBUILD_SRC_DIR}"
            docker push "$${ECR_REPOSITORY}:$${VERSION}"
      finally:
        commands:
          - rm -f "$${HOME}/.m2/settings.xml"
  BUILDSPEC
}

# --------------------------------------------------------------------------
# Stage 1: validacion. Buildspec compartido del bucket (ARN), no una copia en el repo.
# --------------------------------------------------------------------------

resource "aws_codebuild_project" "build" {
  name          = local.build_project_name
  description   = "Valida `common` con el buildspec compartido java-ci.yml."
  service_role  = var.codebuild_role_arn
  build_timeout = 30

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CODEARTIFACT_URL"
      value = var.codeartifact_url
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = local.token_secret.name
      value = local.token_secret.value
      type  = "SECRETS_MANAGER"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "arn:aws:s3:::${var.buildspecs_bucket}/java-ci.yml"
  }

  artifacts {
    type     = "S3"
    location = var.artifact_bucket_name
  }

  tags = var.tags
}

# --------------------------------------------------------------------------
# Stage 2: publicacion. `mvn deploy` + imagen base de la release.
# --------------------------------------------------------------------------

resource "aws_codebuild_project" "publish" {
  name          = local.publish_project_name
  description   = "Publica `common` en CodeArtifact y la imagen base en ECR."
  service_role  = var.codebuild_role_arn
  build_timeout = 60

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CODEARTIFACT_URL"
      value = var.codeartifact_url
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = local.token_secret.name
      value = local.token_secret.value
      type  = "SECRETS_MANAGER"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = local.publish_buildspec
  }

  artifacts {
    type     = "S3"
    location = var.artifact_bucket_name
  }

  tags = var.tags
}

# --------------------------------------------------------------------------
# Pipeline. El source sondea el repo (PollForSourceChanges): CodeCommit no admite webhook.
# --------------------------------------------------------------------------

resource "aws_codepipeline" "this" {
  name     = var.pipeline_name
  role_arn = var.pipeline_role_arn

  artifact_store {
    location = var.artifact_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Common"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["common_source"]
      configuration = {
        RepositoryName       = var.repository_name
        BranchName           = var.source_branch
        PollForSourceChanges = true
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Validate"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["common_source"]
      output_artifacts = ["common_build"]
      configuration = {
        ProjectName = local.build_project_name
      }
    }
  }

  stage {
    name = "Publish"

    action {
      name     = "PublishCommon"
      category = "Build"
      owner    = "AWS"
      provider = "CodeBuild"
      version  = "1"
      # Consume el artefacto del Source, no el del Build: CODEBUILD_SRC_DIR es el input
      # artifact, y `java-ci.yml` no sube artefactos, asi que con `common_build` el proyecto
      # de publicacion recibiria un directorio vacio y no tendria nada que desplegar.
      input_artifacts  = ["common_source"]
      output_artifacts = ["common_published"]
      configuration = {
        ProjectName = local.publish_project_name
      }
    }
  }

  tags = var.tags
}

output "arn" {
  description = "ARN del pipeline. Lo usa el rol de servicio para CreatePipelineExecution."
  value       = aws_codepipeline.this.arn
}

output "build_project_arn" {
  description = "ARN del proyecto CodeBuild de validacion."
  value       = aws_codebuild_project.build.arn
}

output "publish_project_arn" {
  description = "ARN del proyecto CodeBuild de publicacion."
  value       = aws_codebuild_project.publish.arn
}