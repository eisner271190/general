# Cómo usar `common`

## El puerto de logging

`ILogService` vive en `com.epc.common.log` y se inyecta por constructor. El bean lo registra
`CommonLogAutoConfiguration` por `AutoConfiguration.imports`: el microservicio no declara nada.

```java
@Service
public class MiUseCase {

  private final ILogService log;

  public MiUseCase(ILogService log) {
    this.log = log;
  }

  public Mono<Respuesta> ejecutar(String id) {
    log.info(MiLogMessages.EXECUTE_STARTED, id);   // R9: info en la entrada
    log.debug("id={} pagina={}", id, pagina);     // R10: debug para parámetros y variables
    return servicio.cargar(id);
  }
}
```

Convenciones del puerto:

- `{}` con `Object...` es la norma; el overload con `Map<String, Object>` es para campos sueltos que
  no caben en el texto.
- La excepción va en su propio overload (`error(msg, ex)`), nunca como `{}`.
- `withRequestId(id, accion)` publica el `requestId` en el MDC, ejecuta la acción y limpia en el
  `finally`; `clearRequestId()` es para el código reactivo, que no puede usar `Runnable`.
- Para sustituir el motor, el microservicio declara su propio bean `ILogService`:
  `@ConditionalOnMissingBean` se retira solo.

## Los textos de log

- `com.epc.common.log.LogMessages`: lo transversal (arranque, entrada/salida genérica, errores).
- `DomainLogMessages` en `infrastructure.configuration`: lo propio de cada microservicio, generado
  por plantilla siguiendo el precedente de `AiMessages`.

No se escribe el texto dentro del `log.info(...)`: va en su constante.

## Salida JSON en CloudWatch

`common-log` publica `logback-base.xml` como recurso. Usa `LogstashEncoder` con esquema fijo:

| Clave | Origen |
| --- | --- |
| `timestamp` | `@timestamp`, ISO-8601 (RFC 3339) |
| `level` | nivel del evento |
| `message` | texto ya resuelto |
| `logger` | clase que emite |
| `thread` | hilo de ejecución |
| `stack_trace` | solo cuando hay excepción |
| `requestId` | clave `requestId` del MDC |

Un evento es **una línea JSON**: CloudWatch indexa solo el primer fragmento JSON de la línea, luego
agrupar eventos rompe la indexación. `level` y `timestamp` son los campos que Lambda usa para
indexar y filtrar.

## Enmascarado de datos sensibles

`MaskingJsonGeneratorDecorator` sustituye por `***` el valor de los campos de la lista aprobada:

```
password, passwd, secret, secretKey, clientSecret, token, accessToken, refreshToken,
idToken, apiKey, authorization, cookie, setCookie, sessionId, connectionString,
awsSecretAccessKey, awsSessionToken, cardNumber, pan, cvv, email, phone, documentId
```

El enmascarado es por **nombre de campo**, no por valor: la propia librería lo marca como mucho más
barato. No actúa sobre el MDC. Para añadir un campo a la lista hay que editar `logback-base.xml`.

El `common-log` no declara `logstash-logback-encoder`: solo se usa desde el XML, luego va como
dependencia `runtime` del microservicio.

## Qué se registra al arrancar

`common-web` se registra por `AutoConfiguration.imports`. Al arrancar un microservicio WebFlux:

1. `RequestCorrelationFilter` lee `X-Request-Id` (o genera un UUID), lo publica en el MDC con la
   clave `requestId` y lo limpia al terminar la petición. Corre con `HIGHEST_PRECEDENCE`, así que
   hasta el error más temprano lleva identificador.
2. `GlobalExceptionHandler` se registra **solo si el microservicio no define el suyo**.

## Desactivar el advice propio

**No hay propiedad para desactivarlo.** Si el microservicio quiere su propio manejo de errores,
debe declarar un bean de tipo `com.epc.common.web.GlobalExceptionHandler`: la auto-configuración se
retira sola por `@ConditionalOnMissingBean`.

Lo normal es extenderlo y sobrescribir solo el handler que cambie:

```java
@RestControllerAdvice
public class MiExceptionHandler extends GlobalExceptionHandler {

  public MiExceptionHandler(ILogService log) {
    super(log);
  }

  @Override
  @ExceptionHandler(CommonException.class)
  public ResponseEntity<ApiResponse> handleCommonException(CommonException ex) {
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(new ApiResponse(ex.getData(), ex.getMessage(), HttpStatus.BAD_REQUEST.value()));
  }
}
```

## Errores

`CommonException` es checked y lleva contexto (`addData`) que sale en el cuerpo de la respuesta:

```java
throw new CommonException("No se pudo procesar la subscription");
```

El advice la devuelve como `ErrorApiResponse` con el mensaje y el `data`. **El stack trace nunca sale
hacia el cliente**: se registra con `log.error(msg, ex)` y, como `ErrorApiResponse` es
`@JsonInclude(NON_NULL)`, la clave `stackTrace` no aparece en el JSON.

## Correlación desde código

`withRequestId` cubre el caso normal. Sin Spring (jobs, consumidores SQS, batch) el puerto sigue
sirviendo porque `MdcCorrelation` no depende de web:

```java
log.withRequestId(idDeLaPeticion, () -> hacerTrabajo());
```

El MDC no se propaga a los hilos de pool: quien use `Executors` copia con
`MDC.getCopyOfContextMap()` y `MDC.setContextMap()`.

## API congelada

La API pública de `common-log` (`MdcCorrelation`) quedó congelada en `1.0.0`. El puerto
`ILogService` se añadió en `1.1.0`. Añadir claves de correlación con valor semántico requiere un
release mayor.

## Coste en Lambda

`common-web` declara Spring como `provided`: no arrastra reactor-netty ni starters. `common-log`
también, de modo que un microservicio que solo importa `common-log` no carga ninguna clase de
WebFlux. El peso extra en el cold start es el `logstash-logback-encoder`, que se mide en la fase de
verificación. El nivel efectivo en Lambda es `info`: `debug` se activa por propiedad del
microservicio cuando se investiga.
