package com.epc.common.log;

/**
 * Textos transversales de log. Los textos propios de cada microservicio viven en su
 * {@code DomainLogMessages} generado; aqui solo queda lo que es igual en todos.
 */
public final class LogMessages {

  private LogMessages() {
    throw new IllegalStateException("Utility class");
  }

  /** Arranque de la aplicacion, con la version y el ambiente ya resueltos por Spring. */
  public static final String APPLICATION_STARTED =
      "Application {} started in environment {}";

  /** Entrada generica de un metodo. */
  public static final String METHOD_ENTER = "Entering {}";

  /** Salida generica de un metodo. */
  public static final String METHOD_EXIT = "Exiting {}";

  /** Error de negocio con su contexto: el stack trace va al log, no al cliente. */
  public static final String BUSINESS_ERROR = "Business error: {}";

  /** Error no previsto: al cliente solo le llega un mensaje generico. */
  public static final String UNHANDLED_ERROR = "Unhandled error";
}
