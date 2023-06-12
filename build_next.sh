#!/bin/bash

DOCKER_HOST= docker buildx build --progress plain --no-cache --build-arg TAG=${TAG} . --platform linux/arm64 -t vemcogroup/php-cli:next-arm64 --push &

DOCKER_HOST=ssh://${DOCKER_SERVER} docker pull composer:2
DOCKER_HOST=ssh://${DOCKER_SERVER} docker pull php:${TAG}-fpm-alpine
DOCKER_HOST=ssh://${DOCKER_SERVER} docker buildx build --progress plain --no-cache --build-arg TAG=${TAG} . --platform linux/amd64 -t vemcogroup/php-cli:next-amd64 --push &

wait

DOCKER_HOST=
docker pull vemcogroup/php-cli:next-amd64

docker buildx imagetools create -t vemcogroup/php-cli:next vemcogroup/php-cli:next-amd64 vemcogroup/php-cli:next-arm64 &
docker buildx imagetools create -t vemcogroup/php-cli:8.2 vemcogroup/php-cli:next-amd64 vemcogroup/php-cli:next-arm64 &
docker buildx imagetools create -t vemcogroup/php-cli:${TAG} vemcogroup/php-cli:next-amd64 vemcogroup/php-cli:next-arm64 &

wait