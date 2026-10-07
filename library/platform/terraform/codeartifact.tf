# Dominio, upstream de Maven Central y repositorio maven que publica `common`.
# El nombre del repositorio (`common`) no es variable: lo referencian
# `library/common/settings.xml` y `library/common/pom.xml`.
# Sin CMK en el repositorio (ADR-0022): el coste de AWS KMS no lo justifica todavia.

resource "aws_codeartifact_domain" "epc" {
  domain = var.domain_name

  tags = {
    Name = var.domain_name
  }
}

# Maven Central no se referencia por nombre: CodeArtifact exige un repositorio propio
# que actue de puente hacia `public:maven-central`. Sin el, el apply falla con
# "Repository 'central' in domain 'epc' does not exist".
resource "aws_codeartifact_repository" "maven_central" {
  domain     = aws_codeartifact_domain.epc.domain
  repository = "maven-central"

  description = "Puente hacia Maven Central."

  external_connections {
    external_connection_name = "public:maven-central"
  }

  tags = {
    Name = "maven-central"
  }
}

resource "aws_codeartifact_repository" "common" {
  domain     = aws_codeartifact_domain.epc.domain
  repository = "common"

  description = "Artefactos Maven de common (BOM y modulos por capacidad)."

  # Los terceros se resuelven por el puente: no se duplican en el repositorio.
  upstream {
    repository_name = aws_codeartifact_repository.maven_central.repository
  }

  tags = {
    Name = "common"
  }
}