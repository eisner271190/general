# ADR-0008: `cloud/up.ps1` rellena el `baseUrl` de la colección Postman

- **Fecha:** 2026-09-27
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** —

## Contexto

`http_api_url` solo existe después del `terraform apply`, así que había que pegarlo a mano en la colección Postman en cada despliegue.

## Decisión

`cloud/up.ps1` escribe el `baseUrl` de `backend/<ms>/postman/<ms>.postman_collection.json` tras el `apply`, con las nuevas funciones `Get-TerraformOutput` y `Update-PostmanBaseUrl` (UTF-8 sin BOM). El paso manual queda como alternativa documentada en la descripción de la colección.

## Consecuencias

### Positivas

- La colección queda utilizable en cuanto termina el despliegue.

### Negativas y riesgos

- Si no existe la colección o no hay output, el paso se omite con log en lugar de romper el despliegue.

### Coste

0 USD.
