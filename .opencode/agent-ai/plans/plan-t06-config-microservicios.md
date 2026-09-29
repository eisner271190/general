# Plan: T06 — El microservicio obtiene parámetros y secretos al iniciar

**Tarea del TODO:** `.opencode/agent-ai/docs/todo.md` → MVP `T06 — Obtener los parametros y los secrets (Solo los que el ms necesite) al iniciar los ms`
**Fecha:** 2026-09-27 · **Refinamiento:** 2026-09-28 — justificación de `spring-cloud-aws` (§5), rutas de import corregidas (§6 T6.2) y fail-fast en la nube (§10.3).

## 1. Descripción
Hoy el microservicio **no lee nada de AWS**: recibe env vars (Terraform en la Lambda; `up.ps1 -Phase Run` en local) y resuelve `${JWT_SECRET}` etc. desde el entorno. No existe ningún `PropertySource`, cliente SSM/Secrets Manager ni starter relacionado en el `pom`.

## 2. Objetivo
- Al arrancar, el ms carga **solo** sus parámetros del prefijo `/{entorno}/{applicationId}/{ms}/` y las claves que necesita del secreto de la aplicación `/{entorno}/{applicationId}` en el `Environment` de Spring.
- Arranque local sin credenciales AWS y sin llamadas a la nube (lectura sólo con el perfil `cloud`).
- Credenciales AWS solo por rol IAM (Lambda); cero secretos en el repositorio.

## 3. Estado actual vs. nuevo
```text
pom.scriban                  Spring Boot 3.4.0, AWS SDK BOM 2.31.73   (sin spring-cloud-aws)
application-properties:28    jwt.secret=${JWT_SECRET:${jwt-secret:}}  ← fallback de T04, sin valor real
application-properties:42-43 cloud.aws.credentials.*                  ← prefijo erróneo (SCA 3.x usa spring.cloud.aws.*)
cloud/.../terraform-lambda    environment { for key, value ... }       ← env vars, sin SPRING_PROFILES_ACTIVE
---
pom.scriban                    + spring-cloud-aws 3.3.1 (starters parameter-store + secrets-manager)
application-cloud.properties   + spring.config.import=aws-parameterstore:/{{ENV}}/{{APP}}/{{ms}}/,
                                      aws-secretsmanager:{{ENV}}/{{APP}}      (sólo perfil "cloud")
terraform-lambda               + SPRING_PROFILES_ACTIVE="cloud"
                               + IAM ssm:GetParametersByPath (GetSecretValue ya existe)
```

## 4. Referencias web
| Referencia | Aporte |
|---|---|
| https://github.com/awspring/spring-cloud-aws (tabla de compatibilidad) | **3.3.x → Spring Boot 3.4.x** (el pom es 3.4.0). 3.4.x exige Boot 3.5.x ⇒ si el pom sube a 3.5.x, migrar a SCA 3.4.x. |
| https://docs.awspring.io/spring-cloud-aws/docs/3.3.1/reference/html/ | `spring.config.import=aws-parameterstore:` / `aws-secretsmanager:` (recomendado frente al bootstrap legacy); **§16.1: la ruta se usa "tal cual" ⇒ barra final obligatoria** en SSM; `?prefix=` opcional. |
| Código SCA 3.3.1 (`ParameterStorePropertySource`, `SecretsManagerPropertySource`) | Confirma las dos reglas de ruta: SSM hace `replace(path,"")` y luego `replace('/','.')` (sin barra final la clave sale `.DATABASE_HOST`); SM usa el contexto **literal** como `secretId` (una barra inicial no coincide con `develop/com.quizsmart.app`). |
| https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html | Caché en cliente para **llamadas repetidas**; aquí sólo hay 2 por arranque (ver §10.5). |
| `.opencode/agent-ai/plans/plan-reduce-secret-calls.md` | Regla propia: probar env vars/local antes que llamar a AWS → justifica el perfil `cloud` (apagado en local). |
| `.opencode/agent-ai/plans/plan-secretos-unico-por-app.md` | Secreto único por app con JSON **kebab-case** (`jwt-secret`, `api-key`, `android-signing`) → define las claves que verá el ms (T6.3). |

