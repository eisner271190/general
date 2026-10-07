# ADR-0024: Dos repositorios de plataforma, `common` y `platform`, con un pipeline cada uno

- **Fecha:** 2026-10-04
- **Estado:** `Aceptada`
- **Sustituye a:** la parte de reparto por repositorio de ADR-0018
- **Sustituida por:** —
- **Alcance:** proyecto
- **Origen:** objetivo 002; decisión del usuario

## Contexto

ADR-0018 sacaba Azure DevOps y dejaba los repos de microservicios en CodeCommit, pero repartía la
actualización de dependencias **con un PR por repositorio de microservicio**: N microservicios
significaban N PRs y N permisos que mantener. Ese reparto ya no aplica porque la propagación la hace
un único trigger por tag (ADR-0025).

Lo que queda por decidir es **dónde vive la configuración compartida de CI**. La opción de un único
repo con buildspecs, scripts y Terraform mezclaba dos ritmos de cambio muy distintos.

## Decisión

**Dos repositorios en CodeCommit**, declarados en `library/platform/terraform/codecommit.tf`, con
**un pipeline cada uno**:

| Repositorio | Ruta local | Qué contiene | Ritmo de cambio |
|-------------|-----------|--------------|-----------------|
| `common` | `library/common/` | Componente Maven: `common-bom` + módulos por capacidad, samples, `docs/` | **Frecuente**: versión, BOM, código |
| `platform` | `library/platform/` | `buildspecs/`, `scripts/`, `terraform/` | **Muy pocos**: solo infraestructura y automatización |

Motivos, en orden de peso:

- **Cambios frecuentes en `common`, muy pocos en `platform`.** Un solo repo haría que cada release
  del BOM forzara un pipeline de buildspecs y Terraform que no ha cambiado. Con dos repos, el
  pipeline de `common` corre en cada release y el de `platform` casi no corre.
- **Permisos distintos.** El pipeline de `common` publica en CodeArtifact y empuja a ECR; el de
  `platform` arranca builds y escribe en CodeCommit. Un solo rol para los dos sería más ancho que
  cualquiera de los dos casos reales.
- **Radio de daño.** Un cambio en el Terraform de plataforma no debería poder tocar el BOM.

El repositorio de una **aplicación** (`com.quizsmart.app`) no se declara aquí: lo declara su propio
Terraform (`cloud/terraform/app/codecommit.tf`). `platform` solo compone su ARN para el IAM del
trigger del BOM.

## Consecuencias

### Positivas

- Cada pipeline hace una sola cosa y con el mínimo privilegio.
- Publicar una release de `common` no dispara el pipeline de plataforma.
- El bucket de buildspecs es el único punto de acoplamiento, y ya estaba diseñado para eso
  (ADR-0016): publicar un buildspec nuevo no obliga a editar ningún pipeline.

### Negativas y riesgos

- **Sustituye** el reparto por repositorio de ms de ADR-0018: ya no hay un PR por ms. ADR-0018
  sigue `Aceptada` porque su decisión de hosting (CodeCommit, sin Azure DevOps) sigue vigente;
  solo su parte de reparto la sustituyen ADR-0024 y ADR-0025.
- Dos repos que clonar y dos pipelines que mantener en lugar de uno.
- **Estado real**: hoy solo el pipeline de `common` está declarado
  (`terraform/main_pipeline.tf` → módulo `pipeline`). El de `platform` **no** necesita uno propio:
  `platform` no se compila, y su automatización (el bump del BOM) es un proyecto CodeBuild arrancado
  por la regla del tag, no un pipeline con source. Cuando `platform` necesite validar su Terraform o
  sus buildspecs, se declara una segunda llamada al mismo módulo.
- Los repos de `platform` los crea el **apply** de `platform/scripts/up.ps1`, no el agente.

### Coste

**0 USD/mes**. CodeCommit no cobra por repositorio ni por GB; los pipelines son por evento.
Un pipeline más, sin ejecuciones automáticas, sigue en céntimos al mes.