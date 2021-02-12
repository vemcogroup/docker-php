build: up2date
	docker build . -t 7.4

build-8: up2date
	docker build . -t 8.0

multi-tag-and-push: up2date
	docker buildx build .  --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:7.4 --push

multi-tag-and-push-8: up2date
	docker buildx build .  --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:8.0 --push

tag:
	docker tag 7.4 vemcogroup/php-cli:7.4
	docker push vemcogroup/php-cli:7.4

tag-8:
	docker tag 8.0 vemcogroup/php-cli:8.0
	docker push vemcogroup/php-cli:8.0

up2date:
	docker pull php:7.4-fpm-alpine
	docker pull php:8.0-fpm-alpine
	docker pull composer:2

.PHONY: build