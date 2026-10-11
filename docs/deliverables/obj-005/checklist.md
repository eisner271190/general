# Checklist OBJ-005: SSM Parameter Store SecureString

- Fecha: `2026-10-10` · Actualizado: `2026-10-10 19:33:23` (UTC-5)
- Fuentes: `obj-005.md`, `questions.md` (Q1-Q86 decididas salvo Q48; Q82-Q86 resueltas).
- Delegadas a architect: Q23, Q47, Q53. Sin preguntas nuevas abiertas.
- Regla: `[x]` solo decisión explícita del usuario. Implementación y verificación quedan `[ ]`.
- Estado: análisis. Sin implementación. Sin autorización (Q48, último punto).

## 1. Criterios de aceptación (obj-005.md)

- [ ] JSON nuevo sin keystore: esqueleto 210 bytes como referencia; sin medición (Q76).
- [ ] JSON del secreto no contiene `keystore-base64`.
- [ ] Keystore sube y descarga como binario en `keystore/{{APPLICATION_ID}}/keystore.jks`.
- [ ] `application-cloud-properties.scriban` no referencia `aws-secretsmanager:` (Q16).
- [ ] `pom.scriban` no incluye `spring-cloud-aws-starter-secrets-manager` (Q37).
- [ ] Terraform no crea `aws_secretsmanager_secret` y sí `aws_ssm_parameter` SecureString.
- [ ] Terraform crea bucket S3 `${var.project_name}-keystore-${var.environment}` (Q56).
- [ ] IAM Lambda: solo `ssm:GetParameter`, `ssm:GetParametersByPath` y `kms:Decrypt` (Q66).
- [ ] IAM Lambda: sin `ssm:PutParameter` y sin permisos S3 (Q27, Q59).
- [ ] IAM CodeBuild cloud: `ssm:PutParameter` sobre la ruta; sin acceso S3 (Q26, Q59).
- [ ] IAM CodeBuild Flutter: SSM (put, get, kms:Decrypt) y S3 sobre `keystore/{{APPLICATION_ID}}/*`
      (Q67, Q59).
- [ ] Ningún template referencia `secretsmanager:`, `aws secretsmanager` ni "Secrets Manager"
      (Q40, Q41, Q42).
- [ ] Existe `ADR-0027` que sustituye a 0010 y actualiza 0012 y 0022.
- [ ] Bucket keystore con versionado, SSE-S3 y bloqueo total de acceso público (Q58, Q60, Q73).
- [ ] Pipeline descarga y verifica SHA-256 antes de firmar; sin caché local (Q75, Q80).
- [ ] Siembra solo si falta el parámetro o es placeholder (Q77).
- [ ] `down.ps1` borra objeto keystore, todas sus versiones y el bucket por CLI (Q65, Q82).
- [ ] `delete-all-services-aws.ps1` borra el bucket keystore vaciando objetos y versiones (Q82,
      Q84).
- [ ] `get-services-aws.ps1` consulta S3 del bucket keystore (Q84).
- [ ] Excepción a "solo generador" registrada solo en obj-005 para los dos scripts (Q84, Q85).
- [ ] `checklist.md` completo antes de implementar (Q46).

## 2. Decisiones del usuario y trabajo derivado

### 2.1 Alcance y regla de tests

- [x] Solo generador y documentación; `/projects` fuera (Q1).
- [x] `.opencode/scripts/*` dentro de alcance por excepción a "solo generador" (Q84, sustituye Q2).
- [x] `library/platform` y `settings.xml`: solo comentarios y README con Secrets Manager (Q3).
- [x] Comentarios Java con Secrets Manager se actualizan (Q40).
- [x] `postman-collection.scriban` solo si nombra Secrets Manager o secretsmanager (Q41).
- [x] Docs históricos obj-003 y obj-004 no se tocan (Q42).
- [x] Migración de valores fuera; el usuario re-siembra y lo confirma (Q50).
- [x] Solo entorno `develop` (Q51).
- [x] Sin commit ni push sin autorización explícita (Q52).
- [x] Sin crear ni modificar tests (AGENTS.md).
- [x] Excepción autorizada: filtro de `application-context-test.scriban` líneas 74-76 (Q38, Q72).
- [x] Plantilla de test no cuenta como test (Q39).
- [x] Resto de tests no se tocan (Q72).
- [ ] Confirmar en el diff que la plantilla de test no añade otros cambios (Q72).

### 2.2 Secreto, ruta y contenido

- [x] Un SecureString por app con JSON en kebab-case (Q10, Q11).
- [x] Ruta `/{{ENV}}/{{APP}}/secrets` y contenido confirmados (Q6-Q11, Q81).
- [x] Claves del JSON actual entran en el SecureString (Q13).
- [x] Clave de cifrado `aws/ssm` por defecto (Q14, Q24).
- [x] Valor no entra en `terraform.tfstate`; se siembra desde script (Q19).
- [x] SecureString con placeholder y `ignore_changes` (Q69, sustituye Q18).
- [x] Siembra solo si falta el parámetro o su valor es placeholder (Q77, precisa Q30).
- [x] Clave `aws/secretsmanager` cambia a `aws/ssm` (Q24).
- [ ] Implementar siembra condicionada en `up.ps1` cloud (Q77).

