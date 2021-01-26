build:
	docker build . -t 7.4

multi-tag-and-push:
	 docker buildx build .  --platform linux/amd64,linux/arm64 -t vemcogroup/php-cli:7.4.14-multi --push

.PHONY: build