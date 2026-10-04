"""Trigger por release de `common`: sube la version del `import` de `common-bom` en cada
microservicio y abre un pull request.

Se ejecuta en un proyecto CodeBuild disparado por el evento de CodeCommit "Reference Change"
cuando aparece un tag `v*` en el repo `common` (coste 0: los service events de CodeCommit se
ingieren gratis).

Que hace, por repositorio de microservicio:
  1. Lista los repos con el prefijo de los ms (`--repo-prefix`), con paginacion.
  2. Lee su `pom.xml` y busca el `import` de `common-bom`.
  3. Si ya esta a la version nueva, no hace nada (idempotente).
  4. Si no, cambia SOLO esa linea, crea la rama y abre el PR (idempotente, ver
     open-codecommit-prs.py).

Ninguna credencial en este fichero: el cliente boto3 usa el rol del build y las credenciales de Git
llegan por variables de entorno sembradas en Secrets Manager.

Uso:
  NEW_VERSION=1.0.1 python3 bump-bom-version.py
  python3 bump-bom-version.py --new-version 1.0.1 --dry-run
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import logging
import sys
from pathlib import Path

# El helper se llama con guiones (`open-codecommit-prs.py`), que no es un modulo importable:
# se carga por ruta para reutilizar su logica sin duplicarla ni renombrar el fichero.
_HELPER_PATH = Path(__file__).with_name("open-codecommit-prs.py")
_spec = importlib.util.spec_from_file_location("open_codecommit_prs", _HELPER_PATH)
_helper = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_helper)
create_client = _helper.create_client
open_pull_request = _helper.open_pull_request

DEFAULT_POM_PATH = "pom.xml"
DEFAULT_TARGET_REF = "main"
BRANCH_PREFIX = "renovate/common-bom-"
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
LOGGER = logging.getLogger(__name__)


def list_microservice_repositories(client, prefix: str) -> list[str]:
    """Repos de microservicios, paginando: `list_repositories` devuelve 1000 por pagina."""
    paginator = client.get_paginator("list_repositories")
    names: list[str] = []
    for page in paginator.paginate():
        for repository in page.get("repositories", []):
            name = repository["repositoryName"]
            if name.startswith(prefix):
                names.append(name)
    return sorted(names)


def read_file(client, repository: str, file_path: str, ref: str) -> tuple[str, str]:
    """Devuelve (contenido, commitId) del fichero en la rama `ref`."""
    response = client.get_file(
        repositoryName=repository, filePath=file_path, branch=ref
    )
    return response["fileContent"].decode("utf-8"), response["commitId"]


def current_bom_version(pom: str, pattern: str = BOM_VERSION_PATTERN) -> str | None:
    """Version declarada en el `import` de `common-bom`, o None si el ms no lo importa."""
    import re

    match = re.search(pattern, pom, re.S)
    return match.group(2).strip() if match else None


def bump_pom(
    pom: str, new_version: str, pattern: str = BOM_VERSION_PATTERN
) -> str | None:
    """Devuelve el pom con la version del import sustituida, o None si no hay import."""
    import re

    return re.sub(
        pattern, lambda m: m.group(1) + new_version + m.group(3), pom, count=1
    )


def branch_for_version(new_version: str) -> str:
    return f"{BRANCH_PREFIX}{new_version}"


def version_key(version: str) -> tuple:
    """Clave de ordenacion de una version x.y.z (sin discerning prereleases)."""
    parts = version.split(".")
    numbers = [int(part) if part.isdigit() else 0 for part in parts[:3]]
    return tuple(numbers + [0] * (3 - len(numbers)))


def latest_release_version(client, repository: str = COMMON_REPOSITORY) -> str | None:
    """Ultimo tag v* de `common`.

    El trigger se dispara por el evento de CodeCommit, pero el proyecto CodeBuild no puede recibir
    el nombre del tag como variable (el source no admite `branch_ref` en el provider v6). Resolverlo
    aqui desde la API es mas simple y hace el trigger idempotente aunque lleguen dos tags seguidos.
    """
    paginator = client.get_paginator("list_references")
    versions = []
    for page in paginator.paginate(repositoryName=repository):
        for reference in page.get("references", []):
            name = reference.get("referenceName", "")
            if name.startswith("refs/tags/v"):
                versions.append(name[len("refs/tags/v") :])
    return max(versions, key=version_key) if versions else None


def pull_request_title(new_version: str) -> str:
    return f"chore(deps): actualiza common-bom a {new_version}"


def pull_request_body(new_version: str) -> str:
    return (
        "Subida de una linea de la version del `import` de `common-bom`.\n\n"
        f"- Version: `{new_version}`\n"
        f"- Release: {RELEASE_URL_TEMPLATE.format(version=new_version)}\n\n"
        "Generado automaticamente por el trigger de release de `common`.\n"
    )


def update_repository(
    client,
    repository: str,
    new_version: str,
    target_ref: str,
    pom_path: str,
    branch: str,
    dry_run: bool,
) -> dict:
    """Aplica el bump a un repositorio. Idempotente."""
    pom, commit_id = read_file(client, repository, pom_path, target_ref)
    current = current_bom_version(pom)
    if current is None:
        return {
            "repository": repository,
            "status": "skipped",
            "reason": "no importa common-bom",
        }
    if current == new_version:
        return {
            "repository": repository,
            "status": "skipped",
            "reason": f"ya esta en {new_version}",
        }

    updated = bump_pom(pom, new_version)
    if dry_run:
        return {
            "repository": repository,
            "status": "would-update",
            "from": current,
            "to": new_version,
        }

    client.put_file(
        repositoryName=repository,
        filePath=pom_path,
        branch=branch,
        fileContent=updated,
        parentCommitId=commit_id,
        commitMessage=f"chore(deps): actualiza common-bom a {new_version}",
    )
    pull_request = open_pull_request(
        client,
        repository,
        branch,
        pull_request_title(new_version),
        pull_request_body(new_version),
        target_ref,
    )
    return {"repository": repository, "status": "updated", "pullRequest": pull_request}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sube la version del import de common-bom en los repos de ms y abre un PR."
    )
    parser.add_argument(
        "--new-version",
        default=None,
        help="Version nueva de common (sin 'v'). Si se omite, se toma el ultimo tag v* de --common-repository.",
    )
    parser.add_argument(
        "--common-repository",
        default=COMMON_REPOSITORY,
        help="Repo de common donde se busca el ultimo tag (por defecto: %(default)s).",
    )
    parser.add_argument(
        "--repo-prefix",
        required=True,
        help="Prefijo configurado para seleccionar los repos de microservicios.",
    )
    parser.add_argument(
        "--pom-path",
        default=DEFAULT_POM_PATH,
        help="Ruta del pom (por defecto: %(default)s).",
    )
    parser.add_argument(
        "--target-ref",
        default=DEFAULT_TARGET_REF,
        help="Rama base (por defecto: %(default)s).",
    )
    parser.add_argument(
        "--region", default=None, help="Region AWS (por defecto, la del entorno)."
    )
    parser.add_argument("--dry-run", action="store_true", help="No escribe nada.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    args = parse_args(argv)
    if not args.repo_prefix.strip():
        raise SystemExit(
            "--repo-prefix no puede estar vacío; se rechaza procesar todos los repos"
        )
    client = create_client(args.region)

    new_version = args.new_version or latest_release_version(
        client, args.common_repository
    )
    if not new_version:
        print(f"No hay ningun tag v* en {args.common_repository}: nada que hacer")
        return 0

    branch = branch_for_version(new_version)
    repositories = list_microservice_repositories(client, args.repo_prefix)
    print(f"Version de common: {new_version} | rama: {branch}")
    print(f"Repos de ms con prefijo {args.repo_prefix!r}: {len(repositories)}")

    failures = 0
    for repository in repositories:
        try:
            result = update_repository(
                client,
                repository,
                new_version,
                args.target_ref,
                args.pom_path,
                branch,
                args.dry_run,
            )
        except Exception as error:  # noqa: BLE001 - un ms caido no debe parar a los demas
            failures += 1
            result = {"repository": repository, "status": "error", "error": str(error)}
        print(json.dumps(result))
        LOGGER.info("Procesado %s: %s", repository, result["status"])
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
