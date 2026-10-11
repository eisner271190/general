# Preguntas OBJ-005 (explorer, grilling)

- Estado: Q1–Q85 resueltas por el usuario, salvo Q48 (último, pendiente).
- Delegadas a architect (sin decisión del usuario): Q23, Q47, Q53.
- Abiertas: Q48. Dudas en `improvements.md` (D41–D49, todas resueltas).
- Fuente única de preguntas del objetivo. Cada respuesta se registra en la fila correspondiente.

## Alcance y documentación
- **Q1** Alcance generador: ¿OBJ-005 toca solo el generador y no `/projects`?
  ➡️ Sí. Solo `generator/` y documentación; `/projects` fuera.
  ✅ Respuesta: Sí.
- **Q2** `.opencode/scripts/`: ¿entran `get-services-aws.ps1` y `delete-all-services-aws.ps1`?
  ➡️ No. Son herramientas del workspace.
  ✅ Respuesta: No entran; quedan fuera.
- **Q3** `library/platform` y `library/common/settings.xml`: ¿entran en alcance?
  ➡️ Sí, solo comentarios y README que mencionen Secrets Manager.
  ✅ Respuesta: Sí, solo comentarios y README que mencionen Secrets Manager.
- **Q4** ADR 0010: ¿cambio de estado o solo cabecera?
  ➡️ Estado `Sustituida por ADR-00NN` y cabecera coherente.
  ✅ Respuesta: Estado "Sustituida por ADR-0027" y cabecera coherente.
- **Q5** ADR 0012 y 0022: ¿qué se actualiza?
  ➡️ Solo las secciones que citan Secrets Manager o `secrets-manager`.
  ✅ Respuesta: Solo las secciones que citan Secrets Manager o `secrets-manager`.
  ➡️ Usar ADR-0027
  ✅ Respuesta: ADR-0027.
  ➡️ Usar ADR-0027
  ✅ Respuesta: Sustituir la referencia a ADR-0023 por ADR-0027.
  ➡️ Usar ADR-0027
  ✅ Respuesta: Sí, el ADR-0027 corrige la referencia desaparecida.
  ➡️ No actualizar
  ✅ Respuesta: No actualizar el índice.

## Secreto, ruta y contenido
  ➡️ Sí, confirmado.
  ✅ Respuesta: Sí, confirmado.
  ➡️ No.
  ✅ Respuesta: No cambian.
- **Q12** Límite 4 KB: ¿quién mide el JSON real de signing?
  ➡️ El usuario aporta el JSON o confirma tamaño. Si supera 4 KB, parar.
  ✅ Respuesta: El usuario aporta el JSON o confirma el tamaño. Si supera 4 KB, parar.
- **Q13** Claves `subscription-secret-key`, `subscription-webhook-secret`, `ai-api-key`:
  ¿entran en el SecureString? Cloud `up.ps1.scriban:18-19` las siembra.
  ➡️ Sí, todas las claves del JSON actual.
  ✅ Respuesta: Sí, todas las claves del JSON actual entran.
- **Q14** Clave de cifrado del SecureString (`aws/ssm` por defecto): ¿confirmado?
  ➡️ Sí, coherente con coste 0 USD de obj-005.md:76.
  ✅ Respuesta: Sí, clave `aws/ssm` por defecto.
- **Q15** Límite de tamaño: ¿qué pasa si el JSON actual supera 4 KB?
  ➡️ Parar y consultar; no pasar a Advanced sin autorización.
  ✅ Respuesta: No supera 4 KB; queda por debajo del 20 % del límite Standard.
- **Q16** Fuentes SCA en perfil cloud: ¿se mantiene `aws-parameterstore` de microservicio?
  ➡️ Sí. Sustituir `aws-secretsmanager:` por la ruta SSM del secreto.
  ✅ Respuesta: Sí. Sustituir `aws-secretsmanager:` por la ruta SSM del secreto.

## Terraform
- **Q17** `aws_secretsmanager_secret` → `aws_ssm_parameter` SecureString: ¿nombre del recurso?
  ➡️ Confirmar con developer-terraform; mantener nombre actual si no hay motivo.
  ✅ Respuesta: Mantener el nombre actual salvo motivo.
