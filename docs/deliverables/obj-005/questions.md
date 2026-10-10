# Preguntas OBJ-005 (explorer, grilling)

- Estado: `abiertas`. Ninguna respuesta confirmada. Recomendaciones no son acuerdos.
- Fuente única de preguntas del objetivo. Cada respuesta se registra en la fila correspondiente.

## Alcance y documentación
- **Q1** Alcance generador: ¿OBJ-005 toca solo el generador y no `/projects`?
  ➡️ Sí. Solo `generator/` y documentación; `/projects` fuera.
- **Q2** `.opencode/scripts/`: ¿entran `get-services-aws.ps1` y `delete-all-services-aws.ps1`?
  ➡️ No. Son herramientas del workspace.
- **Q3** `library/platform` y `library/common/settings.xml`: ¿entran en alcance?
  ➡️ Sí, solo comentarios y README que mencionen Secrets Manager.
- **Q4** ADR 0010: ¿cambio de estado o solo cabecera?
  ➡️ Estado `Sustituida por ADR-00NN` y cabecera coherente.
- **Q5** ADR 0012 y 0022: ¿qué se actualiza?
  ➡️ Solo las secciones que citan Secrets Manager o `secrets-manager`.
- **Q6** Número del ADR nuevo: ¿cuál?
  ➡️ Usar ADR-0027
- **Q7** ADR-0023 citado en 0022 (línea 70) no existe en `docs/adr`: ¿qué hacer?
  ➡️ Usar ADR-0027
- **Q8** ADR-0023 desaparecido: ¿se corrige en el ADR nuevo?
  ➡️ Usar ADR-0027
- **Q9** `docs/adr/README.md` no lista 0010/0012/0022: ¿se actualiza el índice?
  ➡️ No actualizar

## Secreto, ruta y contenido
- **Q10** Un SecureString por app con ruta `/{{ENV}}/{{APP}}/secrets`: ¿confirmado?
  ➡️ Sí, confirmado.
- **Q11** Claves kebab-case (`android-signing`, `jwt-secret`, `api-key`): ¿cambian?
  ➡️ No.
- **Q12** Límite 4 KB: ¿quién mide el JSON real de signing?
  ➡️ El usuario aporta el JSON o confirma tamaño. Si supera 4 KB, parar.
- **Q13** Claves `subscription-secret-key`, `subscription-webhook-secret`, `ai-api-key`:
  ¿entran en el SecureString? Cloud `up.ps1.scriban:18-19` las siembra.
  ➡️ Sí, todas las claves del JSON actual.
- **Q14** Clave de cifrado del SecureString (`aws/ssm` por defecto): ¿confirmado?
  ➡️ Sí, coherente con coste 0 USD de obj-005.md:76.
- **Q15** Límite de tamaño: ¿qué pasa si el JSON actual supera 4 KB?
  ➡️ Parar y consultar; no pasar a Advanced sin autorización.
- **Q16** Fuentes SCA en perfil cloud: ¿se mantiene `aws-parameterstore` de microservicio?
  ➡️ Sí. Sustituir `aws-secretsmanager:` por la ruta SSM del secreto.

## Terraform
- **Q17** `aws_secretsmanager_secret` → `aws_ssm_parameter` SecureString: ¿nombre del recurso?
  ➡️ Confirmar con developer-terraform; mantener nombre actual si no hay motivo.
- **Q18** ¿El SecureString se crea vacío o con valor?
  ➡️ Sin valor, igual que el contenedor actual (ADR-0010, línea 18).
- **Q19** ¿El valor entra en `terraform.tfstate`?
  ➡️ No. Sembrar desde script, no desde Terraform.
- **Q20** Módulo `cloud/terraform/modules/secrets-manager`: ¿se renombra?
  ➡️ No, salvo que obj-005 lo pida. Cambio mínimo.
- **Q21** `terraform-secrets-manager-variables.scriban` (no leído): ¿se elimina o se adapta?
  ➡️ Leer y decidir con developer-terraform.
- **Q22** `component.json` (líneas 10, 37-38): ¿se actualiza el registro de plantillas?
  ➡️ Sí, si cambian nombres de ficheros.
- **Q23** `terraform-secrets-manager.scriban` (nombre): ¿se renombra a `terraform-ssm-*`?
  ➡️ Solo si el nombre contradice el contenido; decidir con architect.
- **Q24** `terraform-secrets.scriban` (clave `aws/secretsmanager`, línea 11): ¿qué clave?
  ➡️ Sustituir por la clave equivalente de SSM (`aws/ssm`) si aplica.

## IAM
- **Q25** Lambda: ¿`ssm:GetParameter` además de `GetParametersByPath`?
  ➡️ Sí, sobre la ruta `/{{ENV}}/{{APP}}/secrets`. Sin comodín amplio.
- **Q26** CodeBuild (`terraform-pipeline.scriban:203`): ¿`ssm:PutParameter`?
  ➡️ Sí, solo sobre la ruta.
- **Q27** Lambda con `ssm:PutParameter`: ¿procede?
  ➡️ No. Solo lectura.
- **Q28** `kms:Decrypt` para SecureString con `aws/ssm`: ¿hace falta?
  ➡️ Verificar con architect. ADR-0022 dice que no hay CMK propia.
- **Q29** Flutter `codepipeline.yml.scriban:53-62` (`SecretsManagerAccess`): ¿entra?
  ➡️ Sí; sustituir por SSM. Confirmar, no está en obj-005.

## Scripts PowerShell
- **Q30** Siembra con `put-parameter --overwrite`: ¿solo al crear claves faltantes?
  ➡️ Sí. Mantener "no sobrescribir" (ADR-0010 línea 19).
