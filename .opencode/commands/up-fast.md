---
description: "up fast" - levanta el proyecto con up.ps1 sin compilar el .aab ni ejecutar flutter run
---

Ejecuta el `up.ps1` de la raíz del proyecto en modo rápido (`-Fast`): los pasos 1-4 (cloud bootstrap, backend build, cloud apply, backend run) y el frontend con `-SkipBuild -SkipRun`, de modo que no se compila el `.aab` ni se lanza `flutter run`. Úsalo cuando el usuario escriba "up fast", "/up-fast" o pida subir la app sin esperar a la compilación Android.

Pasos:
1. Localiza la raíz del proyecto (carpeta con `up.ps1` y `cloud/`); si hay varios proyectos, pregunta cuál.
2. Indica antes el comando exacto que vas a ejecutar (`./up.ps1 -Fast`) y sus efectos: compila imágenes Docker y toca infraestructura Terraform, por lo que requiere autorización. No lo ejecutes sin ella.
3. Ejecútalo y reporta el resultado con la ruta del log (`logs/yyyy-MM-dd-HH-mm-ss.log`) y los errores con `ruta:línea`.

Con `-AutoApprove:$false` se pide confirmación previa al apply de Terraform.
