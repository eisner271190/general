"""Trigger por release de `common`: sube la version del `import` de `common-bom` en los pom de la
aplicacion y abre un unico pull request.

Se ejecuta en un proyecto CodeBuild disparado por el evento de CodeCommit "Reference Change"
cuando aparece un tag `v*` en el repo `common` (coste 0: los service events de CodeCommit se
ingieren gratis).

Que hace, en un unico repositorio de aplicacion:
  1. Localiza los pom de microservicios por ruta (`--pom-glob`, por defecto `backend/*/pom.xml`).
  2. Lee cada pom y busca el `import` de `common-bom`.
  3. Los que ya estan en la version nueva se saltan (idempotente).
  4. Los demas cambian SOLO esa linea, todos en la MISMA rama, y se abre un unico PR
     (idempotente, ver open-codecommit-prs.py).

Destino: la variable de entorno `APPLICATION_REPOSITORY`, que Terraform inyecta en este proyecto
CodeBuild (variable `application_repository`). `--repository` es el override manual. Este fichero
no contiene ningun nombre de repositorio de aplicacion.

Ninguna credencial en este fichero: el cliente boto3 usa el rol del build, de modo que no hay
`GIT_ASKPASS` ni secreto de Git sembrado en ningun sitio.

Uso:
  NEW_VERSION=1.0.1 python3 bump-bom-version.py
  APPLICATION_REPOSITORY=<repo> python3 bump-bom-version.py --new-version 1.0.1 --dry-run
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import logging
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# --- Constantes (un unico sitio por lenguaje) ---------------------------------
# El helper se llama con guiones (`open-codecommit-prs.py`), que no es un modulo importable:
# se carga por ruta para reutilizar su logica sin duplicarla ni renombrar el fichero.
_HELPER_PATH = Path(__file__).with_name("open-codecommit-prs.py")
_spec = importlib.util.spec_from_file_location("open_codecommit_prs", _HELPER_PATH)
_helper = importlib.util.module_from_spec(_spec)
# Registrar el modulo antes de ejecutarlo: `dataclass` busca su clase en `sys.modules`.
sys.modules[_spec.name] = _helper
_spec.loader.exec_module(_helper)
PullRequestRequest = _helper.PullRequestRequest
create_client = _helper.create_client
open_pull_request = _helper.open_pull_request

APPLICATION_REPOSITORY_VARIABLE = "APPLICATION_REPOSITORY"
DEFAULT_POM_GLOB = "backend/*/pom.xml"
DEFAULT_TARGET_REF = "main"
BRANCH_PREFIX = "bump/common-bom-"
COMMON_REPOSITORY = "common"

# Solo toca la version que sigue a <artifactId>common-bom</artifactId>: nunca otra del pom.
BOM_VERSION_PATTERN = (
    r"(<artifactId>\s*common-bom\s*</artifactId>\s*<version>)([^<]+)(</version>)"
)

RELEASE_URL_TEMPLATE = (
    "https://console.aws.amazon.com/codesuite/codecommit/repositories/"
    + COMMON_REPOSITORY
    + "/browse/refs/tags/v{version}"
)

STATUS_UPDATED = "updated"
STATUS_WOULD_UPDATE = "would-update"
STATUS_SKIPPED = "skipped"
STATUS_ERROR = "error"

# --- Mensajes (centralizados, sin concatenacion inline) -----------------------
LOG_FORMAT = "%(levelname)s: %(message)s"
DESCRIPTION = (
    "Sube la version del import de common-bom en los pom de la aplicacion y abre un PR."
)
COMMIT_MESSAGE = "chore(deps): actualiza common-bom a {new_version}"
PR_TITLE = "chore(deps): actualiza common-bom a {new_version}"
PR_BODY = (
    "Subida de una linea de la version del `import` de `common-bom` en cada pom.\n\n"
    "- Version: `{new_version}`\n"
    "- Release: {release_url}\n\n"
    "Poms actualizados:\n{updated}\n\n"
    "Generado automaticamente por el trigger de release de `common`.\n"
)
MESSAGE_NO_POMS_FOUND = "ningun pom casa con {pom_glob}"
MESSAGE_NOTHING_TO_UPDATE = "nada que actualizar"
MESSAGE_WITHOUT_IMPORT = "{pom_path}: no importa common-bom"
MESSAGE_ALREADY_CURRENT = "{pom_path}: ya esta en {new_version}"
MESSAGE_CHANGED = "{pom_path}: {current_version} -> {new_version}"
MESSAGE_NO_TAG = "No hay ningun tag v* en {repository}: nada que hacer"
MESSAGE_RUN = (
    "Version de common: {new_version} | repo: {repository} | pom: {pom_glob}"
    " | rama: {branch}"
)
MESSAGE_MISSING_VALUE = "Falta {name}: defina la variable de entorno {variable} o pasela por linea de ordenes."
MESSAGE_LOG_CANDIDATES = "Pom candidatos en {folder}: {count}"
MESSAGE_LOG_SUMMARY = "Poms actualizados {updated}, saltados {skipped}"
MESSAGE_LOG_DONE = "Procesado {repository}: {status}"

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class BumpRequest:
    """Todo lo que define un bump: destino, version a sembrar y modo."""

    repository: str
    new_version: str
    pom_glob: str
    target_ref: str
    branch: str
    dry_run: bool


@dataclass(frozen=True)
class PomTarget:
    """Un pom leido con lo que hace falta para decidir y aplicar el bump."""

    path: str
    content: str
    commit_id: str
    current_version: str | None
    parent_commit_id: str | None


@dataclass(frozen=True)
class PomChange:
    """Cambio aplicado a un pom: la nota que se informa y el commit al que encadenar."""

    note: str
    updated: bool
    commit_id: str | None = None


@dataclass
class PomOutcome:
    """Resultado de recorrer los pom de un repositorio."""

    request: BumpRequest
    updated: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)
    parent_commit_id: str | None = None


def find_poms(client, request: BumpRequest) -> list[str]:
    """Rutas de los pom que casan con el glob de la peticion.

    `get_folder` devuelve un nivel, asi que del glob solo interesa la carpeta literal anterior al
    `*` y el nombre de fichero: es todo lo que necesita el layout generado (`backend/<ms>/pom.xml`).
    """
    folder, _, file_name = request.pom_glob.rpartition("/")
    folder = folder.split("*")[0].rstrip("/")
    entries = client.get_folder(
        repositoryName=request.repository, folderPath=folder or "/"
    )
    LOGGER.debug(MESSAGE_LOG_CANDIDATES, folder or "/", len(entries.get("tree", [])))
    return sorted(
        entry["path"]
        for entry in entries.get("tree", [])
        if entry["path"].endswith("/" + file_name) or entry["path"] == file_name
    )


def current_bom_version(pom: str, pattern: str = BOM_VERSION_PATTERN) -> str | None:
    """Version declarada en el `import` de `common-bom`, o None si el pom no lo importa."""
    match = re.search(pattern, pom, re.S)
    return match.group(2).strip() if match else None


def bump_pom(pom: str, new_version: str) -> str:
    """Pom con la version del import sustituida por la nueva."""
    replaced = lambda match: match.group(1) + new_version + match.group(3)
    return re.sub(BOM_VERSION_PATTERN, replaced, pom, count=1)


def read_pom(client, outcome: PomOutcome, pom_path: str) -> PomTarget:
    """Lee un pom de la rama base del repositorio."""
    request = outcome.request
    response = client.get_file(
        repositoryName=request.repository, filePath=pom_path, branch=request.target_ref
    )
    content = response["fileContent"].decode("utf-8")
    return PomTarget(
        path=pom_path,
        content=content,
        commit_id=response["commitId"],
        current_version=current_bom_version(content),
        parent_commit_id=outcome.parent_commit_id,
    )


def skip_reason(pom_target: PomTarget, new_version: str) -> str | None:
    """Motivo para no tocar el pom, o None si hay que bumpearlo."""
    if pom_target.current_version is None:
        return MESSAGE_WITHOUT_IMPORT.format(pom_path=pom_target.path)
    if pom_target.current_version == new_version:
        return MESSAGE_ALREADY_CURRENT.format(
            pom_path=pom_target.path, new_version=new_version
        )
    return None


def put_pom(client, request: BumpRequest, pom_target: PomTarget) -> str:
    """Sube el pom con la version nueva y devuelve el id del commit creado."""
    # El primer commit de la rama nace del commit del propio pom; los siguientes encadenan sobre
    # el anterior: una rama, varios commits, un PR.
    parent_commit_id = pom_target.parent_commit_id or pom_target.commit_id
    response = client.put_file(
        repositoryName=request.repository,
        filePath=pom_target.path,
        branch=request.branch,
        fileContent=bump_pom(pom_target.content, request.new_version),
        parentCommitId=parent_commit_id,
        commitMessage=COMMIT_MESSAGE.format(new_version=request.new_version),
    )
    return response["commitId"]


def apply_pom(client, outcome: PomOutcome, pom_path: str) -> PomChange:
    """Lee un pom y devuelve el cambio a aplicar, o el motivo de dejarlo como esta."""
    request = outcome.request
    pom_target = read_pom(client, outcome, pom_path)
    reason = skip_reason(pom_target, request.new_version)
    if reason is not None:
        return PomChange(note=reason, updated=False)
    note = MESSAGE_CHANGED.format(
        pom_path=pom_target.path,
        current_version=pom_target.current_version,
        new_version=request.new_version,
    )
    if request.dry_run:
        return PomChange(note=note, updated=True)
    return PomChange(
        note=note, updated=True, commit_id=put_pom(client, request, pom_target)
    )


def record_change(outcome: PomOutcome, change: PomChange) -> None:
    """Anota el cambio en el resultado y encadena el siguiente commit."""
    if change.updated:
        outcome.updated.append(change.note)
        outcome.parent_commit_id = change.commit_id
        return
    outcome.skipped.append(change.note)


def apply_poms(client, request: BumpRequest, pom_paths: list[str]) -> PomOutcome:
    """Recorre los pom del repositorio y acumula lo actualizado y lo saltado."""
    outcome = PomOutcome(request=request)
    for pom_path in pom_paths:
        record_change(outcome, apply_pom(client, outcome, pom_path))
    return outcome


def base_result(request: BumpRequest) -> dict:
    """Parte comun de todo resultado: que repositorio se ha procesado."""
    return {"repository": request.repository}


def skipped_result(request: BumpRequest, reason: str) -> dict:
    """No se ha tocado nada y se dice por que."""
    return {**base_result(request), "status": STATUS_SKIPPED, "reason": reason}


def open_bump_pull_request(client, request: BumpRequest, updated: list[str]) -> dict:
    """Abre el unico PR de la rama del bump con los poms actualizados."""
    new_version = request.new_version
    return open_pull_request(
        client,
        PullRequestRequest(
            repository=request.repository,
            source_ref=request.branch,
            title=PR_TITLE.format(new_version=new_version),
            body=PR_BODY.format(
                new_version=new_version,
                release_url=RELEASE_URL_TEMPLATE.format(version=new_version),
                updated="\n".join(f"- `{path}`" for path in updated),
            ),
            target_ref=request.target_ref,
        ),
    )


def build_result(client, outcome: PomOutcome) -> dict:
    """Resultado del bump: lo actualizado, lo saltado y el PR si lo hubo."""
    request = outcome.request
    result = {
        **base_result(request),
        "updated": outcome.updated,
        "skipped": outcome.skipped,
    }
    if not outcome.updated:
        return {**result, "status": STATUS_SKIPPED, "reason": MESSAGE_NOTHING_TO_UPDATE}
    if request.dry_run:
        return {**result, "status": STATUS_WOULD_UPDATE}
    pull_request = open_bump_pull_request(client, request, outcome.updated)
    return {**result, "status": STATUS_UPDATED, "pullRequest": pull_request}


def update_repository(client, request: BumpRequest) -> dict:
    """Aplica el bump a todos los pom del repositorio, en una sola rama y un solo PR."""
    pom_paths = find_poms(client, request)
    if not pom_paths:
        return skipped_result(
            request, MESSAGE_NO_POMS_FOUND.format(pom_glob=request.pom_glob)
        )

    outcome = apply_poms(client, request, pom_paths)
    LOGGER.debug(MESSAGE_LOG_SUMMARY, len(outcome.updated), len(outcome.skipped))
    return build_result(client, outcome)


def branch_for_version(new_version: str) -> str:
    return f"{BRANCH_PREFIX}{new_version}"


def version_key(version: str) -> tuple:
    """Clave de ordenacion de una version x.y.z (sin discerning prereleases)."""
    parts = version.split(".")
    numbers = [int(part) if part.isdigit() else 0 for part in parts[:3]]
    return tuple(numbers + [0] * (3 - len(numbers)))


def latest_release_version(client, repository: str) -> str | None:
    """Ultimo tag v* de `common`.

    El trigger se dispara por el evento de CodeCommit, pero el proyecto CodeBuild no puede recibir
    el nombre del tag como variable (el source no admite `branch_ref` en el provider v6). Resolverlo
    aqui desde la API es mas simple y hace el trigger idempotente aunque lleguen dos tags seguidos.
    """
    versions = []
    for page in client.get_paginator("list_references").paginate(
        repositoryName=repository
    ):
        for reference in page.get("references", []):
            name = reference.get("referenceName", "")
            if name.startswith("refs/tags/v"):
                versions.append(name[len("refs/tags/v") :])
    return max(versions, key=version_key) if versions else None


def add_version_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--new-version",
        default=None,
        help=(
            "Version nueva de common (sin 'v'). Si se omite, se toma el ultimo tag v* "
            "de --common-repository."
        ),
    )
    parser.add_argument(
        "--common-repository",
        default=COMMON_REPOSITORY,
        help="Repo de common donde se busca el ultimo tag (por defecto: %(default)s).",
    )


def add_destination_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--repository",
        default=os.environ.get(APPLICATION_REPOSITORY_VARIABLE),
        help=(
            "Repo de la aplicacion, destino unico del bump. Por defecto, la variable de "
            "entorno APPLICATION_REPOSITORY que inyecta Terraform."
        ),
    )
    parser.add_argument(
        "--pom-glob",
        default=DEFAULT_POM_GLOB,
        help="Ruta de los pom de microservicios (por defecto: %(default)s).",
    )
    parser.add_argument(
        "--target-ref",
        default=DEFAULT_TARGET_REF,
        help="Rama base (por defecto: %(default)s).",
    )


def add_execution_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--region", default=None, help="Region AWS (por defecto, la del entorno)."
    )
    parser.add_argument("--dry-run", action="store_true", help="No escribe nada.")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=DESCRIPTION)
    add_version_arguments(parser)
    add_destination_arguments(parser)
    add_execution_arguments(parser)
    return parser.parse_args(argv)


def require_value(value: str | None, name: str) -> str:
    """Valor obligatorio, o salida con el mensaje que dice como llegar a el."""
    if value is None or not value.strip():
        raise SystemExit(
            MESSAGE_MISSING_VALUE.format(
                name=name, variable=APPLICATION_REPOSITORY_VARIABLE
            )
        )
    return value.strip()


def resolve_new_version(client, args: argparse.Namespace) -> str | None:
    """Version a sembrar: la indicada o, si falta, el ultimo tag de `common`."""
    if args.new_version:
        return args.new_version
    return latest_release_version(client, args.common_repository)


def build_request(args: argparse.Namespace, new_version: str) -> BumpRequest:
    """Peticion de bump con los valores obligatorios ya validados."""
    return BumpRequest(
        repository=require_value(args.repository, "--repository"),
        new_version=new_version,
        pom_glob=require_value(args.pom_glob, "--pom-glob"),
        target_ref=args.target_ref,
        branch=branch_for_version(new_version),
        dry_run=args.dry_run,
    )


def run_bump(client, request: BumpRequest) -> dict:
    """Ejecuta el bump y convierte cualquier fallo en un resultado de error."""
    try:
        return update_repository(client, request)
    except Exception as error:  # noqa: BLE001 - el build debe fallar con el detalle
        LOGGER.exception("No se pudo bumpear %s", request.repository)
        return {**base_result(request), "status": STATUS_ERROR, "error": str(error)}


def announce(request: BumpRequest) -> None:
    """Informa de que se va a bumpear antes de tocar nada."""
    print(
        MESSAGE_RUN.format(
            new_version=request.new_version,
            repository=request.repository,
            pom_glob=request.pom_glob,
            branch=request.branch,
        )
    )


def report(result: dict, repository: str) -> int:
    """Imprime el resultado en JSON y devuelve el codigo de salida del build."""
    print(json.dumps(result))
    LOGGER.info(MESSAGE_LOG_DONE, repository, result["status"])
    return 1 if result["status"] == STATUS_ERROR else 0


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
    args = parse_args(argv)
    client = create_client(args.region)

    new_version = resolve_new_version(client, args)
    if not new_version:
        print(MESSAGE_NO_TAG.format(repository=args.common_repository))
        return 0

    request = build_request(args, new_version)
    announce(request)
    return report(run_bump(client, request), request.repository)


if __name__ == "__main__":
    sys.exit(main())
