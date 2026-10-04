# Cómo usar `common`

## Qué se registra al arrancar

`common-web` se registra por `AutoConfiguration.imports`. Al arrancar un microservicio WebFlux:

1. `RequestCorrelationFilter` lee `X-Request-Id` (o genera un UUID), lo publica en el MDC con la
   clave `requestId` y lo limpia al terminar la petición. Corre con `HIGHEST_PRECEDENCE`, así que
   hasta el error más temprano lleva identificador.
2. `GlobalExceptionHandler` se registra **solo si el microservicio no define el suyo**.

Para ver el `requestId` en los logs, el patrón del `logback.xml` del microservicio debe incluirlo:

```xml
<pattern>%d{yyyy-MM-dd HH:mm:ss} %-5level [%X{requestId}] %logger{36} - %msg%n</pattern>
```

## Desactivar el advice propio

**No hay propiedad para desactivarlo.** Si el microservicio quiere su propio manejo de errores,
debe declarar un bean de tipo `com.epc.common.web.GlobalExceptionHandler`: la auto-configuración se
retira sola por `@ConditionalOnMissingBean`.

Lo normal es extenderlo y sobrescribir solo el handler que cambie:

```java
@RestControllerAdvice
public class MiExceptionHandler extends GlobalExceptionHandler {

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

`MdcCorrelation` funciona sin web (jobs, consumidores SQS, batch):

```java
MdcCorrelation.put(idDeLaPeticion);
try {
  hacerTrabajo();
} finally {
  MdcCorrelation.clear();
}
```

## API congelada

La API pública de `common-log` (`MdcCorrelation`) queda congelada en `1.0.0`. Añadir claves de
correlación con valor semántico requiere un release mayor.

## Coste en Lambda

`common-web` declara Spring como `provided`: no arrastra reactor-netty ni starters. El peso en el
cold start lo pone el `spring-boot-starter-webflux` que ya tenía el microservicio. Un
microservicio que importe solo `common-log` no carga ninguna clase de WebFlux.