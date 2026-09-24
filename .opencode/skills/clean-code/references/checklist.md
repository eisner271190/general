# Clean Code — Checklist (G1–G30)

Fuente: reglas de Robert C. Martin condensadas (dev.to: "Skills, Not Vibes").

## Nombres y expresión
- G18: sin estáticos inappropriate; G20: nombres de función que digan qué hacen.
- G19: usar variables explicativas en lugar de expresiones crípticas.
- G25: reemplazar números mágicos por constantes con nombre.
- G26: ser preciso — no ambigüedades en identificadores ni mensajes.
- G24: seguir convenciones del lenguaje/stack.

## Funciones
- G30: una función = una cosa; extraer si hace "y".
- G31: acoplamientos temporales ocultos (orden de llamadas) → hacer explícitos.
- G22: dependencias lógicas → físicas (parámetros/constructor, no globals).
- G29: evitar negaciones en condicionales (enmascarar con nombres positivos).
- G18: estado compartido mutable → encapsular.

## Estructura
- G5: DRY — copy/paste, mismo cálculo en dos sitios, patrón repetido → extraer.
- G3: límites y boundary conditions — validar índices, null, longitudes.
- G4: no anular salvaguardas — no ignorar validaciones existentes.
- G23: preferir polimorfismo a cadenas gigantes de if/switch cuando el conjunto crece.
- G27: estructura sobre convención implícita; G28: encapsular condicionales en métodos con nombre.
- G21: entender el algoritmo antes de refactorizar; G17(implícito): comentarios solo del "porqué".

## Señales de deuda generada por IA (revisar siempre)
- Duplicación encubierta entre módulos.
- Falta de validación de bordes y null checks.
- Readability: funciones largas, nombres genéricos (`data`, `temp`, `info`).
- Excepciones tragadas, prints/debug en vez de logging.
- Tests ausentes o deshabilitados para "hacer pasar" la suite.
