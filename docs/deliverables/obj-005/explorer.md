# Exploración

- Objetivo: `OBJ-005: Reemplazar AWS Secrets Manager por SSM Parameter Store SecureString`
- Agente: `Explorer`
- Estado: `parcial`
- Resumen: `Secrets Manager aparece en 9 familias de ficheros del generador, library/platform y
  .opencode. ADR-0010 y 0012 existen; 0022 existe. ADR-0023 se cita pero no existe en docs/adr.`
- Bloqueos: `ninguno de lectura. Pendiente: confirmar alcance de .opencode y library/platform`

## Entrevista
| Pregunta | Respuesta | Recomendación | Decisión/estado |
|---|---|---|---|
| Q1-Q55 (ver sección Preguntas Grill-me) | pendiente | ver questions.md | pendiente |

## Contexto y hallazgos
- Objetivo/alcance entendido:
  - Sustituir Secrets Manager por SSM SecureString (perfil cloud, Terraform, IAM, scripts).
  - Crear ADR nuevo que sustituya 0010 y actualice 0012 y 0022.
  - Excluido: /projects, migración de valores, tests, commit/push.
- Estructura, tecnologías y componentes relevantes:
  - Generador: `generator/components/{backend,cloud/aws,frontend/flutter3.47.2,root/workspace}`.
  - Backend: Spring Boot 3.5.16 (plantillas Scriban). Cloud: Terraform AWS. Frontend: Flutter.
  - Plantillas no versionadas en `docs/templates`: no hay `explorer.md` en su raíz; se usó
    `docs/templates/deliverables/explorer.md`.
- Hallazgos (Secrets Manager; ruta:línea):
  - Backend Spring:
    - `generator/components/backend/spring-boot-3.5.16/templates/application-cloud-properties.scriban:1`
      `aws-secretsmanager:{{ ENVIRONMENT }}/{{ APPLICATION_ID }}` en `spring.config.import`.
    - `.../templates/pom.scriban:156` `spring-cloud-aws-starter-secrets-manager`.
    - `.../templates/application-context-test.scriban:74` filtro `aws-secretsmanager:`;
      `:76` `type.contains("SecretsManager")`. Test de plantilla: no crear ni modificar.
    - `.../templates/parameter-properties.scriban:19` comentario de secretos (sin código).
    - `.../templates/parameter-properties.scriban:95-97` comentario sobre prefijo `/`.
    - `.../templates/ai-properties.scriban:20`, `openrouter-adapter.scriban:31`: comentarios.
    - `.../templates/postman-collection.scriban:4,1223`: texto "secreto ... sembrado" (AWS).
    - `.../templates/down.ps1.scriban`: sin referencias Secrets Manager (solo SSM/Terraform).
  - Cloud AWS (Terraform y PowerShell):
    - `generator/components/cloud/aws/templates/terraform-secrets-manager.scriban:2,6,8`
      `aws_secretsmanager_secret "app_secret"`.
    - `.../templates/terraform-secrets.scriban:7,11` módulo `../modules/secrets-manager`, clave
      `aws/secretsmanager`.
    - `.../templates/terraform-secrets-manager-variables.scriban`: pendiente de leer.
    - `.../templates/terraform-lambda.scriban:44-45` IAM `secretsmanager:GetSecretValue`.
    - `.../templates/terraform-pipeline.scriban:203` IAM `secretsmanager:GetSecretValue`.
    - `.../templates/up.ps1.scriban:17-21` siembra del secreto; `:321-404` funciones
      `Invoke-AwsSecretsManager`, describe/get/put-secret-value; `:611` llamada
      `Update-ApplicationSecret`.
    - `.../templates/down.ps1.scriban:8,165-238,315-316,343` borrado de secreto
      (`delete-secret --force-delete-without-recovery`, `restore-secret`).
    - `generator/components/cloud/aws/component.json:10,37-38` registra
      `cloud/terraform/modules/secrets-manager`.
    - `generator/components/cloud/aws/AGENTS.md:4` menciona `modules/{secrets-manager,pipeline}`.
    - SSM ya existe: `terraform-ssm.scriban:3` `aws_ssm_parameter "environment"`;
      `terraform-lambda.scriban:49-50` `ssm:GetParametersByPath` sobre `/{{ENV}}/{{APP}}/...`.
  - Frontend Flutter:
    - `generator/components/frontend/flutter3.47.2/templates/up.ps1.scriban:11,32,34`: texto.
    - `.../up.ps1.scriban:148-238` funciones `Invoke-AwsSecretsManager` y get/put.
    - `.../up.ps1.scriban:282-344,545-547` firma android en el secreto.
    - `.../templates/README.md.scriban:24,66-69,78,90`: IAM y `secretsmanager:*`.
    - `.../templates/codepipeline.yml.scriban:53-62` `SecretsManagerAccess`.
    - `.../templates/down.ps1.scriban`: sin referencias Secrets Manager.
  - Root workspace: `generator/components/root/workspace/templates/up.ps1.scriban` y
    `down.ps1.scriban` sin referencias Secrets Manager (grep).
  - library/platform (documentación y comentarios):
    - `library/platform/README.md:44`.
    - `library/platform/scripts/up.ps1:13`.
    - `library/platform/scripts/publish-common.ps1:10`.
    - `library/platform/terraform/pipeline/main.tf:30`.
    - `library/platform/buildspecs/java-ci.yml:7`.
  - library/common: `library/common/settings.xml:7` (CI desde Secrets Manager).
  - docs/adr:
    - `0010-un-secreto-por-aplicacion.md`: Estado Aceptada; secreto único `<env>/<appId>`;
      líneas 16,18,19,20,22 (IAM `secretsmanager`), 41 coste 0,40 USD.
    - `0012-spring-cloud-aws-en-perfil-cloud.md`: Aceptada; SCA 3.3.1 starters
      `parameter-store` + `secrets-manager` (línea 16); línea 20 IAM `ssm:GetParametersByPath`.
    - `0022-iam-codeartifact-dos-roles.md`: Aceptada; "cero secretos de plataforma" (29-31);
      líneas 69-71 y 81 mencionan Secrets Manager; cita ADR-0023 (líneas 70).
  - .opencode (fuera de generador, dentro del workspace):
    - `.opencode/scripts/get-services-aws.ps1:98,212` (inventario `secretsmanager`).
    - `.opencode/scripts/delete-all-services-aws.ps1:9,162,263-267` (borrado definitivo).
  - Otros docs de obj-003/obj-004 (histórico): no modificar.
