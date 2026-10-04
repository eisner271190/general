package com.epc.samples.web;

import com.epc.common.error.CommonException;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SampleController {

  @GetMapping("/hello")
  public Map<String, String> hello() {
    return Map.of("message", "Hola Mundo");
  }

  /** Lanza la excepcion de la capa comun: la resuelve el advice que gane. */
  @GetMapping("/error")
  public Map<String, String> error() throws CommonException {
    throw new CommonException("Error de negocio de la muestra");
  }
}