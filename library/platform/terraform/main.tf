# Bucket de buildspecs compartidos, repositorio ECR de la imagen base y datos derivados.
#
# El bucket cumple cuatro funciones: buildspecs (raiz), artifact store de CodePipeline,
# logs y cache de CodeBuild. Las claves de las tres ultimas las genera el servicio, asi que
# los permisos IAM se conceden a nivel de bucket (ver iam.tf), nunca con comodines por clave.

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Repos de plataforma (codecommit.tf). El repo de la aplicacion lo declara su propio
  # Terraform (cloud/terraform/app/codecommit.tf del proyecto generado); aqui solo se compone
  # el ARN porque el IAM del trigger de bump necesita nombrarlo.
  common_repository_arn   = aws_codecommit_repository.common.arn
  platform_repository_arn = aws_codecommit_repository.platform.arn

  application_repository_arn = "arn:aws:codecommit:${var.region}:${local.account_id}:repository/${var.application_repository}"

  codeartifact_package_arn = "arn:aws:codeartifact:${var.region}:${local.account_id}:repository/${aws_codeartifact_domain.epc.domain}/${aws_codeartifact_repository.common.repository}"

  # Endpoint maven de CodeArtifact: sale del data source que ya expone outputs.tf, no de una
  # constante. Llega al build como CODEARTIFACT_URL y sustituye al placeholder por -D.
  codeartifact_url = data.aws_codeartifact_repository_endpoint.common.repository_endpoint

  pipeline_name     = "common"
  bump_project_name = "platform-bump-bom"
  bump_project_arn  = "arn:aws:codebuild:${var.region}:${local.account_id}:project/${local.bump_project_name}"
  release_rule_name = "common-release"

  tags = {
    Project     = "epc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# --------------------------------------------------------------------------
# Buildspecs compartidos + artifact store. Sin acceso publico y cifrado en transito.
# El versionado es lo que permite recuperar la version exacta que ejecuto un build.
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "buildspecs" {
  bucket        = var.buildspecs_bucket
  force_destroy = false

  tags = merge(local.tags, { Name = var.buildspecs_bucket })
}

resource "aws_s3_bucket_versioning" "buildspecs" {
  bucket = aws_s3_bucket.buildspecs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "buildspecs" {
  bucket = aws_s3_bucket.buildspecs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buildspecs" {
  bucket = aws_s3_bucket.buildspecs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Sin secretos en la plataforma (ADR-0022): el token de CodeArtifact se pide en `pre_build`
# con `aws codeartifact get-authorization-token` y vive solo en el entorno del build.

# --------------------------------------------------------------------------
# Imagen base de runtime que publica el pipeline de `common` en cada release.
# Sin tag `:latest` (arquitectura 1.6): cada release deja un puntero inmutable.
# --------------------------------------------------------------------------

resource "aws_ecr_repository" "common_base" {
  name                 = var.ecr_common_base_name
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.tags, { Name = var.ecr_common_base_name })
}