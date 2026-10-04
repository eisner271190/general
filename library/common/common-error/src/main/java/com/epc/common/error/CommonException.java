package com.epc.common.error;

import java.util.HashMap;
import java.util.Map;

/**
 * Excepcion de negocio de la capa comun. Es checked a proposito: el microservicio decide donde se
 * propaga y la resuelve su propio advice o el de common-web.
 */
public class CommonException extends Exception {

  private final Map<String, Object> data;

  public CommonException(String message) {
    super(message);
    this.data = new HashMap<>();
  }

  /** Anade contexto al error que acabara en el cuerpo de la respuesta. */
  public void addData(String key, Object value) {
    this.data.put(key, value);
  }

  public Map<String, Object> getData() {
    return data;
  }
}