# Plantillas backend Spring Boot (Maven)

## Qué es aquí
Plantillas Scriban que generan el microservicio en `<proyecto>/<MICROSERVICE_NAME>/`. Fuente de verdad: `component.json` (solo la lista `files` se copia).

## Comandos (en el microservicio generado; pedir autorización)
- Build: `./mvnw -q compile` (Maven wrapper, Java 17; Spring Boot parent 3.4.0).
- Tests, cobertura y calidad: ver skill `java`.

## Convenciones
- Cargar el skill `java` antes de editar: arquitectura hexagonal, Google Java Style, validación/errores, naming.

## Reglas
- Plantillas nuevas/renombradas: actualizar `component.json` en el mismo cambio (una plantilla no listada NO se genera).
- Las plantillas `terraform-*` se registran SOLO en el componente cloud; no registrarlas aquí.
- Tras editar una plantilla, revisar que no queden placeholders `{{ ... }}` sin resolver.