- Restricciones y verificaciones disponibles:
  - Solo lectura. No se ejecutaron comandos de shell.
  - Verificada existencia de ADR 0010, 0012, 0022. No existe ADR-0023.
  - `docs/adr/README.md` no lista 0010/0012/0022 (grep sin coincidencias).
  - No existe `docs/templates/explorer.md` en raíz; sí `docs/templates/deliverables/explorer.md`.
  - `questions.md` y `improvements.md` de obj-005 no existían: creados.
  - `checklist.md` de obj-005 no existe (pendiente según obj-005.md).
  - Tamaño JSON signing (límite 4 KB): no verificable en lectura; sin fuente local identificada.

## Incógnitas, límites y traspasos
- Incógnitas/supuestos:
  - Alcance de `.opencode/scripts/*`: no está en el alcance de obj-005 (Q2).
  - Alcance de `library/platform` y `library/common`: solo documentación (Q3).
  - `terraform-secrets-manager-variables.scriban` no leído (Q21).
  - ADR-0023 citado en ADR-0022 no existe (Q7, Q8).
  - Tamaño real del JSON de signing (Q12, Q43).
- Áreas no revisadas:
  - Contenido completo de `terraform-secrets-manager-variables.scriban`.
  - `docs/adr/0026`, `0025`, `0024`, `0020`, `0018`, `0016` (no son objetivo).
  - Contenido de `library/platform/terraform/*` (solo grep).
  - `generator` README/AGENTS más allá de `cloud/aws/AGENTS.md`.
