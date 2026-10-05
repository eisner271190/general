# Trigger por release de `common`: un tag v* arranca un build que sube UNA linea por pom
# (la <version> del import de common-bom) en el repo de la aplicacion y abre un unico PR.
#
# El repo destino lo declara su propio Terraform (cloud/terraform/app/codecommit.tf del proyecto
# generado); aqui no se declara, solo se compone el ARN para el IAM del rol del build.
#
# Cero credenciales: no hay secreto de Git. El build usa la API de CodeCommit (boto3), que
# autentica con el rol del propio proyecto, y el clon de `platform` lo resuelve el credential
# helper nativo de CodeBuild en la imagen estandar.

resource "aws_codebuild_project" "bump_bom" {
  name          = local.bump_project_name
  description   = "Sube la version del import de common-bom en los pom de la aplicacion y abre un PR."
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "APPLICATION_REPOSITORY"
      value = var.application_repository
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "POM_GLOB"
      value = var.application_pom_glob
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "CODEARTIFACT_DOMAIN"
      value = var.domain_name
      type  = "PLAINTEXT"
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
# Disparador: evento CodeCommit "Reference Change" filtrado a tags v*.
# La ingesta de los service events de CodeCommit es gratuita.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "bump_trigger_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bump_trigger" {
  name                 = "epc-bump-trigger"
  description          = "Arranca el build de bump del BOM cuando aparece un tag v* en `common`."
  assume_role_policy   = data.aws_iam_policy_document.bump_trigger_assume.json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "bump_trigger" {
  statement {
    sid       = "StartBumpBuild"
    actions   = ["codebuild:StartBuild"]
    resources = [local.bump_project_arn]
  }

  # EventBridge exige iam:PassRole sobre el rol del proyecto que arranca.
  statement {
    sid       = "PassBuildRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.codebuild.arn]
  }
}

resource "aws_iam_role_policy" "bump_trigger" {
  name   = "bump-trigger"
  role   = aws_iam_role.bump_trigger.id
  policy = data.aws_iam_policy_document.bump_trigger.json
}

resource "aws_cloudwatch_event_rule" "common_release" {
  name = local.release_rule_name

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
  role_arn = aws_iam_role.bump_trigger.arn

  input = jsonencode({
    projectName = local.bump_project_name
  })
}