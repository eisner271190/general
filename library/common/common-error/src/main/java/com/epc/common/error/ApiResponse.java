package com.epc.common.error;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Contrato de respuesta de la API.
 *
 * <p>Clase mutable (no record) y con constructor no-arg porque los clientes la deserializan desde
 * JSON. El {@code timestamp} se genera en UTC; el tipo sigue siendo {@link LocalDateTime} para no
 * cambiar el JSON que consume el cliente.
 */
public class ApiResponse {

  private Map<String, Object> data;
  private String message;
  private int status;
  private LocalDateTime timestamp;

  public ApiResponse() {
  }

  public ApiResponse(Map<String, Object> data, String message, int status) {
    this.data = data;
    this.message = message;
    this.status = status;
    this.timestamp = LocalDateTime.now(Clock.systemUTC());
  }

  /**
   * Sobrecarga para quando el dato no es un mapa: se envuelve en {@code {"data": x}}. Existe para
   * desambiguar un {@code null} frente al constructor de mapa.
   */
  public ApiResponse(Object data, String message, int status) {
    this.data = new HashMap<>();
    this.data.put("data", data);
    this.message = message;
    this.status = status;
    this.timestamp = LocalDateTime.now(Clock.systemUTC());
  }

  public Map<String, Object> getData() {
    return data;
  }

  public void setData(Map<String, Object> data) {
    this.data = data;
  }

  public String getMessage() {
    return message;
  }

  public void setMessage(String message) {
    this.message = message;
  }

  public int getStatus() {
    return status;
  }

  public void setStatus(int status) {
    this.status = status;
  }

  public LocalDateTime getTimestamp() {
    return timestamp;
  }

  public void setTimestamp(LocalDateTime timestamp) {
    this.timestamp = timestamp;
  }
}