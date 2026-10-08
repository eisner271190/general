package com.epc.common.log;

import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;

/**
 * Registra el puerto de logging por auto-configuracion, para que ningun microservicio tenga que
 * declarar el bean. Se registra por
 * {@code META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports}.
 *
 * <p>El microservicio puede sobrescribirlo: basta con declarar su propio bean {@code ILogService}.
 */
@AutoConfiguration
public class CommonLogAutoConfiguration {

  @Bean
  @ConditionalOnMissingBean(ILogService.class)
  public ILogService logService() {
    return new Slf4jLogService(LoggerFactory.getLogger(Slf4jLogService.class));
  }
}
