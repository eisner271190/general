---
name: Java Clean
description: Convenciones Java/Spring para plantillas y código backend hexagonal (Maven, Google Style, tests)
---

## Estilo
- Google Java Style: indentación de 2 espacios, líneas ≤100, imports sin wildcard y ordenados.
- Nombres en inglés: clases PascalCase, métodos/variables camelCase, constantes UPPER_SNAKE, paquetes lowercase sin guiones.

## Arquitectura (Spring hexagonal)
- `domain` puro (model / ports / servicePorts / usecase): sin framework, sin nube, sin persistencia.
- `application` orquesta casos de uso con `dto` y `mappers` (MapStruct).
- `infrastructure` implementa puertos: adapters, controllers, persistence, configuration.
- `HexagonalArchitectureTest` verifica dependencias: nunca crear dependencias inversas (dominio → infra).

## Buenas prácticas
- Java 17; `record` para DTOs inmutables; Lombok solo donde la plantilla ya lo usa; sin dependencias nuevas sin justificación.
- Validación en la frontera (controller/adapter); errores vía `GlobalExceptionHandler` + `ApiResponse`; excepciones específicas, nunca catch vacío.
- Sin secrets en código/properties: variables de entorno o gestor de secretos.

## Tests (Maven; pedir autorización)
- JUnit 5 por capa (usecase, adapters, controllers); Karate para API.
- `./mvnw test` · cobertura `./mvnw jacoco:report` · mutación PITest.

## Referencias
- google.github.io/styleguide/javaguide.html · Effective Java (Bloch)