- **Q18** ¿El SecureString se crea vacío o con valor?
  ➡️ Sin valor, igual que el contenedor actual (ADR-0010, línea 18).
  ✅ Respuesta: Sustituida por Q69: placeholder + `ignore_changes`. La decisión final es no dejarlo vacío.
- **Q19** ¿El valor entra en `terraform.tfstate`?
  ➡️ No. Sembrar desde script, no desde Terraform.
  ✅ Respuesta: No entra en tfstate. Se siembra desde script, no desde Terraform.
- **Q20** Módulo `cloud/terraform/modules/secrets-manager`: ¿se renombra?
  ➡️ No, salvo que obj-005 lo pida. Cambio mínimo.
  ✅ Respuesta: Sí, renombrar el módulo a `secure-parameters` y propagarlo a `component.json` y a la documentación/cloud del generador.
  ✔️ Decisión del usuario (conflicto 2): renombrar a `secure-parameters`. Alcance: carpeta, `source` en `terraform-secrets.scriban`, `component.json` (10, 37-38) y `cloud/aws/AGENTS.md` (4).
- **Q21** `terraform-secrets-manager-variables.scriban` (no leído): ¿se elimina o se adapta?
  ➡️ Leer y decidir con developer-terraform.
  ✅ Respuesta: Adaptarlo sin más.
- **Q22** `component.json` (líneas 10, 37-38): ¿se actualiza el registro de plantillas?
  ➡️ Sí, si cambian nombres de ficheros.
  ✅ Respuesta: Sí, actualizar component.json si cambian nombres de ficheros.
- **Q23** `terraform-secrets-manager.scriban` (nombre): ¿se renombra a `terraform-ssm-*`?
  ➡️ Solo si el nombre contradice el contenido; decidir con architect.
  ✅ Respuesta: Solo si el nombre contradice el contenido; decidir con architect.
- **Q24** `terraform-secrets.scriban` (clave `aws/secretsmanager`, línea 11): ¿qué clave?
  ➡️ Sustituir por la clave equivalente de SSM (`aws/ssm`) si aplica.
  ✅ Respuesta: Sustituir por la clave equivalente de SSM (`aws/ssm`) si aplica.

## IAM
- **Q25** Lambda: ¿`ssm:GetParameter` además de `GetParametersByPath`?
  ➡️ Sí, sobre la ruta `/{{ENV}}/{{APP}}/secrets`. Sin comodín amplio.
  ✅ Respuesta: Sí, GetParameter y GetParametersByPath sobre la ruta, sin comodín amplio.
- **Q26** CodeBuild (`terraform-pipeline.scriban:203`): ¿`ssm:PutParameter`?
  ➡️ Sí, solo sobre la ruta.
  ✅ Respuesta: Sí, solo sobre la ruta.
- **Q27** Lambda con `ssm:PutParameter`: ¿procede?
  ➡️ No. Solo lectura.
  ✅ Respuesta: No, la Lambda solo lee.
- **Q28** `kms:Decrypt` para SecureString con `aws/ssm`: ¿hace falta?
  ➡️ Verificar con architect. ADR-0022 dice que no hay CMK propia.
  ✅ Respuesta: Sí, añadir kms:Decrypt.
- **Q29** Flutter `codepipeline.yml.scriban:53-62` (`SecretsManagerAccess`): ¿entra?
  ➡️ Sí; sustituir por SSM. Confirmar, no está en obj-005.
  ✅ Respuesta: Sustituir SecretsManagerAccess por:
    - `ssm:GetParameter` + `kms:Decrypt` sobre `/{{ENV}}/{{APP}}/secrets`.
    - `s3:GetObject` / `s3:PutObject` sobre `keystore/{{APPLICATION_ID}}/*`.
  ⚠️ Conflicto a revisar con Q59: `s3:PutObject` en pipeline vs. "escritura solo en up.ps1".

## Scripts PowerShell
- **Q30** Siembra con `put-parameter --overwrite`: ¿solo al crear claves faltantes?
  ➡️ Sí. Mantener "no sobrescribir" (ADR-0010 línea 19).
  ✅ Respuesta: Sí, solo al crear claves faltantes, sin sobrescribir. Precisada por Q77.
- **Q31** `down.ps1`: ¿borrar el parámetro con `delete-parameter`?
  ➡️ Sí. SSM no tiene ventana de recuperación.
  ✅ Respuesta: Sí, borrar con delete-parameter.
