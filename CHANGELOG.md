# Changelog

All notable changes to this pipe are documented here. The pipe follows Semantic Versioning; the Docker image tag mirrors the release tag.

## [0.1.0] — 2026-08-24

Initial release. Port of the [`PrestaFlow/github-action`](https://github.com/PrestaFlow/github-action) and [`PrestaFlow/gitlab-component`](https://github.com/PrestaFlow/gitlab-component) to a Bitbucket Pipe.

### Added
- `Dockerfile` on `php:8.3-cli-alpine` with Composer, docker CLI + compose, curl, jq.
- `entrypoint.sh` orchestrating the pipeline scripts.
- `scripts/flashlight.sh` — boot PrestaShop Flashlight + MariaDB via docker compose.
- `scripts/runner.sh` — execute `composer run prestaflow:json:file`.
- `scripts/visual-download.sh` — pull visual-regression baselines for the current branch.
- `scripts/upload.sh` — POST `results.json` + PNGs to `POST /ci/github-action`.
- `scripts/comment-pr.sh` — idempotent PR summary comment via Bitbucket Cloud API.
- `scripts/outputs.sh` — aggregate final counters, write `prestaflow.env`, fail on any test failure.
- `pipe.yml` metadata declaring inputs and image.
- `examples/bitbucket-pipelines.yml` end-to-end sample.
- README with variable reference, outputs, PR-comment setup, and publishing instructions.
