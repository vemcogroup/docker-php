TAG_PREV = 8.3.22
TAG = 8.4.21
TAG_NEXT = 8.5.12
DOCKER_SERVER = i9

# Define a target to create and use the builder if it doesn't exist
create_builder:
	@if ! docker buildx inspect php_builder > /dev/null 2>&1; then \
		docker buildx create --name php_builder --use; \
	fi

build:
	docker pull php:$(TAG)-fpm-trixie
	docker build --pull --build-arg TAG=$(TAG) -t $(TAG) .

tag-and-push-prev: create_builder
	@echo building $(TAG_PREV)

	docker pull php:$(TAG_PREV)-fpm-trixie
	docker buildx build --builder php_builder --pull --no-cache --build-arg TAG=$(TAG_PREV) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:8.2 -t vemcogroup/php-cli:$(TAG_PREV) --push

tag-and-push: create_builder
	@echo building $(TAG)

	docker pull php:$(TAG)-fpm-trixie
	docker buildx build --builder php_builder --pull --no-cache --build-arg TAG=$(TAG) . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:8.3 -t vemcogroup/php-cli:$(TAG) --push

tag-and-push-next: external-tag-and-push-next

external-tag-and-push-prev:
	@echo building $(TAG_PREV)
	docker pull php:$(TAG_PREV)-fpm-trixie

	TAG=$(TAG_PREV) DOCKER_SERVER=$(DOCKER_SERVER) bash build_prev.sh

external-tag-and-push:
	@echo building $(TAG)
	docker pull php:$(TAG)-fpm-trixie

	TAG=$(TAG) DOCKER_SERVER=$(DOCKER_SERVER) bash build.sh

external-tag-and-push-next:
	@echo building $(TAG_NEXT)
	docker pull php:$(TAG_NEXT)-fpm-trixie

	TAG=$(TAG_NEXT) DOCKER_SERVER=$(DOCKER_SERVER) bash build_next.sh

.PHONY: build tag-and-push-prev tag-and-push tag-and-push-next external-tag-and-push-prev external-tag-and-push external-tag-and-push-next create_builder
