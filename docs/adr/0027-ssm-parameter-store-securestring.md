# ADR-0027: SSM Parameter Store SecureString en lugar de Secrets Manager

- **Fecha:** 2026-10-12
- **Estado:** `Aceptada`
- **Sustituye a:** ADR-0010 (solo en el servicio que guarda el secreto)
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** `obj-005`

## Contexto

- ADR-0010 guarda un secreto único por aplicación en Secrets Manager.
- Coste: 0,40 USD/mes por secreto, más 0,05 USD por 10.000 llamadas API.
- El proyecto no usa rotación ni recuperación de Secrets Manager.
- El secreto lleva el keystore Android en base64 (`android-signing.keystore-base64`).
- El tier Standard de Parameter Store admite valores de hasta 4 KB.
- Un `.jks` RSA 2048 ocupa 2-3 KB en base64; el JSON quedaría al límite.

## Decisión

- El secreto pasa a SSM Parameter Store SecureString, tier Standard.
- Cifrado con la clave gestionada `aws/ssm`, sin CMK propia.
- Ruta: `/{{ENVIRONMENT}}/{{APPLICATION_ID}}/secrets`.
- El módulo Terraform se renombra a `secure-parameters`.
- Terraform crea el parámetro con valor `placeholder` y `ignore_changes = [value]`.
  Así un apply posterior no vacía lo sembrado.
- `cloud/up.ps1` siembra el valor fuera de Terraform.
  El valor nunca entra en `terraform.tfstate` ni en el repositorio.
- El keystore sale del JSON y se guarda en S3:
  - Bucket: `{{project_name}}-keystore-{{environment}}`, uno por entorno.
  - Objeto: `keystore/{{APPLICATION_ID}}/keystore.jks`.
  - Versionado, SSE-S3 y bloqueo total de acceso público.

JSON del secreto, sin keystore. Ronda 300 bytes con valores por defecto, muy por debajo de 4 KB:

```json
{
  "subscription-secret-key": "",
  "jwt-secret": "",
  "ai-api-key": "",
  "subscription-webhook-secret": "",
  "android-signing": {
    "key-alias": "",
    "store-password": "",
    "key-password": ""
  }
}
```

### IAM por rol

- Lambda, solo lectura:
  - `ssm:GetParameter`, `ssm:GetParametersByPath` y `kms:Decrypt` sobre `aws/ssm`.
  - Sin `ssm:PutParameter` ni permisos S3.
- CodeBuild de siembra (cloud): `ssm:PutParameter` sobre la ruta.
- CodeBuild del pipeline Flutter:
  - `ssm:GetParameter`, `ssm:PutParameter` y `kms:Decrypt` sobre la ruta.
  - `s3:GetObject` y `s3:PutObject` sobre `keystore/{{APPLICATION_ID}}/*`.
  - `kms:Encrypt` no hace falta: la clave la gestiona AWS.

### Firma Android

- `flutter/up.ps1 -Sign` es el único generador, lector y escritor del keystore.
- Genera el keystore solo si falta el objeto en S3. Nunca sobrescribe.
- Sube el binario con SHA-256 en los metadatos del objeto.
- Sin caché local: descarga siempre y verifica el SHA-256 antes de firmar.
- Si el hash no coincide, aborta.

### Ciclo de vida

- `cloud/down.ps1` purga por CLI todas las versiones y el objeto keystore.
- `terraform destroy` elimina el bucket. El destroy falla si el bucket no está vacío,
  por eso la purga va antes.
- Una pasada CLI final es idempotente y limpia los restos.
- `delete-parameter` borra el SecureString. No hay `restore-secret`: SSM no tiene ventana.
- `.opencode/scripts/delete-all-services-aws.ps1`:
  - Quita las suscripciones del topic antes de borrarlo y barre las huérfanas.
  - Purga el bucket keystore de cada entorno.

## Consecuencias

### Positivas

- Coste del secreto: de 0,40 USD/mes a 0 USD/mes.
- El keystore deja de competir por los 4 KB.
- El bucket versionado ofrece recuperación de versiones mientras exista.

### Negativas y riesgos

- Sin copia externa del keystore. `down.ps1` borra objeto, versiones y bucket.
  Si se ejecuta, la firma se pierde y la app no actualiza en Play.
- Se asume que la app no está publicada en Play.
- El borrado del SecureString es definitivo, sin ventana: se elimina la lógica
  de `restore-secret`.
- `down.ps1` borra datos reales de forma irreversible.

### Correcciones en ADR existentes

- ADR-0010: sustituido solo en el servicio. Se mantiene un secreto por aplicación,
  con JSON en kebab-case.
- ADR-0012: se quita el starter `secrets-manager` y la referencia a `GetSecretValue`.
- ADR-0022: la cita rota a ADR-0023 apunta a este ADR (ADR-0027).

## Alternativas descartadas

- Secrets Manager: 0,40 USD/mes por secreto.
- Tier Advanced de Parameter Store: no hace falta con el JSON por debajo de 4 KB.
- CMK propia: +1 USD/mes.
- Guardar el `.jks` en git o en el proyecto: expone material de firma.

## Evidencia

- `docs/deliverables/obj-005/architect.md`: precios verificados y decisiones D41, D42.
- `docs/deliverables/obj-005/questions.md`: Q14, Q19, Q28, Q56-Q93.

### Coste

- Antes: 0,40 USD/mes por secreto, más 0,05 USD/10.000 llamadas API.
- Después: ≈ 0,005 USD/mes por aplicación (S3 y peticiones). Estimación propia.
- Parameter Store Standard: sin coste adicional.
- Ahorro ≈ 99 %.
