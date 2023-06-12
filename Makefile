TAG = 8.1.20
TAG_NEXT = 8.2.7
DOCKER_SERVER = hp01

build: up2date
	docker pull php:$(TAG)-fpm-alpine
	docker build --build-arg TAG=$(TAG) -t $(TAG) .

tag-and-push: up2date
	@echo building $(TAG)

	docker pull php:$(TAG)-fpm-alpine
	docker buildx build --no-cache --build-arg TAG=$(TAG) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:8.1  -t vemcogroup/php-cli:$(TAG) --push

tag-and-push-next: up2date
	@echo building $(TAG_NEXT)

	docker pull php:$(TAG_NEXT)-fpm-alpine
	docker buildx build --no-cache --build-arg TAG=$(TAG_NEXT) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:next  -t vemcogroup/php-cli:$(TAG_NEXT) --push

external-tag-and-push: up2date
	@echo building $(TAG)

	docker pull php:$(TAG)-fpm-alpine

	TAG=$(TAG) DOCKER_SERVER=$(DOCKER_SERVER) bash build.sh

external-tag-and-push-next: up2date
	@echo building $(TAG_NEXT)
	docker pull php:$(TAG_NEXT)-fpm-alpine

	TAG=$(TAG_NEXT) DOCKER_SERVER=$(DOCKER_SERVER) bash build_next.sh

up2date:
	docker pull composer:2

.PHONY: build