package com.epc.common.config;

import org.springframework.aot.hint.MemberCategory;
import org.springframework.aot.hint.RuntimeHints;
import org.springframework.aot.hint.RuntimeHintsRegistrar;

/** Pistas de reflexion para GraalVM native image: LogFactory y encoder JSON de logback. */
public class GraalHints implements RuntimeHintsRegistrar {

    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        hints.reflection().registerType(org.apache.commons.logging.LogFactory.class,
            builder -> builder.withMembers(MemberCategory.INVOKE_PUBLIC_CONSTRUCTORS)
                              .withMembers(MemberCategory.INVOKE_PUBLIC_METHODS));
        registerLogSt(hints, "net.logstash.logback.encoder.LogstashEncoder");
        registerLogSt(hints, "net.logstash.logback.mask.MaskingJsonGeneratorDecorator");
    }

    /** El encoder de JSON se instancia por nombre desde logback, no por codigo: lo ve reflection. */
    private void registerLogSt(RuntimeHints hints, String className) {
        try {
            hints.reflection().registerType(Class.forName(className, false, getClass().getClassLoader()),
                builder -> builder.withMembers(MemberCategory.INVOKE_PUBLIC_CONSTRUCTORS)
                                  .withMembers(MemberCategory.INVOKE_PUBLIC_METHODS));
        } catch (ClassNotFoundException e) {
            // Sin la libreria en el classpath nativo no hay nada que registrar.
        }
    }
}
