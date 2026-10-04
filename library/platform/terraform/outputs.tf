# El repositorio no declara formato: CodeArtifact publica un endpoint por formato.
data "aws_codeartifact_repository_endpoint" "common" {
  domain     = aws_codeartifact_domain.epc.domain
  repository = aws_codeartifact_repository.common.repository
  format     = "maven"
}

output "codeartifact_endpoint" {
  description = "Endpoint maven del repositorio `common`. Es lo que se pasa a -Depc.codeartifact.url."
  value       = data.aws_codeartifact_repository_endpoint.common.repository_endpoint
}