## 5. ¿Por qué spring-cloud-aws? (alternativas consideradas)
| Alternativa | Veredicto |
|---|---|
| **AWS SDK v2 a mano** (`SsmClient`/`SecretsManagerClient` + `EnvironmentPostProcessor`/`PropertySource` en `spring.factories`) | **Descartada**: ~100-150 líneas propias (paginación de `GetParametersByPath`, aplanado del JSON, orden en el `Environment`, manejo de errores) + sus tests, cuando la integración ya existe y es declarativa. SCA además fija región/credenciales por cadena por defecto. |
| **Spring Cloud Config Server** (backend Parameter Store) | **Descartada**: exige desplegar y mantener un servidor (coste + operación) para un MVP con un microservicio. |
| **AWS AppConfig** | **Descartada**: servicio adicional con coste tras el nivel gratuito y más piezas móviles; SCA 3.3.x ni lo soporta (llega en 4.1.x). |
| **Lambda extension "Parameters and Secrets"** | **Descartada como vía principal**: sólo existe en Lambda (no en local) y no llena el `Environment` de Spring sin código propio. Se conserva como optimización futura de latencia (§10.5). |
| **Seguir sólo con env vars de Terraform** (status quo) | **No cumple T06**: el ms no leería nada y el secreto quedaría en tfvars/estado (prohibido por T04). |

**Decisión: `spring-cloud-aws` 3.3.1 (starters `parameter-store` + `secrets-manager`)** porque:
1. Integración **declarativa** vía `spring.config.import` (config data API de Boot 3.4): **0 código propio** que mantener.
2. Lectura **sólo con el perfil `cloud`** ⇒ en local 0 llamadas (regla `plan-reduce-secret-calls.md`).
3. Funciona con el **rol IAM de la Lambda sin configuración**: `DefaultCredentialsProvider` incluye las credenciales de contenedor de Lambda y `DefaultAwsRegionProviderChain` lee `AWS_REGION`.
4. **Sin BOM de Spring Cloud**: `spring-cloud-commons`/`spring-cloud-context` son *opcionales* en SCA (sólo los pide el reload, fuera de alcance) ⇒ no se arrastra `spring-cloud-dependencies`.
5. **Coste 0 USD** (sólo llamadas API dentro del nivel gratuito; ver §12).

## 6. Tareas de implementación
> **Estado (2026-09-28):** T6.1–T6.7 implementados y **T6.8 verificado en local** en `feature/t06-config-aws`:
> - `dotnet run --project Generator.csproj` → regenera sin errores; `application-cloud.properties` y `ApplicationContextTest.java` se generan correctamente.
> - `mvn dependency:tree` → **una única versión de AWS SDK (2.31.73)** en todo el árbol y `io.awspring.cloud 3.3.1` sin arrastrar `spring-cloud-*` (valida §6 T6.1).
> - `mvn test` → `ApplicationContextTest` **3/3** y `HolaMundoControllerTest` 1/1 en verde. **No hay `mvnw`** en la plantilla (sólo `.mvn/`): se usa `mvn`.
> - ⚠️ `HexagonalArchitectureTest` falla **2/3 de forma preexistente**: `target/classes/com/quizsmart/quizapi` sólo contiene `infrastructure` (la configuración no tiene entidades, así que `domain`/`application` se generan vacíos y ArchUnit exige que las reglas revisen algo). No está causado por T06 (fallo con o sin este cambio).
> - ⚠️ JaCoCo avisa `ClassTooLargeException` al instrumentar `DefaultSsmClient` (no fatal: el test sigue y termina en verde).
> - **Pendiente (sólo despliegue):** `./cloud/up.ps1 -Phase Apply` + invocación Lambda + `curl .../actuator/health` (T6.8.2-4, requiere cuenta AWS; `terraform apply` está denegado para el agente).
> Ambas fases en el mismo branch, **commits separados por fase**.
### Fase 1 — Integración (feature `feature/t06-config-aws`)
1. **T6.1 `pom.scriban`**: propiedad `<spring.cloud.aws.version>3.3.1</spring.cloud.aws.version>` y dos dependencias:
   ```xml
   <dependency><groupId>io.awspring.cloud</groupId><artifactId>spring-cloud-aws-starter-parameter-store</artifactId><version>${spring.cloud.aws.version}</version></dependency>
   <dependency><groupId>io.awspring.cloud</groupId><artifactId>spring-cloud-aws-starter-secrets-manager</artifactId><version>${spring.cloud.aws.version}</version></dependency>
   ```
   **Colisión de SDK:** el pom ya importa `software.amazon.awssdk:bom 2.31.73` **antes** que cualquier otro BOM (`pom.scriban:35-45`) y SCA 3.3.1 está compilado contra 2.29.52; el BOM declarado primero gana (es la propia recomendación de SCA §2.3 "Choosing AWS SDK version"). Verificar con `./mvnw -q dependency:tree` (requiere autorización) que **sólo hay una versión** de `software.amazon.awssdk:*`; no se esperan exclusiones. *Alternativa equivalente:* importar `io.awspring.cloud:spring-cloud-aws-dependencies:3.3.1` tras el BOM de AWS y declarar los starters sin `<version>`.
