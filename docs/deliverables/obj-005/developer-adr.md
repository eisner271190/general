# Implementación

- Objetivo: `obj-005: Reemplazar AWS Secrets Manager por SSM Parameter Store SecureString`
- Agente/especialidad: `Developer / Documentación ADR`
- Estado: `completo`
- Resumen: `ADR-0027 creado; ADR-0010, 0012 y 0022 actualizados solo en los puntos pedidos.`
- Fecha: `2026-10-12 (hora no disponible)`
- Bloqueos: `ninguno de escritura. Dudas en la sección Dudas.`
- Alcance y ADR aprobados: `obj-005.md; architect.md (Q53, D41, D42); questions.md`

## Cambios
| Archivo/componente | Cambio | Motivo |
|---|---|---|
| `docs/adr/0027-ssm-parameter-store-securestring.md` | Nuevo ADR | Tarea 1 |
| `docs/adr/0010-un-secreto-por-aplicacion.md` | Estado y "Sustituida por" a ADR-0027; nota final | Tarea 2 |
| `docs/adr/0012-spring-cloud-aws-en-perfil-cloud.md` | Starter, ruta, IAM, coste, nota | Tarea 3 |
| `docs/adr/0022-iam-codeartifact-dos-roles.md` | ADR-0023 → ADR-0027; aclaración SecureString | Tarea 4 |
| `docs/deliverables/obj-005/developer-adr.md` | Este informe | AGENTS.md |

## Decisiones y desviaciones
- ADR-0027 en estado `Aceptada`, como indicó el encargo.
- JSON del secreto: `≈ 300 bytes` con valores por defecto (cifra de Q100), no `210`.
- JSON en bloque multilínea; es el mismo objeto que el de una línea.
- 0012: la ruta del secreto pasa a `/develop/com.quizsmart.app/secrets` (con barra inicial).
- 0012: el coste pasa a 0 USD con `GetParameter` (SecureString) en lugar de `GetSecretValue`.
- 0022: se tocan solo las líneas 70-71 (ADR-0023 y único secreto por aplicación).
- No se tocó `docs/adr/README.md` (Q9).
- No se tocó el generador, `/projects`, `.opencode/`, tests ni git.

## Verificaciones y resultados
- Escritura en `docs/adr/`: correcta, sin denegaciones.
- Grep de `Secrets Manager|secrets-manager|GetSecretValue|ADR-0023` en `docs/adr/`:
  - Quedan menciones intencionadas (ver Dudas).
  - Sin `ADR-0023` como cita activa.
- Líneas de 0027 > 100 caracteres: ninguna.
- No se ejecutó Terraform, PowerShell ni AWS.

## Dudas
- Estado `Aceptada` de ADR-0027: `questions.md` no registra aprobación explícita del ADR por
  el usuario. Recomiendo confirmar antes de marcarlo como vigente.
- `questions.md` cabecera dice "Q48 autorizada", pero Q48 dice "no autorizar todavía".
  Recomiendo aclarar; no afecta a este ADR, pero sí a la implementación.
- Cifra del JSON: Q100 está abierta. ADR-0027 usa `≈ 300 bytes`; `obj-005.md` y
  `use-cases.md` (TC-02) siguen en `210`. Recomiendo actualizar esos dos documentos.
- Borrado de suscripciones del topic en `delete-all-services-aws.ps1`: viene del encargo,
  pero no aparece en `obj-005.md` (líneas 94-96). Recomiendo añadirlo allí o retirarlo del ADR.
- `0010`: el cuerpo sigue citando Secrets Manager (contexto histórico). Solo se cambió
  estado, cabecera y nota, según el encargo.
- `0022` líneas 29 y 81: mencionan Secrets Manager para secretos de plataforma (no de app).
  No se cambiaron. Recomiendo dejarlas.

## Defectos, limitaciones y riesgos
- Sin copia externa del keystore (riesgo documentado en ADR-0027).
- ADR-0027 asume que la app no está publicada en Play (Q78).

## Traspaso
- Reviewer/Tester: `pendiente`. Revisar la matriz de criterios de `obj-005.md` (línea 146:
  "Existe ADR-0027...") y marcar como cumplida tras la revisión.
- Architect: `pendiente` para confirmar Estado y cifra de 300 bytes.

## Archivos creados/modificados
- `docs/adr/0027-ssm-parameter-store-securestring.md` (creado)
- `docs/adr/0010-un-secreto-por-aplicacion.md`
- `docs/adr/0012-spring-cloud-aws-en-perfil-cloud.md`
- `docs/adr/0022-iam-codeartifact-dos-roles.md`
- `docs/deliverables/obj-005/developer-adr.md`
