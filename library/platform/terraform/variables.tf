variable "region" {
  type        = string
  description = "Region de AWS donde se crea el dominio y el repositorio de CodeArtifact."
}

variable "domain_name" {
  type        = string
  description = "Nombre del dominio de CodeArtifact (epc). Lo referencian settings.xml y renovate.json."

  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{1,8}[a-z0-9]$", var.domain_name))
    error_message = "domain_name debe ser 3-10 caracteres: minuscula, digitos y guiones, sin empezar ni acabar en guion."
  }
}