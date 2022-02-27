#!/bin/bash

DOCKER_HOST= docker buildx build --build-arg TAG=${TAG} . --platform linux/arm64 -t vemcogroup/php-cli:8.1-arm64 --push &

DOCKER_HOST=ssh://${DOCKER_SERVER} docker pull composer:2
DOCKER_HOST=ssh://${DOCKER_SERVER} docker pull php:${TAG}-fpm-alpine
DOCKER_HOST=ssh://${DOCKER_SERVER} docker buildx build --build-arg TAG=${TAG} . --platform linux/amd64 -t vemcogroup/php-cli:8.1-amd64 --push &

wait
