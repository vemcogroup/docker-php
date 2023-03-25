#!/bin/bash

DOCKER_HOST= docker buildx build --no-cache --build-arg TAG=${TAG} . --platform linux/arm64 -t vemcogroup/php-cli:next-arm64 --push &

DOCKER_HOST=ssh://${DOCKER_SERVER} docker pull composer:2
DOCKER_HOST=ssh://${DOCKER_SERVER} docker pull php:${TAG}-fpm-alpine
DOCKER_HOST=ssh://${DOCKER_SERVER} docker buildx build --no-cache --build-arg TAG=${TAG} . --platform linux/amd64 -t vemcogroup/php-cli:next-amd64 --push &

wait

DOCKER_HOST=
docker pull vemcogroup/php-cli:next-amd64

docker manifest rm vemcogroup/php-cli:next &
docker manifest rm vemcogroup/php-cli:${TAG} &

wait

docker manifest create vemcogroup/php-cli:next --amend vemcogroup/php-cli:next-amd64 --amend vemcogroup/php-cli:next-arm64 &
docker manifest create vemcogroup/php-cli:8.2 --amend vemcogroup/php-cli:next-amd64 --amend vemcogroup/php-cli:next-arm64 &
docker manifest create vemcogroup/php-cli:${TAG} --amend vemcogroup/php-cli:next-amd64 --amend vemcogroup/php-cli:next-arm64 &

wait

docker manifest push vemcogroup/php-cli:next &
docker manifest push vemcogroup/php-cli:8.2 &
docker manifest push vemcogroup/php-cli:${TAG} &

wait