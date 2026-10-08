# ADR-0025: Logs estructurados en JSON con logstash-logback-encoder

- Estado: `propuesto` (pendiente de aprobacion del usuario)
- Fecha: `2026-10-07`
- Objetivo: `obj-003`

## Contexto

- `library/common` es un multi-modulo Maven en Java 17.
- El motor efectivo es slf4j + logback (logback llega por `spring-boot-starter`).
- `common-log` solo expone hoy `MdcCorrelation`: sin beans, sin punto deinyeccion.
- 27 plantillas del `generator` loguean con `LoggerFactory` y literales sueltos.
- Los datos sensibles no se enmascaran de forma centralizada.
- Lambda indexa solo el primer JSON de cada linea y exige `level` y `timestamp` RFC 3339.

## Decision

- Motor: se mantiene logback y se anade `net.logstash.logback:logstash-logback-encoder` 8.x.
- Puerto: interfaz `ILogService` en `com.epc.common.log`, inyectada por constructor.
- Bean: `CommonLogAutoConfiguration` con su propio `AutoConfiguration.imports` y
  `@ConditionalOnMissingBean`.
- Enmascarado: `MaskingJsonGeneratorDecorator` por `<path>` de un token, mascara `***`.
- Esquema JSON fijo: `timestamp`, `level`, `message`, `logger`, `thread`, `stack_trace`,
  `requestId`.
- Textos: `LogMessages` en `common-log` y `DomainLogMessages` por microservicio.

## Alternativas consideradas

| Alternativa | Motivo de descarte |
|---|---|
| Migrar a Log4j2 con `JsonTemplateLayout` | Cambia el motor en todos los ms sin ganancia |
| `logback-json` (ch.qos.logback.contrib) | Sin mantenimiento; reportado como no soportado |
| `MaskingConverter` de logback | No existe en logback-classic: supuesto falso del enunciado |
| Enmascarado por regex sobre el valor | La propia libreria lo marca como mucho mas caro que por path |
| Campo estatico `LoggerFactory` en cada clase | Acopla cada clase al logger e impide sustituirlo |
| MDC inyectado como bean | MDC es clase final de metodos estaticos: no es inyectable |

## Consecuencias

- Positivas: JSON consultable en CloudWatch, trazabilidad por `requestId`, enmascarado
  centralizado, textos sin literales sueltos.
- Negativas: una dependencia nueva; `debug` expone PII si alguien sube el nivel en Lambda;
  el `info` en cada metodo multiplica volumen ingerido.
- Mitigaciones: nivel efectivo `info` en Lambda; lista fija de campos sensibles aprobada por
  el usuario el `2026-10-07`.

## Notas

- Version 8.x: la 9.x exige Jackson 3 y el proyecto usa Jackson 2 con Spring Boot 3.4.0.
- `common-log` pasa de `1.0.0` a `1.1.0` porque su API esta congelada en esa version.
- Sin cambios en Terraform ni IAM: el log group por defecto `/aws/lambda/quizapi` basta.
- Requiere verificar que CodeArtifact replica la dependencia antes de implementar.
