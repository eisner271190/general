# integrator-up: ejecución UP -Fast (develop)

## Autorización

- Autorizado por el usuario: UP -Fast, entorno develop.
- Script: `C:\epc\general\projects\com.quizsmart.app\up.ps1`.
- Comando: `pwsh -NoProfile -File up.ps1 -Fast -Environment develop`.
- Sin ediciones al generador ni a los scripts. Sin commit/push en el monorepo.
- El push --force a CodeCommit ocurre dentro del script aprobado (paso 3b).

## Precondiciones (2026-10-11 23:48:40)

- `cloud/terraform/app/secrets.tf`: existe.
- `cloud/terraform/app/keystore_bucket.tf`: existe.
- Docker 29.8.0: disponible.
- Terraform v1.16.4: disponible.
- AWS CLI 2.28.6: disponible.
- Resultado: OK, se procede.

## Resultado global

- Exit code del script: `0`.
- Inicio 2026-10-11 23:48:44, fin 2026-10-12 00:01:39.
- Log generado por el script: `projects/com.quizsmart.app/logs/2026-10-11-23-48-44.log` (165.936 bytes).
- Log de la consola: `projects/com.quizsmart.app/up-fast-run.log`.

## Resultado por paso

| # | Paso | Inicio | Fin | Estado |
|---|------|--------|-----|--------|
| 0 | platform | 23:48:44 | 23:49:22 | OK. Apply 28 recursos |
| 0b | publish-common | 23:49:22 | 23:50:03 | OK. BUILD SUCCESS |
| 0c | publish-buildspecs | 23:50:03 | 23:50:14 | OK. 3 de 3 |
| 1 | cloud Bootstrap (ECR) | 23:50:14 | 23:50:38 | OK. ECR quizapi creado |
| 2 | backend Build | 23:50:38 | 23:56:05 | OK. imagen creada y subida |
| 3 | cloud Apply | 23:56:05 | 23:58:54 | OK. app + quizapi |
| 3b | codecommit | 23:58:54 | 00:00:59 | OK. push a main |
| 4 | backend Run | 00:00:59 | 00:01:03 | OK. contenedor iniciado |
| 5 | frontend | 00:01:03 | 00:01:39 | OK parcial (solo keystore/firma) |

- El script no emite un exit code por paso; solo el global `0`.
- La marca de éxito por paso es su línea `Despliegue finalizado`, presente en las 9 fases.
- Ninguna fase mostró `Error`, `Exception` o `Exit code: 1`.

### Detalle por paso

- 0 platform: `terraform init`, plan y apply. 28 to add, 0 to change, 0 to destroy.
  - Creados: CodeCommit `platform` y `common`, dominio CodeArtifact `epc`,
    repos maven `maven-central` y `common`, ECR `epc/common-base`,
    S3 `epc-buildspecs` (con bloqueo público y versionado), roles IAM,
    CodeBuild `common-build`, `common-publish`, `platform-bump-bom`,
    CodePipeline `common`, regla EventBridge `common-release`.
- 0b publish-common: token de CodeArtifact obtenido (no persistido),
  `settings.xml` efímero creado y borrado. `mvn deploy` de 10 módulos: SUCCESS.
- 0c publish-buildspecs: `bump-bom.yml`, `docker-build.yml`, `java-ci.yml` subidos
  a `s3://epc-buildspecs/`. Los 3 head-object dieron 404 previo, esperado (bucket nuevo).
- 1 Bootstrap: ECR `quizapi` creado. Docker Desktop estaba caído; el script lo arrancó solo.
- 2 backend Build (corre siempre, incluso con `-Fast`): imagen docker construida (~3m15s)
  y subida a ECR. Sesión ECR iniciada con éxito.
- 3 cloud Apply:
  - `terraform/app`: plan y apply. Recurso `Parámetro seguro de la aplicación`.
  - `terraform/quizapi`: plan y apply. API Gateway, API Gateway -> Lambda,
    Cognito, Cognito clientes, Cognito Google, Cognito IAM, ECR, Lambda + IAM,
    SNS, SNS -> SQS, SQS. Todos creados.
  - Post-apply: 6 parámetros actualizados, `baseUrl` en Postman actualizado a
    `https://qrqjkju031.execute-api.us-east-1.amazonaws.com/`,
    parámetro de secrets sembrado con 5 valores.
- 3b codecommit: copia temporal en `%TEMP%\app-seed-*`, repo git nuevo,
  push a `https://git-codecommit.us-east-1.amazonaws.com/v1/repos/com.quizsmart.app`,
  rama `main` creada. Aviso de `push --force` ya données al usuario.
- 4 backend Run: contenedor previo eliminado, 37 parámetros leídos de Parameter
  Store, contenedor `quizapi` iniciado.
- 5 frontend con `-Fast`: sin compilación y sin ejecución (SkipBuild/SkipRun).
  Aun así hizo: flutter clean, pub get, iconos de lanzamiento, generación y subida
  del keystore de Android, y alta de la firma en Parameter Store.

## Verificación de solo lectura

### Lambda e imagen

- Lambda `quizapi`: existe. `PackageType` = Image, `MemorySize` = 512.
- ECR `quizapi`: 1 imagen, tag `latest`, `imagePushedAt` = 2026-10-11T23:56:04-05:00.
  Coincide con la subida del paso 2.

### Bucket de keystore

- Bucket `com.quizsmart.app-keystore-develop`: existe.
- Versionado: `Status = Enabled`.
- Bloqueo público: las 4 opciones en `true`.
- Objetos: `keystore/com.quizsmart.app/keystore.jks` (2.0 KB, 2026-10-12).

### CodeArtifact

- Dominio `epc`: `Active`.
- Repositorio `common` (maven) contiene `com.epc.common:common-web:1.1.6`.
- Versión 1.1.6 coincide con la publicada en el paso 0b.

### Parameter Store

- 37 parámetros bajo `/develop/com.quizsmart.app/quizapi`, todos `String`.
- `/develop/com.quizsmart.app/secrets`: existe, tipo `SecureString`,
  modificado 2026-10-12T00:01:38 (firma Android añadida en el paso 5).

## Desviación encontrada

- El brief pedía verificar el parámetro SecureString
  `/develop/com.quizsmart.app/quizapi/secrets`.
- Esa ruta NO existe. La SecureString creada por el script es
  `/develop/com.quizsmart.app/secrets` (sembrada en el paso 3, ampliada en el paso 5).
- Los 37 parámetros de `quizapi` son todos `String`; no hay ningún `secrets`
  bajo el prefijo `/develop/com.quizsmart.app/quizapi`.
- No es un fallo del despliegue: es una diferencia entre la ruta del brief y la que
  produce `up.ps1`. Queda reportado, sin tocar ningún script.
- Recomendación: confirmar el nombre canónico esperado antes de que un consumidor
  (Lambda, frontend o Postman) lea `.../quizapi/secrets`.

## Notas y pendientes

- Sin reintentos: no hubo que ejecutar ninguna recuperación.
- Sin cambios en el generador ni en los scripts.
- Sin commit ni push en el monorepo.
- Terraform reporta aviso de estar desactualizado (1.16.4 vs 1.16.5). Sin impacto.
- El frontend no se compiló ni se ejecutó por `-Fast`. Para levantar la UI hay que
  correr `up.ps1` sin `-Fast`.
- Recomendación: dejar el IAM en modo lectura y sin secretos en los logs al revisar
  los 37 parámetros; este informe no imprime ningún valor de secreto.