---
name: Flutter Clean
description: Convenciones Flutter/Dart para escribir o revisar código de apps Flutter (provider, lints, UI, assets, verificación)
---

## Base
- Effective Dart: nombres descriptivos en inglés; documentación `///` en APIs públicas; preferir `final`/inmutabilidad; evitar `print` (usar logging).
- Lints: `package:flutter_lints/flutter.yaml` (activo en `analysis_options.yaml`). No desactivar reglas globales; suprimir con `// ignore:` puntuales en la línea.

## Estado y datos
- Estado con `provider` (^6.1.x): `ChangeNotifier` + `Provider`; modelos separados de la UI.
- HTTP con `http` (^1.5): capa DataSource/Repositorio; nunca llamadas HTTP directas desde widgets.
- Serialización JSON en modelos con campos nullable validados; errores de red manejados (no ignorados).

## UI
- Widgets pequeños con un solo propósito; extraer widgets repetidos.
- `const` constructors donde sea posible; sin trabajo pesado en `build()`.
- Responsive con LayoutBuilder/MediaQuery; sin tamaños hardcodeados.
- Accesibilidad: semántica y tamaños táctiles mínimos.

## Seguridad
- Secrets solo en assets `.env.*` con placeholders — jamás valores reales en plantillas ni git.
- Tokens con `flutter_secure_storage`.

## Verificación obligatoria antes de terminar
1. `dart format .`
2. `flutter analyze` → 0 issues
3. `flutter test` si hay tests afectados

## Referencias
- dart.dev/effective-dart · flutter.dev/docs · github.com/flutter/agent-plugins (26 skills oficiales; selección prevista en fase 2)
