package com.epc.samples.web;

import com.epc.common.error.ApiResponse;
import com.epc.common.error.CommonException;
import com.epc.common.error.ErrorApiResponse;
import com.epc.common.web.GlobalExceptionHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Advice propio del microservicio. Al ser un bean de tipo {@link GlobalExceptionHandler} hace que
 * la auto-configuracion de common-web no registre el suyo: queda un solo handler de
 * {@link CommonException} y es este.
 */
@RestControllerAdvice
public class SampleExceptionHandler extends GlobalExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(SampleExceptionHandler.class);
  private static final String SAMPLE_MESSAGE = "Manejado por el advice de la muestra";

  @Override
  @ExceptionHandler(CommonException.class)
  public ResponseEntity<ApiResponse> handleCommonException(CommonException ex) {
    log.error("Error de negocio capturado por el advice de la muestra: {}", ex.getMessage());
    ErrorApiResponse response =
        new ErrorApiResponse(ex.getData(), SAMPLE_MESSAGE, HttpStatus.INTERNAL_SERVER_ERROR.value());
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
  }
}