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
