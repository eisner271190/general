# ADR-0025: Renovate retirado; el BOM se actualiza a mano y el trigger por tag hace un único PR

- **Fecha:** 2026-10-04
- **Estado:** `Aceptada`
- **Sustituye a:** el reparto de actualización de dependencias de ADR-0018
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; decisión del usuario

## Contexto

ADR-0018 diseñó dos automatizaciones de dependencias: Renovate programado con EventBridge Scheduler
dentro de `common`, y un trigger por tag `v*` que bumpea el BOM en cada repositorio de microservicio
y abría un PR en cada uno.

Medido al implementar: **Renovate no tiene plataforma para CodeCommit**, así que su flujo real era
`platform: local` (deja ramas, no PRs) más dos scripts propios, un Scheduler y credenciales de
Git sembradas en Secrets Manager. Coste de todo ese aparato para actualizar un fichero de un `pom`.

## Decisión

**Renovate queda retirado del proyecto.** Se borra su infraestructura completa:

| Se borra | Dónde estaba |
|----------|--------------|
| Terraform de Renovate | `terraform/renovate.tf` (proyecto CodeBuild, rol, Scheduler, regla de evento, secreto de Git) |
| Buildspec | `buildspecs/renovate.yml` |
| Configuración | `common/renovate.json` |
| Proyecto CodeBuild | `common-renovate` |
| Scheduler | `common-renovate-weekly` (EventBridge Scheduler) |
| Credenciales | secreto `epc/<env>/codecommit-git` y sus variables `GIT_ASKPASS` en los buildspecs |

Y las variables `renovate_schedule_expression`, `platform_source_branch` y `ms_repository_prefix`.

**Lo que queda, y quién lo hace:**

1. **El BOM dentro de `common` se actualiza a mano**, por aviso de seguridad. Editar
   `common-bom/pom.xml`, compilar, publicar. Es una edición de un fichero y una persona;
   automatizarlo con dos scripts, un Scheduler y credenciales sembradas no compensa.
2. **La propagación a las aplicaciones la hace el trigger por tag**: un tag `v*` en `common` arranca
   `platform-bump-bom`, que sube **una línea** (la `<version>` del `import` de `common-bom`) en cada
   pom del glob `backend/*/pom.xml` del repositorio de la aplicación y abre **un único PR** en
   `com.quizsmart.app`, rama `bump/common-bom-<versión>`. Idempotente y sin Git: usa la API
   de CodeCommit con el rol del build (ADR-0022).

## Consecuencias

### Positivas

- **Un solo PR por release**, no uno por microservicio. Con un repo de aplicación, el soporte de N
  microservicios es una línea más en el pom.
- Desaparecen el Scheduler, el proyecto CodeBuild, la regla de evento y el secreto de credenciales
  de Git: menos piezas que mantener y menos superficie de credenciales.
- El flujo que queda es el que se puede depurar leyendo un script de 200 líneas.
- Coherente con ADR-0024: un repo por aplicación, un PR por release.

### Negativas y riesgos

- **Las actualizaciones de terceros no salen de `common`**: el criterio de aceptación 6 del objetivo
  queda **fuera del alcance**. Ante un aviso de seguridad hay que intervenir a mano. Aceptado: la
  ventana de exposición se mide en días, no en el tiempo que tarda Scheduler.
- `open-codecommit-prs.py` se queda **sin consumidor** (lo usaba solo Renovate). Se mantiene
  porque es la rutina de PR idempotente que usa `bump-bom-version.py`; si algún día sobra, se borra.
- ADR-0018 pasa a tener su parte de reparto sustituida por este ADR y por ADR-0024. Su decisión de
  hosting sigue vigente, por eso **no se marca `Obsoleta`**.

### Coste

**−0,40 USD/mes** respecto a tener un secreto de Git. Scheduler y proyecto CodeBuild ya eran ~0 USD
(4 invocaciones/mes, dentro de las 14 gratuitas de EventBridge Scheduler), así que el ahorro real es
el secreto y su rotación. Total del objetivo: **< 2 USD/mes**.