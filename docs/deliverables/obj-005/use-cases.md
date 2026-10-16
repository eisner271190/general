# Casos de prueba obj-005

- Fecha: `2026-10-11`
- Objetivo: `obj-005`
- Fuente: criterios de aceptación de `obj-005.md` y decisiones Q1-Q93.
- Estado general: pendiente; sin autorización para implementar (Q48).
- "Checklist completo" = ítems definidos y trazados (Q87); `[ ]` queda para ejecución.

## Casos de prueba

- TC-01 JSON sin keystore: el JSON del secreto no contiene `keystore-base64`.
  - Esperado: 0 coincidencias de `keystore-base64` en el JSON generado.
  - Resultado: pendiente.
  - Resultado: pendiente.
- TC-03 Subida del keystore: `up.ps1 -Sign` sube el `.jks` como binario en
  `keystore/{{APPLICATION_ID}}/keystore.jks`.
  - Esperado: objeto binario en S3 con esa clave; SHA-256 como metadato (Q80).
  - Resultado: pendiente.
- TC-04 Generación condicionada: si el objeto ya existe en S3, no se sobrescribe (Q88).
  - Esperado: se lee el objeto existente; 0 escrituras.
  - Resultado: pendiente.
- TC-05 Bucket: nombre `${var.project_name}-keystore-${var.environment}` (Q93, sin hardcodear),
  versionado, SSE-S3 y bloqueo total de acceso público.
  - Esperado: los cuatro atributos correctos en AWS.
  - Resultado: pendiente.
- TC-06 Pipeline: descarga el `.jks` de S3 y verifica SHA-256 antes de firmar; sin caché
  local (Q75, Q80).
  - Esperado: verificación correcta; falla si el hash no coincide.
  - Resultado: pendiente.
- TC-07 Siembra del parámetro: solo si el parámetro falta o su valor es el placeholder (Q77).
  - Esperado: sin `put-parameter` si el valor real ya existe.
  - Resultado: pendiente.
- TC-08 Perfil cloud: `application-cloud-properties.scriban` sin `aws-secretsmanager:`.
  - Esperado: 0 coincidencias; importa la ruta SSM.
  - Resultado: pendiente.
- TC-09 Dependencias: `pom.scriban` sin `spring-cloud-aws-starter-secrets-manager` y con
  `parameter-store`.
  - Esperado: 1 starter; versión SCA sin cambios (Q37).
  - Resultado: pendiente.
- TC-10 Terraform: sin `aws_secretsmanager_secret`; con `aws_ssm_parameter` SecureString,
  placeholder e `ignore_changes` (Q69); valor fuera de tfstate (Q19).
  - Esperado: plan sin secretos SM; parámetro no reescrito.
  - Resultado: pendiente.
- TC-11 Módulo: carpeta `secure-parameters` y `source`, `component.json` (10, 37-38) y
  `cloud/aws/AGENTS.md:4` actualizados (Q20).
  - Esperado: 0 referencias a `modules/secrets-manager`.
  - Resultado: pendiente.
- TC-12 IAM Lambda: `ssm:GetParameter`, `ssm:GetParametersByPath` y `kms:Decrypt` sobre la
  ruta y `aws/ssm`; sin `PutParameter` y sin S3 (Q27, Q59, Q66).
  - Esperado: policy acotada; 0 permisos S3.
  - Resultado: pendiente.
- TC-13 IAM CodeBuild cloud: `ssm:PutParameter` sobre la ruta; sin S3 (Q26, Q59).
  - Esperado: siembra funciona; 0 acceso a bucket keystore.
  - Resultado: pendiente.
- TC-14 IAM CodeBuild Flutter: SSM (put, get, kms:Decrypt) y S3 sobre
  `keystore/{{APPLICATION_ID}}/*` (Q67, Q59).
  - Esperado: firma y subida funcionan; sin permisos fuera del prefijo.
  - Resultado: pendiente.
- TC-15 Referencias: grep de `secretsmanager:`, `aws secretsmanager` y "Secrets Manager" en
  plantillas del generador (Q40, Q41, Q42).
  - Esperado: 0 coincidencias (salvo excepción del filtro de test, Q72).
  - Resultado: pendiente.
- TC-16 ADR: existe `docs/adr/0027-*.md`; 0010 "Sustituida por ADR-0027"; 0012 y 0022
  actualizados; sin cambios en `docs/adr/README.md` (Q9, Q55).
  - Esperado: referencias a ADR-0023 corregidas (Q8).
  - Resultado: pendiente.
- TC-17 `down.ps1` (cloud): borra parámetro, objeto, todas las versiones y el bucket;
  orden: `terraform destroy` del bucket primero y CLI después (Q89, Q90).
  - Esperado: sin `restore-secret`; sin estado desincronizado (D41, D42 abiertas).
  - Resultado: pendiente.
- TC-18 `delete-all-services-aws.ps1`: vacía y borra el bucket keystore de todos los
  entornos (Q91), con vaciado previo de versiones.
  - Esperado: buckets de todos los entornos eliminados.
  - Resultado: pendiente.
- TC-19 `get-services-aws.ps1`: muestra solo la existencia del bucket (Q92), con nombre
  derivado de `environment` + `project_name` (Q93).
  - Esperado: sin listar objetos ni versiones; sin nombre hardcodeado.
  - Resultado: pendiente.
- TC-20 Excepción de alcance: los cambios en `.opencode/scripts/*` se documentan solo en
  `obj-005.md`, no en AGENTS.md (Q84, Q85).
  - Esperado: AGENTS.md sin cambios.
  - Resultado: pendiente.
- TC-21 App publicada: se asume no publicada y se continúa (Q78); si está publicada, el
  keystore nuevo bloquea las actualizaciones en Play.
  - Esperado: confirmación antes de subir a Play; riesgo registrado.
  - Resultado: pendiente.
- TC-22 Verificación previa (M5): comprobar si
  `library/platform/terraform/pipeline/main.tf:30` y
  `library/platform/buildspecs/java-ci.yml:7` son código o comentario.
  - Esperado: decisión registrada antes de tocarlos.
  - Resultado: pendiente.
- TC-23 Proceso: `checklist.md` ítems definidos y trazados (Q87) y autorización escrita
  (Q48) antes de implementar.
  - Esperado: Q48 cerrada antes de cualquier cambio de código.
  - Resultado: pendiente.
