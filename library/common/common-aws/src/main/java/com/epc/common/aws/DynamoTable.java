package com.epc.common.aws;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** Nombre de la tabla DynamoDB asociada a una entidad. */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface DynamoTable {
    String value();
}
