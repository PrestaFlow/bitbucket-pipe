# PrestaFlow — Bitbucket Pipe

Run [PrestaFlow](https://prestaflow.io) tests inside Bitbucket Pipelines: optionally boot a PrestaShop Flashlight instance, execute your suite, upload results (plus error and visual‑regression screenshots) to PrestaFlow, and comment the summary back on the pull request.

Companion of [`PrestaFlow/github-action`](https://github.com/PrestaFlow/github-action) and [`PrestaFlow/gitlab-component`](https://github.com/PrestaFlow/gitlab-component) — same behaviour, same backend, different CI idioms.

## Quick start

```yaml
# bitbucket-pipelines.yml
image: php:8.3-cli

pipelines:
  pull-requests:
    '**':
      - step:
          name: PrestaFlow
          services: [docker]
          script:
            - pipe: docker://prestaflow/pipe-push:0.2.0
              variables:
                TOKEN: $PRESTAFLOW_TOKEN
                PROJECT_ID: pk_01ABC...
                FLASHLIGHT: 'true'
                PS_VERSION: '9.0.0'
                BITBUCKET_ACCESS_TOKEN: $PRESTAFLOW_BITBUCKET_TOKEN
```

Full sample: [`examples/bitbucket-pipelines.yml`](./examples/bitbucket-pipelines.yml).

## Required repository variables

Add these in **Repository settings → Repository variables**:

| Variable | Required | Purpose |
|---|---|---|
| `PRESTAFLOW_TOKEN` | yes | PrestaFlow API token. Mark as **Secured**. |
| `PRESTAFLOW_BITBUCKET_TOKEN` | optional | Bitbucket Repository Access Token with `pullrequest:write` scope. Only needed if you want the pipe to post PR summary comments. Mark as **Secured**. |

## Variables

| Name | Default | Description |
|---|---|---|
| `TOKEN` | — | PrestaFlow API token. Required. |
| `PROJECT_ID` | `""` | PrestaFlow project Product Key (e.g. `pk_01ABC…`). |
| `API_URL` | `https://api.prestaflow.io` | PrestaFlow API base URL. |
| `EXECUTE` | `true` | Run `composer run prestaflow:json:file` before upload. Set to `false` if a previous step already produced `results.json`. |
| `SUITES` | `""` | Comma‑separated suites to run (e.g. `BackOffice,FrontOffice`). Empty runs all. |
| `FLASHLIGHT` | `false` | Boot a PrestaShop Flashlight Docker container to test against. Requires `services: [docker]` on the step. |
| `PS_VERSION` | `latest` | Flashlight image tag when `FLASHLIGHT=true` (`9.0.0`, `8.2.8-nginx`, `latest`). See [Flashlight](#flashlight) for the version given to the tests. |
| `FLASHLIGHT_MOUNT` | `auto` | Where to mount the workspace inside the Flashlight container: `auto`, `root`, `modules`, or `themes`. `auto` reads `composer.json` `type` (`prestashop-module` / `prestashop-theme`). |
| `FLASHLIGHT_INIT_SCRIPTS` | `""` | Path (absolute or relative to the workspace) to a directory of Flashlight init scripts, mounted read‑only at `/tmp/init-scripts`. |
| `FLASHLIGHT_INSTALL_MODULE` | `true` | When `composer.json` has `type: prestashop-module`, install the mounted module in Flashlight once the shop is ready. Set to `false` to skip. |
| `PR_COMMENT` | auto | Post/update a PR summary comment. Defaults to `true` on pull‑request pipelines, `false` otherwise. |
| `UPLOAD_ARTIFACTS` | `true` | Copy `results.json` (and `prestaflow.env`) into `$BITBUCKET_PIPE_SHARED_STORAGE_DIR`. |
| `VISUAL` | `true` | Enable visual‑regression round‑trip (baseline download before the run, actual/diff upload after). |
| `BITBUCKET_ACCESS_TOKEN` | `""` | Access token used to post PR comments. See [PR comments](#pr-comments). |

## Outputs

After the pipe runs, it writes `prestaflow.env` into the workspace **and** into `$BITBUCKET_PIPE_SHARED_STORAGE_DIR/prestaflow.env` (when available). The file contains:

```sh
PRESTAFLOW_REPORT_ID=…            # PrestaFlow report ID
PRESTAFLOW_REPORT_URL=…           # https://prestaflow.io/reports/…
PRESTAFLOW_PASSED=42
PRESTAFLOW_FAILED=0
PRESTAFLOW_SKIPPED=3
PRESTAFLOW_TOTAL=45
PRESTAFLOW_DURATION_MS=185432
PRESTAFLOW_STATUS=success         # or "failure"
# With FLASHLIGHT=true:
PRESTAFLOW_FO_URL=http://localhost:8000/
PRESTAFLOW_BO_URL=http://localhost:8000/admin-dev/
PRESTAFLOW_PS_VERSION=8.2.8       # when it could be told
PRESTAFLOW_FLASHLIGHT_TAG=8.2.8-nginx
```

Consume it in a later step by declaring `artifacts: [prestaflow.env]` on the pipe step and sourcing it downstream:

```yaml
- step:
    name: PrestaFlow
    services: [docker]
    artifacts: [prestaflow.env]
    script:
      - pipe: docker://prestaflow/pipe-push:0.2.0
        variables:
          TOKEN: $PRESTAFLOW_TOKEN
          PROJECT_ID: pk_01ABC...

- step:
    name: Notify
    script:
      - . prestaflow.env
      - echo "Report ready → $PRESTAFLOW_REPORT_URL ($PRESTAFLOW_STATUS)"
```

## PR comments

When the pipe runs on a pull‑request pipeline and `BITBUCKET_ACCESS_TOKEN` is set, it posts (or updates) a summary comment via the [Bitbucket Cloud API](https://developer.atlassian.com/cloud/bitbucket/rest/api-group-pullrequests/#api-repositories-workspace-repo-slug-pullrequests-pull-request-id-comments-post). Idempotency is done via a hidden marker `<!-- prestaflow-run:<project-key> -->` inside the comment body.

To create the token:

1. Repository settings → Access tokens → **Create Repository Access Token**.
2. Grant it **Pull requests: write**.
3. Add it as a **Secured** repository variable (e.g. `PRESTAFLOW_BITBUCKET_TOKEN`) and pass it as `BITBUCKET_ACCESS_TOKEN`.

If the token is missing, the pipe warns and continues — PR comments are non‑fatal.

## Flashlight

Setting `FLASHLIGHT: 'true'` boots a `prestashop/prestashop-flashlight:<PS_VERSION>` container plus a `mariadb:lts`, waits until `/admin-dev/` answers (PrestaShop really serving, not just the web server), then prepares the shop and the settings of your tests. The step needs `services: [docker]`.

**PrestaShop version.** `prestaflow/php-library` only accepts a bare version (`1.7.8.11`, `8.2.8`) in `PRESTAFLOW_PS_VERSION`, and stops on anything else. The image keeps the tag you give, but the version passed to the tests is read from it: `8.2.8-nginx` gives `8.2.8`, `1.7.8.11-7.4-fpm-alpine-nginx` gives `1.7.8.11`. For a tag without a version (`latest`, `nightly`…), the pipe reads the image's `PS_VERSION` variable (`latest` is 9.2.1 at the time of writing). When nothing gives the version, `PRESTAFLOW_PS_VERSION` is left to you, with a warning in the log.

> `latest` is PrestaShop 9.2, which installs the Hummingbird theme. Pass `PRESTAFLOW_THEME: 'hummingbird'` in the pipe's `variables:`, or the library looks for Classic's markup.

**Accounts.** Since `prestaflow/php-library` 1.9.0 the library no longer falls back on demo accounts. With Flashlight, the pipe provides the image's back-office account (`admin@prestashop.com` / `prestashop`) and the demo customer of the PrestaShop fixtures (`pub@prestashop.com` / `123456789`), at the lowest priority.

**`.env.local`.** The library reads its settings from `.env.local`, or from `.env` when there is no `.env.local`. The pipe writes one merged `.env.local`, from the lowest to the highest priority:

1. the Flashlight accounts (`PRESTAFLOW_BO_EMAIL`, `PRESTAFLOW_BO_PASSWD`, `PRESTAFLOW_FO_EMAIL`, `PRESTAFLOW_FO_PASSWD`);
2. your repository's `.env.local`, or `.env` when there is none, copied as is;
3. the shop: `PRESTAFLOW_FO_URL`, `PRESTAFLOW_BO_URL` (`…/admin-dev/`) and `PRESTAFLOW_PS_VERSION`;
4. the `PRESTAFLOW_*` variables passed to the pipe (its own settings and tokens excepted).

Those keys are removed from composer's environment so the library reads them from the file. A versioned `.env.local` is merged, not overwritten, and put back when the pipe exits (the generated file is removed when the repository had none).

A pipe only receives the variables listed under its `variables:`, so pass library settings there:

```yaml
- pipe: docker://prestaflow/pipe-push:0.2.0
  variables:
    TOKEN: $PRESTAFLOW_TOKEN
    FLASHLIGHT: 'true'
    PS_VERSION: 'latest'
    PRESTAFLOW_THEME: 'hummingbird'
```

**Module.** When `composer.json` has `type: prestashop-module`, the mounted module is installed with `php bin/console prestashop:module install <name>` in the container. If an init-script already installed it, PrestaShop upgrades it instead. A failed install only prints a warning; set `FLASHLIGHT_INSTALL_MODULE: 'false'` to skip it.

`FLASHLIGHT_MOUNT`:

- `auto` (default): reads `composer.json` `type` and mounts under `modules/<name>` or `themes/<name>`; falls back to `modules/<repo-basename>` with a warning.
- `root`: mount workspace at `/var/www/html` (custom PrestaShop distributions).
- `modules` / `themes`: force the location.

## What the pipe does

The container's entrypoint runs these scripts in order — each is a small self‑contained bash script under [`scripts/`](./scripts):

1. `flashlight.sh` — boot Flashlight, install the module and write `.env.local` (opt‑in). `flashlight-restore.sh` puts your `.env.local` back when the pipe exits.
2. `visual-download.sh` — pull visual baselines for the current branch.
3. `runner.sh` — `composer run prestaflow:json:file` (unless `EXECUTE=false`).
4. `upload.sh` — POST `results.json` + error/visual PNGs to the PrestaFlow API.
5. `comment-pr.sh` — post/update the PR comment.
6. `outputs.sh` — aggregate final counters and exit non‑zero on any test failure.

## Publishing

- **Docker Hub**: the pipe is distributed as `prestaflow/pipe-push:<version>`. Build & push:
  ```bash
  docker build -t prestaflow/pipe-push:0.2.0 -t prestaflow/pipe-push:0 -t prestaflow/pipe-push:latest .
  docker push prestaflow/pipe-push:0.2.0
  docker push prestaflow/pipe-push:0
  docker push prestaflow/pipe-push:latest
  ```
- **Bitbucket Marketplace**: submit this repository at <https://bitbucket.org/product/features/pipelines/integrations>. Marketplace listings point to the same `pipe.yml`/Docker image; there's no separate artifact to publish.

## License

MIT — see [LICENSE](./LICENSE).
