# Revisión

- Objetivo: `OBJ-005: Reemplazar AWS Secrets Manager por SSM Parameter Store SecureString`
- Agente: `Reviewer`
- Estado: `completo`
- Resumen: `Fase 3, solo análisis. 3 altas (estado documental, Q48, Q78), 5 medias, 6 bajas.
  Veredicto: requiere cambios.`
- Bloqueos: `ninguno de lectura. Sin acceso a plantillas Scriban/Terraform, ADR reales ni AWS.`
- Hora: `no disponible en el entorno (UTC-5); sin timestamp por paso (AGENTS).`
- Alcance/artefactos revisados:
  - `obj-005.md` (actualizado 19:33:23).
  - `questions.md` (Q1-Q86, sección Dependencias).
  - `checklist.md` (actualizado 19:33:23).
  - `improvements.md` (D1-D49).
  - `explorer.md` (solo para estado).
  - `AGENTS.md` raíz y plantilla `docs/templates/deliverables/reviewer.md`.
- Criterios:
  - `AGENTS.md`: fuente única `questions.md`; cada pregunta registrada; checklist; use-cases.
  - `checklist.md` L6: `[x]` solo con decisión explícita del usuario.
  - Coherencia de Q1-Q86 con `obj-005.md` y `checklist.md`.
- Límite de permisos:
  - El encargo pide registrar preguntas en `questions.md`; mi rol solo permite editar este informe.
  - No edité `questions.md`. Las propuestas están en la sección 5 para que el responsable las registre.
  - No edité `checklist.md`, `obj-005.md` ni `improvements.md`.

## 1. Verificación de `[x]` en questions.md

- Entradas `[x]` revisadas: 25 (Q63-Q86; Q74 aparece dos veces).
- Con respuesta explícita del usuario (`✅ Respuesta` o `Decisión del usuario`): 25 de 25.
- Q1-Q62 no llevan `[x]`; todas tienen `✅ Respuesta`.
  - Q12: la respuesta repite la recomendación; sin cierre explícito.
  - Q23, Q47, Q53: delegadas a architect; no son decisión del usuario.
- Líneas `Decisión del usuario` no tienen fecha ni autor; se aceptó el `✅` como respuesta.
- Hecho: Q48 responde el criterio ("tras cerrar...") y "no autorizar todavía" (L167).

## 2. Hallazgos priorizados

### Altos

- H1 · alta · Estado de dudas falso en `questions.md` y `checklist.md`.
  - Evidencia: `questions.md` L5 "D41–D49, todas resueltas"; `checklist.md` L5 "Sin preguntas
    nuevas abiertas".
  - Observado: `improvements.md` D41, D42, D43, D44, D46 y D47 siguen con "Acción: confirmar/definir"
    sin cierre (L181-205).
  - Esperado: dudas abiertas registradas en `questions.md`; estado veraz.
  - Criterio: AGENTS "Cada pregunta se agrega a questions.md"; fuente única.
  - Recomendación: corregir L5 y `checklist.md` L5; registrar D41-D47 (sección 5).
  - Hecho: texto y líneas citadas. Inferencia: ninguna.

- H2 · alta · Q48 no cumple su precondición.
  - Evidencia: `questions.md` L166 "Tras cerrar questions.md y checklist.md"; `obj-005.md` L162.
  - Observado: quedan abiertos D41-D47, Q23/Q47/Q53 (architect) y ítems `[ ]` de implementación.
  - Esperado: no pedir autorización hasta cerrar la precondición.
  - Criterio: AGENTS "No se puede iniciar la implementación sin la autorización explícita".
  - Recomendación: no solicitar autorización; cerrar pendientes; definir "checklist completo" (Q87).
  - Hecho: la precondición está escrita. Inferencia: que el checklist no está completo (depende
    de la definición en Q87).

- H3 · alta · Contradicción sobre publicación en Play (Q78).
  - Evidencia: `questions.md` L291-292 "Asumir que no está publicada y continuar";
    `checklist.md` L168 "confirmar antes de subir a Play"; `obj-005.md` L169 "Usuario confirma".
  - Observado: el checklist exige confirmación; la respuesta del usuario asume y continúa.
  - Esperado: una sola regla alineada con Q78.
  - Criterio: consistencia de decisiones del usuario.
  - Recomendación: alinear checklist y `obj-005.md` L169 con Q78; si la duda sigue, reabrir Q78.
  - Hecho: textos citados. Inferencia: riesgo de bloqueo de actualizaciones en Play.

