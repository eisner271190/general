# Plan: T06 — El microservicio obtiene parámetros y secretos al iniciar

**Tarea del TODO:** `.opencode/agent-ai/docs/todo.md` → MVP `T06 — Obtener los parametros y los secrets (Solo los que el ms necesite) al iniciar los ms`
**Fecha:** 2026-09-27

## 1. Descripción
Hoy el microservicio **no lee nada de AWS**: recibe env vars (Terraform en la Lambda; `up.ps1 -Phase Run` en local) y resuelve `${JWT_SECRET}` etc. desde el entorno. No existe ningún `PropertySource`, cliente SSM/Secrets Manager ni starter relacionado en el `pom`.

## 2. Objetivo
- Al arrancar, el ms carga **solo** sus parámetros del prefijo `/{entorno}/{applicationId}/{ms}/` y las claves que necesita del secreto de la aplicación `/{entorno}/{applicationId}` en el `Environment` de Spring.
- Arranque local sin credenciales AWS y sin llamadas a la nube (import opcional y por perfil).
- Credenciales AWS solo por rol IAM (Lambda); cero secretos en el repositorio.

## 3. Estado actual vs. nuevo
```text
pom.scriban                Spring Boot 3.4.0, AWS SDK BOM 2.31.73  (sin spring-cloud-aws)
application-properties:28  jwt.secret=${JWT_SECRET}  ← solo entorno
                           aws.region / cloud.aws.credentials.*    ← solo entorno
lambda.tf:54               environment { variables = var.environment_variables }
---
pom.scriban                + spring-cloud-aws 3.3.1 (starter parameter-store + secrets-manager)
application-cloud.*        + spring.config.import=optional:aws-parameterstore:...,
                                 optional:aws-secretsmanager:...     (perfil "cloud")
terraform-lambda           + SPRING_PROFILES_ACTIVE=cloud  y política IAM ssm/secretsmanager
```

## 4. Referencias web
| Referencia | Aporte |
|---|---|
| https://github.com/awspring/spring-cloud-aws (tabla de compatibilidad) | **3.3.x → Spring Boot 3.4.x** (el pom es 3.4.0). 3.4.x exige Boot 3.5.x. |
| https://docs.awspring.io/spring-cloud-aws/docs/current/reference/html/ | `spring.config.import=optional:aws-parameterstore:` / `optional:aws-secretsmanager:` (recomendado frente al bootstrap legacy). |
| https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html | Caché en cliente para no agotar cuota de `GetSecretValue`. |
| `.opencode/agent-ai/plans/plan-reduce-secret-calls.md` | Regla propia: probar env vars/local antes que llamar a AWS → justifica el `optional:` y el perfil. |

## 5. Tareas de implementación
### Fase 1 — Integración (feature `feature/t06-config-aws`)
1. **T6.1 `pom.scriban`**: propiedad `<spring.cloud.aws.version>3.3.1</spring.cloud.aws.version>` y dos dependencias:
   ```xml
   <dependency><groupId>io.awspring.cloud</groupId><artifactId>spring-cloud-aws-starter-parameter-store</artifactId><version>${spring.cloud.aws.version}</version></dependency>
   <dependency><groupId>io.awspring.cloud</groupId><artifactId>spring-cloud-aws-starter-secrets-manager</artifactId><version>${spring.cloud.aws.version}</version></dependency>
   ```
   Verificar colisión de versiones con el BOM `software.amazon.awssdk:bom 2.31.73` (`./mvnw -q dependency:tree`, requiere autorización); si la hay, excluir los `software.amazon.awssdk` transitivos conflictivos.
2. **T6.2 Nueva plantilla `application-cloud-properties.scriban`** → `src/main/resources/application-cloud.properties`:
   ```properties
   spring.config.import=optional:aws-parameterstore:/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}/{{ Name }},\
                        optional:aws-secretsmanager:/{{ ENVIRONMENT }}/{{ APPLICATION_ID }}
   ```
   El Parameter Store es **por microservicio**; el secreto es **por aplicación** (`develop/com.quizsmart.app`, ver T04): el import trae sus claves al `Environment` y **cada ms sólo usa las que necesita**.
   Registrarla en `components/backend/spring-boot-3.5.16/component.json` (regla: plantilla no listada ⇒ no se genera).
3. **T6.3 Restringir lo que se carga**: los parámetros se importan **solo** del prefijo del ms (no de `/config/application`) y el secreto es el de la aplicación, cumpliendo "sólo los que el ms necesite" a nivel de claves. Las claves SSM (`DATABASE_HOST`, `JWT_EXPIRATION`, …) y las claves del JSON del secreto (`JWT_SECRET`) pasan a estar en el `Environment`; `${JWT_SECRET}` de `application-properties.scriban:28` deja de requerir env var.
4. **T6.4 Activación en la Lambda**: `terraform-lambda.scriban` → `environment { variables = merge(var.environment_variables, { SPRING_PROFILES_ACTIVE = "cloud" }) }`.
5. **T6.5 IAM en `terraform-lambda.scriban`**: `ssm:GetParametersByPath` (+`kms:Decrypt` si algún parámetro es `SecureString`) sobre `/develop/{{ APPLICATION_ID }}/{{ Name }}/*` y `secretsmanager:GetSecretValue` sobre el secreto de la aplicación `{{ ENVIRONMENT }}/{{ APPLICATION_ID }}-*` (lo crea T04).

