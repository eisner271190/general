---
name: .NET Clean
description: Convenciones .NET (nullable, records, DI, mensajes, códigos de error, capas) para código C# y plantillas Scriban
---

## Base
- Nullable reference types habilitados; `record` para configuración y planes inmutables.
- `async` solo para I/O; dispose determinista de streams; `System.Text.Json` por defecto.
- Inyección por constructor; sin estado mutable estático; APIs públicas pequeñas y explícitas.
- Excepciones específicas con mensaje que identifique el input inválido; nunca tragar excepciones.

## Mensajes y errores
- Mensajes fijos en un catálogo de mensajes, nunca inline en la lógica.
- Códigos de error estables (`GEN001`, …); una excepción de dominio propia para errores con código.
- Salida CLI: `<error-code>: <message>`. Sin infraestructura de localización hasta que haga falta.

## Capas
- Presentation (entrada/salida de la app, exit codes) → Application (casos de uso vía Application Service/Command Handler, interfaces de infra) → Domain (reglas, invariantes; sin JSON/CLI/FS) → Infrastructure (repos, FS, logs tras interfaces).
- Patrones permitidos si resuelven algo concreto: Application Service, Builder, Strategy, Factory, Repository, Chain of Responsibility, Facade, DI.

## Valores
- `const` para valores técnicos (nombres de archivo, placeholders, códigos); Options Pattern/JSON por ambiente; `enum` para conjuntos cerrados.
- Nombres técnicos descriptivos (p. ej. `PlanFileName`), no literales de archivo sueltos (p. ej. `"plan.json"`).

## Escritura de archivos (resumen)
- Salida determinista por ambiente; renderizar antes de escribir; fallar antes de escribir si hay rutas, duplicados o placeholders inválidos; rechazar rutas absolutas y segmentos `..`.

## Referencias
- learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions · github.com/dotnet/skills