### Medios

- H4 · media · `[x]` en checklist con inferencias o estado de implementación.
  - Evidencia: `checklist.md` L120 "(inferencia de Q75; confirmar, D37)"; L143 "≈0,005 USD/mes";
    L144 "Documentación... actualizada"; L149 "(Q73, D23)".
  - Observado: `[x]` sin decisión explícita (L6 lo prohíbe).
  - Esperado: `[ ]` o redacción como decisión. L149 debería citar Q44, no Q73.
  - Recomendación: cambiar a `[ ]` o reformular; corregir la cita de L149.
  - Hecho: texto citado. Inferencia: ninguna.

- H5 · media · Respuestas contradictorias o sustituidas sin marca.
  - Evidencia:
    - Q71 L257-260: "No, usar el JSON real" y "basta la estimación" en la misma entrada.
    - Q74 L269-273: "aprobada" sin marca; Q75 L282 la sustituye.
    - Q61 L220: "se debe documentar backup/restore"; Q86 L332-335 lo elimina.
    - Q63 L232: "Debe registrarse backup"; Q83 L324 lo sustituye.
    - Q2 L12-14: sin marca; Q84 L320 la sustituye.
  - Observado: el lector puede tomar la respuesta vieja.
  - Esperado: cada entrada sustituida lleva "Sustituida por Qnn".
  - Recomendación: marcar Q2, Q61, Q63, Q71 y Q74 (primera entrada) con su sustituta.
  - Hecho: textos citados.

- H6 · media · Afirmaciones de tamaño sin medición.
  - Evidencia: Q15 L50 "No supera 4 KB; 20 %"; Q70 L256 "usar el JSON real para validar el 4 KB";
    `obj-005.md` L172 "parar"; Q76 L285 "Sin medición".
  - Observado: Q15 y Q70 afirman o piden medir; Q76 dice que no se mide.
  - Esperado: una sola regla (Q76).
  - Recomendación: marcar Q15 como sustituida por Q76; corregir el texto de Q70.
  - Hecho: textos citados. Inferencia: el 20 % no tiene fuente.

- H7 · media · Pendientes técnicos fuera de checklist y questions.
  - Evidencia: `obj-005.md` L77-81 "Verificar antes de implementar `terraform/pipeline/main.tf:30`
    y `buildspecs/java-ci.yml:7`"; L92 "vaciado previo como el bucket de buildspecs"; L94
    "pendiente de confirmar".
  - Observado: no están en `checklist.md` ni en `questions.md`.
  - Esperado: ítem `[ ]` en checklist y dudas registradas.
  - Recomendación: añadir ítems `[ ]`; D42 y la verificación de M5 van a la sección 5.
  - Hecho: textos citados. Inferencia: M5 puede ser código, no comentario.

- H8 · media · Falta `use-cases.md`.
  - Evidencia: listado de `docs/deliverables/obj-005/` sin `use-cases.md`.
  - Observado: no existe.
  - Esperado: `use-cases.md` con casos de prueba (AGENTS "Se deben ir agregando").
  - Criterio: AGENTS, Durante el proceso.
  - Recomendación: crearlo antes de la siguiente revisión.
  - Hecho.

### Bajos

- H9 · baja · Q64 ambiguo: "Generar siempre".
  - Evidencia: `questions.md` L236 "Generar siempre, como hoy"; Q59 L209 "si falta el objeto".
  - Recomendación: aclarar con Q88.
  - Inferencia: "siempre" puede leerse como regenerar aunque exista.

- H10 · baja · Referencias de línea obsoletas en `questions.md`.
  - Evidencia: Q14 L46 "obj-005.md:76"; Q33 L113 "obj-005.md:17"; Q51 L175 "obj-005.md:25";
    Q68 L249 "obj-005:27"; Q77 L287 "obj-005:31"; Q29 L96 "no está en obj-005".
  - Recomendación: retirar las líneas o marcarlas como históricas.
  - Hecho.

- H11 · baja · Residuos en encabezado, Dependencias y "⚠️".
  - Evidencia:
    - `questions.md` L3 "Q1–Q85" (falta Q86).
    - L339-344 "bloquea" para Q75-Q80 ya resueltas.
    - L223 "Queda pendiente solo el tamaño".
    - L100, L199, L203 avisos "⚠️" ya resueltos por Q59, Q61 y Q63.
  - Recomendación: actualizar el texto o marcar como resuelto.