- **Q32** Lógica `restore-secret` en `down.ps1.scriban:194-204`: ¿se elimina?
  ➡️ Sí. No aplica a SSM.
  ✅ Respuesta: Sí, eliminar la lógica restore-secret.
- **Q33** Flutter `up.ps1`: ¿`get-parameter --with-decryption`?
  ➡️ Sí, según obj-005.md:17.
  ✅ Respuesta: Sí, get-parameter --with-decryption.
- **Q34** Flutter `up.ps1` con `-Sign` sin secreto: ¿mismo comportamiento?
  ➡️ Sí. Mantener error explícito.
  ✅ Respuesta: Sí, mismo error explícito.
- **Q35** Flutter `up.ps1` crea `android-signing` si falta: ¿mantener?
  ➡️ Sí, sin cambio de comportamiento.
  ✅ Respuesta: Sí, sin cambio de comportamiento.
- **Q36** `README.md.scriban` (Flutter) líneas 24, 66-69, 78: ¿reescribir IAM y texto?
  ➡️ Sí, a `ssm:GetParameter` y `ssm:PutParameter`.
  ✅ Respuesta: Sí, reescribir IAM y texto a `ssm:GetParameter` y `ssm:PutParameter`.

## Backend Spring
- **Q37** `pom.scriban:156`: ¿solo se quita el starter?
  ➡️ Sí. Mantener `parameter-store`; no cambiar versión de SCA.
  ✅ Respuesta: Sí, solo quitar el starter y mantener parameter-store.
- **Q38** `application-context-test.scriban:74-76`: ¿se ajusta el filtro?
  ➡️ Preguntar: es plantilla de test y obj-005 prohíbe modificar tests.
  ✅ Respuesta: Sí, ajustar el filtro (líneas 74-76).
 ¿Plantilla de test cuenta como "test" a efectos de la regla?
  ➡️ Confirmar explícitamente con el usuario antes de tocarla.
  ✅ Respuesta: No cuenta como test; se puede modificar.
- **Q40** Comentarios Java con "Secrets Manager" (`ai-properties:20`, `openrouter-adapter:31`,
  `parameter-properties:19,95-97`): ¿se actualizan?
  ➡️ Sí, para que ningún template lo mencione.
  ✅ Respuesta: Sí, actualizar todos los comentarios Java.
- **Q41** `postman-collection.scriban:4,1223`: ¿"secreto" cuenta como referencia?
  ➡️ No. Solo texto que nombre Secrets Manager o AWS secretsmanager.
  ✅ Respuesta: No cuenta; solo texto que nombre Secrets Manager o secretsmanager.

## Criterios y verificación
- **Q42** Criterio "ningún template referencia `secretsmanager:`": ¿incluye `.opencode` y docs?
  ➡️ Solo generador. Docs históricos (obj-003/004) no se tocan.
  ✅ Respuesta: Solo generador y documentación; docs históricos obj-003/004 no se tocan.
- **Q43** "Cabe en 4 KB": ¿medición o estimación?
  ➡️ Medición del JSON real. Estimación no basta.
  ✅ Respuesta: Estimación suficiente. Resuelto con Q62 (210 bytes medidos sin valores).
- **Q44** Verificación de arranque cloud: ¿quién la ejecuta?
  ➡️ Tester con acceso AWS. Si no hay acceso, queda bloqueada.
  ✅ Respuesta: Integrator despliega en AWS; tester verifica el arranque.
- **Q45** ¿Se añaden criterios de aceptación nuevos?
  ➡️ Sí: comentarios (Q40), `component.json` (Q22), docs (Q9).
  ✅ Respuesta: Sí: comentarios (Q40), `component.json` (Q22) y docs (ADRs 0010/0012/0022, sin índice).
- **Q46** `checklist.md` de obj-005: ¿se crea antes de implementar?
  ➡️ Sí, obligatorio (AGENTS.md).
  ✅ Respuesta: Sí, checklist.md antes de implementar, obligatorio.
- **Q47** Coste "0 USD/mes": ¿verificado con precios AWS vigentes?
  ➡️ Sí, architect verifica antes de cerrar ADR.
  ✅ Respuesta: Sí, architect verifica precios AWS antes de cerrar el ADR.