- **Q31** `down.ps1`: ¿borrar el parámetro con `delete-parameter`?
  ➡️ Sí. SSM no tiene ventana de recuperación.
- **Q32** Lógica `restore-secret` en `down.ps1.scriban:194-204`: ¿se elimina?
  ➡️ Sí. No aplica a SSM.
- **Q33** Flutter `up.ps1`: ¿`get-parameter --with-decryption`?
  ➡️ Sí, según obj-005.md:17.
- **Q34** Flutter `up.ps1` con `-Sign` sin secreto: ¿mismo comportamiento?
  ➡️ Sí. Mantener error explícito.
- **Q35** Flutter `up.ps1` crea `android-signing` si falta: ¿mantener?
  ➡️ Sí, sin cambio de comportamiento.
- **Q36** `README.md.scriban` (Flutter) líneas 24, 66-69, 78: ¿reescribir IAM y texto?
  ➡️ Sí, a `ssm:GetParameter` y `ssm:PutParameter`.

## Backend Spring
- **Q37** `pom.scriban:156`: ¿solo se quita el starter?
  ➡️ Sí. Mantener `parameter-store`; no cambiar versión de SCA.
- **Q38** `application-context-test.scriban:74-76`: ¿se ajusta el filtro?
  ➡️ Preguntar: es plantilla de test y obj-005 prohíbe modificar tests.
- **Q39** ¿Plantilla de test cuenta como "test" a efectos de la regla?
  ➡️ Confirmar explícitamente con el usuario antes de tocarla.
- **Q40** Comentarios Java con "Secrets Manager" (`ai-properties:20`, `openrouter-adapter:31`,
  `parameter-properties:19,95-97`): ¿se actualizan?
  ➡️ Sí, para que ningún template lo mencione.
- **Q41** `postman-collection.scriban:4,1223`: ¿"secreto" cuenta como referencia?
  ➡️ No. Solo texto que nombre Secrets Manager o AWS secretsmanager.

## Criterios y verificación
- **Q42** Criterio "ningún template referencia `secretsmanager:`": ¿incluye `.opencode` y docs?
  ➡️ Solo generador. Docs históricos (obj-003/004) no se tocan.
- **Q43** "Cabe en 4 KB": ¿medición o estimación?
  ➡️ Medición del JSON real. Estimación no basta.
- **Q44** Verificación de arranque cloud: ¿quién la ejecuta?
  ➡️ Tester con acceso AWS. Si no hay acceso, queda bloqueada.
- **Q45** ¿Se añaden criterios de aceptación nuevos?
  ➡️ Sí: comentarios (Q40), `component.json` (Q22), docs (Q9).
- **Q46** `checklist.md` de obj-005: ¿se crea antes de implementar?
  ➡️ Sí, obligatorio (AGENTS.md).
- **Q47** Coste "0 USD/mes": ¿verificado con precios AWS vigentes?
  ➡️ Sí, architect verifica antes de cerrar ADR.

## Dependencias y proceso
- **Q48** Autorización explícita para implementar: ¿cuándo?
  ➡️ Tras cerrar questions.md y checklist.md. Pedir por escrito.
- **Q49** Limpieza de secretos AWS: ¿antes o después de desplegar?
  ➡️ Después de validar `develop`; el usuario avisa.
- **Q50** Migración de valores existentes: ¿fuera de alcance?
  ➡️ Sí. El usuario re-siembra; confirmar.
- **Q51** Entornos distintos de `develop`: ¿fuera?
  ➡️ Sí, según obj-005.md:25.
- **Q52** Commit o push: ¿cuándo?
  ➡️ Nunca sin autorización explícita (AGENTS.md).
- **Q53** Nombre del ADR nuevo: ¿título?
  ➡️ Confirmar con architect; ejemplo: "SSM Parameter Store SecureString en lugar de Secrets
  Manager".
- **Q54** Estado de ADR 0010 tras el ADR nuevo: ¿"Sustituida"?
  ➡️ Sí, con enlace al ADR nuevo.
- **Q55** `docs/adr/` por versión: ¿se crea solo el ADR nuevo?
  ➡️ Sí, más las actualizaciones de 0010, 0012 y 0022.

## Cambio 2026-10-10: keystore a S3 (fuente única)
- **Q56** Bucket S3: `keystore/{{APPLICATION_ID}}/keystore.jks` es clave de objeto, no nombre de
  bucket. ¿Nombre del bucket (p. ej. uno por entorno, `develop`)?
  ➡️ Bucket por entorno y objeto con esa ruta. Confirmar nombre.
- **Q57** Keystore actual dentro del secreto: ¿lo subes tú a S3 antes del despliegue?
  ➡️ Sí, fuera de código (igual que Q50). Confirmar.
- **Q58** Cifrado y acceso del bucket: ¿SSE-S3 o SSE-KMS, y bloqueo de acceso público?
  ➡️ SSE-S3 y bloqueo de acceso público total. Confirmar.
- **Q59** ¿Quién lee el keystore? Lambda, CodeBuild o solo Flutter `up.ps1` local.
  ➡️ Solo quien firma. Lectura S3 acotada; escritura solo en Flutter `up.ps1`.
- **Q60** Versionado del bucket: ¿activarlo para recuperar un keystore borrado?
  ➡️ Sí. Un keystore perdido no se regenera sin romper la app en Play.
- **Q61** Borrado en `down.ps1`: ¿se borra el objeto keystore o se conserva?
  ➡️ Conservar.
- **Q62** JSON nuevo sin keystore: ¿se mide ya el tamaño real?
  ➡️ Sí. Medir igualmente aunque sea muy inferior a 4 KB.
