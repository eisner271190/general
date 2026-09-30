# Todo (priorizado)

> **Flujo:** di **"Trabajar"** (o `/trabajar TXX`) → por cada tarea:
> branch `feature/<plan>` → generar plan → implementar → pull request.
> Al crear el PR: marcar `- [x]` con el enlace. Al fusionar: mover a `docs/done.md`.

## MVP (Prioridad)
- Separar el generador en componentes independientes: Frontend, Backend y Cloud. Cada componente debe ser un proyecto independiente, con sus propios modelos, estrategias, targets y templates, de forma que el generador sea completamente agnóstico a implementaciones concretas.

## Frontend
- Optimizar carga inicial de la app, debe demorar máximo 1 segundo
- Suscripción
- AdMob
- Consumo de servicios REST

## Cloud
- Separar los parametros del frontend bajo el prefijo /frontend/quizsmart/ en ssm.tf (decision de parametros.md #6)
- Plantillas con todas las propiedades de cada servicio AWS
- AWS ElastiCache

## DevSecOps
- SonarQube
- Trivy
- Dependency Check
- Observabilidad

## Documentación
- Diagram as Code
- Diagrama de componentes

## Backend
- Obtener los parametros del parameter store, no de la lambda.
- Quitar los parametros de la lambda
- Poder actualizar el arquetipo
- Supabase: login y registro
- API Suscripcion
    -> Actualmente en el frontend, se tiene una implementación sobre una suscripcion basada en revenueCat. Al tenerla en el frontend, se exponer API-Key y otros datos sensibles. Diseña una solución donde se extraiga el consumo de esa API en el backend.
- API Ad
- API Notifications
- API Parameters
- API Identity
- API AI