## Dependencias y proceso
- **Q48** Autorización explícita para implementar: ¿cuándo?
  ➡️ Tras cerrar questions.md y checklist.md. Pedir por escrito.
  ✅ Respuesta: Tras cerrar questions.md y checklist.md, pedida por escrito.
  ✔️ Decisión del usuario: no autorizar todavía; mantener análisis.
- **Q49** Limpieza de secretos AWS: ¿antes o después de desplegar?
  ➡️ Después de validar `develop`; el usuario avisa.
  ✅ Respuesta: Ya no existen; el usuario los eliminó manualmente.
- **Q50** Migración de valores existentes: ¿fuera de alcance?
  ➡️ Sí. El usuario re-siembra; confirmar.
  ✅ Respuesta: Fuera de alcance; el usuario re-siembra y lo confirma.
- **Q51** Entornos distintos de `develop`: ¿fuera?
  ➡️ Sí, según obj-005.md:25.
  ✅ Respuesta: Sí, fuera de alcance; solo develop.
- **Q52** Commit o push: ¿cuándo?
  ➡️ Nunca sin autorización explícita (AGENTS.md).
  ✅ Respuesta: Nunca sin autorización explícita.
- **Q53** Nombre del ADR nuevo: ¿título?
  ➡️ Confirmar con architect; ejemplo: "SSM Parameter Store SecureString en lugar de Secrets
  Manager".
  ✅ Respuesta: Confirmar con architect; usar como borrador "SSM Parameter Store SecureString en lugar de Secrets Manager".
- **Q54** Estado de ADR 0010 tras el ADR nuevo: ¿"Sustituida"?
  ➡️ Sí, con enlace al ADR nuevo.
  ✅ Respuesta: Sí, estado "Sustituida" con enlace al ADR nuevo.
- **Q55** `docs/adr/` por versión: ¿se crea solo el ADR nuevo?
  ➡️ Sí, más las actualizaciones de 0010, 0012 y 0022.
  ✅ Respuesta: Sí, solo el ADR nuevo más las actualizaciones de 0010, 0012 y 0022.

## Cambio 2026-10-10: keystore a S3 (fuente única)
- **Q56** Bucket S3: `keystore/{{APPLICATION_ID}}/keystore.jks` es clave de objeto, no nombre de
  bucket. ¿Nombre del bucket (p. ej. uno por entorno, `develop`)?
  ➡️ Bucket por entorno y objeto con esa ruta. Confirmar nombre.
  ✅ Respuesta: Bucket nuevo dedicado por entorno: `${var.project_name}-keystore-${var.environment}`.
    - Terraform crea el bucket vacío (igual que el contenedor del secreto).
    - Subida del `.jks` solo desde `frontend/up.ps1` con `-Sign` (ver Q59).
    - Versionado + SSE + bloqueo de acceso público, como el bucket de artefactos.
    - ⚠️ Usuario indica que `down.ps1` SÍ borra el objeto: conflicto con Q61 (conservar).
- **Q57** Keystore actual dentro del secreto: ¿lo subes tú a S3 antes del despliegue?
  ➡️ Sí, fuera de código (igual que Q50). Confirmar.
  ✅ Respuesta: No lo subo desde el secreto. Se sube vía `frontend/up.ps1` con `-Sign` tras el despliegue.
    - ⚠️ El secreto ya fue eliminado (Q49): verificar que el keystore sigue recuperable.
- **Q58** Cifrado y acceso del bucket: ¿SSE-S3 o SSE-KMS, y bloqueo de acceso público?
  ➡️ SSE-S3 y bloqueo de acceso público total. Confirmar.
  ✅ Respuesta: SSE-S3 y bloqueo de acceso público total.
- **Q59** ¿Quién lee el keystore? Lambda, CodeBuild o solo Flutter `up.ps1` local.
  ➡️ Solo quien firma. Lectura S3 acotada; escritura solo en Flutter `up.ps1`.
  ✅ Respuesta: `up.ps1 -Sign` (local y CodeBuild Flutter) lee el `.jks` de S3, o lo genera y sube si falta
    (extendiendo `Get-OrCreateAndroidSigning`, líneas 283-299). Es único lector y escritor.
    - CodeBuild Flutter (`codepipeline.yml.scriban:41`): `s3:GetObject` + `s3:PutObject` sobre
      `keystore/{{APPLICATION_ID}}/*`.
    - Lambda backend: cero permisos S3.
    - CodeBuild cloud (terraform-pipeline): solo siembra SSM; sin acceso al keystore.