### Fase 2 — Seguridad y verificación (feature `feature/t06-seguridad-verificacion`)
6. **T6.6 Reducir actuator**: en `application-properties.scriban:5` cambiar `management.endpoints.web.exposure.include=*` por `health,info,prometheus`. Hoy `show-details=always` + `include=*` exponen **el valor de todas las propiedades** en `/actuator/env`; con secretos en el `Environment` es una fuga. La ruta `/actuator/health` del API GW (`apigateway_lambda.tf:21-26`) sigue funcionando.
7. **T6.7 Tests**: test de contexto **sin** perfil `cloud` (sin credenciales) que asegure que el arranque no llama a AWS; test de la propiedad `jwt.secret` desde env var (patrón ya usado en `test/health_repository_test.dart` del front y en los tests JUnit del backend).
8. **T6.8 Verificación**:
   ```powershell
   ./backend/quizapi/up.ps1 -Phase Build          # compilar (autorización)
   ./backend/quizapi/up.ps1 -Phase Run            # local: sin perfil cloud, sin llamadas AWS
   ./cloud/up.ps1 -Phase Apply && ./backend/quizapi/up.ps1 -Phase Run
   aws lambda invoke --function-name quizapi out.json   # o revisar CloudWatch
   curl https://<invoke_url>/actuator/health             # → {"status":"UP"}
   ```
   En los logs debe verse el `PropertySource` de Parameter Store/Secrets Manager al iniciar con el perfil `cloud`.

## 6. Flujo de datos
1. **Local:** `up.ps1 -Phase Run` → `aws ssm get-parameters-by-path` → `docker run -e CLAVE=valor` → Spring resuelve `${...}` (como hoy). **Perfil `cloud` desactivado ⇒ 0 llamadas en el arranque de la app.**
2. **Nube (Lambda):** arranque con `SPRING_PROFILES_ACTIVE=cloud` → `spring.config.import` → SSM + Secrets Manager (con caché) → `Environment` → `jwt.secret=${JWT_SECRET}` resuelto.
3. **Credenciales en nube:** rol IAM de la Lambda (no `AWS_ACCESS_KEY_ID` en la app).

## 7. Archivos a crear
| Archivo | Propósito |
|---|---|
| `generator/components/backend/spring-boot-3.5.16/templates/application-cloud-properties.scriban` | Import de SSM + Secrets Manager, activado por perfil. |

## 8. Archivos a modificar
| Archivo | Cambio |
|---|---|
| `.../templates/pom.scriban` | Starters `spring-cloud-aws` 3.3.1. |
| `.../templates/application-properties.scriban` | `management.endpoints.web.exposure.include=health,info,prometheus`. |
| `.../backend/spring-boot-3.5.16/component.json` | Registrar la plantilla nueva. |
| `.../templates/terraform-lambda.scriban` | `SPRING_PROFILES_ACTIVE=cloud` + política IAM SSM/Secrets Manager. |
| `projects/com.quizsmart.app/...` (salidas) | Sincronizar (están en `.gitignore`). |

## 9. Preguntas y recomendaciones
1. **¿Perfil `cloud` o import siempre activo?** → *Recomendación:* **perfil `cloud` activado solo en la Lambda**. Un `optional:` global haría que un desarrollador con credenciales AWS en local arrastre valores remotos sin darse cuenta (rompe el patrón "local primero" de `plan-reduce-secret-calls.md`).
2. **¿Dejar de inyectar env vars en la Lambda (ya no haría falta)?** → *Recomendación:* **mantenerlas una fase** como fallback (el mapa ya existe en `lambda.tf`) y eliminarlas en un plan posterior, cuando se confirme la lectura en nube. Migrar todo a la vez encadena el riesgo de T05+T06.
3. **¿`spring-cloud-aws 3.3.1` frente a subir el pom a Boot 3.5.x?** → *Recomendación:* **3.3.1** con Boot 3.4.0 (compatibilidad oficial). Upgrade de Boot es otra tarea del backlog.
4. **¿Exponer detalles de salud (`show-details=always`)?** → *Recomendación:* `always` solo si se necesita el detalle de los `health indicators`; combinar con T6.6 para no exponer propiedades.
5. **¿Caché de secretos?** → *Recomendación:* usar la caché por defecto de Spring Cloud AWS (TTL 300 s) y, si crece el tráfico, la extensión Lambda de Parameters & Secrets (mejora tiempos fríos y coste).
6. **¿Cuenta/perfil AWS?** (depende de T04/T05) → *Recomendación:* resolverlo antes de desplegar.

## 10. Decisiones tomadas
1. Spring Cloud AWS **3.3.x** (compat con Boot 3.4.0 del pom).
2. Lectura **por perfil** y **solo del prefijo del ms**.
3. Credenciales exclusivamente por rol IAM en la nube.

## 11. Costos
- **Infra:** sin recursos nuevos. Llamadas: 1 `GetParametersByPath` + 1 `GetSecretValue` por arranque/ciclo de vida (nivel gratuito 10.000 llamadas/mes de SM y SSM) → **0 USD** en el MVP.
- **Esfuerzo:** 5-6 archivos, 2 capas (backend + cloud) → tarea **grande**: 2 features/PRs, **2 sesiones** (incluye `mvnw compile/test` con autorización).
- **Contexto/tokens:** medio (pom + plantillas + IAM).

## 12. Fuera de alcance
- Crear los secretos/parámetros → **T04** y **T05**.
- Rotación de secretos y refresco en caliente (`@RefreshScope`).
- Migrar el `up.ps1` local para que el ms lea directo de AWS (hoy inyecta env vars por diseño).
- Quitar del todo las env vars de la Lambda (§9.2).
