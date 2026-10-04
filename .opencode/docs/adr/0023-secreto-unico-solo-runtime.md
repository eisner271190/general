# ADR-0023: Un único secreto JSON por aplicación, decidido por coste

- **Fecha:** 2026-10-04
- **Estado:** `Aceptada`
- **Sustituye a:** ADR-0010
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 003, plan `plan-codeartifact-bootstrap.md`

## Contexto

Secrets Manager cobra **0,40 USD/mes** por secreto. Tres secretos sueltos por aplicación costaban
**1,20 USD/mes**; uno solo con todo dentro, **0,40 USD/mes**. La forma del secreto no era una
preferencia de diseño: era el coste.

## Decisión

**Un solo secreto en Secrets Manager por aplicación**, con nombre `<entorno>/<applicationId>`
(p. ej. `develop/com.quizsmart.app`), y **un único JSON en kebab-case** dentro.

### Estructura actual

```json
{
  "jwt-secret": "<PLACEHOLDER>",
  "api-key": "<PLACEHOLDER>",
  "subscription-secret-key": "<PLACEHOLDER>",
  "subscription-webhook-secret": "<PLACEHOLDER>",
  "ai-api-key": "<PLACEHOLDER>"
}
```

- **Quién lo siembra:** `up.ps1` tras el `apply`, con las claves que falten y `PLACEHOLDER` en las
  vacías (`generator/components/cloud/aws/templates/up.ps1.scriban`).
- **Quién lo crea:** Terraform declara el contenedor vacío; sin él, `up.ps1` aborta.
- **Cómo lo lee la app:** una clave del JSON por propiedad de `application-properties`.