- **Q60** Versionado del bucket: ¿activarlo para recuperar un keystore borrado?
  ➡️ Sí. Un keystore perdido no se regenera sin romper la app en Play.
  ✅ Respuesta: Sí, activar versionado.
- **Q61** Borrado en `down.ps1`: ¿se borra el objeto keystore o se conserva?
  ➡️ Conservar.
  ✅ Respuesta: Q65 prevalece: se borran todas las versiones del keystore. Q60 queda como mitigación parcial, no como salvavidas; se debe documentar backup/restore y no depender del bucket versionado como única garantía.
- **Q62** JSON nuevo sin keystore: ¿se mide ya el tamaño real?
  ➡️ Sí. Medir igualmente aunque sea muy inferior a 4 KB.
  ✅ Respuesta: La estimación basta. Esqueleto medido: 210 bytes sin valores (muy por debajo de 4 KB). Resuelve el conflicto con Q43 (estimación suficiente). Queda pendiente solo el tamaño con keystore, que no aplica (el keystore va en S3, Q56).

## Reviewer · 2026-10-10 (hora no disponible)

- [x] Q63 ¿Dónde está el `.jks` actual si el secreto fue eliminado (Q49)?
  - Decisión del usuario: sin backup externo; solo versionado de S3 (Q60).
  - Riesgo: con Q65 (`down.ps1` borra todas las versiones) no queda recuperación tras `down.ps1`.
  - Confirmado por el usuario: combinación Q60 + Q65 aceptada con este riesgo.
  - rec: confirmar copia local o backup antes de desplegar.
  ✅ Respuesta: No hay copia; hay que generar uno nuevo. Debe registrarse backup antes del despliegue.
    - Q83 sustituye "backup antes del despliegue": no se exige backup previo.
- [x] Q64 ¿`Get-OrCreateAndroidSigning` debe generar keystore nuevo si S3 no tiene objeto?
  - rec: no; error explícito si la app ya está publicada.
  ✅ Respuesta: Generar siempre, como hoy (igual que el comportamiento actual del secreto).
- [x] Q65 ¿`down.ps1` borra solo el objeto actual, sus versiones o nada (Q61)?
  - Decisión del usuario (conflicto 1): borrar objeto y todas sus versiones. Q61 sustituida.
  - rec: objeto actual; conservar versiones; no borrar bucket.
  ✅ Respuesta: Se borran todas las versiones.
- [x] Q66 ¿Corregir obj-005:64 a `GetParameter` + `GetParametersByPath` + `kms:Decrypt` (Lambda)?
  - rec: sí, solo lectura (Q25, Q27, Q28).
  ✅ Respuesta: Sí, solo lectura en Lambda: `ssm:GetParameter` + `ssm:GetParametersByPath` + `kms:Decrypt` sobre `aws/ssm`; sin `PutParameter`. CodeBuild de siembra usa `PutParameter`.
- [x] Q67 ¿CodeBuild Flutter necesita `ssm:PutParameter` sobre la ruta (Q35, Q59) y `kms:Encrypt`?
  - rec: sí; architect verifica.
  ✅ Respuesta: Sí, necesita `ssm:PutParameter` sobre `/{{ENV}}/{{APP}}/secrets`; `kms:Encrypt` no aplica con `aws/ssm` (la clave la gestiona AWS). Sí requiere `kms:Decrypt` para `get-parameter --with-decryption`. También necesita `s3:GetObject` + `s3:PutObject` sobre `keystore/{{APPLICATION_ID}}/*`.
- [x] Q68 ¿Bucket por entorno (Q56) y corregir obj-005:27 "por app"?
  - rec: sí, por entorno.
  ✅ Respuesta: Sí a ambas: bucket por entorno, con prefijo por app (`keystore/{{APPLICATION_ID}}/keystore.jks`). El texto de obj-005:27 debe corregirse.
- [x] Q69 ¿SecureString con placeholder + `ignore_changes` en lugar de vacío (Q18)?
  - rec: sí; developer-terraform verifica provider.
  ✅ Respuesta: Sí, placeholder + `ignore_changes`; mejor que dejarlo vacío. Evita que Terraform vuelva a reescribir el valor y deja el parámetro siempre con un valor legible.
