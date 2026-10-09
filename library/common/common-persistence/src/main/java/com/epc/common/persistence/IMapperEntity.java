package com.epc.common.persistence;

public interface IMapperEntity<P, E> {
    P toPersistenceModel(E entity);
    E toEntity(P persistenceModel);
}
