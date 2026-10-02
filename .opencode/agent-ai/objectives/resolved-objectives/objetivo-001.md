# Objetivo 001

## Objetivo

Crear un endpoint de IA generativa agnóstico al proveedor en el backend (Spring Boot), consumirlo desde el frontend (Flutter) eliminando el consumo directo de OpenRouter, y almacenar credenciales sensibles en AWS Secret Manager y parámetros públicos en AWS Systems Manager (SSM) Parameter Store.

## Contexto

Actualmente el frontend (Flutter) consume directamente la API de OpenRouter (`https://openrouter.ai/api/v1/chat/completions`) para generar preguntas de quiz. Esto presenta varios problemas:

- **Acoplamiento al proveedor:** el frontend está ligado a OpenRouter; cambiar de proveedor requiere modificar el cliente Flutter.
- **Exposición de credenciales:** la API key de OpenRouter podría estar expuesta en el código del frontend o en variables de entorno del cliente.
- **Falta de control:** no hay capa de autorización, auditoría ni centralización de la lógica de IA.

El generador (`generator/`) es la fuente de verdad. Todo cambio debe implementarse en las plantillas Scriban y registrarse en `component.json` correspondiente. El JSON de configuración (`generator/target/com.quizsmart.app/com.quizsmart.app.json`) es entrada, no salida.

## Restricciones

- **No modificar tests:** el usuario escribe y gestiona los tests. Si un test queda rojo, informar y esperar instrucciones.
- **No hacer commit ni push sin autorización.**
- **No ejecutar tests** (`mvn test`, `flutter test`, etc.).
- **No usar `terraform apply` ni `terraform destroy`.**
- **No editar `.env` ni archivos de credenciales sin petición explícita.**
- **No secretos en código:** las API keys y datos sensibles van en AWS Secret Manager; los parámetros públicos en SSM Parameter Store.
- **Cambio mínimo:** no hacer refactors no relacionados.
- **Respetar la arquitectura hexagonal** del backend (Spring Boot) y la estructura de features del frontend (Flutter).
- **Actualizar `component.json`** al agregar/renombrar plantillas.
- **Considerar costos AWS:** el diseño debe minimizar el costo (ej. un solo endpoint de IA, no uno por microservicio).

## Alcance

### Backend (Spring Boot 3.5.16)

1. **Endpoint de IA generativa** (`/api/v1/ai/generate`):
   - Agnóstico al proveedor: usar un puerto (`IAProviderPort`) con una interfaz que abstraiga la llamada al proveedor de IA.
   - Implementación inicial: adaptador para OpenRouter (mismo contrato actual).
   - El endpoint recibe un prompt y devuelve la respuesta generada.

2. **Configuración del proveedor:**
   - API key de IA en AWS Secret Manager.
   - Parámetros públicos (URL, modelo, temperatura, max_tokens) en SSM Parameter Store.
   - El backend lee la configuración al arrancar (patrón actual con `ParameterProperties`).

3. **Registro en `component.json`:** agregar las plantillas nuevas al componente `spring-boot-3.5.16`.

### Frontend (Flutter 3.47.2)

4. **Cliente de IA:**
   - Eliminar el consumo directo de OpenRouter (`ai_api_client.dart` actual).
   - Crear un cliente que consuma el endpoint del backend (`/api/v1/ai/generate`).
   - Mantener la misma interfaz para que el resto de la app no cambie.

5. **Configuración:**
   - Eliminar `API_URL` de los archivos `.env.*` (ya no se necesita la URL de OpenRouter en el frontend).
   - El frontend solo necesita la URL base del backend (que ya existe o se agrega como parámetro público).

6. **Registro en `component.json`:** actualizar las plantillas modificadas en el componente `flutter3.47.2`.

### Cloud (AWS Terraform)

7. **Secret Manager:**
   - Agregar en el secreto de la app el API key del proveedor de IA (ej. `openrouter_api_key`).
   - El secreto se siembra fuera de Terraform (en `up.ps1`).

8. **SSM Parameter Store:**
   - Agregar parámetros públicos del proveedor de IA (modelo, temperatura, etc.).
   - Seguir el patrón actual: `aws_ssm_parameter` con `for_each` sobre `var.environment_variables`.

9. **Registro en `component.json`:** agregar las plantillas nuevas al componente `cloud/aws`.

### Generador (target JSON)

10. **Actualizar `com.quizsmart.app.json`:**
    - Reemplazar `API_URL` (OpenRouter) por la URL base del backend.
    - Agregar variables de configuración del proveedor de IA (públicas).
    - Mantener las variables existentes que sigan siendo necesarias.

## Criterios de aceptación

- [ ] El backend expone `POST /api/v1/ai/generate` que recibe un prompt y devuelve la respuesta generada.
- [ ] El endpoint es agnóstico al proveedor: existe un puerto `IAProviderPort` y un adaptador `OpenRouterAdapter`.
- [ ] La API key de OpenRouter está en AWS Secret Manager, no en código ni en variables de entorno del frontend.
- [ ] Los parámetros públicos del proveedor (modelo, temperatura, etc.) están en SSM Parameter Store.
- [ ] El frontend consume el endpoint del backend, no OpenRouter directamente.
- [ ] No hay referencias a `openrouter.ai` en el frontend (excepto en comentarios de migración si es necesario).
- [ ] Los archivos `.env.*` del frontend no contienen la API key de OpenRouter.
- [ ] Las plantillas nuevas están registradas en `component.json` correspondiente.
- [ ] El generador compila (`dotnet build`).
- [ ] No se rompen los endpoints existentes (auth, parameters, subscription, etc.).

## Fuera del alcance

- **No implementar múltiples proveedores de IA** (solo OpenRouter como implementación inicial, pero con la interfaz lista para agregar más).
- **No modificar la lógica de generación de preguntas** (el prompt y el formato de respuesta se mantienen igual).
- **No agregar rate limiting ni caching** de respuestas de IA (se puede considerar en un futuro).
- **No modificar el pipeline de CI/CD** (asume que el despliegue ya funciona).
- **No agregar tests** (el usuario los gestiona).
- **No modificar otros microservicios** (solo `quizapi` o el microservicio que corresponda).
- **No cambiar la estructura de carpetas** del generador ni de los componentes.
