---
name: Clean Code
description: Principios y reglas de código limpio (SOLID, DRY, KISS, naming) al escribir, revisar o refactorizar código en cualquier stack
---

## Principios
1. **SRP** — una responsabilidad por clase, método o módulo.
2. **OCP** — extender por abstracción; no modificar estable sin necesidad.
3. **LSP** — las implementaciones respetan los contratos de su abstracción.
4. **ISP** — interfaces pequeñas y focadas, no gigantes.
5. **DIP** — casos de alto nivel dependen de abstracciones, no de infraestructura.
6. **DRY** — centralizar reglas, transformaciones y validaciones duplicadas.
7. **KISS** — el diseño más simple que satisfaga el requisito.
8. **YAGNI** — no introducir abstracciones sin caso de uso actual.
9. **Fail fast** — validar entradas e invariantes antes de mutar estado.
10. **Separación de concerns** — dominio / aplicación / infraestructura / presentación independientes.
11. **G30 (énfasis fuerte)** — una función = una cosa; si hace "y" (dos verbos o dos acciones en el nombre/cuerpo), extraer de inmediato en un método con un solo propósito. Regla de oro al escribir **y** al revisar.

## Naming
- Inglés para identificadores; PascalCase clases/métodos/públicos; camelCase locales/privados; prefijo `I` en interfaces.
- Verbos para métodos (`BuildPlan`, `ValidateConfiguration`); nombres para modelos (`GenerationPlan`).
- Sin siglas sin explicar ni nombres de una letra; el nombre revela intención, no implementación.

## Diseño
- Patrones solo si resuelven un problema concreto: Application Service, Builder, Strategy, Factory, Repository, DI.
- Si el comportamiento es simple, implementación directa gana (no adornar la arquitectura).

## Discipline de cambio
- El cambio más pequeño que resuelva el requisito; preservar contratos públicos; sin refactors no relacionados en el mismo cambio; actualizar documentación si cambia comportamiento; revisar el diff al terminar.

## Checklist detallada
Ver `references/checklist.md` de este skill (reglas G1–G30 de Clean Code).
