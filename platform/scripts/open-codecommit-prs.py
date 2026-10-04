"""Abre pull requests en CodeCommit de forma idempotente.

Se usa desde los dos caminos de Renovate:

  1. `bump-bom-version.py` (trigger por release de `common`).
  2. Manualmente, pasando una lista de repos y ramas.

Idempotencia: antes de crear un PR busca uno ABIERTO cuyo `sourceReference` sea esa rama. Si ya
existe, no hace nada. Con eso se puede reejecutar el trigger sin duplicar PRs.

El cliente boto3 se inyecta: asi la logica se puede probar sin AWS ni red.

Uso:
  python3 open-codecommit-prs.py --repository quizapi --branch renovate/common-bom-1.0.1 \
      --title "..." --body "..." [--target-ref main] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import logging
import sys

DEFAULT_TARGET_REF = "main"
OPEN_STATUS = "OPEN"
LOGGER = logging.getLogger(__name__)


def create_client(region: str | None = None):
    """Cliente CodeCommit. Import perezoso: los tests de logica no necesitan boto3."""
    import boto3

    return boto3.client("codecommit", region_name=region)


def find_open_pull_request(client, repository: str, source_ref: str) -> dict | None:
    """Devuelve el PR abierto cuya rama origen es `source_ref`, o None."""
    paginator = client.get_paginator("list_pull_requests")
    for page in paginator.paginate(
        repositoryName=repository, pullRequestStatus=OPEN_STATUS
    ):
        for pull_request in page.get("pullRequests", []):
            if pull_request.get("sourceReference") == source_ref:
                return pull_request
    return None


def open_pull_request(
    client,
    repository: str,
    source_ref: str,
    title: str,
    body: str,
    target_ref: str = DEFAULT_TARGET_REF,
    dry_run: bool = False,
) -> dict:
    """Crea el PR solo si no hay ya uno abierto desde `source_ref`. Devuelve el resultado."""
    existing = find_open_pull_request(client, repository, source_ref)
    if existing:
        return pull_request_result(repository, source_ref, existing)

    if dry_run:
        return result(repository, source_ref, "would-create")

    created = client.create_pull_request(
        repositoryName=repository,
        title=title,
        sourceReference=source_ref,
        destinationReference=target_ref,
        description=body,
    )
    return pull_request_result(
        repository, source_ref, created["pullRequest"], "created"
    )


def result(repository: str, source_ref: str, status: str) -> dict:
    return {"repository": repository, "sourceRef": source_ref, "status": status}


def pull_request_result(
    repository: str, source_ref: str, pull_request: dict, status: str = "already-open"
) -> dict:
    pull_request_id = pull_request.get("pullRequestId")
    response = result(repository, source_ref, status)
    response["pullRequestId"] = pull_request_id
    if status == "created":
        response["url"] = (
            "https://console.aws.amazon.com/codesuite/codecommit/repositories/"
            f"{repository}/pull-requests/{pull_request_id}"
        )
    return response


def open_pull_requests(
    client,
    repositories: list[str],
    source_ref: str,
    title: str,
    body: str,
    target_ref: str = DEFAULT_TARGET_REF,
    dry_run: bool = False,
) -> list[dict]:
    """Aplica `open_pull_request` a cada repositorio. Un fallo no detiene a los demas."""
    return [
        process_repository(
            client, repository, source_ref, title, body, target_ref, dry_run
        )
        for repository in repositories
    ]


def process_repository(
    client,
    repository: str,
    source_ref: str,
    title: str,
    body: str,
    target_ref: str,
    dry_run: bool,
) -> dict:
    try:
        response = open_pull_request(
            client, repository, source_ref, title, body, target_ref, dry_run
        )
        LOGGER.info("CodeCommit PR %s: %s", repository, response["status"])
        return response
    except Exception as error:  # noqa: BLE001 - un repo caido no debe parar el trigger
        LOGGER.exception("No se pudo abrir PR en %s", repository)
        return {"repository": repository, "status": "error", "error": str(error)}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Abre pull requests idempotentes en CodeCommit (Renovate / bump del BOM)."
    )
    parser.add_argument(
        "--repository",
        action="append",
        required=True,
        dest="repositories",
        help="Nombre del repositorio. Repetible.",
    )
    parser.add_argument(
        "--branch", required=True, help="Rama origen (sourceReference) del PR."
    )
    parser.add_argument("--title", required=True, help="Titulo del PR, con la version.")
    parser.add_argument(
        "--body", default="", help="Cuerpo del PR, con el enlace al release."
    )
    parser.add_argument(
        "--target-ref",
        default=DEFAULT_TARGET_REF,
        help="Rama destino del PR (por defecto: %(default)s).",
    )
    parser.add_argument(
        "--region", default=None, help="Region AWS (por defecto, la del entorno)."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="No crea nada: solo informa de lo que crearia.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    args = parse_args(argv)
    client = create_client(args.region)
    results = open_pull_requests(
        client,
        args.repositories,
        args.branch,
        args.title,
        args.body,
        args.target_ref,
        args.dry_run,
    )
    for result in results:
        print(json.dumps(result))
    return 0 if all(r["status"] != "error" for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
