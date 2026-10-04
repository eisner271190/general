package com.epc.common.web;

import com.epc.common.error.ApiResponse;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnClass;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.web.server.WebFilter;

/**
 * Auto-configuracion de common-web. Se registra por
 * {@code META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports}.
 *
 * <p>Las condiciones de contexto van en la clase; el "gana el del microservicio" va en los metodos
 * {@code @Bean}, porque las condiciones de una clase devuelta por {@code @Bean} no se evaluan.
 */
@AutoConfiguration
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.REACTIVE)
@ConditionalOnClass({WebFilter.class, ApiResponse.class})
public class WebAutoConfiguration {

  /** El advice propio del microservicio gana: basta con declarar un bean de este tipo. */
  @Bean
  @ConditionalOnMissingBean(GlobalExceptionHandler.class)
  public GlobalExceptionHandler globalExceptionHandler() {
    return new GlobalExceptionHandler();
  }

  @Bean
  @ConditionalOnMissingBean(name = "requestCorrelationFilter")
  public RequestCorrelationFilter requestCorrelationFilter() {
    return new RequestCorrelationFilter();
  }
}