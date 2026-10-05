variable "pipeline_name" {
  type        = string
  description = "Nombre del pipeline y prefijo de los nombres de sus dos proyectos CodeBuild."
}

variable "repository_name" {
  type        = string
  description = "Repositorio CodeCommit que es el source (lo crea el usuario)."
}

variable "source_branch" {
  type        = string
  description = "Rama del repositorio que activa el pipeline."

  default = "main"
}

variable "artifact_bucket_name" {
  type        = string
  description = "Bucket S3 que sirve de artifact store y de destino de los artefactos del build."
}

variable "buildspecs_bucket" {
  type        = string
  description = "Bucket versionado donde viven los buildspecs; el source del build los referencia por ARN."
}

variable "codeartifact_url" {
  type        = string
  description = "Endpoint maven de CodeArtifact. Valor plano: se pasa al build como CODEARTIFACT_URL y este lo inyecta en `mvn deploy` con -D."
}

variable "codeartifact_secret_arn" {
  type        = string
  description = "Secreto de Secrets Manager con el token de CodeArtifact. El valor lo siembra el usuario; aqui no hay secretos."
}

variable "ecr_repository_url" {
  type        = string
  description = "URL del repositorio ECR donde el stage Publish deja la imagen base de la release."
}

variable "codebuild_role_arn" {
  type        = string
  description = "Rol de servicio de los dos proyectos CodeBuild de este pipeline."
}

variable "pipeline_role_arn" {
  type        = string
  description = "Rol de servicio de CodePipeline."
}

variable "tags" {
  type        = map(string)
  description = "Etiquetas que se propagan a los recursos del pipeline."
  default     = {}
}