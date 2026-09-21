# Todo (priorizado)

## Frontend
1. Generar el .aab firmado. DONE
2. Reducir la cantidad de llamadas a secret manager.
    Buscar primero los secret en las variables de entorno y localmente. 
    Si no existe, entonces buscarlas en aws secret manager.
3. Crear solo un secret por app
4. Suscripción.
5. AdMob.
6. Consumo de servicios REST.

## Cloud
1. Tener plantillas con todas las propiedades de cada servicio AWS.
2. Mover proyecto Terraform a la carpeta `cloud`, fuera de `backend`. DONE
3. AWS ElastiCache.

## DevSecOps
1. Pipeline para generar .aab firmado. DONE
2. Cuando se cree un proyecto, se debe crear el repositorio correspondiente (Code Commit). DONE
3. Crear AWS secret manager con terraform
4. Crear CodeBuild, CodePipeline y CodeCommit con terraform
5. SonarQube.
6. Trivy.
7. Azure Pipeline.
8. Dependency Check.
9. Observabilidad.

## Documentación
1. Diagram as Code.
2. Diagrama de componentes.

## Backend
1. Poder actualizar el arquetipo.
2. Supabase: login y registro.
