package com.epc.common.web;

import com.epc.common.error.ApiResponse;
import com.epc.common.error.CommonException;
import com.epc.common.error.ErrorApiResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Advice por defecto de la capa comun (reactivo). No es un {@code @Component}: es un bean de la
 * auto-configuracion, porque {@code @ConditionalOnMissingBean} solo es fiable en auto-configuracion.
 *
 * <p>El stack trace nunca sale hacia el cliente; se registra en el log.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
  private static final String UNEXPECTED_ERROR_MESSAGE = "Unexpected error";

  /** Error de negocio: se expone su mensaje y su contexto, que son datos, no estructura interna. */
  @ExceptionHandler(CommonException.class)
  public ResponseEntity<ApiResponse> handleCommonException(CommonException ex) {
    log.error("Business error: {}", ex.getMessage(), ex);
    ErrorApiResponse response = new ErrorApiResponse(ex.getData(), ex.getMessage(),
        HttpStatus.INTERNAL_SERVER_ERROR.value());
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
  }

  /** Cualquier otra excepcion: mensaje generico en el cuerpo, detalle real en el log. */
  @ExceptionHandler(Exception.class)
  public ResponseEntity<ApiResponse> handleException(Exception ex) {
    log.error("Unhandled error", ex);
    ApiResponse response = new ApiResponse(ex.getMessage(), UNEXPECTED_ERROR_MESSAGE,
        HttpStatus.INTERNAL_SERVER_ERROR.value());
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
  }
}