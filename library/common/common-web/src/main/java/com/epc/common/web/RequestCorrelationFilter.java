package com.epc.common.web;

import com.epc.common.log.MdcCorrelation;
import java.util.UUID;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

/**
 * Filtro que correlaciona la peticion: lee {@code X-Request-Id} o genera un UUID, lo publica en el
 * MDC y lo limpia al terminar. Corre primero que todo lo demas, y no lo hace ningun advice, para
 * que hasta el error mas temprano lleve identificador.
 */
public class RequestCorrelationFilter implements WebFilter, Ordered {

  private static final String REQUEST_ID_HEADER = "X-Request-Id";

  @Override
  public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
    MdcCorrelation.put(resolveRequestId(exchange));
    return chain.filter(exchange).doFinally(signalType -> MdcCorrelation.clear());
  }

  @Override
  public int getOrder() {
    return Ordered.HIGHEST_PRECEDENCE;
  }

  private String resolveRequestId(ServerWebExchange exchange) {
    String requestId = exchange.getRequest().getHeaders().getFirst(REQUEST_ID_HEADER);
    if (requestId != null && !requestId.isBlank()) {
      return requestId;
    }
    return UUID.randomUUID().toString();
  }
}