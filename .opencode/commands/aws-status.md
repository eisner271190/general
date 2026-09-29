---
description: "Estado rapido de los servicios AWS del proyecto (solo lectura, sin exploracion)"
---

Consulta el estado actual de los servicios AWS con un UNICO comando (sin explorar el repositorio ni hacer llamadas AWS CLI adicionales, para que la respuesta sea rapida):

```powershell
pwsh -NoProfile -File .opencode/scripts/get-services-aws.ps1
```

Si el usuario pasa argumentos, anexalos al final del comando (por ejemplo `-AsJson`), o usa `$ARGUMENTS` como parametros del script.

Reglas:
1. Ejecuta solo ese script: no hagas `aws ...` a mano ni consultes ficheros `.tf`/estados de Terraform (el script ya los recoge y compara).
2. Reporta sin reescribir: tabla SERVICIO/AWS/DETALLE, seccion ESTADOS TERRAFORM y seccion DESFASES; cierra con una linea de conclusion (todo alineado, o que recursos faltan/sobran).
3. Solo lectura: no crees ni borras nada con este comando.
4. Para borrar recursos existe `.opencode/scripts/delete-all-services-aws.ps1`; nunca lo ejecutes sin autorizacion explicita del usuario (ademas exige `-Force` fuera de un shell interactivo). Tras borrar, vuelve a lanzar este comando para confirmar el estado.
5. Si el script reporta fallos de credenciales (ExpiredToken / SSO), indicalo y para; no reintentes con otras credenciales.
