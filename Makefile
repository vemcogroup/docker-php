#TAG = 8.0.18
TAG = 8.1.5
DOCKER_SERVER = hp01

build: up2date
	docker pull php:$(TAG)-fpm-alpine
	docker build --build-arg TAG=$(TAG) -t $(TAG) .

tag-and-push-8x: up2date
	docker pull php:$(TAG)-fpm-alpine
	docker buildx build --build-arg TAG=$(TAG) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:$(TAG) --push

external-tag-and-push-80: up2date
	docker pull php:$(TAG)-fpm-alpine

	TAG=$(TAG) DOCKER_SERVER=$(DOCKER_SERVER) bash build.sh

	DOCKER_HOST=
	docker pull vemcogroup/php-cli:8.0-amd64

	docker manifest rm vemcogroup/php-cli:8.0 &
	docker manifest rm vemcogroup/php-cli:$(TAG) &

	sleep 5

	docker manifest create vemcogroup/php-cli:8.0 --amend vemcogroup/php-cli:8.0-amd64 --amend vemcogroup/php-cli:8.0-arm64 &
	docker manifest create vemcogroup/php-cli:$(TAG) --amend vemcogroup/php-cli:8.0-amd64 --amend vemcogroup/php-cli:8.0-arm64

	docker manifest push vemcogroup/php-cli:8.0 &
	docker manifest push vemcogroup/php-cli:$(TAG)

external-tag-and-push-81: up2date
	docker pull php:$(TAG)-fpm-alpine

	TAG=$(TAG) DOCKER_SERVER=$(DOCKER_SERVER) bash build81.sh
	DOCKER_HOST=
	docker pull vemcogroup/php-cli:8.1-amd64

	docker manifest rm vemcogroup/php-cli:8.1 &
	docker manifest rm vemcogroup/php-cli:$(TAG) &

	sleep 5

	docker manifest create vemcogroup/php-cli:8.1 --amend vemcogroup/php-cli:8.1-amd64 --amend vemcogroup/php-cli:8.1-arm64 &
	docker manifest create vemcogroup/php-cli:$(TAG) --amend vemcogroup/php-cli:8.1-amd64 --amend vemcogroup/php-cli:8.1-arm64

	docker manifest push vemcogroup/php-cli:8.1 &
	docker manifest push vemcogroup/php-cli:$(TAG)

tag-and-push-80: up2date
	docker buildx build --build-arg TAG=$(TAG) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:8.0 -t vemcogroup/php-cli:$(TAG) --push

up2date:
	@echo building $(TAG)
	docker pull composer:2

.PHONY: build