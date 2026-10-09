package com.epc.common.persistence;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class MapperInfo {

    private String tableName;
    private Class<?> persistenceModelClass;
    private Class<?> dynamoModelClass;
    private IMapperDynamo mapperDynamo;
    private IMapperEntity mapperEntity;

    public String getTableName() {
        return tableName;
    }

    public void setTableName(String tableName) {
        this.tableName = tableName;
    }

    public Class<?> getPersistenceModelClass() {
        return persistenceModelClass;
    }

    public void setPersistenceModelClass(Class<?> persistenceModelClass) {
        this.persistenceModelClass = persistenceModelClass;
    }

    public Class<?> getDynamoModelClass() {
        return dynamoModelClass;
    }

    public void setDynamoModelClass(Class<?> dynamoModelClass) {
        this.dynamoModelClass = dynamoModelClass;
    }

    public IMapperDynamo getMapperDynamo() {
        return mapperDynamo;
    }

    public void setMapperDynamo(IMapperDynamo mapperDynamo) {
        this.mapperDynamo = mapperDynamo;
    }

    public IMapperEntity getMapperEntity() {
        return mapperEntity;
    }

    public void setMapperEntity(IMapperEntity mapperEntity) {
        this.mapperEntity = mapperEntity;
    }
}