### 2.3 Terraform

- [x] Mantener nombre del recurso salvo motivo (Q17).
- [x] Renombrar módulo a `secure-parameters` (Q20).
- [x] Propagar rename: carpeta, `source` en `terraform-secrets.scriban`, `component.json`
      (líneas 10, 37-38) y `cloud/aws/AGENTS.md` línea 4 (Q20).
- [x] Adaptar `terraform-secrets-manager-variables.scriban` (Q21).
- [x] Actualizar `component.json` si cambian nombres de ficheros (Q22).
- [ ] Renombrar `terraform-secrets-manager.scriban` a `terraform-ssm-*` solo si contradice
      el contenido; lo decide architect (Q23).
- [ ] Verificar provider: `aws_ssm_parameter` con placeholder e `ignore_changes` (Q69, D22).

### 2.4 IAM

- [x] Lambda: `GetParameter` y `GetParametersByPath` sobre la ruta, sin comodín (Q25).
- [x] Lambda: solo lectura, sin `PutParameter` (Q27).
- [x] Lambda: `kms:Decrypt` sobre `aws/ssm` (Q28, Q66).
- [x] Lambda: cero permisos S3 (Q59).
- [x] CodeBuild cloud: `ssm:PutParameter` solo sobre la ruta (Q26).
- [x] CodeBuild cloud: sin acceso al keystore (Q59).
- [x] CodeBuild Flutter: `PutParameter` sobre la ruta y `kms:Decrypt` (Q67).
- [x] CodeBuild Flutter: sin `kms:Encrypt` con `aws/ssm` (Q67).
- [x] CodeBuild Flutter: `s3:GetObject` y `s3:PutObject` sobre `keystore/{{APPLICATION_ID}}/*`
      (Q59, Q67).
- [x] Flutter `codepipeline.yml.scriban`: `SecretsManagerAccess` sustituido por SSM y S3 (Q29).

### 2.5 Bucket S3 del keystore

- [x] Bucket por entorno: `${var.project_name}-keystore-${var.environment}` (Q56, Q68).
- [x] Prefijo por app: `keystore/{{APPLICATION_ID}}/keystore.jks` (Q68).
- [x] Terraform crea el bucket vacío (Q56).
- [x] Versionado activado (Q60, Q73).
- [x] SSE-S3 y bloqueo total de acceso público (Q58, Q73).
- [x] Único lector y escritor: `up.ps1 -Sign` en local y CodeBuild Flutter (Q59).
- [x] Si falta el objeto, `up.ps1 -Sign` genera y sube keystore nuevo (Q59, Q64).
- [x] `down.ps1` borra el objeto y todas sus versiones (Q65, sustituye Q61).
- [x] Sin backup externo; solo versionado de S3 (Q63, Q60).
- [x] Q83: no se exige backup previo; solo versionado S3 (Q63, Q65).
- [ ] Subir keystore tras despliegue vía `up.ps1 -Sign` (Q57).

### 2.6 Scripts PowerShell (Flutter y cloud)

- [x] `up.ps1` Flutter: `get-parameter --with-decryption` (Q33).
- [x] `up.ps1` Flutter con `-Sign` sin secreto: error explícito (Q34).
- [x] `up.ps1` Flutter: crea `android-signing` si falta, sin cambio de comportamiento (Q35).
- [x] `up.ps1` Flutter: sube y baja keystore de S3, no del secreto (Q57, Q59).
- [x] `up.ps1` Flutter: genera keystore nuevo si falta el objeto en S3 (Q64).
- [x] `down.ps1`: borrar parámetro con `delete-parameter` (Q31).
- [x] `down.ps1`: eliminar lógica `restore-secret` (Q32).
- [x] Sin caché local de `android/upload-keystore.jks` (Q75; sustituye Q74).
- [x] Pipeline descarga siempre y verifica SHA-256 antes de firmar (Q75, Q80).
- [x] SHA-256 guardado como metadato del objeto S3 al subir con `-Sign` (Q80).
- [x] README Flutter: IAM y texto a `ssm:GetParameter` y `ssm:PutParameter` (Q36).
- [x] README Flutter sin sección de caché (inferencia de Q75; confirmar, D37).
- [x] Alcance de `down.ps1`: borra objeto, versiones y bucket por CLI, fuera de Terraform (Q82).

### 2.7 Backend Spring

- [x] `pom.scriban`: solo quitar el starter; mantener `parameter-store` (Q37).
- [x] `application-cloud-properties.scriban`: sin `aws-secretsmanager:` (Q16).
- [x] Fuentes SCA: `aws-parameterstore` de microservicio se mantiene (Q16).
- [x] Filtro `aws-secretsmanager:` ajustado en `application-context-test.scriban` (Q38, Q72).
- [x] Comentarios Java actualizados: `ai-properties:20`, `openrouter-adapter:31`,
      `parameter-properties:19,95-97` (Q40).

