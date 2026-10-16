# OBJ-005 · developer-java

- Objetivo: `OBJ-005: Reemplazar AWS Secrets Manager por SSM Parameter Store SecureString`
- Agente: `developer-java` (informe creado por decisión del usuario, Q109)
- Estado: `documentado; cambios registrados por developer-scriban; verificación de tester`
- Fecha de registro: `2026-10-12`
- Fuente: solo lo registrado en `developer-scriban.md` y `tester.md`.

## Resumen

- Los cambios Java los aplicó `developer-scriban` en plantillas Spring del generador.
- No existe informe Java previo: este documento solo recoge lo ya registrado.
- Sin commit ni push. Sin tests creados. Solo el filtro de `application-context-test` (Q72).

## Cambios Java / Spring (`components/backend/spring-boot-3.5.16/templates/`)

- `application-cloud-properties.scriban`:
  - Fuera `aws-secretsmanager:`.
  - Importa el SecureString como `aws-parameterstore:/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/secrets`
    (Q16).
- `pom.scriban`:
  - Fuera `spring-cloud-aws-starter-secrets-manager`.
  - Se mantiene `spring-cloud-aws-starter-parameter-store` y la versión de SCA (Q37).
- `ai-properties.scriban:20`: comentario Parameter Store (SecureString) en lugar de
  Secrets Manager (Q40).
- `openrouter-adapter.scriban:31`: mismo cambio de comentario (Q40).
- `parameter-properties.scriban:19` y `:95-97`:
  - Comentarios actualizados (Q40).
  - La heurística del prefijo `/` documenta la ruta `/env/app/secrets`.
- `application-context-test.scriban:74-76` (excepción autorizada, Q72, Q38, Q39):
  - Filtro pasa a `aws-parameterstore:` + `name.contains("/secrets")` +
    `type.contains("ParameterStore")`.
  - Se elimina `aws-secretsmanager:` y `type.contains("SecretsManager")`.
  - Ningún otro cambio en el fichero.
- `postman-collection.scriban:4`: `ai-api-key` se siembra en el SecureString de
  `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/secrets` (Q41). Línea 1223 sin cambios.

## Decisiones abiertas de Java (Q94, Q95)

- Q94: `aws-parameterstore:` con ruta exacta carga el parámetro, pero SCA no lo descifra sin
  `with-decryption`.
  - Respuesta del usuario: verificar en arranque cloud (tester).
  - Si no descifra: `ParameterStorePropertySource` con `withDecryption=true`.
- Q95: `name.contains("/secrets")` es más amplio que el filtro original.
  - Respuesta del usuario: suficiente; ajustar si el test falla.

## Verificación (tester, `tester.md`)

- `pom.xml` generado conserva `spring-cloud-aws-starter-parameter-store` y no trae
  `secrets-manager` (TC-09 OK).
- `application-cloud-properties.yaml` generado:
  - `spring.config.import=aws-parameterstore:/develop/com.quizsmart.app/quizapi/,`
    `aws-parameterstore:/develop/com.quizsmart.app/secrets`.
- Grep de `secretsmanager|Secrets Manager` en `generator/`: 0 coincidencias.
- Generación en sandbox fuera de `/projects`: `OK=1`. Sin cambios en el repositorio.
- Postman: placeholders `{{baseUrl}}`, `{{token}}`, `{{username}}` son variables de Postman, no
  Scriban. Correcto.
- Parseo de JSON de Postman OK tras render.
- Diff de `application-context-test` limitado al filtro (Q72) según `developer-scriban.md`.

## Pendientes

- Q94: verificar en arranque cloud que el SecureString se descifra (integrator y tester).
- Q95: confirmar que el filtro de test no falla con el arranque real.
- Verificación de arranque cloud con AWS (Q44): integrator despliega, tester verifica.
- Revisar que el filtro de `application-context-test` no requiere más cambios tras el arranque.
- Q99 (fuera de Java): quedan 4 restos de Secrets Manager en `.opencode/scripts/`.
  - Respuesta del usuario: limpiar dentro de obj-005. Sin ejecutar en este informe.
- Q100 (cerrada, fuera de Java): ADR-0027 usa ≈ 300 bytes con valores por defecto.

## Bloqueos

- Ninguno para documentación.
- Implementación bloqueada por Q103 (autorización por escrito pendiente en `questions.md`).
- Sin acceso AWS en este informe; la verificación real de arranque queda para integrator.
