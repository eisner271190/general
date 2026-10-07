---
name: Clean Code
description: Principios y reglas de código limpio para escribir, revisar o refactorizar software
---

## Alcance
Usa esta skill al escribir, revisar o refactorizar código en cualquier stack.

## Flujo de trabajo
1. Comprende el requisito y el código existente antes de cambiarlo.
2. Aplica los principios generales y las reglas EPC pertinentes al cambio.
3. Revisa el diff y confirma que el cambio es mínimo y conserva los contratos.

## Principios
1. **SRP** — una responsabilidad por clase, método o módulo.
2. **OCP** — extender por abstracción; no modificar estable sin necesidad.
3. **LSP** — las implementaciones respetan los contratos de su abstracción.
4. **ISP** — interfaces pequeñas y enfocadas, no gigantes.
5. **DIP** — casos de alto nivel dependen de abstracciones, no de infraestructura.
6. **DRY** — centralizar reglas, transformaciones y validaciones duplicadas.
7. **KISS** — el diseño más simple que satisfaga el requisito.
8. **YAGNI** — no introducir abstracciones sin caso de uso actual.
9. **Fail fast** — validar entradas e invariantes antes de mutar estado.
10. **Separación de concerns** — dominio, aplicación, infraestructura y presentación
    independientes.
11. **G30 (énfasis fuerte)** — una función = una cosa; si hace "y" (dos verbos o dos acciones
    en el nombre/cuerpo), extraer de inmediato en un método con un solo propósito. Regla de oro
    al escribir y al revisar.

## Naming
- Inglés para identificadores; PascalCase para clases, métodos y públicos; camelCase para
  locales y privados; prefijo `I` en interfaces.
- Verbos para métodos (`BuildPlan`, `ValidateConfiguration`); nombres para modelos
  (`GenerationPlan`).
- Sin siglas sin explicar ni nombres de una letra; el nombre revela intención, no implementación.

## Diseño
- Patrones solo si resuelven un problema concreto: Application Service, Builder, Strategy,
  Factory, Repository o DI.
- Si el comportamiento es simple, gana la implementación directa.
- Cuando existan múltiples variantes de una operación, encapsula cada variante en una
  implementación de Strategy y ejecútalas mediante la abstracción común.
- Propicia el uso del patrón Facade para simplificar métodos.

## Reglas EPC
- R1: Los métodos deben tener máximo 20 líneas. Extraer lógica a métodos auxiliares cuando sea
  necesario.
- R2: Extraer toda lógica contenida dentro de bloques de llaves en métodos auxiliares. Extraer
  cada `if`/`for` a un método.
- R3: Definir una única clase o interfaz por archivo.
- R4: Cuando existan múltiples variantes de una operación, encapsular cada variante en una
  implementación de Strategy y ejecutarlas mediante la abstracción común.
- R5: Todos los queries deben estar encapsulados en métodos.
- R6: Extraer una condición cuando combine dos o más comparaciones mediante operadores lógicos,
  o cuando su expresión requiera interpretación para entender su intención.
- R7: Limitar los métodos a un máximo de dos parámetros. Si un método requiere más, agruparlos
  en una abstracción; esta excepción solo aplica a métodos Factory.
- R8: No instanciar objetos directamente en el flujo principal; encapsular cada creación en un
  método dedicado y descriptivo.
- R9: Siempre agregar `log.info` para registrar la entrada y salida de los métodos.
- R10: Siempre agregar `log.debug` para registrar información detallada durante la ejecución de
  los métodos: parámetros, variables y línea por línea.
- R11: Crear una clase para los mensajes y logs, para centralizar y estandarizar su gestión en
  toda la aplicación.
- R12: Crear una clase para las constantes, para centralizar y estandarizar los valores
  constantes en toda la aplicación.
- R13 (Facade): usar Facade para simplificar métodos; por ejemplo, un método de procesamiento
  puede delegar validación, cálculo, persistencia y notificación a operaciones dedicadas.

## Disciplina de cambio
- Hacer el cambio más pequeño que resuelva el requisito.
- Preservar contratos públicos y evitar refactors no relacionados.
- Actualizar documentación si cambia el comportamiento y revisar el diff al terminar.

## Checklist detallada
Ver `references/checklist.md` para las reglas G1–G30 de Clean Code.

## Requisitos y límites
- Validar entradas e invariantes antes de mutar estado.
- Si falta información esencial, preguntar antes de asumir.

## Resultado
Entregar código claro y el cambio mínimo necesario; informar brevemente qué se modificó y qué
verificaciones se ejecutaron.
