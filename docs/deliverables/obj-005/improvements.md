# Mejoras y dudas OBJ-005

- Registro de dudas: causa y tipo de problema, para no repetirlas.

## Dudas
- **D1** ADR-0023 citado en ADR-0022 (línea 70) no existe en `docs/adr`.
  - Causa: referencia a ADR no creado o renumerado.
  - Tipo: documentación, referencia rota.
  - Acción: Q7 y Q8.
- **D2** `docs/templates/explorer.md` no existe en raíz; existe en `docs/templates/deliverables/`.
  - Causa: ruta de template no homogénea.
  - Tipo: plantilla, ruta.
  - Acción: usar `deliverables/explorer.md`; confirmar convención.
- **D3** `docs/adr/README.md` no lista ADR 0010, 0012 ni 0022.
  - Causa: índice no mantenido o sin esas entradas.
  - Tipo: documentación, índice.
  - Acción: Q9.
- **D4** obj-005 pide revisar `application-context-test.scriban`, que es plantilla de test.
  - Causa: conflicto entre alcance y regla "no crear ni modificar tests".
  - Tipo: alcance, regla ambigua.
  - Acción: Q38 y Q39.
- **D5** obj-005 no menciona `ai-api-key` ni claves `subscription-*` sembradas por cloud up.ps1.
  - Causa: lista de claves incompleta en obj-005.
  - Tipo: requisito incompleto.
  - Acción: Q13.
- **D6** obj-005 no menciona `codepipeline.yml.scriban` (Flutter) con `secretsmanager`.
  - Causa: alcance sin inventario completo de IAM.
  - Tipo: alcance incompleto.
  - Acción: Q29.
- **D7** obj-005 no menciona `.opencode/scripts/*` ni comentarios Java con Secrets Manager.
  - Causa: inventario de referencias no hecho antes del objetivo.
  - Tipo: alcance, criterio de búsqueda ambiguo.
  - Acción: Q2, Q40, Q42.
- **D8** El tamaño del JSON de signing (4 KB) no es verificable en lectura.
  - Causa: sin acceso al secreto real ni fichero local con el JSON.
  - Tipo: dato faltante.
  - Acción: Q12, Q43.
- **D9** `terraform-secrets-manager-variables.scriban` no leído.
  - Causa: fuera de la búsqueda por palabras clave.
  - Tipo: lectura pendiente.
  - Acción: Q21.

## Mejoras de proceso
- Hacer el inventario de referencias con grep antes de redactar el alcance.
- Incluir en el alcance todos los ficheros que contengan la palabra clave, o excluirlos explícitamente.
- Definir si los comentarios cuentan para el criterio "ningún template referencia" (Q42).

## Cambio 2026-10-10
- **D10** Ruta `keystore/{{APPLICATION_ID}}/keystore.jks` escrita como "bucket" en la petición.
  - Causa: confusión entre nombre de bucket y clave de objeto en S3.
  - Tipo: requisito ambiguo.
  - Acción: Q56.
- **D11** S3 no estaba en el alcance original de obj-005.
  - Causa: decisión de almacenamiento tomada después del borrador.
  - Tipo: alcance cambiado.
  - Acción: obj-005.md actualizado; Q57-Q61.
- **D12** El keystore actual dentro del secreto debe migrarse a S3 y luego borrarse.
  - Causa: migración no contemplada; obj-005 excluía migración de valores.
  - Tipo: alcance incompleto (dato sensible duplicado).
  - Acción: Q57.
