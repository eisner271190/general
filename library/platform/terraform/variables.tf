variable "region" {
  type        = string
  description = "Region de AWS donde se crea el dominio y el repositorio de CodeArtifact."
}

variable "domain_name" {
  type        = string
  description = "Nombre del dominio de CodeArtifact (epc). Lo referencian settings.xml y el token que pide cada build."

  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{1,8}[a-z0-9]$", var.domain_name))
    error_message = "domain_name debe ser 3-10 caracteres: minuscula, digitos y guiones, sin empezar ni acabar en guion."
  }
}

# ---------------------------------------------------------------------------
# Variables de la plataforma (bucket, ECR, IAM, pipeline, repos de CodeCommit).
# ---------------------------------------------------------------------------

variable "environment" {
  type        = string
  description = "Nombre del entorno. Solo se usa para nombrar los secretos (epc/<env>/...) y las etiquetas."

  validation {
    condition     = can(regex("^[a-z][a-z0-9\\-]{1,15}$", var.environment))
    error_message = "environment debe ser minusculas, digitos y guiones (2-16 caracteres)."
  }
}

variable "buildspecs_bucket" {
  type        = string
  description = "Bucket S3 versionado donde viven los buildspecs compartidos y donde CodePipeline guarda sus artefactos."

  default = "epc-buildspecs"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\.\\-]{1,61}[a-z0-9]$", var.buildspecs_bucket))
    error_message = "buildspecs_bucket debe ser un nombre de bucket S3 valido."
  }
}

variable "ecr_common_base_name" {
  type        = string
  description = "Repositorio ECR de la imagen base de runtime que publica `common`."

  default = "epc/common-base"
}

variable "common_source_bucket" {
  type        = string
  description = "Nombre del repositorio CodeCommit de `common`. Lo declara codecommit.tf."

  default = "common"
}

variable "platform_source_bucket" {
  type        = string
  description = "Nombre del repositorio CodeCommit de `platform`. Es el source del build de bump."

  default = "platform"
}

variable "source_branch" {
  type        = string
  description = "Rama de trabajo de los repos de plataforma. La crea Terraform como `default_branch` y es la que activa el pipeline de `common`."

  default = "main"
}

variable "application_repository" {
  type        = string
  description = "Nombre del repositorio CodeCommit de la aplicacion (codecommit.tf del proyecto generado). Destino unico del trigger de bump del BOM: llega al build como APPLICATION_REPOSITORY."

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.\\-]{1,100}$", var.application_repository))
    error_message = "application_repository debe ser un nombre de repositorio CodeCommit."
  }
}

variable "application_pom_glob" {
  type        = string
  description = "Ruta (relativa a la raiz del repo de la aplicacion) de los pom de microservicios que el trigger de bump actualiza."

  default = "backend/*/pom.xml"

  validation {
    condition     = can(regex("^[A-Za-z0-9*.\\-_/]+$", var.application_pom_glob))
    error_message = "application_pom_glob debe ser una ruta con globs (backend/*/pom.xml)."
  }
}