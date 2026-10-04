# ADR-0022: IAM de CodeArtifact en dos roles y token solo por variable de entorno

- **Fecha:** 2026-10-03
- **Estado:** `Aceptada`
- **Sustituye a:** —
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; `question-008.md`, `question-010.md`

## Contexto

CodeArtifact no usa usuario ni contraseña: el login de Maven es un **token temporal de 12 h** emitido por AWS a partir de la identidad de quien lo pide. Por tanto **el rol IAM es la frontera de seguridad**: si el rol puede publicar, el token puede publicar. El objetivo exigía que el token viviera en la variable de entorno `CODEARTIFACT_AUTH_TOKEN`.

## Decisión

Matriz IAM mínima acordada:

| Rol | Permisos | Quién lo usa |
|-----|-----------|--------------|
| **Publicación** | `codeartifact:GetAuthorizationToken` + `ReadFromRepository` + `PublishPackageVersion` + `GetPackageVersion` sobre el ARN del repositorio | Solo el pipeline de `common` |
| **Solo lectura** | `codeartifact:GetAuthorizationToken` + `ReadFromRepository` | Builds de los ms y Renovate |

- **`kms:Decrypt` no hace falta**: el repositorio no usa CMK propia (decisión de coste).
- El token se emite con `get-authorization-token` en el momento y viaja **siempre por variable de entorno**, nunca en un fichero: un `settings.xml` con el token en claro acaba en el contexto de Docker, en los logs o en un commit. En el build local el `Dockerfile` lo monta con `RUN --mount=type=secret` y genera el `settings.xml` en el mismo `RUN`, de modo que no queda en ninguna capa.
- Renovate pide un token fresco en cada ejecución.

## Consecuencias

### Positivas

- Radio de exposición mínimo: si se filtra el rol de un microservicio, el daño máximo es **leer**, no publicar.
- No hay CMK propia: se evita el coste mensual de la clave.

### Negativas y riesgos

- No hay alternativa al secreto: un repositorio Maven privado exige autenticación HTTPS. Lo que se reduce es el radio de exposición, no la necesidad.
- El token **no se persiste en Secrets Manager**: dura 12 h, así que guardar un valor es guardar algo ya expirado. En el bootstrap local sale de las credenciales del propio usuario, sin ningún secreto previo que sembrar. En CI sí habrá que sembrar `epc/<env>/codeartifact` para los builds, porque CodeBuild no tiene identidad de usuario.
- Los dos roles siguen vigentes para CodeBuild: son el mecanismo de mínimo privilegio del pipeline de publicación y de los builds de lectura.
- `.tf` declarativos: el agente no ejecuta `terraform apply`.

### Coste

0 USD. Sin CMK propia se evita **+1 USD/mes**.
