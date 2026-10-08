# common

Componente reutilizable para los microservicios Java: contrato de error, puerto de logging con
salida JSON en CloudWatch, correlación de logs y **un único sitio donde vive la versión de cada
dependencia**.

## Módulos

| Módulo | Qué trae | Depende de |
| --- | --- | --- |
| `common-bom` | Gobierno de versiones (solo `dependencyManagement`) | — |
| `common-log` | `ILogService` + `Slf4jLogService` (auto-configuración), `LogMessages`, `MdcCorrelation`, `logback-base.xml` | `slf4j-api`, spring-boot-starter (provided) |
| `common-error` | `ApiResponse`, `ErrorApiResponse`, `CommonException` | `jackson-annotations` (provided) |
| `common-web` | `GlobalExceptionHandler` + filtro de correlación, por auto-configuración WebFlux | `common-log`, `common-error`, spring (provided) |

`common-web` es la **única** capa que toca web. Un microservicio que solo quiere logging importa
`common-log` y no arrastra WebFlux ni reactor-netty.

## Logs estructurados

El puerto de logging se inyecta por constructor y sale por `CommonLogAutoConfiguration`, así que el
microservicio no declara ningún bean:

```java
@Service
public class MiUseCase {

  private final ILogService log;

  public MiUseCase(ILogService log) {
    this.log = log;
  }

  public Mono<Respuesta> ejecutar(String id) {
    log.info("Ejecutando {}", id);          // R9: info en la entrada
    log.debug("id={} pag={}", id, pagina); // R10: debug para parámetros
    return ...
  }
}
```

La salida es una línea JSON por evento (`LogstashEncoder` con esquema fijo `timestamp`, `level`,
`message`, `logger`, `thread`, `stack_trace`, `requestId`) y los campos sensibles de la lista
aprobada salen enmascarados como `***`. Detalle: `docs/como-usar.md`.

## Build

```bash
mvn clean install        # compila e instala 1.1.0 en el repositorio local
```

Compila **fuera** de Docker desde que la imagen base es de runtime: el `docker build` del
microservicio solo copia `target/classes` y `target/dependency/`.

```bash
mvn -B compile dependency:copy-dependencies -DincludeScope=runtime
docker build -t mi-ms .
```

## Versión

Una sola, `1.1.0`, literal, sin `${revision}` ni SNAPSHOT. Se bumpea en `pom.xml` (una línea) antes
de publicar. Ver `docs/como-versionar.md`.

## Consumirlo

1. Conserva tu `<parent>spring-boot-starter-parent</parent>`.
2. Añade el `import` de `com.epc.common:common-bom` en tu `<dependencyManagement>`.
3. Declara las dependencias **sin `<version>`**: `common-web` (o `common-log`), más
   `net.logstash.logback:logstash-logback-encoder` en scope `runtime` para el encoder de JSON.

Detalle y snippets: `docs/como-migrar-un-ms.md`.

## Documentación

- `docs/como-usar.md` — el puerto de logging, el esquema JSON, qué se registra al arrancar.
- `docs/como-versionar.md` — publicar una versión nueva.
- `docs/como-migrar-un-ms.md` — migración de un microservicio existente.

## Publicación

`platform/buildspecs/java-ci.yml` valida; el pipeline publica en CodeArtifact y sube
`epc/common-base:<version>` a ECR. El token llega por `CODEARTIFACT_AUTH_TOKEN`, nunca en el repo.
