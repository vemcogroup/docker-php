#!/bin/bash
set -euo pipefail

: "${TAG:?Set TAG to the PHP release version}"
: "${DOCKER_SERVER:?Set DOCKER_SERVER to the native AMD64 builder host}"
image=vemcogroup/php-cli
amd_builder=${AMD64_BUILDER:-php_builder_${DOCKER_SERVER}}
export DOCKER_CLI_HINTS=false

DOCKER_HOST= docker buildx inspect "$amd_builder" >/dev/null 2>&1 ||
  DOCKER_HOST= docker buildx create --name "$amd_builder" "ssh://${DOCKER_SERVER}"

DOCKER_HOST= docker buildx build --builder php_builder --pull --no-cache --build-arg TAG="$TAG" . --platform linux/arm64 -t "$image:$TAG-arm64" --push &
arm_pid=$!
DOCKER_HOST= docker buildx build --builder "$amd_builder" --pull --no-cache --build-arg TAG="$TAG" . --platform linux/amd64 -t "$image:$TAG-amd64" --push &
amd_pid=$!
build_status=0
wait "$arm_pid" || build_status=$?
wait "$amd_pid" || build_status=$?
test "$build_status" -eq 0

DOCKER_HOST= docker pull --platform linux/arm64 "$image:$TAG-arm64"
DOCKER_HOST=ssh://${DOCKER_SERVER} docker pull --platform linux/amd64 "$image:$TAG-amd64"
DOCKER_HOST= TEST_PLATFORM=linux/arm64 sh tests/smoke-arm64.sh "$image:$TAG-arm64"
DOCKER_HOST=ssh://${DOCKER_SERVER} TEST_PLATFORM=linux/amd64 sh tests/smoke-arm64.sh "$image:$TAG-amd64"
DOCKER_HOST= docker buildx imagetools create --prefer-index=false -t "$image:8.5-arm64" -t "$image:next-arm64" "$image:$TAG-arm64"
DOCKER_HOST= docker buildx imagetools create --prefer-index=false -t "$image:8.5-amd64" -t "$image:next-amd64" "$image:$TAG-amd64"
DOCKER_HOST= docker buildx imagetools create -t "$image:8.5" -t "$image:$TAG" -t "$image:next" "$image:$TAG-amd64" "$image:$TAG-arm64"
