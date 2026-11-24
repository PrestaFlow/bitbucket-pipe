# Changelog

All notable changes to this pipe are documented here. The pipe follows Semantic Versioning; the Docker image tag mirrors the release tag.

## [0.2.0] — Unreleased

Flashlight fixes of the GitHub Action v2.3.0 to v2.4.1, for `prestaflow/php-library` 1.9.0.

### Fixed
- **`PRESTAFLOW_PS_VERSION` is taken from the image tag, not set to the tag itself.** The library only accepts a bare version, so `latest` (the default) or `8.2.8-nginx` stopped the run on `Error with version …`. `8.2.8-nginx` now gives `8.2.8`. For a tag without a version (`latest`, `nightly`…), the version is read from the image's `PS_VERSION` variable, with `app/AppKernel.php` as a fallback; when nothing gives it, it is left to you with a warning. The image still uses the tag as given.
- **Flashlight accounts.** The generated `.env.local` sets the image's back-office account (`admin@prestashop.com` / `prestashop`) and the demo customer (`pub@prestashop.com` / `123456789`) at the lowest priority: php-library 1.9.0 no longer falls back on demo accounts.
- **A versioned `.env.local` is no longer overwritten.** It is merged into the generated one and restored when the pipe exits. The generated file is, from the lowest to the highest priority: Flashlight accounts, your `.env.local` (or `.env`), the shop's `PRESTAFLOW_FO_URL` / `PRESTAFLOW_BO_URL` / `PRESTAFLOW_PS_VERSION`, then the `PRESTAFLOW_*` variables passed to the pipe. Those keys are removed from composer's environment so the library reads them from the file.
- **Readiness.** The pipe waits for `/admin-dev/` to answer 302/200 instead of any 2xx/3xx on `/`, and names the last status on timeout.

### Added
- `FLASHLIGHT_INSTALL_MODULE` variable (default `true`): when `composer.json` has `type: prestashop-module`, the mounted module is installed with `php bin/console prestashop:module install <name>` once the shop is ready. A failed install only warns.
- `PRESTAFLOW_BO_URL` and `PRESTAFLOW_FLASHLIGHT_TAG` in `prestaflow.env`.

### Changed
- `PS_VERSION` reaches the scripts as `PRESTAFLOW_FLASHLIGHT_TAG` (it was `PRESTAFLOW_PS_VERSION`). `PRESTAFLOW_PS_VERSION` in `prestaflow.env` is now the bare version, and is absent when it could not be told. A `PRESTAFLOW_PS_VERSION` passed to the pipe is no longer overwritten by `PS_VERSION`, and wins.
- A `PRESTAFLOW_*` variable passed to the pipe now reaches the tests with Flashlight, and wins over the generated values.
- `pipe.yml`, the README and the example reference `prestaflow/pipe-push:0.2.0` (and the floating `:0`). They said `1.0.0`, which never matched a release.

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