2. **T6.2 Nueva plantilla `application-cloud-properties.scriban`** → `src/main/resources/application-cloud.properties`:
   ```properties
   spring.config.import=aws-parameterstore:/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/{{ MICROSERVICE_NAME }}/,aws-secretsmanager:{{ ENVIRONMENT }}/{{ APPLICATION_ID }}
   ```
   - **Barra final obligatoria en SSM** (`.../{{ MICROSERVICE_NAME }}/`): sin ella `ParameterStorePropertySource` deja la clave como `.DATABASE_HOST` y `${DATABASE_HOST}` no resolvería. La ruta es **la misma** que usa `terraform-ssm.scriban` (T05) y `up.ps1` (`{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/{{ MICROSERVICE_NAME }}`).
   - **Sin barra inicial en el secreto**: T04 crea `develop/com.quizsmart.app`; con `/develop/...` el `GetSecretValue` falla.
   - El Parameter Store es **por microservicio**; el secreto es **por aplicación** (`develop/com.quizsmart.app`): el import trae sus claves al `Environment` y **cada ms sólo usa las que necesita**.
   - Registrarla en `components/backend/spring-boot-3.5.16/component.json` (regla: plantilla no listada ⇒ no se genera).
3. **T6.3 Restringir lo que se carga**: los parámetros se importan **solo** del prefijo del ms (no de `/config/application`) y el secreto es el de la aplicación, cumpliendo "sólo los que el ms necesite" a nivel de claves SSM. Claves resultantes: `DATABASE_HOST`, `JWT_EXPIRATION`, … (SSM) y `jwt-secret` (kebab-case, ver T04) que hace operativo `application-properties.scriban:28`. ⚠️ **Riesgo aceptado:** el JSON único de la aplicación aporta también `android-signing` y `api-key` al `Environment` de **todos** los ms (decisión de coste de T04, 1 × 0,40 USD/mes); se mitiga con T6.6.
4. **T6.4 Activación en la Lambda**: `generator/components/cloud/aws/templates/terraform-lambda.scriban` → el bloque `variables` es una comprensión `for` con filtro de claves reservadas (líneas 61-71), así que:
   ```hcl
   variables = merge(
     { for key, value in var.environment_variables : key => value
       if !contains(["AWS_REGION","AWS_ACCESS_KEY_ID","AWS_SECRET_ACCESS_KEY","AWS_SESSION_TOKEN","AWS_PROFILE"], key) },
     { SPRING_PROFILES_ACTIVE = "cloud" }
   )
   ```
5. **T6.5 IAM en la misma plantilla**: añadir a `aws_iam_role_policy`
   ```hcl
   { Effect = "Allow",
     Action = ["ssm:GetParametersByPath"],
     Resource = ["arn:aws:ssm:*:*:parameter/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/{{ MICROSERVICE_NAME }}/*"] }
   ```
   - `secretsmanager:GetSecretValue` **ya existe** (líneas 42-46, T04) → comprobar, **no duplicar**.
   - `kms:Decrypt` **sólo si** algún parámetro pasa a `SecureString` (hoy T05 los crea como `String` → no hace falta).
   - ⚠️ Modificar **sólo** `generator/components/cloud/aws/templates/terraform-lambda.scriban`: la copia `backend/.../templates/terraform-lambda.scriban` **no está registrada** (regla del componente cloud).

