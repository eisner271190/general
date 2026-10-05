# Pipeline de publicacion de `common`: valida (java-ci.yml) y publica (buildspec inline).
#
# El buildspec de publicacion va inline a proposito: hace falta en cada release y anadir un
# quinto fichero al bucket seria una dependencia mas que subir a mano. El de validacion si
# viene del bucket, referenciado por ARN, para que los ms consuman el mismo fichero.

locals {
  build_project_name   = "${var.pipeline_name}-build"
  publish_project_name = "${var.pipeline_name}-publish"

  # `$${}` sale como `${}`: el shell expande las variables del build. El heredoc va SIN comillas
  # para que `$CODEARTIFACT_AUTH_TOKEN` se sustituya al generar el settings.xml efimero.
  publish_buildspec = <<-BUILDSPEC
    version: 0.2

    env:
      variables:
        MAVEN_OPTS: "-Xmx3072m"
        ECR_REPOSITORY: "${var.ecr_repository_url}"
        CODEARTIFACT_DOMAIN: "${var.codeartifact_domain_name}"

    phases:
      install:
        runtime-versions:
          java: corretto17
      pre_build:
        commands:
          - 'echo "CODEARTIFACT_URL: $${CODEARTIFACT_URL}"'
          # ADR-0022: el token se pide aqui con la identidad del build y se inyecta en el
          # settings.xml efimero. No hay secreto en Terraform ni en Secrets Manager, y el
          # fichero se borra en `finally`.
          - |
            CODEARTIFACT_AUTH_TOKEN="$(aws codeartifact get-authorization-token \
              --domain "$CODEARTIFACT_DOMAIN" --query authorizationToken --output text)"
            test -n "$CODEARTIFACT_AUTH_TOKEN" || { echo "No se pudo obtener el token"; exit 1; }
            mkdir -p "$${HOME}/.m2"
            cat > "$${HOME}/.m2/settings.xml" <<SETTINGS
            <?xml version="1.0" encoding="UTF-8"?>
            <settings>
              <servers>
                <server>
                  <!-- El id debe coincidir con el distributionManagement de common/pom.xml. -->
                  <id>codeartifact</id>
                  <username>aws</username>
                  <password>$CODEARTIFACT_AUTH_TOKEN</password>
                </server>
              </servers>
            </settings>
            SETTINGS
          - 'unset CODEARTIFACT_AUTH_TOKEN'
          - 'test -n "$${CODEARTIFACT_URL}" || { echo "CODEARTIFACT_URL vacia"; exit 1; }'
      build:
        commands:
          - 'mvn -B -ntp deploy -Depc.codeartifact.url="$${CODEARTIFACT_URL}"'
      post_build:
        commands:
          # La version sale del POM raiz: es la unica fuente de verdad del numero. Se lee aqui
          # y no en pre_build porque CodeBuild ejecuta cada fase en su propia shell: un export
          # de pre_build no llega a post_build.
          - 'VERSION="$(mvn -B -ntp -N help:evaluate -Dexpression=project.version -DforceStdout -q | tr -d "\r")"'
          - 'test -n "$${VERSION}" || { echo "No se pudo leer project.version"; exit 1; }'
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

    # Sin secretos: `java-ci.yml` pide el token con la identidad del build (ADR-0022).
    environment_variable {
      name  = "CODEARTIFACT_DOMAIN"
      value = var.codeartifact_domain_name
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "arn:aws:s3:::${var.buildspecs_bucket}/java-ci.yml"
  }

  # El API de CodeBuild exige artifacts.type = CODEPIPELINE cuando source.type = CODEPIPELINE.
  # El bucket sigue siendo el artifact store del pipeline (artifact_store), no del proyecto.
  artifacts {
    type = "CODEPIPELINE"
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
      name  = "CODEARTIFACT_DOMAIN"
      value = var.codeartifact_domain_name
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = local.publish_buildspec
  }

  # El API de CodeBuild exige artifacts.type = CODEPIPELINE cuando source.type = CODEPIPELINE.
  # El bucket sigue siendo el artifact store del pipeline (artifact_store), no del proyecto.
  artifacts {
    type = "CODEPIPELINE"
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