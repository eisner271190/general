package com.epc.common.persistence;

public interface IMapperDynamo<P, D> {
    P toPersistenceModel(D dynamo);
    D toDynamo(P persistenceModel);
}