### Fase 2 — Seguridad y verificación (feature `feature/t06-seguridad-verificacion`)
6. **T6.6 Reducir actuator** en `application-properties.scriban:5`: `management.endpoints.web.exposure.include=*` → `health,info,prometheus`. Hoy `show-details=always` + `include=*` exponen **el valor de todas las propiedades** en `/actuator/env`; con secretos en el `Environment` es una fuga. La ruta `/actuator/health` del API GW (`apigateway_lambda.tf:21-26`) sigue funcionando. **En el mismo fichero:** eliminar las líneas 42-43 (`cloud.aws.credentials.*`): prefijo erróneo para SCA 3.x (`spring.cloud.aws.*`), config muerta que además podría resolver `${AWS_ACCESS_KEY_ID}` al mostrar detalles; las credenciales las resuelve la cadena por defecto (IAM/env).
7. **T6.7 Tests**: plantilla nueva `application-context-test.scriban` → `ApplicationContextTest` (registrada en `component.json`) con `@SpringBootTest` **sin** perfil `cloud`:
   - el contexto arranca sin credenciales y **sin** ningún `PropertySource` de Parameter Store/Secrets Manager (si SCA intentara leer AWS, el contexto fallaría);
   - `jwt.secret` se resuelve desde la variable de entorno `JWT_SECRET`;
   - el `application.properties` conserva el fallback `jwt.secret=${JWT_SECRET:${jwt-secret:}}` (clave del secreto de T04);
   - las propiedades en línea `AWS_REGION=us-east-1` y `spring.cloud.aws.region.static=us-east-1` evitan depender del entorno de la máquina (SCA crea los clientes `SsmClient`/`SecretsManagerClient` al arrancar aunque no haya import; **no** hacen ninguna llamada). Si `ConsumedEvents > 0` se añade también `AWS_SQS_URL_<ms>`.
8. **T6.8 Verificación**:
   ```powershell
   ./backend/quizapi/up.ps1 -Phase Build          # compilar (autorización)
   ./backend/quizapi/up.ps1 -Phase Run            # local: sin perfil cloud, sin llamadas AWS
   ./cloud/up.ps1 -Phase Apply && ./backend/quizapi/up.ps1 -Phase Run
   aws lambda invoke --function-name quizapi out.json   # o revisar CloudWatch
   curl https://<invoke_url>/actuator/health             # → {"status":"UP"}
   ```
   En los logs debe verse el `PropertySource` de Parameter Store/Secrets Manager al iniciar con el perfil `cloud` (y **no** deben aparecer los valores del secreto en el log).

## 7. Flujo de datos
1. **Local:** `up.ps1 -Phase Run` → `aws ssm get-parameters-by-path` → `docker run -e CLAVE=valor` → Spring resuelve `${...}` (como hoy). **Perfil `cloud` desactivado ⇒ 0 llamadas en el arranque de la app.**
2. **Nube (Lambda):** arranque con `SPRING_PROFILES_ACTIVE=cloud` → `spring.config.import` (requerido: falla si falta SSM o el secreto) → SSM + Secrets Manager → `Environment` → `jwt.secret=${JWT_SECRET:${jwt-secret:}}` resuelto con `jwt-secret`.
3. **Credenciales en nube:** rol IAM de la Lambda (no `AWS_ACCESS_KEY_ID` en la app).

## 8. Archivos a crear
| Archivo | Propósito |
|---|---|
| `generator/components/backend/spring-boot-3.5.16/templates/application-cloud-properties.scriban` | Import de SSM (con `/` final) + Secrets Manager (sin `/` inicial), activado por perfil. |
| `generator/components/backend/spring-boot-3.5.16/templates/application-context-test.scriban` | `ApplicationContextTest`: arranque sin perfil `cloud` y `jwt.secret` (T6.7). |

## 9. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `generator/components/backend/spring-boot-3.5.16/templates/pom.scriban` | Starters `spring-cloud-aws` 3.3.1. |
| `.../backend/spring-boot-3.5.16/templates/application-properties.scriban` | `include=health,info,prometheus`; quitar `cloud.aws.credentials.*` (42-43). |
| `.../backend/spring-boot-3.5.16/component.json` | Registrar las dos plantillas nuevas (`application-cloud.properties` y `ApplicationContextTest.java`). |
| `generator/components/cloud/aws/templates/terraform-lambda.scriban` | `SPRING_PROFILES_ACTIVE=cloud` (merge) + política IAM SSM. *(El duplicado del backend no se toca: no está registrado.)* |
| `projects/com.quizsmart.app/...` (salidas) | Sincronizar (están en `.gitignore`). |

