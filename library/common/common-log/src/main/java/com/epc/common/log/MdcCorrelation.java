package com.epc.common.log;

import org.slf4j.MDC;

/**
 * Correlacion de logs sin dependencia de web: escribe y limpia la clave {@code requestId} del MDC.
 *
 * <p>API congelada en {@code 1.0.0}. Quien necesite mas claves de correccion las anade en el
 * siguiente release con valor semantico.
 */
public final class MdcCorrelation {

  /** Clave del MDC con el identificador de la peticion en curso. */
  public static final String REQUEST_ID_KEY = "requestId";

  private MdcCorrelation() {
    throw new IllegalStateException("Utility class");
  }

  /**
   * Publica el identificador de la peticion en el MDC. Los valores vacios se ignoran para no
   * sobreescribir con null lo que haya dejado una peticion anterior del mismo hilo.
   */
  public static void put(String requestId) {
    if (isEmpty(requestId)) {
      return;
    }
    MDC.put(REQUEST_ID_KEY, requestId);
  }

  /** Devuelve el identificador de la peticion en curso, o {@code null} si no hay. */
  public static String get() {
    return MDC.get(REQUEST_ID_KEY);
  }

  /** Limpia la clave de correccion. Se invoca siempre al terminar la peticion. */
  public static void clear() {
    MDC.remove(REQUEST_ID_KEY);
  }

  private static boolean isEmpty(String value) {
    return value == null || value.isBlank();
  }
}