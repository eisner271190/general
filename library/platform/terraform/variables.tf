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

# ---------------------------------------------------------------------------
# Variables de la plataforma (bucket, ECR, IAM, pipeline, Renovate).
# Los repos de CodeCommit los crea el usuario: aqui solo se da su nombre.
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
  description = "Nombre del repositorio CodeCommit de `common` (lo crea el usuario). Su ARN se compone: el repositorio no se declara aqui."
}

variable "platform_source_bucket" {
  type        = string
  description = "Nombre del repositorio CodeCommit de `platform` (lo crea el usuario). Es el source de los builds de Renovate y del bump."
}

variable "platform_source_branch" {
  type        = string
  description = "Rama de `platform` que ejecutan los builds de Renovate y de bump."

  default = "main"
}

variable "ms_repository_prefix" {
  type        = string
  description = "Prefijo de nombre de los repos de microservicios. Es lo unico que separa los ms de `common` y `platform` (bump-bom-version.py --repo-prefix)."

  default = "com.quizsmart.app/"
}

variable "renovate_schedule_expression" {
  type        = string
  description = "Expresion cron de EventBridge Scheduler para el build programado de Renovate."

  default = "cron(0 4 ? * MON *)"
}