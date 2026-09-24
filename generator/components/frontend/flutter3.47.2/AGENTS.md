# Plantillas frontend Flutter 3.47.2

## Qué es aquí
Plantillas Scriban que generan la app Flutter (`pubspec.yaml`, `analysis_options.yaml`, assets `.env.*`, CI AWS `buildspec.yml`/`codepipeline.yml`) + `defaults/` (íconos, assets Android/iOS copiados tal cual).

## Convenciones y comandos
- Cargar el skill `flutter`: formato/análisis/tests, estado, UI, lints, seguridad.

## Reglas
- Los `.env.*` son plantillas con placeholders: jamás valores reales ni secretos en git.
- Cambios de plantilla pasan por `component.json` (solo la lista `files` se copia).
