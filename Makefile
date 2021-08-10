TAG = 8.0.8

build-8: up2date
	docker build . -t $TAG

tag-and-push-8x: up2date
	docker pull php:$(TAG)-fpm-alpine
	docker buildx build . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:$(TAG) --push

tag-and-push-80: up2date
	docker pull php:8.0-fpm-alpine
	docker buildx build . --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:8.0 -t vemcogroup/php-cli:$(TAG) --push

up2date:
	@echo building $(TAG)
	docker pull composer:2

.PHONY: build