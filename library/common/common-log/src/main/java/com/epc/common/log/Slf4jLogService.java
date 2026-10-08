package com.epc.common.log;

import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.spi.LoggingEventBuilder;

/**
 * Implementacion del puerto sobre SLF4J.
 */
public final class Slf4jLogService implements ILogService {

  private final Logger logger;

  public Slf4jLogService(Logger logger) {
    this.logger = logger;
  }

  @Override
  public void debug(String message) {
    logger.debug(message);
  }

  @Override
  public void debug(String message, Object... args) {
    logger.debug(message, args);
  }

  @Override
  public void debug(String message, Map<String, Object> fields) {
    logWithFields(logger.atDebug(), message, fields);
  }

  @Override
  public void info(String message) {
    logger.info(message);
  }

  @Override
  public void info(String message, Object... args) {
    logger.info(message, args);
  }

  @Override
  public void info(String message, Map<String, Object> fields) {
    logWithFields(logger.atInfo(), message, fields);
  }

  @Override
  public void warn(String message, Object... args) {
    logger.warn(message, args);
  }

  @Override
  public void warn(String message, Throwable error) {
    logger.warn(message, error);
  }

  @Override
  public void error(String message, Object... args) {
    logger.error(message, args);
  }

  @Override
  public void error(String message, Throwable error) {
    logger.error(message, error);
  }

  @Override
  public void withRequestId(String requestId, Runnable action) {
    MdcCorrelation.put(requestId);
    try {
      action.run();
    } finally {
      clearRequestId();
    }
  }

  @Override
  public void clearRequestId() {
    MdcCorrelation.clear();
  }

  private static void logWithFields(LoggingEventBuilder event, String message,
      Map<String, Object> fields) {
    if (fields != null) {
      fields.forEach(event::addKeyValue);
    }
    event.log(message);
  }
}
