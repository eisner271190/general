# Roles IAM de la plataforma. Minimo privilegio y sin comodines por clave.
#
# El bucket de buildspecs sirve para buildspecs, artifact store, logs y cache de CodeBuild.
# Las claves de las tres ultimas las genera el servicio, no este repositorio: enumerarlas
# con comodines se rompe en cuanto cambia un nombre de artefacto, asi que los permisos del
# artifact store se conceden a nivel de bucket (iam.tf, ArtifactStore*).

# --------------------------------------------------------------------------
# common-publisher: publica `common` en CodeArtifact (lo usa el stage Publish del pipeline).
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "common_publisher_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codeartifact.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "common_publisher" {
  name                 = "epc-common-publisher"
  description          = "Publica los artefactos Maven de common en CodeArtifact."
  assume_role_policy   = data.aws_iam_policy_document.common_publisher_assume.json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "common_publisher" {
  # La API de CodeArtifact exige GetAuthorizationToken sobre `*`: es la unica accion global
  # del rol, y solo entrega un token de 12 h para el dominio de la llamada.
  statement {
    sid       = "GetToken"
    actions   = ["codeartifact:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "CommonPackage"
    actions = [
      "codeartifact:GetPackageVersion",
      "codeartifact:PublishPackageVersion",
      "codeartifact:ReadFromRepository",
    ]
    resources = [local.codeartifact_package_arn]
  }
}

resource "aws_iam_role_policy" "common_publisher" {
  name   = "common-publisher"
  role   = aws_iam_role.common_publisher.id
  policy = data.aws_iam_policy_document.common_publisher.json
}

# --------------------------------------------------------------------------
# common-reader: lectura del repositorio maven para los builds de los ms.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "common_reader_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "common_reader" {
  name                 = "epc-common-reader"
  description          = "Resuelve com.epc.common:* desde CodeArtifact en los builds de los microservicios."
  assume_role_policy   = data.aws_iam_policy_document.common_reader_assume.json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "common_reader" {
  statement {
    sid       = "GetToken"
    actions   = ["codeartifact:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ReadCommonPackage"
    actions = [
      "codeartifact:GetPackageVersion",
      "codeartifact:ReadFromRepository",
    ]
    resources = [local.codeartifact_package_arn]
  }
}

resource "aws_iam_role_policy" "common_reader" {
  name   = "common-reader"
  role   = aws_iam_role.common_reader.id
  policy = data.aws_iam_policy_document.common_reader.json
}

# --------------------------------------------------------------------------
# buildspecs-publisher: `aws s3 sync` (scripts/publish-buildspecs.sh) sobre el bucket.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "buildspecs_publisher_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    # S3 exige que el principal que hace sync sea el propio bucket.
    condition {
      test     = "StringEquals"
      variable = "s3:SourceArn"
      values   = ["arn:aws:s3:::${var.buildspecs_bucket}/${var.buildspecs_bucket}"]
    }
  }
}

resource "aws_iam_role" "buildspecs_publisher" {
  name                 = "epc-buildspecs-publisher"
  description          = "Publica los buildspecs compartidos en el bucket versionado."
  assume_role_policy   = data.aws_iam_policy_document.buildspecs_publisher_assume.json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "buildspecs_publisher" {
  # `s3 sync` necesita enumerar el bucket para decidir que subir.
  statement {
    sid       = "EnumerateBucket"
    actions   = ["s3:GetBucketVersioning", "s3:ListBucket"]
    resources = [aws_s3_bucket.buildspecs.arn]
  }

  statement {
    sid       = "UploadBuildspecs"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.buildspecs.arn}/*"]
  }
}

resource "aws_iam_role_policy" "buildspecs_publisher" {
  name   = "buildspecs-publisher"
  role   = aws_iam_role.buildspecs_publisher.id
  policy = data.aws_iam_policy_document.buildspecs_publisher.json
}

# --------------------------------------------------------------------------
# codebuild: rol de servicio de los 4 proyectos CodeBuild (los 2 del pipeline de `common`
# y los 2 de automatizacion de renovate.tf). Compartirlo evita cuatro roles identicos.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name                 = "epc-codebuild"
  description          = "Rol de servicio de los proyectos CodeBuild de la plataforma."
  assume_role_policy   = data.aws_iam_policy_document.codebuild_assume.json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid = "ArtifactStoreBucket"
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:PutBucketAcl",
    ]
    resources = [aws_s3_bucket.buildspecs.arn]
  }

  statement {
    sid = "ArtifactStoreObjects"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.buildspecs.arn}/*"]
  }

  statement {
    sid       = "GetEcrToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Solo push sobre el repositorio de la imagen base. No hay GetDownloadUrlForLayer: las
  # imagenes base de los ms se construyen desde public.ecr.aws, no desde este repositorio.
  statement {
    sid = "PushCommonBase"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteMultipartUpload",
      "ecr:InitiateMultipartUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.common_base.arn]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "codebuild"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

# --------------------------------------------------------------------------
# pipeline: rol de servicio de CodePipeline. PollForSourceChanges=true (no hay webhook
# posible en CodeCommit), asi que no hace falta ningun secreto de webhook.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "pipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name                 = "epc-common-pipeline"
  description          = "Rol de servicio del pipeline de publicacion de `common`."
  assume_role_policy   = data.aws_iam_policy_document.pipeline_assume.json
  max_session_duration = 3600
  tags                 = local.tags
}

data "aws_iam_policy_document" "pipeline" {
  statement {
    sid = "ArtifactStoreBucket"
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:PutBucketAcl",
    ]
    resources = [aws_s3_bucket.buildspecs.arn]
  }

  statement {
    sid = "ArtifactStoreObjects"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.buildspecs.arn}/*"]
  }

  # CodeCommit del repo `common`: acotado a ese repositorio, nunca a `*`.
  statement {
    sid = "ReadCommonRepository"
    actions = [
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:GetRepository",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:ListBranches",
      "codecommit:UploadArchive",
    ]
    resources = [local.common_repository_arn]
  }

  statement {
    sid       = "StartPipeline"
    actions   = ["codepipeline:CreatePipelineExecution"]
    resources = [module.pipeline.arn]
  }

  statement {
    sid       = "RunBuildProjects"
    actions   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
    resources = [module.pipeline.build_project_arn, module.pipeline.publish_project_arn]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name   = "pipeline"
  role   = aws_iam_role.pipeline.id
  policy = data.aws_iam_policy_document.pipeline.json
}