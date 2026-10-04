#!/usr/bin/env bash
# Publica la imagen base de runtime en ECR. Lo ejecuta el pipeline en cada release.
#
#   AWS_REGION=us-east-1 AWS_ACCOUNT_ID=123456789012 ./docker/publish-base-image.sh 1.0.0
#
# El token de ECR lo obtiene aws ecr get-login-password en el momento: nunca se escribe en disco.
set -euo pipefail

VERSION="${1:?uso: publish-base-image.sh <version>}"
REPOSITORY="${ECR_REPOSITORY:-epc/common-base}"
ACCOUNT_ID="${AWS_ACCOUNT_ID:?falta AWS_ACCOUNT_ID}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"

IMAGE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPOSITORY}:${VERSION}"

aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker build -t "${IMAGE}" "$(dirname "$0")"
docker push "${IMAGE}"

echo "Publicada ${IMAGE}"