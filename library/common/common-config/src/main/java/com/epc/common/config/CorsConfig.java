package com.epc.common.config;

import com.epc.common.log.ILogService;
import java.util.Arrays;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.reactive.CorsWebFilter;
import org.springframework.web.cors.reactive.UrlBasedCorsConfigurationSource;
import org.springframework.web.reactive.config.CorsRegistry;
import org.springframework.web.reactive.config.WebFluxConfigurer;

/**
 * CORS transversal para WebFlux. Los textos de log son locales: la libreria no depende de la
 * aplicacion (D72).
 */
@Configuration
public class CorsConfig implements WebFluxConfigurer {

    private static final String CORS_MAPPINGS_CONFIGURED =
            "Configuring CORS mappings via WebFluxConfigurer.addCorsMappings";
    private static final String CORS_FILTER_CREATED = "Creating CorsWebFilter bean";

    private final ILogService log;

    public CorsConfig(ILogService log) {
        this.log = log;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        log.info(CORS_MAPPINGS_CONFIGURED);
        registry.addMapping("/**")
                .allowedOrigins(
                        "http://localhost:3000",
                        "http://127.0.0.1:3000"
                )
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }

    /** CorsWebFilter para peticiones: util con RouterFunctions y puntos de breakpoint. */
    @Bean
    public CorsWebFilter corsWebFilter() {
        log.info(CORS_FILTER_CREATED);
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(Arrays.asList("http://localhost:3000", "http://127.0.0.1:3000"));
        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.addAllowedHeader("*");
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return new CorsWebFilter(source);
    }
}
