# Imagen base de runtime para microservicios Java sobre AWS Lambda.
# No compila Maven: la compilacion vive en platform/buildspecs/docker-build.yml.
# No fija USER: el COPY del Dockerfile del microservicio corre como root y produce ficheros legibles.
FROM public.ecr.aws/lambda/java:17

ENV TZ=UTC