- H12 · baja · Ejemplo de clave incorrecto.
  - Evidencia: Q11 L307 "api-key"; `obj-005.md` L20 y Q13 usan `ai-api-key`.
  - Recomendación: corregir el ejemplo de Q11 en la trazabilidad.

- H13 · baja · Criterios y checklist no alineados.
  - Evidencia: subida del keystore tras despliegue (Q57) está en `checklist.md` L105 y en
    `obj-005.md` riesgos L173, pero no en criterios (L118-145). Q12 y Q15 no aparecen en checklist.
  - Criterio: "Si se identifican nuevos criterios... agregarlos".
  - Recomendación: añadir el criterio y mencionar Q12 y Q15 en el checklist.

- H14 · baja · `explorer.md` desactualizado.
  - Evidencia: L13 "Q1-Q55 pendiente"; L93 "Q2" abierta; L123 "Todas abiertas".
  - Criterio: `improvements.md` D40.
  - Recomendación: responsable del explorer lo actualiza; no es de esta revisión.

## 3. Elementos sin defecto

- Ruta `/{{ENV}}/{{APP}}/secrets`, clave `aws/ssm` y bucket `${var.project_name}-keystore-...`:
  coherentes en `obj-005.md` y `checklist.md` (Q10, Q14, Q56, Q68).
- Lambda solo lectura sin `PutParameter` ni S3 (Q27, Q59, Q66), igual en `obj-005.md` y checklist.
- `restore-secret` eliminado (Q32) y `delete-parameter` (Q31): coherentes.
- Q48 es el último punto en la sección 4 y en la sección 5 del checklist.
- Q1-Q86 están todas en `questions.md`; el checklist cita Q1-Q86 salvo Q12, Q15 y Q43.
- Q82, Q84, Q85 y Q86 coinciden en `obj-005.md` (L90-92, L181-182) y en el checklist.
- 25 de 25 entradas `[x]` tienen respuesta explícita del usuario.

## 4. Límites

- No leí plantillas Scriban/Terraform ni los ADR 0010, 0012, 0022 en esta fase.
- No verifiqué AWS: precios, provider `aws_ssm_parameter` ni tamaños.
- No puedo confirmar autoría ni fecha de las líneas "Decisión del usuario".
- Hora UTC-5 no disponible; sin timestamps por paso.
- No cerré ninguna pregunta.

## 5. Preguntas propuestas (para registrar en questions.md por el responsable)

- Q87 ¿"checklist completo" (Q46, Q48) = ítems definidos y trazados, con `[ ]` solo para
  implementación y verificación? Rec: sí.
- Q88 ¿Q64 "generar siempre" = generar keystore solo si falta el objeto en S3? Rec: sí; nunca
  sobrescribir un objeto existente.
- Q89 ¿Qué `down.ps1` borra el bucket keystore: cloud (`down.ps1.scriban`) o Flutter? Rec: cloud (D47).
- Q90 ¿Orden de borrado: CLI (objeto, versiones, bucket) antes o después de `terraform destroy`,
  y `state rm`? Rec: CLI antes, con purga de versiones como delete-all; architect confirma (D41, D42).
- Q91 ¿`delete-all-services-aws.ps1` borra el bucket keystore de todos los entornos o solo
  `develop`? Rec: solo `develop` (Q51, D43).
- Q92 ¿Qué muestra `get-services-aws.ps1` del bucket? Rec: existencia, objetos, versiones, SSE y
  bloqueo público (D44).
- Q93 ¿Cómo obtienen los scripts CLI el nombre del bucket sin hardcodearlo? Rec: parámetro de
  entorno con nombre derivado de `project_name`, o salida de Terraform; architect confirma (D46).

## 6. Acciones sugeridas al responsable

- Corregir estado en `questions.md` L3, L5 y en `checklist.md` L4-L5 (H1, H2).
- Alinear Q78 en `checklist.md` L168 y `obj-005.md` L169 (H3).
- Marcar sustituciones en Q2, Q15, Q61, Q63, Q71 y Q74 (H5, H6).
- Crear `use-cases.md` (H8).
- Registrar Q87-Q93 y pasar las pendientes técnicas al checklist (H7).

