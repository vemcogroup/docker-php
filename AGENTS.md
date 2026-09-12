# Repository agent guidance

## Image ownership

- This repository builds and publishes only the `vemcogroup/php-cli` base images.
- Keep PHP runtime, extensions, and system-library changes here.
- Publish base-image tags such as `vemcogroup/php-cli:8.5` and `vemcogroup/php-cli:next` only through this repository's CI workflow.
- Do not build, package, or push `vemcount/app` images from this repository or from a local checkout.
- Vemcount application images are owned by the Vemcount repository and must be built and pushed by its CI pipeline after consuming the published PHP base image.
- Local validation may inspect or run images, but must not push application images to ECR or another registry.

