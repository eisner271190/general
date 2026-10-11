# Revisión

- Objetivo: `OBJ-005: Reemplazar AWS Secrets Manager por SSM Parameter Store SecureString`
- Agente: `Reviewer`
- Estado: `completo`
- Resumen: `Revisión de coherencia (fase 3, modo análisis). 4 bloqueantes, 6 altas, 10 medias.`
- Bloqueos: `ninguno de lectura. Requiere cambios en obj-005.md y decisiones del usuario (Q63-Q73).`
- Alcance/artefactos revisados:
  - `AGENTS.md` (raíz workspace).
  - `obj-005.md`, `questions.md` (Q1-Q62), `improvements.md` (D1-D12), `explorer.md`.
  - Plantilla `docs/templates/deliverables/reviewer.md` y `questions.md`.
  - Existencia de `docs/adr/` (0010, 0012, 0022; sin 0023 ni 0027).
  - No revisado: plantillas Scriban/Terraform reales (fuera de alcance de esta fase).
- Criterios: `AGENTS.md` (reglas duras, preguntas, output), criterios de `obj-005.md`,
  coherencia de respuestas con la decisión del 2026-10-10 (keystore fuera del JSON, S3).
- Autor de respuestas: no determinable. `questions.md` no registra fecha ni autor por respuesta.

## Clasificación de preguntas (sin cerrar ninguna)

- Respondidas, con decisión distinta a la recomendación (probables del usuario):
  - Q4, Q5, Q13, Q20, Q21, Q28, Q32, Q37, Q38, Q39, Q40, Q41, Q49, Q50.
  - Q56, Q57, Q59, Q60, Q61.
- Respondidas, coinciden con la recomendación (no distinguible si son del usuario):
  - Q1-Q3, Q10-Q12, Q14-Q19, Q22, Q24-Q27, Q29-Q31, Q33-Q36, Q42-Q47, Q51-Q55, Q58, Q62.
- Solo recomendadas, sin decisión del usuario:
  - Q23 (decidir con architect), Q53 (título ADR, "confirmar con architect").
  - Q29 tiene respuesta, pero el conflicto con Q59 sigue abierto (ver A4).
- Sin enunciado en `questions.md` (solo respuesta suelta):
  - Q6, Q7, Q8, Q9, Q10, Q11, Q39. Q7-Q8 se deducen de la respuesta a Q5.
- Pendientes explícitos:
  - Q48 (autorización por escrito para implementar).
  - Q56 (confirmar nombre de bucket), Q58 (confirmar SSE-S3 y bloqueo).
  - Q61 (subpregunta: versiones antiguas en `down.ps1`).
  - Q57 (origen del `.jks` si el secreto ya no existe).

## Hallazgos

Formato: severidad, evidencia, observado/esperado, criterio, recomendación, hecho/inferencia.

### Bloqueantes

- B1 · Keystore: posible pérdida y generación silenciosa de clave nueva.
  - Evidencia: Q49 (secretos eliminados), Q57 (subida "desde el secreto"), Q59 (genera si falta).
  - Observado: el `.jks` actual puede no existir; `up.ps1 -Sign` lo generaría de nuevo.
  - Esperado: no generar keystore nuevo si la app ya está publicada; fallar de forma explícita.
  - Criterio: obj-005 Riesgos (keystore no subido), Q61 (keystore perdido rompe Play).
  - Recomendación: resolver Q63 y Q64 antes de autorizar implementación.
  - Hecho: Q49 y Q57 lo indican. Inferencia: pérdida de firma en Play si se regenera.
