# Renovate y bump de la version del BOM (ADR-0018).
#
# CodeCommit no tiene plataforma de PR en Renovate (no existe `platform: awsCodeCommit`), asi
# que el trabajo se reparte en dos caminos, los dos en CodeBuild:
#
#   1. Renovate programado -> Scheduler semanal -> este repositorio actualiza las versiones
#      de terceros del BOM en `common` con `platform: local` y deja ramas.
#   2. Trigger por release -> tag v* en `common` -> bump-bom-version.py sube UNA linea (la
#      <version> del import de common-bom) en cada ms y abre el PR idempotente.
#
# Los repos de CodeCommit los crea el usuario: aqui solo se compone su ARN.

# --------------------------------------------------------------------------
# Credenciales de Git de CodeCommit. Declarado vacio a proposito: las siembra el usuario.
# --------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "codecommit_git" {
  name                    = "${local.secret_name_prefix}/codecommit-git"
  description             = "Credenciales Git HTTPS de CodeCommit (claves: username, password)."
  recovery_window_in_days = 0

  tags = merge(local.tags, { Name = "${local.secret_name_prefix}/codecommit-git" })
}

locals {
  # El buildspec clona por HTTPS con GIT_ASKPASS: la contrasena no se escribe ni en
  # ~/.gitconfig ni en el disco del build.
  git_username_secret = "${aws_secretsmanager_secret.codecommit_git.arn}:username"
  git_password_secret = "${aws_secretsmanager_secret.codecommit_git.arn}:password"

  common_git_url   = "https://git-codecommit.${var.region}.amazonaws.com/v1/repos/${var.common_source_bucket}"
  platform_git_url = "https://git-codecommit.${var.region}.amazonaws.com/v1/repos/${var.platform_source_bucket}"
}

# --------------------------------------------------------------------------
# common-renovate: Renovate programado sobre el repo `common`.
# --------------------------------------------------------------------------

resource "aws_codebuild_project" "renovate" {
  name          = local.renovate_project_name
  description   = "Renovate semanal sobre `common` (platform: local, sin credenciales en el repo)."
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 60

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CODEBUILD_SOURCE_REPO_URL"
      value = local.common_git_url
      type  = "PLAINTEXT"
    }

    # Renovate construye sus hostRules del entorno (RENOVATE_DETECT_HOST_RULES_FROM_ENV=true),
    # de modo que el repositorio no lleva ninguna credencial.
    environment_variable {
      name  = "MAVEN_USERNAME"
      value = "aws"
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "CODEARTIFACT_URL"
      value = local.codeartifact_url
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "CODEARTIFACT_AUTH_TOKEN"
      value = "${aws_secretsmanager_secret.codeartifact.arn}:token"
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "MAVEN_PASSWORD"
      value = "${aws_secretsmanager_secret.codeartifact.arn}:token"
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GIT_USERNAME"
      value = local.git_username_secret
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GIT_PASSWORD"
      value = local.git_password_secret
      type  = "SECRETS_MANAGER"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "arn:aws:s3:::${var.buildspecs_bucket}/renovate.yml"
  }

  artifacts {
    type     = "S3"
    location = var.buildspecs_bucket
  }

  tags = local.tags
}

# --------------------------------------------------------------------------
# platform-bump-bom: se dispara con el evento CodeCommit "Reference Change" (tag v*).
# El repositorio es `platform`, que es donde vive bump-bom-version.py.
# La version no viaja por variable: el script resuelve el ultimo tag v* de `common`.
# --------------------------------------------------------------------------

resource "aws_codebuild_project" "bump_bom" {
  name          = local.bump_project_name
  description   = "Sube la version del import de common-bom en cada ms y abre el PR."
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "CODEBUILD_SOURCE_REPO_URL"
      value = local.platform_git_url
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "MS_REPOSITORY_PREFIX"
      value = var.ms_repository_prefix
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "CODEARTIFACT_URL"
      value = local.codeartifact_url
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "GIT_USERNAME"
      value = local.git_username_secret
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GIT_PASSWORD"
      value = local.git_password_secret
      type  = "SECRETS_MANAGER"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "arn:aws:s3:::${var.buildspecs_bucket}/bump-bom.yml"
  }

  artifacts {
    type     = "S3"
    location = var.buildspecs_bucket
  }

  tags = local.tags
}

# --------------------------------------------------------------------------
# Disparadores: Scheduler semanal (4 ejecuciones/mes, dentro de las 14 gratuitas de
# EventBridge Scheduler) y regla sobre el evento de CodeCommit (ingesta gratuita).
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "renovate_scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com", "events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "renovate_scheduler" {
  name                 = "epc-renovate-scheduler"
  description          = "Dispara el build programado de Renovate."
  assume_role_policy   = data.aws_iam_policy_document.renovate_scheduler_assume.json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "renovate_scheduler" {
  statement {
    sid       = "StartRenovateBuild"
    actions   = ["codebuild:StartBuild"]
    resources = [local.renovate_project_arn]
  }

  # El Scheduler exige iam:PassRole sobre el rol del proyecto que arranca.
  statement {
    sid       = "PassBuildRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.codebuild.arn]
  }
}

resource "aws_iam_role_policy" "renovate_scheduler" {
  name   = "renovate-scheduler"
  role   = aws_iam_role.renovate_scheduler.id
  policy = data.aws_iam_policy_document.renovate_scheduler.json
}

resource "aws_scheduler_schedule" "renovate" {
  name       = local.renovate_schedule_name
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.renovate_schedule_expression

  target {
    arn      = local.renovate_project_arn
    role_arn = aws_iam_role.renovate_scheduler.arn

    input = jsonencode({
      source = local.renovate_project_name
    })
  }
}

resource "aws_cloudwatch_event_rule" "common_release" {
  name = local.release_rule_name

  # CodeCommit "Reference Change" filtrado a tags v*: una release de `common` arranca el bump.
  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Reference Change"]
    detail = {
      repositoryName = [var.common_source_bucket]
      referenceName  = [{ prefix = "refs/tags/v" }]
    }
  })
}

resource "aws_cloudwatch_event_target" "common_release" {
  rule     = aws_cloudwatch_event_rule.common_release.name
  arn      = local.bump_project_arn
  role_arn = aws_iam_role.renovate_scheduler.arn

  input = jsonencode({
    projectName = local.bump_project_name
  })
}