## Veredicto

- `requiere cambios`
- Motivo: H1-H3 (altas). No avanzar al usuario ni solicitar autorización (Q48) hasta cerrar H1-H3.

## Fase 4 (documental) · 2026-10-11 02:48:01 (UTC-5)

- Agente: reviewer. Solo documentación; sin producto, tests ni work items.
- Atendidos: H1 (D41/D42 abiertas; D43-D47 cerradas), H3 (Q78 alineado), H5/H6 (sustituciones
  marcadas), H7 (pendientes M5 en checklist), H8 (`use-cases.md`), H9 (Q88), H11 (cabeceras,
  Dependencias, avisos ⚠️).
- Archivos modificados: `obj-005.md`, `checklist.md`, `questions.md`, `improvements.md`,
  `use-cases.md` (nuevo), `reviewer.md` (esta sección).
- Q87-Q93 registradas y reflejadas en `obj-005.md` y `checklist.md`.
- Q48 sigue abierta; sin autorización para implementar.
- No actualizado: `explorer.md` (H14; decisión del orquestador).

## Revisión final · OBJ-005 · 2026-10-12 (hora no disponible; sin timestamp por paso)

- Agente: reviewer. Solo lectura y este informe. Sin producto, tests ni commits.
- Lectura: `AGENTS.md` (raíz, generator, cloud/aws), `obj-005.md`, `questions.md`,
  `checklist.md`, `architect.md`, `developer-*.md`, `integrator*.md`, `tester.md`,
  `use-cases.md`, `improvements.md`.
- Límite: no leí el contenido completo de cada plantilla Flutter/backend; verifiqué
  por grep y por existencia. No verifiqué AWS ni ejecuté nada.
- Límite de permisos: no edité `questions.md`. Las dudas nuevas van en la sección 5.

## Veredicto final

- `requiere cambios`
- Motivo: B1 (autorización de implementación no verificable) y A1-A4 (altas).
- No avanzar al usuario hasta resolver B1 y las altas.

## Verificaciones (punto a punto)

1. Restos de Secrets Manager: PASA (con matices).
   - `generator/`: 0 coincidencias (`secretsmanager`, `secrets-manager`, `keystore-base64`, etc.).
   - `.opencode/scripts/`: 0 coincidencias. Q99 está limpiado en el código.
   - ADR `0010`: estado `Sustituida por ADR-0027` y cabecera correctas. El cuerpo conserva
     menciones históricas (aceptable).
   - ADR `0012`: estado y cita a ADR-0027 presentes. Solo menciones históricas.
   - ADR `0022`: `ADR-0023` eliminado (cita sustituida por ADR-0027). Quedan líneas 29 y 81
     con Secrets Manager para secretos de plataforma (developer-adr las recomienda dejar).
   - ADR `0027`: existe, estado `Aceptada` (ver A6).
2. `[x]` en `questions.md` sin decisión explícita del usuario: NO PASA.
   - Q87-Q93, Q101, Q102, Q82-Q86: "Opción N del usuario" o "Confirmado por el usuario". OK.
   - Q94, Q95, Q96, Q97, Q98: "Según la recomendación del usuario". Es la recomendación de
     un subagente adoptada sin que conste que el usuario la eligiera (A5).
   - Q100: la respuesta la redacta el documento ("ADR-0027 Aceptada..."). No es del usuario (A5).
   - Q23, Q47, Q53 y D41/D42: cerrados por architect, no por el usuario (`D39`). Constan
     como `[x]` en `checklist.md` (A5).
   - Q63-Q81: `✅ Respuesta` sin fecha ni autor (trazabilidad débil; media).
3. Coherencia obj-005 / checklist / questions: PARCIAL.
   - Cifra ≈ 300 bytes: OK en `obj-005.md` (L118, L126), `checklist.md` (L13), Q100, ADR-0027.
   - `use-cases.md`: falta TC-02 (salta de TC-01 a TC-03). Q100 pedía corregirlo. NO PASA.
   - Q99: el texto de la entrada aún dice "Recomiendo: dejarlos" (L428-429). La respuesta
     dice "limpiar". La respuesta se aplicó; el texto debe limpiarse. Checklist L254 sigue `[ ]`.
   - Q102: APLICADO. `get-services-aws.ps1` no tiene `-Simple`; sí `-Detail` y `-AsJson`.
   - Q76 no marca "sustituida parcialmente por Q100" (baja).
