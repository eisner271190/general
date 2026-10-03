# ADR-0001: Terraform vive en `cloud/terraform/<microservicio>/`

- **Fecha:** 2026-09-21
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** plan `plan-move-terraform-to-cloud.md`

## Contexto

El Terraform del proyecto estaba fuera del árbol de la aplicación generada, lo que rompía la premisa del generador: todo lo que se despliega se define en un componente y se materializa en `projects/<id>`.

## Decisión

Los `.tf` de cada microservicio viven en `cloud/terraform/<microservicio>/` dentro del proyecto generado y el directorio queda registrado en `components/cloud/aws/component.json`, de modo que el generador lo emite.

## Consecuencias

### Positivas

- El Terraform se genera y se versiona junto al microservicio que despliega.

### Negativas y riesgos

- Cada microservicio nuevo necesita su entrada en `component.json`.

### Coste

0 USD (solo ficheros de instrucción).
