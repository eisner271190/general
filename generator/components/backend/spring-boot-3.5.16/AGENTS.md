# Plantillas backend Spring Boot (Maven)

## Qué es aquí
Plantillas Scriban que generan el microservicio en `<proyecto>/<MICROSERVICE_NAME>/`. Fuente de verdad: `component.json` (solo la lista `files` se copia).

## Comandos (en el microservicio generado; pedir autorización)
- Build: `./mvnw -q compile` (Maven wrapper, Java 17; Spring Boot parent 3.4.0).
- Tests, cobertura y calidad: ver skill `java`.

## Despliegue
- `up.ps1 -Fast` (raíz del proyecto) NO refresca la imagen `:latest` de la Lambda si solo cambió código (Terraform no ve cambio en `image_uri`).
- Para desplegar cambios de código a la Lambda: ejecutar `<proyecto>/backend/update-all.ps1` (todos los ms) o `<proyecto>/backend/<ms>/update-ms.ps1` (uno), que llaman `aws lambda update-function-code` + `wait function-updated`. No hacer `update-function-code` manual.

## Convenciones
- Cargar el skill `java` antes de editar: arquitectura hexagonal, Google Java Style, validación/errores, naming.

## Reglas
- Plantillas nuevas/renombradas: actualizar `component.json` en el mismo cambio (una plantilla no listada NO se genera).
- Las plantillas `terraform-*` se registran SOLO en el componente cloud; no registrarlas aquí.
- Tras editar una plantilla, revisar que no queden placeholders `{{ ... }}` sin resolver.
- **Endpoint agregado, modificado o eliminado → actualizar `postman-collection.scriban` en el MISMO cambio**: item con request real y ejemplos de response (éxito + error). Sin esa entrada el endpoint no se puede probar a mano y el trabajo está incompleto. Si el endpoint es público, no le añadas `Authorization: Bearer`. Tras editarla, parsear el JSON para confirmar que sigue siendo válido.
