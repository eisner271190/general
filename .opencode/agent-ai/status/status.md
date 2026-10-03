# Status — objetivo 002 (`common`)

**Fecha:** 2026-10-03 · **Rama:** `objetivo-002-common` (sin commits: todo está en el working tree)

Retomar aquí: leer este fichero, luego `.opencode/agent-ai/objectives/objetivo-002.md` y `.opencode/agent-ai/deliverables/objetivo-002/implementation-002.md` (sección de tareas del usuario).

## Dónde está el flujo

Fases de `WORKFLOW`: research ✅ · architect ✅ (v2) · reviewer-plan ✅ (veredicto: vuelve a architect) · architect v2 ✅ · developer ✅ · tester ❌ **FALLA_IMPLEMENTACION** → developer corrigió los 2 defectos → **falta re-test**.

Entregables en `.opencode/agent-ai/deliverables/objetivo-002/`: `research-002.md`, `architecture-002.md` (v2), `plan-review-002.md`, `implementation-002.md`, `test-report-002.md` (v2, veredicto `FALLA_IMPLEMENTACION`).

Dudas: **001–018 resueltas**. Ya no hay carpeta de resueltas: cada respuesta con consecuencias quedó como ADR (`DECISIONS`, `question-NNN.md` citado en `Origen:`). Siguiente ID de ADR libre: **0023**; siguiente duda libre: **019**.

## Decisiones en vigor

En `DECISIONS` (`docs/adr/`, índice en `DECISIONS_INDEX`), las del objetivo 002: **ADR-0016** buildspecs en **bucket S3 versionado** (CodeBuild no admite pin de commit), `common-web` **WebFlux**, `Dart fuera de alcance` - **ADR-0017** repo único `platform/` (obsoleta en su parte de plataforma) - **ADR-0018** **CodeCommit** como hosting de ms, **Azure DevOps eliminado**, Renovate con `platform: local` (programado) + **trigger por tag `v*`** que bumpea `common-bom` y abre PRs - **ADR-0019** el generador deja de emitir el código de `common` - **ADR-0020** `common-parent` **no se publica** - **ADR-0021** precedencia Maven (la versión de Boot se gobierna desde el parent del ms) - **ADR-0022** IAM de CodeArtifact con dos roles (publicación / solo lectura) y sin CMK.

## Pendiente — lo puede hacer el agente

1. **Eliminar Azure DevOps del código**: borrar `platform/azure/stages/*`, `projects/com.quizsmart.app/backend/quizapi/azure-build.yml` y `generator/components/backend/spring-boot-3.5.16/templates/azure-build.scriban`. El ms necesita su sustituto: proyecto CodeBuild por microservicio que referencia el buildspec del bucket por ARN (Terraform en el ms).
2. **Limpiar Azure de la documentación**: `architecture-002.md` (→ v3), `implementation-002.md`, `.opencode/docs/planteamiento.txt:159`, `AGENTS.md`. Objetivo y `DECISIONS` ya están limpios.
3. **Generador importa `common`**: borrar `api-response.scriban`, `general-exception.scriban`, `global-exception-handler.scriban` (y `ErrorApiResponse` si existe), darlos de baja en `component.json`, y `pom.scriban` importando `common-bom` con `common-web`/`common-log`/`common-error` solo si el ms los necesita. `logback.scriban` se queda.
4. **`maven.deploy.skip`** en `common-parent` (no publicarlo).
5. **Re-test** del objetivo (IAM corregido + trigger de Renovate/CodeCommit, que nadie ha verificado aún).
6. **Reviewer** y PR: **requiere autorización del usuario para commit y push**.

## Pendiente — lo tiene que hacer el usuario (AWS/credenciales)

1. `terraform apply` de `platform/` y de la parte de CodeBuild del ms.
2. Sembrar `epc/develop/codeartifact` (token) y `epc/develop/codecommit-git` (credenciales Git).
3. `mvn deploy` de `common` + `dependency:get` del BOM.
4. `./scripts/publish-buildspecs.sh` y `aws s3 ls s3://epc-buildspecs/` (buildspecs en la raíz).
5. Publicar `epc/common-base:1.0.0` en ECR y probar el `Dockerfile` de 4 líneas del piloto.
6. **3 imports de test** del piloto (el agente no toca tests): `HolaMundoControllerTest.java:3-4`, `ParameterControllerTest.java:4`; luego la suite.
7. `renovate --platform=local --dry-run` y `bump-bom-version.py --dry-run`.

Comandos exactos de cada punto: `implementation-002.md`.

## Restricciones que siguen vigentes

No commit ni push sin autorización · no crear ni modificar tests · `terraform apply`/`destroy` prohibidos al agente · sin secretos en ficheros (token por variable de entorno) · identificadores en inglés · duda `NON_BLOCKING` → registrar en `QUESTIONS_OPEN` (siguiente libre: **019**) y seguir.

## Detalles sueltos

- Medición de precedencia Maven (cerrada): una entrada explícita gana a un `import` aunque venga de un ancestro → **la versión de Spring Boot se gobierna desde el parent de cada ms, no desde `common-bom`**.
- `.opencode/docs/planteamiento.txt:100` tiene una línea `+ ADR folder` que **no** es del agente; pendiente de decidir si se organiza un ADR por decisión.
- Efecto colateral de borrar `azure-build.yml`: desaparece la `NVD_API_KEY` en claro (línea 16). Siguen fuera de alcance las credenciales `admin/admin` de `sonar-scanner.properties`.
