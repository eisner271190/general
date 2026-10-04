package com.epc.common.error;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.Map;

/**
 * Respuesta de error. El campo {@code stackTrace} se conserva por compatibilidad de contrato pero
 * el advice nunca lo puebla: el stack va al log con {@code log.error}. Con
 * {@link JsonInclude.Include#NON_NULL} la clave no aparece en el JSON.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ErrorApiResponse extends ApiResponse {

  private String stackTrace;

  public ErrorApiResponse(Map<String, Object> data, String message, int status) {
    super(data, message, status);
  }

  public String getStackTrace() {
    return stackTrace;
  }

  public void setStackTrace(String stackTrace) {
    this.stackTrace = stackTrace;
  }
}