4. Checklist `[x]` con evidencia y `[ ]` en AWS: PARCIAL.
   - Desfasados (evidencia presente y marcados `[ ]`): ADR-0027 (L28, L143), ADR-0010 (L144),
     ADR-0012/0022 (L146-149), M5 (L166; TC-22 lo verifica como comentarios), excepción
     de scripts (L38), Q99 (L254).
   - Verificación AWS con evidencia parcial (integrator-up): bucket con versionado y bloqueo
     público, SecureString `/develop/com.quizsmart.app/secrets` existe, objeto keystore existe.
     Quedan `[ ]` por falta de evidencia de SSE, de metadato `sha256` y de descarga/hash (TC-03,
     TC-05, TC-06). Correcto mantenerlos `[ ]`.
   - Implementación `[x]` sin decisión del usuario: la línea 6 del checklist dice `[x]` solo
     para decisiones. Hay ~40 `[x]` de implementación (contradicción de regla, A7).
5. Plantillas en `component.json` vs disco: PASA.
   - `cloud/aws`: las 27 plantillas declaradas en `files` existen. No hay huérfanas en
     `cloud/aws/templates`. `terraform-secrets-manager*` ya no existe (renombrada).
   - Backend: las `terraform-*` duplicadas (12) existen y no están registradas; es intencional
     según `cloud/aws/AGENTS.md`. No se consideran huérfanas (informativa).
   - Flutter: `codepipeline.yml`, `up.ps1`, `down.ps1` y `README.md` registrados y existentes.
   - `component.json` cloud usa `{{MICROSERVICE_NAME}}` en claves; `cloud/aws/AGENTS.md` dice
     que no debe ir en nombres de archivo. Preexistente, fuera de obj-005 (informativa).

## Hallazgos priorizados

### B1 · bloqueante · Autorización de implementación no verificable

- Evidencia:
  - `questions.md` L3: "Q48 autorizada por escrito (2026-10-11)".
  - `questions.md` L175: "Decisión del usuario: no autorizar todavía; mantener análisis".
  - `checklist.md` L229 y L259: Q48 `[ ]`. `obj-005.md` L5 "sin autorización para implementar".
  - `developer-scriban.md` L4: "Q48 concedida por el coordinador". Lo mismo en `developer-powershell.md`.
  - `integrator-up.md` L5 y `developer-powershell-default.md` L3: "autorizado por el usuario".
- Observado: se implementó generador, scripts y ADR, y se ejecutaron AWS (borrado, `up -Fast`)
  sin autorización escrita del usuario en `questions.md`. Los registros se contradicen.
- Criterio: AGENTS "No se puede iniciar la implementación sin autorización explícita".
- Recomendación: pedir al usuario confirmación escrita y fechada. Registrarla en `questions.md`
  como única fuente. Corregir la cabecera de `questions.md` y `obj-005.md` L5.
- Hecho: textos citados. Inferencia: que la autorización existió de palabra (no verificable).

### A1 · alta · Acciones destructivas en AWS fuera del alcance registrado

- Evidencia: `integrator.md` ejecuta `delete-all-services-aws.ps1 -Force`: 70 de 72 recursos
  borrados. Incluye plataforma (`library/platform`), CodeArtifact (4 paquetes `com.epc.common`),
  buildspecs, roles IAM y el secreto `develop/com.quizsmart.app`.
- Esperado: `obj-005.md` excluye "Entornos distintos de develop" (Q51) y no menciona borrar
  plataforma. Q91 solo amplía los buckets keystore a todos los entornos.
- Observado: el alcance "72 recursos" se confirma en `integrator.md` L74, no en `questions.md`.
- Recomendación: registrar en `questions.md` la decisión del usuario sobre el alcance del borrado
  y actualizar `obj-005.md` (Q51, Q91). Revisar si hace falta reconstruir `common` (ya hecho).
- Hecho: texto citado. Inferencia: el usuario lo confirmó en conversación (no verificable).

### A2 · alta · Q49 contradicha por el hecho registrado

- Evidencia: `questions.md` L178 "Ya no existen; el usuario los eliminó manualmente".
  `integrator.md` L115-116: el inventario encontró vivo `develop/com.quizsmart.app` y DELETEALL lo
  borró. `obj-005.md` L203-204: "Secretos AWS no borrados: resuelto por el usuario (Q49)".
