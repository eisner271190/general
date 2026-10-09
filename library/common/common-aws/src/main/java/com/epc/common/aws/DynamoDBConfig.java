package com.epc.common.aws;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

/** Clientes DynamoDB (cliente base y enhanced). */
@Configuration
public class DynamoDBConfig {

    @Value("${aws.region}")
    private String awsRegion;

    @Bean
    public DynamoDbClient dynamoDbClient() {
        return DynamoDbClient.create();
    }

    @Bean
    public DynamoDbEnhancedClient enhancedClient(DynamoDbClient client) {
        return DynamoDbEnhancedClient.builder()
                .dynamoDbClient(client)
                .build();
    }
}
