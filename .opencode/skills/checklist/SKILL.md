---
name: Checklist previo a implementación
description: Revisa un objetivo antes de implementar y genera preguntas por cada punto abierto. Úsala al iniciar cualquier objetivo, antes de codificar, mover, renombrar o generar artefactos.
---

## Alcance
Usa esta skill antes de implementar cualquier objetivo de `DELIVERABLES/obj-NNN/`. No la uses para revisar código ya implementado ni para tareas sin cambios de artefactos.

## Flujo de trabajo
1. Lee `DELIVERABLES/obj-NNN/obj-NNN.md`, `questions.md` y `improvements.md`.
2. Revisa cada punto de la lista siguiente y marca cumplido o abierto.
3. Por cada punto abierto, agrega una pregunta a `questions.md`: corta, clara y con recomendación.
4. Registra las dependencias en la sección `Dependencias` de `questions.md`.
5. Si quedan puntos abiertos, no implementes. Espera la respuesta del usuario.
6. Al resolver una duda, actualiza `DELIVERABLES/obj-NNN/*.md`.

## Lista de revisión

### Alcance y artefactos
- [ ] Haz una lista de los archivos que sí puedes cambiar y de los que no.
- [ ] Anota qué dominio tiene cada caso de uso.
- [ ] Confirma que cada dominio o paquete del alcance tiene plantillas que lo generen.
- [ ] Revisa que cada criterio de aceptación no contradiga una decisión anterior.
- [ ] Revisa en `component.json` que cada dominio y usecase del alcance esté en `directories`.
- [ ] Divide la migración en fases y define cómo comprobar cada una.
- [ ] Define cuándo se considera terminado cada paso del objetivo.

### Ubicación
- [ ] Anota dónde va cada clase, bean y configuración.
- [ ] Define en el ADR la estructura de carpetas de cada slice.
- [ ] Revisa que el ADR no contradiga decisiones anteriores.
- [ ] Usa un solo nombre para cada carpeta común.
- [ ] Asigna cada clase a un solo dominio y slice.
- [ ] Revisa si el módulo o paquete destino ya existe.
- [ ] Compara library y app antes de decidir dónde va una clase.

### Naming
- [ ] Revisa la convención de nombres del ADR antes de nombrar algo.
- [ ] Revisa que cada nombre de paquete o clase sea válido en el lenguaje.
- [ ] Revisa los sufijos del objetivo y de las plantillas, y elige uno.
- [ ] Anota qué significa cada placeholder, con un ejemplo.
- [ ] Anota qué cubre cada término antes de cambiarlo.
- [ ] Define el nombre de cada clase nueva antes de dividir una clase existente.
- [ ] Anota qué nombres técnicos no se cambian.
- [ ] Después de cambiar un nombre, busca el nombre viejo en todo el repo.
- [ ] Explica por qué existe cada nivel de paquete en el ADR.

### Dependencias
- [ ] Dibuja qué slice depende de qué otro slice.
- [ ] Revisa que una nueva dependencia no cree un ciclo.
- [ ] Anota qué clase reemplaza a cuál en el ADR antes de borrar o unir clases.
- [ ] Busca dónde se usa una clase antes de borrarla o dejarla.
- [ ] Anota puerto, adaptador e implementación de cada slice.
- [ ] Anota qué clases de la app usa una clase antes de moverla a library.
- [ ] Anota qué módulos dependen de qué otros módulos antes de crear uno.

### Configuración
- [ ] Da a cada agente solo los permisos que necesita para su tarea.
- [ ] Incluye los archivos de configuración en la lista de cambios.
- [ ] Busca rutas absolutas en las plantillas y cámbialas por rutas relativas.
- [ ] Antes de generar, lista los archivos que se van a sobrescribir.
- [ ] Revisa cada condición que depende del nombre, con cada destino.
- [ ] Busca quién usa una clase compartida antes de dividirla.
- [ ] Compara las plantillas de la carpeta con `component.json`.

### Tests
- [ ] Busca en los tests los imports de cada clase que vas a mover.
- [ ] Anota quién es responsable de cada test antes de asignarlo.
- [ ] Busca en los tests el nombre de cada clase que vas a cambiar.
- [ ] Revisa qué decisiones mencionan un test antes de borrarlo.
- [ ] Anota cuándo se borra cada test, en el ADR.
- [ ] No crees ni cambies tests sin permiso.

### Versiones
- [ ] Busca todos los lugares donde aparece la versión antes de subirla.
- [ ] Revisa qué archivos locales se van a sobrescribir antes de instalar.

### Documentación
- [ ] Revisa cómo se llaman los documentos en la carpeta antes de crear uno.
- [ ] Compara el estado del ADR con la tabla de estados.
- [ ] Lee el README de la carpeta antes de cambiar un índice.
- [ ] Revisa que cada plantilla o sección citada existe.
- [ ] Compara el estado real de los artefactos con la sección `Dependencias`.
- [ ] Revisa que cada ruta en AGENTS.md existe.
- [ ] Revisa el ADR contra las decisiones nuevas antes de marcarlo como aceptado.
- [ ] Busca los documentos que mencionan un módulo nuevo y actualízalos.

### Arranque
- [ ] Anota cómo se registran los beans de library antes de programarlos.
- [ ] Revisa en qué paquete busca Spring las clases antes de elegir la ubicación.
- [ ] Anota en el ADR el perfil local antes de pedir propiedades obligatorias.

### Verificación externa
- [ ] Marca cada verificación que use AWS y pide permiso antes de ejecutarla.
- [ ] Busca carpetas de salida con el paquete viejo antes de compilar.

## Requisitos y límites
- No hagas commit ni push sin permiso.
- No crees ni cambies tests sin permiso.
- Si falta información importante, pregunta al usuario antes de suponer.
- Si un punto no aplica, márcalo como no aplica y escribe el motivo.

## Resultado
- `questions.md` actualizado con una pregunta por cada punto abierto.
- Lista de puntos cumplidos y abiertos, con su grupo.
- Confirmación de si se puede empezar a implementar.
