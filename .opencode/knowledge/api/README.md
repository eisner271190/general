# knowledge/api

Contratos y convenciones API de los microservicios generados.

- Envoltorio de respuesta: `ApiResponse` (éxito) y `ErrorApiResponse` (error) — plantillas en `generator/components/backend/spring-boot-3.5.16/templates/`.
- Manejo de errores: `GlobalExceptionHandler` + `GeneralException`; códigos y mensajes centralizados.
- Versionado de rutas: prefijo `/api/v1` (verificar por endpoint antes de asumir).

Referencia registrada en `.opencode/opencode.json` (alias `api`). Ampliar aquí con endpoints y esquemas concretos.