- Recomendación: corregir Q49 y los riesgos de `obj-005.md` con el hecho real.

### A3 · alta · Cambios en scripts fuera de la excepción registrada

- Evidencia: la excepción (`obj-005.md` L93-98, Q84) cubre solo el bucket keystore. En
  `delete-all-services-aws.ps1`, `developer-powershell-fix.md` y `fix2.md` añadieron:
  - `--targets` cambiado a `--ids` en EventBridge (bug que causó fallo en integrator).
  - Barrido SNS que desuscribe suscripciones de la cuenta por `TopicArn -like "*:$TopicName"`.
  En `get-services-aws.ps1`, `developer-powershell-default.md` cambió la salida por defecto a
  simple y `-Simple` por `-Detail`.
- Criterio: `obj-005.md` L121-122 "solo modificar... excepción"; Q92 "solo existencia".
- Observado: no hay pregunta ni decisión en `questions.md` para el barrido SNS ni para la
  salida simple por defecto. El barrido SNS es destructivo y sin pruebas (solo `-WhatIf` con 0
  suscripciones).
- Recomendación: registrar decisiones o revertir. Documentar en `obj-005.md` el alcance real.

### A4 · alta · Informes obligatorios ausentes

- Evidencia: `obj-005.md` L165 y L168 registran `developer-terraform.md` y `developer-java.md`.
  No existen en `docs/deliverables/obj-005/`. El cambio Terraform y el de Java sí se aplicaron
  (`tester.md` valida plantillas y módulos).
- Criterio: AGENTS "Obligatorio crear un informe... `DELIVERABLES/obj-NNN/{subagent}.md`".
- Recomendación: crear los informes faltantes (lo hace el responsable), o justificar su ausencia.
- Hecho: lista de ficheros. Inferencia: el trabajo Terraform/Java lo hizo otro agente (no consta).

### A5 · alta · `[x]` sin decisión explícita del usuario

- Evidencia:
  - Q94-Q98: "Según la recomendación del usuario". No hay decisión del usuario registrada.
  - Q100: la respuesta la escribe el documento ("ADR-0027 Aceptada..."), no el usuario.
  - Q23, Q47, Q53, D41, D42: decisiones de architect, marcadas `[x]` en `checklist.md`
    (L212-213). `improvements.md` D39 dice que no son decisiones del usuario.
- Criterio: `checklist.md` L6 "[x] solo decisión explícita del usuario".
- Recomendación: marcar `[ ]` (o "propuesta de architect") hasta confirmación del usuario.
  Confirmar Q94-Q98 y Q100 con el usuario.

### A6 · alta · ADR-0027 en estado `Aceptada` sin aprobación registrada

- Evidencia: `docs/adr/0027-...md` L4 `Aceptada`. `developer-adr.md` Dudas (L39-40): "`questions.md`
  no registra aprobación explícita del ADR por el usuario". Q100 lo cita como si fuera decisión.
- Recomendación: confirmar con el usuario antes de dar el ADR por vigente.

### A7 · alta · Checklist y estado documental desfasados

- `obj-005.md` L3-5: "Estado: borrador... sin autorización" (desfasado).
- `obj-005.md` tabla de entregables (L161-173): `developer-scriban`, `developer-terraform`,
  `developer-java`, `integrator`, `adr` como "pendiente" (desfasado).
- `questions.md` L5 "Abiertas: ninguna"; L3 "Q1–Q93 resueltas" con Q94-Q102 fuera del rango.
- `checklist.md` L254 Q99 `[ ]`. L143, L146-149 ADR `[ ]` (desfasado). L166 M5 `[ ]`.
- `checklist.md` L6 regla de `[x]` contradicha por ~40 `[x]` de implementación.
- Recomendación: un responsable actualiza cabeceras y estados en una pasada.

### M1 · media · `use-cases.md` sin TC-02 y TC-01 con texto duplicado

- `use-cases.md` salta de TC-01 a TC-03. TC-01 tiene dos líneas "Resultado: pendiente" (L13-14).
- `tester.md` y `checklist.md` L234-235 citan TC-02 con 113/294 bytes y "210" (desfasado con Q100).
- Recomendación: restaurar TC-02 con ≈ 300 bytes (Q100) y marcar resultados reales de TC-01.

### M2 · media · Q99 con texto contradictorio

