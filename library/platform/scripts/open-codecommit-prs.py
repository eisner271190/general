"""Abre pull requests en CodeCommit de forma idempotente.

Se usa desde el trigger de release de `common` (`bump-bom-version.py`) y desde cualquier otro
disparador que necesite abrir un PR.

Idempotencia: antes de crear un PR busca uno ABIERTO cuyo `sourceReference` sea esa rama. Si ya
existe, no hace nada. Con eso se puede reejecutar el trigger sin duplicar PRs.

El repositorio es siempre un parametro (`--repository`, repetible): este script no conoce ningun
repositorio de aplicacion, asi que no hay ningun nombre escrito aqui.

El cliente boto3 se inyecta: asi la logica se puede probar sin AWS ni red.

Uso:
  python3 open-codecommit-prs.py --repository <repo> --branch bump/common-bom-1.0.1 \
      --title "..." --body "..." [--target-ref main] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from dataclasses import dataclass

# --- Constantes (un unico sitio por lenguaje) ---------------------------------
DEFAULT_TARGET_REF = "main"
OPEN_STATUS = "OPEN"
STATUS_ALREADY_OPEN = "already-open"
STATUS_CREATED = "created"
STATUS_WOULD_CREATE = "would-create"
STATUS_ERROR = "error"
PULL_REQUEST_URL = (
    "https://console.aws.amazon.com/codesuite/codecommit/repositories"
    "/{repository}/pull-requests/{pull_request_id}"
)

# --- Mensajes (centralizados, sin concatenacion inline) -----------------------
LOG_FORMAT = "%(levelname)s: %(message)s"
DESCRIPTION = "Abre pull requests idempotentes en CodeCommit (trigger del BOM)."
MESSAGE_CREATED = "CodeCommit PR creado en %s"
MESSAGE_ALREADY_OPEN = "CodeCommit PR ya abierto en %s: %s"
MESSAGE_WOULD_CREATE = "CodeCommit PR que se crearia en %s"
MESSAGE_FAILED = "No se pudo abrir el PR en %s"
MESSAGE_LOG_START = "Apertura de PR en %s desde la rama %s hacia %s (dry_run=%s)"
MESSAGE_LOG_END = "Fin de la apertura de PR en %s: %s"

LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class PullRequestRequest:
    """Lo que identifica y describe un PR a abrir en un repositorio."""

    repository: str
    source_ref: str
    title: str
    body: str
    target_ref: str = DEFAULT_TARGET_REF
    dry_run: bool = False


def create_client(region: str | None = None):
    """Cliente CodeCommit. Import perezoso: la logica se puede probar sin boto3."""
    import boto3

    return boto3.client("codecommit", region_name=region)


def find_open_pull_request(client, request: PullRequestRequest) -> dict | None:
    """PR abierto de ese repositorio cuya rama origen es la de la peticion, o None."""
    paginator = client.get_paginator("list_pull_requests")
    pages = paginator.paginate(
        repositoryName=request.repository, pullRequestStatus=OPEN_STATUS
    )
    for page in pages:
        for pull_request in page.get("pullRequests", []):
            if pull_request.get("sourceReference") == request.source_ref:
                return pull_request
    return None


def create_pull_request(client, request: PullRequestRequest) -> dict:
    """Llama a la API para crear el PR y devuelve el PR creado."""
    created = client.create_pull_request(
        repositoryName=request.repository,
        title=request.title,
        sourceReference=request.source_ref,
        destinationReference=request.target_ref,
        description=request.body,
    )
    return created["pullRequest"]


def describe_pull_request(request: PullRequestRequest, pull_request: dict) -> dict:
    """Parte comun del resultado: repositorio, rama e identificador del PR."""
    pull_request_id = pull_request.get("pullRequestId")
    return {
        "repository": request.repository,
        "sourceRef": request.source_ref,
        "pullRequestId": pull_request_id,
        "url": PULL_REQUEST_URL.format(
            repository=request.repository, pull_request_id=pull_request_id
        ),
    }


def existing_result(request: PullRequestRequest, pull_request: dict) -> dict:
    """Resultado cuando el PR ya estaba abierto: no se ha creado nada."""
    LOGGER.info(
        MESSAGE_ALREADY_OPEN, request.repository, pull_request.get("pullRequestId")
    )
    return {
        **describe_pull_request(request, pull_request),
        "status": STATUS_ALREADY_OPEN,
    }


def created_result(request: PullRequestRequest, pull_request: dict) -> dict:
    """Resultado tras crear el PR."""
    LOGGER.info(MESSAGE_CREATED, request.repository)
    return {**describe_pull_request(request, pull_request), "status": STATUS_CREATED}


def planned_result(request: PullRequestRequest) -> dict:
    """Resultado en `--dry-run`: lo que se crearia sin llamar a la API."""
    LOGGER.info(MESSAGE_WOULD_CREATE, request.repository)
    return {
        "repository": request.repository,
        "sourceRef": request.source_ref,
        "status": STATUS_WOULD_CREATE,
    }


def open_pull_request(client, request: PullRequestRequest) -> dict:
    """Crea el PR solo si no hay ya uno abierto desde esa rama."""
    existing = find_open_pull_request(client, request)
    if existing:
        return existing_result(request, existing)
    if request.dry_run:
        return planned_result(request)
    return created_result(request, create_pull_request(client, request))


def open_repository_pull_request(client, request: PullRequestRequest) -> dict:
    """Abre el PR de un repositorio; un fallo no detiene a los demas."""
    try:
        return open_pull_request(client, request)
    except Exception as error:  # noqa: BLE001 - un repo caido no debe parar el trigger
        LOGGER.exception(MESSAGE_FAILED, request.repository)
        return {
            "repository": request.repository,
            "status": STATUS_ERROR,
            "error": str(error),
        }


def build_request(repository: str, args: argparse.Namespace) -> PullRequestRequest:
    """Peticion de PR de un repositorio a partir de los argumentos ya parseados."""
    return PullRequestRequest(
        repository=repository,
        source_ref=args.branch,
        title=args.title,
        body=args.body,
        target_ref=args.target_ref,
        dry_run=args.dry_run,
    )


def add_repository_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--repository",
        action="append",
        required=True,
        dest="repositories",
        help="Nombre del repositorio. Repetible.",
    )


def add_pull_request_arguments(parser: argparse.ArgumentParser) -> None:
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


def add_execution_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--region", default=None, help="Region AWS (por defecto, la del entorno)."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="No crea nada: solo informa de lo que crearia.",
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=DESCRIPTION)
    add_repository_arguments(parser)
    add_pull_request_arguments(parser)
    add_execution_arguments(parser)
    return parser.parse_args(argv)


def open_pull_requests(client, args: argparse.Namespace) -> list[dict]:
    """Aplica la peticion a cada repositorio indicado."""
    results = []
    for repository in args.repositories:
        LOGGER.debug(
            MESSAGE_LOG_START, repository, args.branch, args.target_ref, args.dry_run
        )
        results.append(
            open_repository_pull_request(client, build_request(repository, args))
        )
        LOGGER.debug(MESSAGE_LOG_END, repository, results[-1]["status"])
    return results


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
    args = parse_args(argv)
    client = create_client(args.region)
    results = open_pull_requests(client, args)
    for result in results:
        print(json.dumps(result))
    return 0 if all(result["status"] != STATUS_ERROR for result in results) else 1


if __name__ == "__main__":
    sys.exit(main())
