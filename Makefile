TAG = 8.0.14
DOCKER_SERVER = nuc

build-8: up2date
	docker build --build-arg TAG=$(TAG) -t $(TAG) .

tag-and-push-8x: up2date
	docker pull php:$(TAG)-fpm-alpine
	docker buildx build --build-arg TAG=$(TAG) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:$(TAG) --push

external-tag-and-push-80: up2date
	docker pull php:$(TAG)-fpm-alpine

#	TAG=$(TAG) DOCKER_SERVER=$(DOCKER_SERVER) bash build.sh

	docker manifest create vemcogroup/php-cli:8.0 --amend vemcogroup/php-cli:8.0-amd64 --amend vemcogroup/php-cli:8.0-arm64
	docker manifest create vemcogroup/php-cli:$(TAG) --amend vemcogroup/php-cli:8.0-amd64 --amend vemcogroup/php-cli:8.0-arm64
	docker manifest push vemcogroup/php-cli:8.0
	docker manifest push vemcogroup/php-cli:$(TAG)

tag-and-push-80: up2date
	docker buildx build --build-arg TAG=$(TAG) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:8.0 -t vemcogroup/php-cli:$(TAG) --push

up2date:
	@echo building $(TAG)
	docker pull composer:2

.PHONY: build