- B2 · IAM S3: obj-005 da acceso a Lambda y CodeBuild, Q59 lo niega.
  - Evidencia: obj-005:28-29 y criterio :65 vs Q59 ("Lambda backend: cero permisos S3"; "CodeBuild
    cloud: sin acceso al keystore").
  - Observado/esperado: obj-005 debe reflejar Q59 (solo Flutter `up.ps1`/CodeBuild Flutter).
  - Criterio: consistencia obj-005 vs decisiones registradas.
  - Recomendación: corregir obj-005:28-29 y :65; confirmar con Q59 explícitamente.
  - Hecho.
- B3 · Q61 contradice la recomendación y el criterio de conservar.
  - Evidencia: Q61 respuesta "Borrar el objeto keystore en down.ps1"; rec "Conservar".
  - Observado: el usuario decide borrar; el riesgo queda registrado pero sin cerrar.
  - Esperado: confirmación explícita de borrado, con alcance (objeto actual o versiones).
  - Criterio: obj-005:33-34 ("según diseño") es ambiguo.
  - Recomendación: Q65; no implementar `down.ps1` keystore hasta cerrarlo.
  - Hecho.
- B4 · Criterio de 4 KB no cumplido en su forma.
  - Evidencia: obj-005:56 "cabe en 4 KB, medido"; Q43 "estimación no basta"; Q62 "210 bytes sin
    valores", respuesta "estimación basta".
  - Observado: no hay medición con valores reales; el 210 B es esqueleto.
  - Esperado: medición o estimación explícita con valores de longitud máxima (Q71).
  - Criterio: obj-005:56 y Requisitos :51.
  - Recomendación: aceptar la estimación solo si el usuario la confirma por escrito (Q71).
  - Hecho.

### Altos

- A1 · Bucket: "por app" frente a "por entorno".
  - Evidencia: obj-005:27 "bucket S3 para keystore por app"; Q56 "bucket por entorno".
  - Recomendación: Q68; corregir obj-005:27 según respuesta.
- A2 · Estado de preguntas contradictorio.
  - Evidencia: `questions.md` cabecera "respondidas (Q1-Q62)"; obj-005:20 y :85 "pendiente/abiertas";
    `explorer.md` "todas abiertas", "Confirmación: no".
  - Recomendación: actualizar estado solo tras confirmación del usuario; no cerrar por inercia.
- A3 · Trazabilidad rota en `questions.md`.
  - Evidencia: sin enunciado Q6-Q11 y Q39; Q5 cita Q7/Q8 sin entrada propia.
  - Recomendación: reconstruir enunciados (solo texto), sin cambiar respuestas.
- A4 · Permisos de CodeBuild Flutter incompletos.
  - Evidencia: Q29 (solo `ssm:GetParameter` + `kms:Decrypt`); Q35 y Q59 (crea android-signing y
    keystore si faltan).
  - Observado: falta `ssm:PutParameter` si el script siembra SSM; `kms:Decrypt` no está en criterio.
  - Recomendación: Q67.
  - Hecho: omisiones. Inferencia: se requiere `PutParameter` si el script escribe SSM.
- A5 · Lambda IAM: criterio incorrecto.
  - Evidencia: obj-005:64 "GetParameter y PutParameter" para Lambda y CodeBuild; Q27 "la Lambda solo
    lee"; Q25 pide también `GetParametersByPath`; Q28 pide `kms:Decrypt`.
  - Recomendación: reescribir criterio :64 por rol (Lambda read, CodeBuild put). Hecho.
- A6 · Versionado, cifrado y bloqueo público fuera de criterios.
  - Evidencia: Q56, Q58, Q60 respondidas; obj-005:63 solo "crea bucket".
  - Recomendación: añadir criterios (Q73). Hecho (criterio ausente).
- A7 · Exclusión de tests contradice AGENTS y alcance.
  - Evidencia: AGENTS "Nunca crees ni modifiques tests"; obj-005:35 incluye
    `application-context-test.scriban`; obj-005:45 excluye tests; Q39 "no cuenta como test".
  - Observado: obj-005 se contradice internamente y contra una regla dura.
  - Recomendación: Q72. Inferencia: la plantilla genera código de test.
- A8 · Obsolescencia de dependencias y riesgos tras Q49/Q57.
  - Evidencia: obj-005:86 (usuario limpia secretos), :98 (secretos no borrados), :99 (keystore viejo
    en el secreto), :40 ("usuario lo re-siembra").
  - Observado: el secreto ya no existe; el keystore debe recuperarse o regenerarse (ver B1).
  - Recomendación: reescribir esas filas tras Q63.

### Medios

- M1 · Coste "0 USD" incorrecto con S3. Q14 cita "obj-005.md:76" (línea de entregables, no coste).
  - obj-005:101-104 ya dice "S3 coste bajo, a verificar". Q47 pide verificar. Hecho.
- M2 · Q18 "SecureString sin valor" en Terraform.
  - Inferencia: `aws_ssm_parameter` exige `value` en el provider; requiere placeholder (Q69).
- M3 · Renombre de módulo (Q20 "secure-parameters") no aparece en obj-005 ni criterios. Hecho.
- M4 · Q29 dice "no está en obj-005"; obj-005:32 sí lo incluye. Hecho (dato obsoleto).
- M5 · Q3 "solo comentarios y README" frente a `library/platform/terraform/pipeline/main.tf:30`
  y `buildspecs/java-ci.yml:7`. Inferencia: pueden ser código; verificar antes de implementar.
- M6 · Criterio :66 solo cubre `secretsmanager:` y `aws secretsmanager`. Q40-Q41 piden también el
  texto "Secrets Manager". Hecho.
- M7 · Q15 afirma "no supera 4 KB; 20 % del límite" sin medición citada. Hecho.
- M8 · Entregables sin `integrator` (Q44 lo requiere para desplegar). Hecho.
- M9 · `checklist.md` y `use-cases.md` no existen. AGENTS exige `checklist.md`; Q46 la exige antes de
  implementar. Hecho.
- M10 · Q15 habla del "JSON actual" sin precisar si incluye `keystore-base64`. Confirmar. Hecho.

### Bajos / informativos

- I1 · `explorer.md` sin actualizar tras Q1-Q62 (ver A2). Hecho.
- I2 · `questions.md` no usa la sección "Respuestas del usuario" de la plantilla; respuestas inline
  sin fecha ni autor. Hecho.
- I3 · Hora UTC-5 no disponible en el entorno; registros sin hora exacta (AGENTS). Hecho.

## Revisado sin defectos y límites

- Sin defectos identificados:
  - Ruta SSM `/{{ENV}}/{{APP}}/secrets` (obj-005:49) coherente con Q10 y Q25.
  - Clave `aws/ssm` (Q14, Q24) sin contradicción.
  - `restore-secret` eliminado (Q32) coherente con SSM sin ventana de recuperación.
  - Lambda sin `PutParameter` (Q27) coherente con Lambda de solo lectura.
  - Límite de no implementar sin autorización (Q48, AGENTS) registrado como pendiente.
  - ADR 0010, 0012 y 0022 existen; ADR 0027 aún no existe (correcto, es nuevo).
- Límites/bloqueos:
  - No se leyeron plantillas Scriban/Terraform; solo documentación.
  - No se verificó AWS (precios, provider `aws_ssm_parameter`); son inferencias.
  - No se verificó tamaño real del JSON; no hay acceso al secreto ni fichero local.
  - Autoría de respuestas no determinable (sin fecha ni autor).
  - Hora exacta no disponible.

## Veredicto

- `requiere cambios`
- Motivo: B1-B4. No avanzar a implementación ni a usuario hasta cerrar Q63-Q73.
