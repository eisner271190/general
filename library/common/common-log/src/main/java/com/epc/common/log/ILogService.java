package com.epc.common.log;

import java.util.Map;

/**
 * Puerto de logging del microservicio. Se inyecta por constructor: la clase que lo usa no depende
 * de ningun motor concreto, luego el bean se puede sustituir desde el propio microservicio.
 *
 * <p>Convenio: placeholders {@code {}} con {@code Object...}. El mapa es la excepcion para campos
 * sueltos que no caben en el texto. La excepcion ({@code Throwable}) va en su propio overload,
 * nunca como {@code {}}.
 */
public interface ILogService {

  void debug(String message);

  void debug(String message, Object... args);

  void debug(String message, Map<String, Object> fields);

  void info(String message);

  void info(String message, Object... args);

  void info(String message, Map<String, Object> fields);

  void warn(String message, Object... args);

  void warn(String message, Throwable error);

  void error(String message, Object... args);

  void error(String message, Throwable error);

  /**
   * Ejecuta la accion con el identificador de peticion publicado en el MDC y lo limpia al
   * terminar, tambien si la accion falla.
   */
  void withRequestId(String requestId, Runnable action);

  /** Limpia la clave de correccion. {@code withRequestId} ya lo hace en su {@code finally}. */
  void clearRequestId();
}
