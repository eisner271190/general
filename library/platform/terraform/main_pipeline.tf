# Pipeline de `common`: CodePipeline + los dos CodeBuild que necesita.
# Source CodeCommit, validacion con el buildspec compartido del bucket (ARN) y publicacion
# con un buildspec inline (mvn deploy + imagen base).
#
# Un modulo por pipeline: cada microservicio tiene el suyo, y este solo declara el de
# `common`. El source sondea el repositorio (CodeCommit no admite webhook con HMAC en el
# provider v6), asi que no hace falta ningun secreto de webhook.

module "pipeline" {
  source = "./pipeline"

  pipeline_name = local.pipeline_name

  repository_name = var.common_source_bucket
  source_branch   = var.source_branch

  artifact_bucket_name = var.buildspecs_bucket
  buildspecs_bucket    = var.buildspecs_bucket

  codeartifact_domain_name = var.domain_name
  codeartifact_url         = local.codeartifact_url
  ecr_repository_url       = aws_ecr_repository.common_base.repository_url

  codebuild_role_arn = aws_iam_role.codebuild.arn
  pipeline_role_arn  = aws_iam_role.pipeline.arn

  tags = local.tags
}