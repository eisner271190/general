# Plantillas del componente backend no registradas en `component.json`

Revisión: `generator/components/backend/spring-boot-3.5.16/…` vs `templates/` (181 plantillas).
Resultado: **56 plantillas existen pero NO están en `component.json`** → **no se generan**.

## 1. Seguridad / JWT (paquete condicionado a `Name == "security"`)
| Plantilla | Condición |
|---|---|
| `jwt-provider.scriban` | `{{ if(Name == "security") }}` |
| `jwt-authentication-manager.scriban` | `{{ if(Name == "security") }}` |
| `jwt-authentication-filter.scriban` | `{{ if(Name == "security") }}` |
| `security-config.scriban` | `{{ if(Name == "security") }}` |
| `security-context-repository.scriban` | `{{ if(Name == "security") }}` |
| `path-constants.scriban` | `{{ if(Name == "security") }}` |

## 2. Andamiaje genérico por entidad (sin registro ni bucle de entidades)
`adapter`, `adapter-test`, `controller`, `controller-test`, `dto`, `entity`, `model`,
`port`, `repository`, `router`, `service`, `service-test`, `servicePort`, `iservice`,
`usecase`, `usecase-test`, `persistence-model`, `datasource`, `handler`,
`mapperDto`, `mapperEntity`, `mapperDynamo`, `mapperPersistenceModel`

## 3. Terraform (14, duplicadas; registradas solo en `components/cloud/aws`)
`terraform-provider`, `terraform-variables`, `terraform-apigateway`,
`terraform-apigateway-lambda`, `terraform-ecr`, `terraform-sqs`, `terraform-sns`,
`terraform-sns-subscriptions`, `terraform-cognito`, `terraform-cognito-iam`,
`terraform-cognito-client`, `terraform-cognito-google-provider`, `terraform-dynamodb`,
`terraform-lambda`

## 4. Infra / otros
`docker-compose`, `docker-compose-localstack`, `Dockerfile-graalvm`, `log4j2`,
`prometheus`, `dashboard`, `workspace`, `graalvm-runtime-hints`, `iauthservice`,
`auth-request-dto`, `auth-response-dto`, `dynamo`, `dynamo-schema`, `DynamoBean`,
`EXCHANGE_ENDPOINT_README.md`

## ¿Por qué "se generó" JwtProvider si el micro no se llama `security`?

**No se generó.** Evidencia:
1. `component.json` no registra `jwt-provider.scriban` (ni ninguna JWT/seguridad).
2. `projects/com.quizsmart.app/generation-plan.json` no contiene `JwtProvider`
   ni `authentication\jwt` (solo `jwt_decoder.dart` del **frontend**, que es otro módulo).
3. No existe ningún `JwtProvider.java` en el workspace.

### Mecanismo (si estuviera registrada)
- `GenerationPlanBuilder.cs` línea 41: `Name = microservice.Name` → para el micro
  `quizapi`, `Name == "security"` es **falso** → Scriban renderizaría **vacío**
  (clase sin contenido), no la clase.
- Solo se generaría con contenido si el microservicio se llamara exactamente `security`.

### De dónde viene la confusión de que "usa JWT"
Lo que **sí se genera** y menciona JWT:
- `pom.scriban` → dependencias `jjwt-api/impl/jackson` (siempre).
- `application-properties.scriban` → `jwt.secret=${JWT_SECRET}` y `jwt.expiration`.
- Frontend: `jwt_decoder.dart` (decode de id_token de Cognito).

Esos artefactos hacen parecer que existe un proveedor JWT en el backend, pero la
clase `JwtProvider` nunca se crea.
