# ADR-0003: Criterio de "tarea grande"

- **Fecha:** 2026-09-23
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** workspace
- **Origen:** —

## Contexto

Sin un umbral objetivo, el agente decidía por intuición cuándo un cambio necesitaba plan previo, y los cambios estructurales (migraciones de BD, renombrados) llegaban a revisión ya applied.

## Decisión

Una tarea es grande si supera cualquiera de estos umbrales: **más de 5 ficheros**, **más de 2 capas o componentes**, o **diff estimado superior a 400 líneas**. Riesgo alto (cambios de base de datos, migraciones, renombrados) obliga a hacer plan **primero**, aunque la tarea sea pequeña.

## Consecuencias

### Positivas

- El umbral es verificable y no depende del criterio del agente.

### Negativas y riesgos

- Tareas de 6 ficheros triviales pasan por plan; es el sobrecoste aceptado.

### Coste

0 USD.