- [x] Q70 ¿Sustituir "0 USD/mes" por "coste bajo (S3)" y corregir cita de Q14?
  - Decisión del usuario (conflicto 4): coste bajo (S3), ≈ 0,005 USD/mes por app. obj-005.md actualizado.
  - rec: sí.
  ✅ Respuesta: No. El coste real no es 0 USD; hay S3 y el coste de ejecución. Lo correcto es mantener el principio de costo bajo y usar el JSON real para validar el 4 KB.
- [x] Q71 ¿Aceptas estimar el 4 KB con valores de longitud máxima, no con JSON real?
  - rec: sí, por escrito.
  ✅ Respuesta: No, usar el JSON real. El caso de prueba real se mide con el contenido final; la estimación solo sirve como referencia.
  ✔️ Decisión del usuario (conflicto 3): el JSON nunca llegará a 4 KB; basta la estimación. Sin medición ni validación de tamaño. Q43/Q62 prevalecen.
- [x] Q72 ¿Confirmas excepción a "no modificar tests" para `application-context-test.scriban`?
  - rec: sí y registrar en AGENTS/obj-005; si no, excluir.
  ✅ Respuesta: Sí, excepción autorizada. Se ajusta el filtro de `application-context-test.scriban` sin modificar el resto de tests.
- [x] Q73 ¿Añadir a criterios: versionado (Q60), SSE-S3 y bloqueo público (Q58)?
  - rec: sí.
  ✅ Respuesta: Sí, añadimos al criterio de aceptación que el bucket de keystore tenga versionado, cifrado con SSE-S3 y bloqueo total de acceso público.

## Cambio 2026-10-10: caché local y pipeline (fuente única)
- [x] Q74 ¿Caché local del `.jks` y descarga en pipeline?
  - Decisión del usuario: aprobada la propuesta.
  - Local: si `android/upload-keystore.jks` existe, se usa sin descargar de S3.
  - Pipeline: descarga siempre y verifica hash antes de firmar.
  - README Flutter: explicar caché local y cómo invalidarla (borrar el `.jks`).
- [x] Q74 ¿Se usa caché local (sustituida por Q75) del `.jks` para acelerar `-Sign` con verificación de hash?
  - rec: sí, local temporal, pero pipeline siempre valida.
  ✅ Respuesta: No, sin caché local.

## Revisión checklist · 2026-10-10 19:05:13 (UTC-5)

- [x] Q75 ¿Caché local del `.jks`? Q74 tiene dos respuestas contrarias (aprobada / no).
  - rec: no; la última respuesta dice sin caché. Pipeline siempre descarga y verifica.
  ✅ Respuesta: Sin caché local. Pipeline siempre descarga y verifica hash. Q74 queda sustituida.
- [x] Q76 ¿4 KB con JSON real o sin medición? Q71 dice "usar JSON real" y "sin medición".
  - rec: sin medición; registrar esqueleto de 210 bytes sin valores (Q62) como referencia.
  ✅ Respuesta: Sin medición. Esqueleto de 210 bytes como referencia. Q71 queda sustituida.
- [x] Q77 ¿El script de siembra sobrescribe el placeholder? Q30 "sin sobrescribir" vs Q69.
  - rec: sí, solo si falta el parámetro o su valor es el placeholder. Corrige obj-005:31.
  ✅ Respuesta: Sí, solo si falta el parámetro o su valor es el placeholder. Q30 se precisa.
- [x] Q78 ¿La app ya está publicada en Play? Keystore nuevo (Q64) impide actualizar.
  - rec: confirmar antes de desplegar; si está publicada, parar.
  ✅ Respuesta: Asumir que no está publicada y continuar. Riesgo: si lo está, el keystore nuevo
    bloquea las actualizaciones en Play.
- [x] Q79 ¿`down.ps1` o Terraform destruyen el bucket keystore o solo sus versiones?
  - rec: solo versiones; el bucket se conserva (rec de Q65).
  ✅ Respuesta: Destruir también el bucket (Terraform destroy), además de objeto y versiones.
    Riesgo: pérdida total del keystore si se ejecuta destroy.