- Traspasos:
  - architect: decidir ADR nuevo y actualización de 0010/0012/0022; resolver Q4-Q8, Q28, Q47.
  - developer-scriban: plantillas listadas en hallazgos (backend, cloud, flutter).
  - developer-terraform: `terraform-secrets*.scriban`, `terraform-lambda`, `terraform-pipeline`.
  - developer-powershell: `up.ps1`/`down.ps1` (cloud y flutter) y funciones `*SecretString`.
  - developer-java: `pom.scriban`, `application-cloud-properties.scriban`, test de contexto
    (solo si el usuario autoriza tocar test; obj-005 prohíbe crear/modificar tests).

## Confirmación
- Entendimiento confirmado por el usuario: `no; pendiente de respuestas a questions.md`

## Actualización 2026-10-10
- Cambio de alcance: keystore sale del JSON del secreto y pasa a S3
  (`keystore/{{APPLICATION_ID}}/keystore.jks`).
- Impacto: `up.ps1.scriban` (Flutter, líneas 282-344 y 545-547) y `codepipeline.yml.scriban`
  (líneas 53-62) requieren revisar la lógica de firma.
- Preguntas nuevas: Q56-Q62 en `questions.md`.

## Preguntas Grill-me
- Fuente única: `docs/deliverables/obj-005/questions.md` (55 preguntas, con recomendación).
- Todas abiertas. Recomendación no es acuerdo.
- Críticas: Q2, Q3, Q4, Q8, Q12, Q28, Q38, Q39, Q43.
- Lista:
  - Q1 Alcance generador vs /projects
  - Q2 Scripts `.opencode` fuera de alcance
  - Q3 `library/platform` solo documentación
  - Q4 Estado de ADR 0010
  - Q5 Qué actualizar en 0012 y 0022
  - Q6 Número del ADR nuevo
  - Q7 ADR-0023 citado y ausente
  - Q8 Corrección de referencia a ADR-0023
  - Q9 Índice `docs/adr/README.md`
  - Q10 Un SecureString por app y ruta
  - Q11 Claves kebab-case sin cambio
  - Q12 Medición real del JSON (4 KB)
  - Q13 Claves subscription y ai-api-key
  - Q14 Clave de cifrado `aws/ssm`
  - Q15 JSON > 4 KB: parar
  - Q16 Fuentes SCA del perfil cloud
  - Q17 Nombre del recurso Terraform
  - Q18 SecureString creado vacío
  - Q19 Valor fuera de tfstate
  - Q20 Renombrar módulo `secrets-manager`
  - Q21 `terraform-secrets-manager-variables`
  - Q22 `component.json`
  - Q23 Renombrar plantilla Terraform
  - Q24 Clave `aws/secretsmanager` en módulo
  - Q25 Lambda: `ssm:GetParameter`
  - Q26 CodeBuild: `ssm:PutParameter`
  - Q27 Lambda sin `PutParameter`
  - Q28 `kms:Decrypt`
  - Q29 `codepipeline.yml.scriban` Flutter
  - Q30 Siembra `put-parameter --overwrite`
  - Q31 `down.ps1`: `delete-parameter`
  - Q32 Quitar `restore-secret`
  - Q33 Flutter `get-parameter --with-decryption`
  - Q34 Flutter `-Sign` sin secreto
  - Q35 Flutter crea `android-signing`
  - Q36 Flutter `README.md.scriban`
  - Q37 Quitar starter sin cambiar versión
  - Q38 Filtro `aws-secretsmanager:` en test
  - Q39 Plantilla de test: confirmar
  - Q40 Comentarios Java con Secrets Manager
  - Q41 Postman "secreto"
  - Q42 Criterio de "ningún template"
  - Q43 Medición de 4 KB
  - Q44 Verificación de arranque cloud
  - Q45 Criterios nuevos
  - Q46 `checklist.md` antes de implementar
  - Q47 Coste 0 USD verificado
  - Q48 Autorización para implementar
  - Q49 Limpieza de secretos AWS
  - Q50 Migración de valores fuera
  - Q51 Entornos distintos de develop
  - Q52 Commit/push sin autorización
  - Q53 Título del ADR nuevo
  - Q54 Estado de 0010 tras ADR nuevo
  - Q55 Ficheros de `docs/adr` a crear o cambiar
