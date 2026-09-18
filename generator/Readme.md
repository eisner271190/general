# Generator

Cuando un equipo de desarrollo inicia un nuevo proyecto, el primer desafío no es escribir la lógica de negocio, sino definir la base sobre la que todo lo demás va a crecer. En cada nuevo servicio o aplicación, se repite el mismo trabajo antes de empezar a construir la funcionalidad real. En organizaciones con varios equipos y proyectos similares, ese esfuerzo manual consume tiempo, genera inconsistencias y retrasa el inicio del desarrollo.

Desde el punto de vista de los distintos roles:

### Backend
1. Definir microservicios por dominio, como autenticación, pagos, inventario o notificaciones.
2. Crear APIs REST o gRPC con endpoints base, versionado y modelos de respuesta.
3. Incluir health checks, circuit breakers, retries y timeouts para resiliencia.
4. Establecer capas de aplicación, dominio e infraestructura para separar responsabilidades.
5. Definir autenticación, autorización, logging y manejo de errores para cada servicio.

### Frontend
1. Definir la estructura de vistas por módulo, como dashboard, clientes, compras o reportes.
2. Crear componentes reutilizables para botones, formularios, tablas y navegación.
3. Establecer gestión de estado, rutas, layouts y patrones de acceso a APIs.
4. Definir configuración de entorno y variables para desarrollo, staging y producción.
5. Preparar la base para diseño responsivo, accesibilidad y despliegue web.

### DevSecOps
1. Definir pipelines de CI/CD para build, test, análisis estático y despliegue.
2. Incluir escaneo de vulnerabilidades, dependencias y secretos.
3. Establecer políticas de calidad, cobertura y validaciones automáticas.
4. Definir entornos de prueba, aprobación y promoción entre etapas.
5. Preparar evidencias de auditoría, trazabilidad y cumplimiento de seguridad.

### Cloud
1. Definir la infraestructura necesaria para entornos de desarrollo, QA y producción.
2. Crear redes, subredes, balanceadores, DNS y reglas de seguridad.
3. Definir secretos, variables de entorno y configuraciones por ambiente.
4. Establecer políticas de escalabilidad, alta disponibilidad y autoescalado.
5. Preparar despliegue con contenedores, servicios gestionados o infraestructura como código.

### Arquitectura
1. Definir la estructura base del sistema por capas y dominios.
2. Establecer contratos de integración entre servicios, APIs y eventos.
3. Definir principios de diseño como separación de responsabilidades, desacoplamiento y extensibilidad.
4. Identificar patrones de resiliencia, observabilidad y manejo de fallos.
5. Acordar la organización de carpetas, convenciones de nomenclatura y estándares operativos del proyecto.

Así, el generador resuelve este problema al convertir esas decisiones iniciales en una base reusable, automatizada y consistente para cada nuevo proyecto.

## Objetivo

Automatizar la creación de carpetas, archivos y archivos predeterminados para generar una estructura de proyecto completa.

## Flujo principal

1. Crear el proyecto .NET base.
2. Leer la configuración con el listado de paths.
3. Crear carpetas a partir de esas rutas.
4. Leer el diccionario de archivos (`path -> contenido`).
5. Crear los archivos con su contenido.
6. Copiar archivos predeterminados.

