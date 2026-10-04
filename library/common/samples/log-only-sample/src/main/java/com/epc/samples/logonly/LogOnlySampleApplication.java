package com.epc.samples.logonly;

import com.epc.common.log.MdcCorrelation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.stereotype.Component;

@SpringBootApplication
public class LogOnlySampleApplication {

  public static void main(String[] args) {
    SpringApplication.run(LogOnlySampleApplication.class, args);
  }

  /** Escribe una linea correlacionada y otra sin correlacionar, para ver el efecto del MDC. */
  @Component
  static class CorrelationDemo implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(CorrelationDemo.class);

    @Override
    public void run(String... args) {
      log.info("Microservicio sin web: arranca sin common-web en el classpath");
      MdcCorrelation.put("sample-request-id");
      log.info("Linea correlacionada");
      MdcCorrelation.clear();
      log.info("Linea sin correlacionar");
    }
  }
}