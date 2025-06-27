TAG_PREV = 8.2.28
TAG = 8.3.22
TAG_NEXT = 8.4.8
DOCKER_SERVER = hp01-local
#DOCKER_SERVER = nuc

# Define a target to create and use the builder if it doesn't exist
create_builder:
	@if ! docker buildx inspect php_builder > /dev/null 2>&1; then \
		docker buildx create --name php_builder --use; \
	fi

build: up2date
	docker pull php:$(TAG)-fpm-alpine
	docker build --build-arg TAG=$(TAG) -t $(TAG) .

tag-and-push: up2date
	@echo building $(TAG)

	docker pull php:$(TAG)-fpm-alpine
	docker buildx build --builder php_builder --no-cache --build-arg TAG=$(TAG) . --platform linux/arm64 -t vemcogroup/php-cli:8.2 -t vemcogroup/php-cli:$(TAG) --push

tag-and-push-next: up2date
	@echo building $(TAG_NEXT)

	docker pull php:$(TAG_NEXT)-fpm-alpine
	docker buildx build --builder php_builder --no-cache --build-arg TAG=$(TAG_NEXT) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:next -t vemcogroup/php-cli:$(TAG_NEXT) --push


external-tag-and-push-prev: up2date
	@echo building $(TAG_PREV)
	docker pull php:$(TAG_PREV)-fpm-alpine

	TAG=$(TAG_PREV) DOCKER_SERVER=$(DOCKER_SERVER) bash build_prev.sh

external-tag-and-push: up2date
	@echo building $(TAG)
	docker pull php:$(TAG)-fpm-alpine

	TAG=$(TAG) DOCKER_SERVER=$(DOCKER_SERVER) bash build.sh

external-tag-and-push-next: up2date
	@echo building $(TAG_NEXT)
	docker pull php:$(TAG_NEXT)-fpm-alpine

	TAG=$(TAG_NEXT) DOCKER_SERVER=$(DOCKER_SERVER) bash build_next.sh

up2date: create_builder
	docker pull composer:2

.PHONY: build
