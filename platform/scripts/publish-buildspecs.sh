#!/usr/bin/env bash
# Publica los buildspecs compartidos en el bucket versionado. Lo ejecuta el pipeline de
# platform o el usuario a mano durante el bootstrap.
#
#   AWS_REGION=us-east-1 ./scripts/publish-buildspecs.sh
set -euo pipefail

BUCKET="${BUILDSPECS_BUCKET:-epc-buildspecs}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

aws s3 sync "${SCRIPT_DIR}/../buildspecs" "s3://${BUCKET}/" --region "${REGION}"

echo "Buildspecs publicados en s3://${BUCKET}/ (versionado: cada publicacion crea una version nueva)"