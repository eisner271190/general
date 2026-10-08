package com.epc.samples.logonly;

import com.epc.common.log.ILogService;
import com.epc.common.log.LogMessages;
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

    private final ILogService log;

    CorrelationDemo(ILogService log) {
      this.log = log;
    }

    @Override
    public void run(String... args) {
      log.info("Microservicio sin web: arranca sin common-web en el classpath");
      log.withRequestId("sample-request-id", () -> log.info(LogMessages.METHOD_ENTER, "sample"));
      log.info(LogMessages.METHOD_EXIT, "sample");
    }
  }
}