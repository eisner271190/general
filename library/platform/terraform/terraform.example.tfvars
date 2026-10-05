# Copia este fichero a terraform.tfvars y ajusta los valores. `*.tfvars` esta en .gitignore.
region      = "us-east-1"
domain_name = "epc"

# Entorno: solo nombra las etiquetas. No hay secretos en la plataforma (ADR-0022): el token de
# CodeArtifact lo pide cada build con la identidad del rol de CodeBuild.
environment = "develop"

# Repos de CodeCommit de plataforma (los declara codecommit.tf).
common_source_bucket   = "common"
platform_source_bucket = "platform"
source_branch          = "main"

# Repos de la aplicacion: destino unico del trigger de bump del BOM. El repositorio lo
# declara cloud/terraform/app/codecommit.tf del proyecto generado; aqui solo se compone el ARN.
# application_repository no tiene valor por defecto: cada aplicacion pone el suyo. El valor de
# ejemplo hay que cambiarlo por el repo real.
application_repository = "mi-aplicacion"
application_pom_glob   = "backend/*/pom.xml"

# Buildspecs compartidos (tambien artifact store del pipeline) y repositorio de la imagen base.
buildspecs_bucket    = "epc-buildspecs"
ecr_common_base_name = "epc/common-base"