## 10. Preguntas y recomendaciones
1. **¿Perfil `cloud` o import siempre activo?** → *Recomendación:* **perfil `cloud` activado solo en la Lambda**. Un `optional:` global haría que un desarrollador con credenciales AWS en local arrastre valores remotos sin darse cuenta (rompe el patrón "local primero" de `plan-reduce-secret-calls.md`).
2. **¿Dejar de inyectar env vars en la Lambda (ya no haría falta)?** → *Recomendación:* **mantenerlas una fase** como fallback (el mapa ya existe en `lambda.tf`) y eliminarlas en un plan posterior, cuando se confirme la lectura en nube. Migrar todo a la vez encadena el riesgo de T05+T06.
3. **¿`optional:` o import requerido en el perfil cloud?** → *Recomendación:* **requerido (sin `optional:`)**. El perfil ya está apagado en local, así que `optional:` no aporta protección allí y en la nube sólo encubriría fallos de IAM o un T04/T05 sin desplegar. Preferible fallar al arrancar antes que hacerlo con `jwt.secret` vacío (firma con clave vacía).
4. **¿`spring-cloud-aws 3.3.1` frente a subir el pom a Boot 3.5.x?** → *Recomendación:* **3.3.1** con Boot 3.4.0 (compatibilidad oficial). Upgrade de Boot es otra tarea del backlog; al hacerlo, subir SCA a 3.4.x.
5. **¿Exponer detalles de salud (`show-details=always`)?** → *Recomendación:* `always` sólo si se necesita el detalle de los `health indicators`; combinar con T6.6 para no exponer propiedades.
6. **¿Caché de secretos?** → SCA **no expone ninguna propiedad de caché** (comprobado en 3.3.1): carga la config **una vez por arranque** (1 `GetParametersByPath` + 1 `GetSecretValue` por ciclo frío), por lo que no hace falta caché ni `SecretCache`. Si más adelante se hacen llamadas en caliente, la extensión Lambda de Parameters & Secrets reduce latencia de arranque (0 USD, capa gratuita).
7. **¿Exponer el secreto de la aplicación completo a todos los ms?** → *Recomendación:* **aceptarlo en el MVP** (decisión de coste de T04: 1 secreto = 0,40 USD/mes; dividirlo en `ms`/`app` sumaría +0,40 USD/mes por secreto) **y cerrar T6.6**; revisar si crece el número de ms.
8. **¿Cuenta/perfil AWS?** (depende de T04/T05) → *Recomendación:* resolverlo antes de desplegar.

## 11. Decisiones tomadas
1. Spring Cloud AWS **3.3.x** (compat con Boot 3.4.0 del pom); justificación y alternativas descartadas en §5.
2. Lectura **por perfil** y **solo del prefijo del ms**; rutas exactas: SSM **con** barra final y secreto **sin** barra inicial (T6.2).
3. Import **requerido** en el perfil cloud (fail-fast, §10.3).
4. Credenciales exclusivamente por rol IAM en la nube; eliminar `cloud.aws.credentials.*` (T6.6).

## 12. Costos
- **Infra:** sin recursos nuevos. Llamadas: 1 `GetParametersByPath` + 1 `GetSecretValue` por ciclo frío (nivel gratuito 10.000 llamadas/mes de SM y SSM) → **0 USD** en el MVP.
- **Latencia:** +2 llamadas API en el arranque de la Lambda (≈50-150 ms por ciclo frío, sin coste); mitigación futura en §10.6.
- **Esfuerzo:** 5-6 archivos, 2 capas (backend + cloud) → tarea **grande**: 2 features/PRs, **2 sesiones** (incluye `mvnw compile/test` con autorización).
- **Contexto/tokens:** medio (pom + plantillas + IAM).

## 13. Fuera de alcance
- Crear los secretos/parámetros → **T04** y **T05**.
- Rotación de secretos y refresco en caliente (`@RefreshScope`; exige `spring-cloud-context`, hoy opcional).
- Migrar el `up.ps1` local para que el ms lea directo de AWS (hoy inyecta env vars por diseño).
- Quitar del todo las env vars de la Lambda (§10.2).
- Extensión Lambda de Parameters & Secrets y Spring Cloud Config Server (§5).
