# Copia este fichero a terraform.tfvars y ajusta los valores. `*.tfvars` esta en .gitignore.
region      = "us-east-1"
domain_name = "epc"

# Entorno: solo nombra los secretos (epc/<environment>/codeartifact y
# epc/<environment>/codecommit-git) y las etiquetas. Los secretos se declaran vacios a
# proposito: sus valores los siembra el usuario con `aws secretsmanager put-secret-value`.
environment = "develop"

# Repos de CodeCommit (los crea el usuario; aqui solo se compone su ARN).
common_source_bucket   = "common"
platform_source_bucket = "platform"
platform_source_branch = "main"

# Convencion de nombres de los repos de microservicios: es lo unico que los separa de
# `common` y `platform` en el bump automatico del BOM.
ms_repository_prefix = "com.quizsmart.app/"

# Buildspecs compartidos (tambien artifact store del pipeline) y repositorio de la imagen base.
buildspecs_bucket    = "epc-buildspecs"
ecr_common_base_name = "epc/common-base"

# Renovate programado (4 ejecuciones/mes, dentro de las 14 gratuitas del Scheduler).
renovate_schedule_expression = "cron(0 4 ? * MON *)"