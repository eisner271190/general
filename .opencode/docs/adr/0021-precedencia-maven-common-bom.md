# ADR-0021: Precedencia Maven — una entrada explícita gana a un `import`

- **Fecha:** 2026-10-03
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; `question-007.md`, `question-018.md`

## Contexto

El criterio de aceptación #5 daba a entender que `common-bom` gobernaba todas las versiones desde un único fichero. Eso no es lo que hace Maven, y había que medirlo antes de comprometer el criterio.

Se midió con el discriminante `epc.spring-boot.version=3.3.11` sobre `samples/log-only-sample` (parent en 3.4.0): los módulos de Boot resolvieron a **3.4.0** (entradas explícitas de `spring-boot-dependencies` vía `spring-boot-starter-parent`) y el resto (`spring-core` 6.1.19, `micrometer-core` 1.13.13) a la versión del BOM.

## Decisión

Regla medida y adoptada: **una entrada explícita de `dependencyManagement` gana a cualquier `import`, aunque la explícita venga de un ancestro; entre dos `import`, gana el del POM hijo.**

Consecuencia asumida: **la versión de Spring Boot se gobierna desde el `<parent>` de cada microservicio, no desde `common-bom`.** El BOM gobierna AWS SDK, spring-cloud-aws y las dependencias que ningún BOM importado cubre.

**Nota de la medición:** `spring-boot-dependencies:3.4.0` **ya no gobierna MapStruct** (la propiedad `mapstruct.version` no existe). Se añadió al BOM como `epc.mapstruct.version=1.6.3`; `janino` y `r2dbc-h2` sí los governa Boot y se eliminaron del BOM. La tabla §1.4.2 de `architecture-002.md` queda corregida con estos datos.

## Consecuencias

### Positivas

- El criterio #5 se reescribe con el mecanismo real: la definición de la versión vive en un solo fichero y el consumo se actualiza subiendo una línea en el `import`.
- `annotationProcessorPaths` **sí** resuelve versión desde el BOM (CA #11 sin excepción).

### Negativas y riesgos

- Hoy `spring-boot-starter-parent:3.4.0` es **literal** en el `pom.xml` de `quizapi` y no se puede gobernar desde el BOM: un `import` no puede fijar la versión del `<parent>`. La versión del BOM y la del parent de cada ms deben coincidir; Renovate sube las dos.
- Camino futuro identificado y **no aplicado**: que el parent del ms sea `common-parent`, cuyo parent sería `spring-boot-starter-parent`. Queda fuera de este objetivo.

### Coste

0 USD.
