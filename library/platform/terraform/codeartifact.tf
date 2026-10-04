# Dominio y repositorio maven que publica `common`.
# El nombre del repositorio (`common`) no es variable: lo referencian
# `library/common/settings.xml` y `library/common/pom.xml`.
# Sin CMK en el repositorio (ADR-0022): el coste de AWS KMS no lo justify todavia.

resource "aws_codeartifact_domain" "epc" {
  domain = var.domain_name

  tags = {
    Name = "epc"
  }
}

resource "aws_codeartifact_repository" "common" {
  domain     = aws_codeartifact_domain.epc.domain
  repository = "common"

  description = "Artefactos Maven de common (BOM y modulos por capacidad)."

  # Maven Central como upstream: los terceros se resuelven sin duplicarlos en el repositorio.
  upstream {
    repository_name = "central"
  }

  tags = {
    Name = "common"
  }
}