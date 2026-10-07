# Repos de CodeCommit de la plataforma. Los microservicios de la aplicacion viven en el repo que
# declara su propio Terraform (cloud/terraform/app/codecommit.tf en el proyecto generado): aqui no
# se enumeran, solo se compone su ARN para el IAM del trigger.

resource "aws_codecommit_repository" "common" {
  repository_name = var.common_source_bucket
  description     = "Componente reutilizable common (BOM + modulos por capacidad)."
  default_branch  = var.source_branch

  tags = merge(local.tags, { Name = var.common_source_bucket })
}

resource "aws_codecommit_repository" "platform" {
  repository_name = var.platform_source_bucket
  description     = "Plataforma: buildspecs compartidos, scripts y Terraform."
  default_branch  = var.source_branch

  tags = merge(local.tags, { Name = var.platform_source_bucket })
}