### 2.8 ADR y documentación

- [x] ADR nuevo numerado `ADR-0027` (Q4, Q5, Q6, Q7, Q81).
- [x] ADR-0010: estado "Sustituida por ADR-0027" con enlace y cabecera coherente (Q4, Q54).
- [x] ADR-0012 y 0022: solo secciones que citan Secrets Manager o `secrets-manager` (Q5).
- [x] ADR-0022: referencia ADR-0023 sustituida por ADR-0027 (Q5, Q8, D1).
- [x] No actualizar índice `docs/adr/README.md` (Q9).
- [x] Solo se crea el ADR nuevo, más 0010, 0012 y 0022 (Q55).
- [ ] Título del ADR "SSM Parameter Store SecureString en lugar de Secrets Manager" confirmado
      por architect (Q53).
- [ ] Coste verificado con precios AWS vigentes antes de cerrar ADR (Q47, architect).
- [x] Coste: "coste bajo (S3)" y ≈ 0,005 USD/mes por app, no "0 USD" (Q70).
- [x] Documentación del generador y `library/platform` actualizada (Q3, Q45).

### 2.9 Verificación y proceso

- [x] Integrator despliega en AWS; tester verifica el arranque cloud (Q44).
- [x] Integrator añadido a la tabla de entregables de obj-005.md (Q73, D23).
- [x] Sin implementación sin checklist completo (Q46).
- [x] Secretos AWS eliminados por el usuario (Q49).
- [x] Tamaño 4 KB: sin medición; esqueleto de 210 bytes como referencia (Q76, Q62).
- [x] Migración del keystore: no hay copia; se genera uno nuevo (Q57, Q63, Q64).

### 2.10 Scripts del workspace (excepción Q84)

- [x] Excepción a "solo generador": incluye `.opencode/scripts/*` (Q84).
- [x] Excepción no se registra en AGENTS.md; vive solo en obj-005 (Q85).
- [x] `down.ps1` borra objeto, versiones y bucket por CLI, fuera de Terraform (Q82).
- [ ] `delete-all-services-aws.ps1`: borra bucket keystore vaciando objetos y versiones (Q82, Q84).
- [ ] `get-services-aws.ps1`: consulta S3 del bucket keystore (Q84).
- [ ] Formato de salida de `get-services-aws.ps1` sin definir (ver improvements.md).

## 3. Riesgos a vigilar (obj-005.md)

- [ ] JSON real supera 4 KB: parar y consultar; no pasar a Advanced (Q76).
- [ ] Keystore no subido antes del despliegue: tester valida firma (Q57).
- [ ] Keystore nuevo generado: se asume app no publicada; confirmar antes de subir a Play (Q78).
- [ ] Pérdida total del keystore por borrado de objeto, versiones y bucket (Q65, Q79, Q82).
- [ ] Borrado total del keystore por `down.ps1` o `delete-all-services-aws.ps1` (Q79, Q82, Q84).
- [ ] Estado de Terraform desincronizado si el bucket se borra por CLI antes de `destroy` (Q82).
- [ ] Sin backup previo ni externo; solo versionado S3, que `down.ps1` borra (Q63, Q65, Q83).
- [ ] Lambda o CodeBuild sin permiso SSM, KMS o S3: verificación en tester (Q44).
- [ ] Bucket sin cifrado o con acceso público: bloqueado en Terraform (Q58, Q73).
- [x] Secretos AWS no borrados a tiempo: resuelto por el usuario (Q49).
- [x] Keystore viejo queda en el secreto: resuelto, secreto eliminado (Q49, Q63).

## 4. Decisiones resueltas y pendientes

- [x] Q75: sin caché local; pipeline descarga y verifica hash (Q74 sustituida).
- [x] Q76: 4 KB sin medición; esqueleto de 210 bytes como referencia (Q71 sustituida).
- [x] Q77: siembra solo si falta el parámetro o es placeholder (precisa Q30).
- [x] Q78: asumir app no publicada; riesgo de keystore nuevo registrado.
- [x] Q79: bucket destruido en destroy; alcance de `down.ps1` en Q82 (orden: D41, architect).
- [x] Q80: SHA-256 como metadato del objeto S3 al subir con `-Sign`.
- [x] Q81: mapeo de Q6-Q11 y Q39 confirmado por el usuario (D35 resuelta).
- [ ] Q23, Q47, Q53: delegados a architect; pendientes de su informe.
- [x] Q82: `down.ps1` borra objeto, versiones y bucket por CLI (fuera de Terraform).
- [x] Q83: no se exige backup previo; solo versionado S3.
- [x] Q84: excepción "solo generador" para `.opencode/scripts/*`.
- [x] Q85: excepción no se registra en AGENTS.md; solo en obj-005.
- [x] Q86: documentación backup/restore eliminada tras Q83 (sin guía de restore).
- [ ] Q48: último punto; no cerrar hasta autorización escrita.

## 5. Autorización

- [ ] Q48: autorización explícita y por escrito del usuario para implementar. Último punto.