- [x] Q80 ¿De dónde sale el hash de verificación de la pipeline (Q74)?
  - rec: SHA-256 guardado como metadato del objeto S3 al subirlo con `-Sign`.
  ✅ Respuesta: SHA-256 como metadato del objeto S3, guardado al subir el `.jks` con `-Sign`.
- [x] Q81 ¿Confirmas el mapeo de Q6-Q11 y Q39 (enunciados perdidos, D18)?
  - Enunciados restaurados desde el commit `4192aed` (`questions.md`):
    - Q6 Número del ADR nuevo: ¿cuál? → Respuesta: ADR-0027.
    - Q7 ADR-0023 citado en 0022 (línea 70) no existe: ¿qué hacer? → Respuesta: ADR-0027.
    - Q8 ADR-0023 desaparecido: ¿se corrige en el ADR nuevo? → Respuesta: ADR-0027.
    - Q9 `docs/adr/README.md` no lista 0010/0012/0022: ¿se actualiza? → Respuesta: no.
    - Q10 Un SecureString por app con ruta `/{{ENV}}/{{APP}}/secrets`: ¿confirmado? → Sí.
    - Q11 Claves kebab-case (`android-signing`, `jwt-secret`, `api-key`): ¿cambian? → No.
    - Q39 ¿Plantilla de test cuenta como "test"? → No cuenta; se puede modificar.
  - ✅ Respuesta: mapeo confirmado por el usuario.
  - rec: reconstruir enunciados desde obj-005.md y confirmar cada respuesta.

## Cambio 2026-10-10 19:18:41 (UTC-5): preguntas nuevas

- [x] Q82 ¿`down.ps1` borra también el bucket keystore, o solo el objeto y sus versiones?
  - ✅ Respuesta: Opción 2 del usuario: `down.ps1` borra objeto, versiones y bucket (CLI, fuera de Terraform).
    Además pide borrado en `.opencode/scripts/delete-all-services-aws.ps1` y consulta S3 en
    `.opencode/scripts/get-services-aws.ps1`. Ver nueva pregunta Q84 (conflicto con AGENTS).
- [x] Q84 ¿Incluir `.opencode/scripts/` en obj-005 pese a "solo generador" (AGENTS) y Q2?
  - ✅ Respuesta: Opción 1 del usuario: incluir ambos scripts y registrar la excepción a "solo generador".
    Q2 queda sustituida.
  - Causa: Q79 responde "Terraform destroy" para el bucket; no indica si `down.ps1` lo borra.
  - rec: `down.ps1` borra objeto y versiones (Q65); el bucket solo con Terraform destroy (Q79).
- [x] Q83 ¿Se exige backup del keystore antes del despliegue?
  - ✅ Respuesta: Opción 1 del usuario: no se exige backup previo; solo versionado S3 (Q63).
- [x] Q85 ¿Registrar la excepción "solo generador" en AGENTS.md para `.opencode/scripts/`?
  - ✅ Respuesta: Opción 2 del usuario: no registrar en AGENTS.md; la excepción vive solo en obj-005.
  - Causa: Q63 dice "sin backup externo" y también "debe registrarse backup antes del despliegue".
  - rec: aceptar sin backup externo y registrar riesgo; si se exige, definir destino.

## Cambio 2026-10-10 19:30:14 (UTC-5): duda tras Q83

- [x] Q86 ¿Q83 elimina también la documentación de backup/restore exigida en Q61?
  - ✅ Respuesta: Opción 1 del usuario: sí; se elimina la documentación de backup/restore.
  - Causa: Q83 retira el backup previo; Q61 pedía documentar backup/restore.
  - rec: documentar solo el riesgo "sin copia externa" y el versionado S3; sin guía de restore.

## Dependencias

- Q75 bloquea README Flutter y `up.ps1` (caché local).
- Q76 bloquea criterio de 4 KB.
- Q77 bloquea script de siembra y `down.ps1`.
- Q78 bloquea subida inicial del keystore y despliegue.
- Q79 bloquea `down.ps1` y Terraform destroy del bucket.
- Q80 bloquea verificación de hash en pipeline.
- Q48 bloquea implementación; va al final.
- Q82 resuelta: alcance de `down.ps1` y destrucción del bucket (Q79).
- Q83 resuelta: no exige backup previo. Q86 resuelta: sin documentación backup/restore.