- `questions.md` L428-431: "Recomiendo: dejarlos..." y "Si se limpian..." tras la respuesta "limpiar".
- Recomendación: retirar las líneas de recomendación obsoletas.

### M3 · media · Trazabilidad débil de respuestas

- Q63-Q81 y Q94-Q100: `✅ Respuesta` sin fecha ni autor. "Decisión del usuario" sin fecha.
- Q74 duplicada. Q71 con dos respuestas (sustitución marcada, pero Q71 L257-260 conserva ambas).
- Recomendación: añadir fecha y fuente a cada decisión del usuario.

### M4 · media · Inventario de integrator no alineado con la realidad

- `integrator-up.md` L108-115: la ruta SecureString real es `/develop/com.quizsmart.app/secrets`.
  El brief decía `.../quizapi/secrets`. Coherente con `obj-005.md` (`/{{ENV}}/{{APP}}/secrets`).
- Recomendación: confirmar que ningún consumidor espera `quizapi/secrets` (Postman, Lambda).
- Hecho: la diferencia viene del brief, no del código. Inferencia: sin impacto (no verificado).

### B2 · baja · Hitos de tests y verificación residual

- DELETEALL se corrigió (`--ids`) después de la ejecución AWS. Sin prueba de reejecución.
- `terraform fmt` marca 5 ficheros preexistentes en `quizapi/` (fuera de obj-005; informativa).
- `up.ps1` (raíz) y `UPDATEALL` quedan sin destino tras DELETELOCAL (informativa; regenerar).

## Elementos sin defecto (verificados)

- Ruta SSM `/{{ENV}}/{{APP}}/secrets`, clave `aws/ssm` y bucket `${var.project_name}-keystore-...`.
- Generador: 0 restos de Secrets Manager. ADR-0023 eliminado de ADR-0022.
- `component.json` cloud: 27 plantillas declaradas existentes. Sin huérfanas en `cloud/aws`.
- Q102 aplicado. Q101 aplicado (`-AsJson` implica detalle completo).
- Bucket keystore en AWS (integrator-up): versionado y bloqueo público activos.
- Parámetro SecureString `/develop/com.quizsmart.app/secrets` existe (tipo SecureString).

## Límites de esta revisión

- No validé en AWS ni ejecuté `terraform`, PowerShell ni el generador.
- No leí el contenido íntegro de todas las plantillas backend/Flutter (solo grep y existencia).
- Hora UTC-5 no disponible: sin timestamps por paso.
- No pude verificar la autorización del usuario (B1): solo documentos.

## 5. Dudas nuevas (para registrar en questions.md por el responsable)

- Q103 ¿Confirmas por escrito la autorización de implementación de OBJ-005 (Q48)?
  Rec: sí; fecha y alcance. Hoy `questions.md` L3 y L175 se contradicen.
- Q104 ¿El borrado `delete-all -Force` (70/72 recursos, incluida plataforma) fue confirmado
  por ti? Rec: registrarlo en `questions.md` y actualizar Q51/Q91 en `obj-005.md`.
- Q105 ¿Aceptas el barrido SNS de `delete-all-services-aws.ps1` (desuscribe por nombre de topic)?
  Rec: sí con prueba `-WhatIf` documentada; si no, revertir.
- Q106 ¿Aceptas la salida simple por defecto de `get-services-aws.ps1` (`-Detail` para completo)?
  Rec: sí; registrar la decisión (Q101/Q102 no la cubren).
- Q107 ¿Q94-Q98 y Q100 son decisiones tuyas? Rec: confirmar o reabrir (las marcas dicen
  "según la recomendación").
- Q108 ¿Apruebas `ADR-0027` como `Aceptada`? Rec: sí, con confirmación explícita.
- Q109 ¿Los informes de `developer-terraform` y `developer-java` se crean o se retiran de la
  tabla? Rec: crearlos (AGENTS obliga) con el contenido real.
- Q110 ¿Confirmas que ningún consumidor espera `.../quizapi/secrets` (brief de integrator)?
  Rec: sí; la ruta canónica es `/develop/com.quizsmart.app/secrets`.

## Veredicto (resumen)

- `requiere cambios`.
- Bloqueantes: B1 (autorización). Altas: A1-A7.
- Cuando B1 y A1-A7 estén resueltos, volver a revisar para `aprobado con observaciones`.
