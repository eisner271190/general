# ADR-0010: Un único secreto por aplicación en Secrets Manager

- **Fecha:** 2026-09-28
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** plan `plan-secretos-unico-por-app.md` (sustituye a `plan-t04-secretos-secrets-manager.md`)

## Contexto

Tres secretos sueltos costaban **1,20 USD/mes** frente a **0,40 USD/mes** de un único JSON, y una CMK propia habría añadido **+1 USD/mes**.

## Decisión

Un solo secreto en Secrets Manager por aplicación, con nombre `<entorno>/<applicationId>` (p. ej. `develop/com.quizsmart.app`) y un **único JSON en kebab-case** (`android-signing`, `jwt-secret`, `api-key`).

- Terraform solo crea el **contenedor**: la plantilla `terraform-secrets-manager.scriban` no lleva `for_each` ni `secret_version` y se instancia desde `cloud/terraform/app/secrets.tf`, de modo que el valor **nunca** entra en `terraform.tfstate` ni en el repositorio.
- `cloud/up.ps1` siembra `jwt-secret` y `api-key` solo si faltan: nunca sobrescribe, nunca crea el secreto y nunca loguea el valor.
- `frontend/up.ps1` solo lee o añade `android-signing` (merge por clave) y **falla** si el secreto no existe.
- Con `-Sign` el pipeline compila el `.aab` firmado; sin `-Sign` se borran `key.properties` y `upload-keystore.jks`, y `buildspec.yml` solo asegura `pwsh` y ejecuta el script.
- IAM del CodeBuild pasa de `CreateSecret` a `PutSecretValue` sobre `arn:aws:secretsmanager:<region>:<cuenta>:secret:<entorno>/<applicationId>-*`; la Lambda recibe `secretsmanager:GetSecretValue`.
- `jwt.secret=${JWT_SECRET:${jwt-secret:}}` deja el fallback listo para T06.
- El `bootstrap` de cloud salta los directorios sin `ecr.tf` (el nuevo `app/` no tiene).
- Los secretos legados `/epc/.../android-signing*` se borran (borrón y cuenta nueva).

## Consecuencias

### Positivas

- 0,80 USD/mes ahorrados frente a secretos separados.
- El valor del secreto no existe en ningún fichero versionado.

### Negativas y riesgos

- Sin `-Sign` y sin secreto, solo hay aviso y se continúa; con `-Sign` sigue siendo error de secuencia.
- El borrado de los secretos legados quedó **pendiente de autorización**.

### Coste

**0,40 USD/mes** (un secreto de Secrets Manager). Evita +1 USD/mes de CMK propia.
