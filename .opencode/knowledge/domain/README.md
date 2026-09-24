# knowledge/domain

Reglas de negocio y términos del dominio.

- `quizsmart` — app de quizzes (frontend Flutter + backend Spring generados por el componente).
- Autenticación: Cognito con proveedor Google; tokens manejados por el backend.
- Comunicación: API REST (API Gateway + Lambda/ECS según pipeline), colas SNS/SQS, persistencia en DynamoDB.
- Ambientes: dev / staging / prod (variables por ambiente en `epc.json` y Terraform).

Referencia registrada en `.opencode/opencode.json` (alias `domain`). Ampliar aquí con reglas de negocio concretas.
