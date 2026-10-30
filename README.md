# PHP base image

PHP 8.5 images are published to Docker Hub as `vemcogroup/php-cli:8.5`, the PHP version tag, and `next`, so external developers can pull them without AWS access.

Release command: `make external-tag-and-push-next`, using the configured native ARM64 and AMD64 builders and an authenticated Docker Hub account. The release script pulls current upstream images, disables build-layer caching, and verifies both architectures before updating the shared tags. Architecture-specific version tags are published first for validation.

The build and smoke checks require Debian Trixie Brotli `1.1.0-2+deb13u1` or newer, Node.js 24.22.1 or newer, and Bun 1.4.4 or newer. Existing PHP extensions and runtime checks remain enabled.

The temporary private ECR repository was removed after the public Docker Hub release was verified. Application images are built and deployed separately by their owning repositories and must be rebuilt with a refreshed base to consume the fixes.
