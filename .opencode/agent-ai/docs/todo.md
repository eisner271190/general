# Todo (priorizado)

> **Flujo:** di **"Trabajar"** (o `/trabajar TXX`) → por cada tarea:
> branch `feature/<plan>` → generar plan → implementar → pull request.
> Al crear el PR: marcar `- [x]` con el enlace. Al fusionar: mover a `docs/done.md`.

## MVP (Prioridad)
- [ ] T01 — Separar el generador en componentes independientes: Frontend, Backend y Cloud. Cada componente debe ser un proyecto independiente, con sus propios modelos, estrategias, targets y templates, de forma que el generador sea completamente agnóstico a implementaciones concretas.
- [ ] El frontend debe obtener los parametros consumiendo un servicio del backend
- [ ] T07 — El frontend debe obtener la URL del API Gateway y consumir los servicios del backend /actuator/health

## Frontend
- [ ] T04 — Suscripción
- [ ] T05 — AdMob
- [ ] T06 — Consumo de servicios REST

## Cloud
- [ ] T17 — Separar los parametros del frontend bajo el prefijo /frontend/quizsmart/ en ssm.tf (decision de parametros.md #6)
- [ ] T07 — Plantillas con todas las propiedades de cada servicio AWS
- [ ] T08 — AWS ElastiCache

## DevSecOps
- [ ] T09 — SonarQube
- [ ] T10 — Trivy
- [ ] T11 — Dependency Check
- [ ] T12 — Observabilidad

## Documentación
- [ ] T13 — Diagram as Code
- [ ] T14 — Diagrama de componentes

## Backend
- [ ] T15 — Poder actualizar el arquetipo
- [ ] T16 — Supabase: login y registro
