# ADR-0018: Azure DevOps eliminado; CI solo CodePipeline + CodeBuild y ms en CodeCommit

- **Fecha:** 2026-10-03
- **Estado:** `Aceptada`
- **Sustituye a:** ADR-0017
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; `question-006.md`

> **Nota de 2026-10-04:** este ADR **sigue `Aceptada`**. Su decisión de hosting —solo CodeCommit,
> CodePipeline y CodeBuild, sin Azure DevOps— continúa vigente y no se ha tocado.
>
> Lo que **queda sustituido** es su reparto de actualización de dependencias, escrito abajo como
> (a) Renovate programado y (b) un PR por repositorio de microservicio:
>
> - (a) → **ADR-0025**: Renovate se retira; el BOM se actualiza a mano y su propagación la hace el
>   trigger por tag.
> - (b) → **ADR-0024** y **ADR-0025**: un repositorio por aplicación y **un único PR** por release de
>   `common`, no uno por microservicio.
>
> También quedan obsoletas las líneas 20-21 y 21 (los dos automatismos de Renovate) y la línea 41
> (el coste del Scheduler, que ya no existe).

## Contexto

El objetivo 002 mezclaba dos plataformas: el piloto `quizapi` traía un `azure-build.yml`, mientras que el resto del diseño era CodePipeline + CodeBuild. Renovate no soporta CodeCommit de forma nativa, así que el criterio de aceptación "Renovate abre PR en un microservicio" no era verificable con ninguna de las dos plataformas sin reformularlo.

## Decisión

El usuario decide **definitivamente no usar Azure DevOps** y pide eliminarlo de planes, objetivos, `AGENTS.md` y del proyecto entero. Los repos de los microservicios viven en **CodeCommit**.

Como Renovate no tiene soporte nativo de CodeCommit, el reparto de actualización de dependencias es:

- **(a) Renovate programado:** CodeBuild con EventBridge Scheduler semanal, `platform: local`, actualiza las versiones de terceros dentro de `common`; el script `open-codecommit-prs.py` convierte las ramas que deja Renovate en pull requests.
- **(b) Trigger por release:** un tag `v*` en `common` dispara un CodeBuild que bumpea la `<version>` del `import` de `common-bom` en todos los repos de ms y abre un PR en cada uno (`bump-bom-version.py`, idempotente).

## Consecuencias

### Positivas

- Una sola plataforma de CI en todo el proyecto; desaparece la ambigüedad de ADR-0017.
- Beneficio colateral: al borrar `azure-build.yml` desaparece la clave `NVD_API_KEY` que estaba **en claro** en la línea 16.
- Renovate no necesita credenciales en el repositorio.

### Negativas y riesgos

- Se borran `platform/azure/stages/*`, `quizapi/azure-build.yml` y la plantilla `generator/components/backend/spring-boot-3.5.16/templates/azure-build.scriban`.
- El microservicio necesita su sustituto: un proyecto CodeBuild por microservicio que referencia el buildspec del bucket por ARN (Terraform en el ms).
- Desaparece el criterio de aceptación de "plantilla de Azure DevOps" y se sustituye por el del trigger de release.
- `architecture-002.md` pasa a v3 y el criterio de Azure sale de `docs/planteamiento.txt`.
- `platform: local` **no** es la vía soportada para abrir PRs: depende de dos scripts propios (`open-codecommit-prs.py`, `bump-bom-version.py`) que hay que mantener.

### Coste

**0 USD adicionales**. EventBridge ingiere **gratis** los service events de CodeCommit, y Scheduler tiene 14 M de invocaciones/mes gratis (se usan 4). El coste nuevo son los minutos de CodeBuild, del orden de centavos al mes.
