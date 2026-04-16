# First Clone Setup

This page is the canonical setup map for a fresh clone. It answers two questions:

1. Which files do you need to create or edit before running anything?
2. Which files are optional, generated later, or only needed for advanced workflows?

## Required vs Optional Files

| File | Required | When it appears | What you must do |
| --- | --- | --- | --- |
| `.env` | Yes for the simplest workflow | You create it from `.env.example` | Fill in the values used by the build and deploy scripts. This is the only config file auto-loaded by `scripts/config.sh`. |
| `plugin-config.json` | Yes | Already present in the repo | Review and replace the example plugin identity, description, and supported DAM-facing metadata. |
| `.env.local`, `.env.dev`, `.env.uat`, `.env.prod` | Optional | You create them from the matching `.example` files | Use these only if you want separate environment profiles. They are loaded by `source scripts/load-env.sh <env>` or by the profile-aware shortcuts such as `./scripts/deploy.sh dev`. |
| `helm/dam-plugin/values.yaml` | Optional | Already present in the repo | Review defaults. Override only if the chart defaults are not enough for your environment. |
| `helm/dam-plugin/values-*.yaml` or your own values file | Optional | Some may already exist; you can add your own | Use for environment-specific Helm overrides such as resources, ingress, or database wiring. |
| `.template-config.json` | Generated | Created by `./scripts/init-template.sh` | Review if you use the initialization workflow; you do not create this by hand in a fresh clone. |
| `docs/DATABASE_SETUP.md` | Generated and optional | Created by init when database guidance is needed | Use only if the initializer generates it. Do not expect it to exist in a clean clone. |
| `.env.loaded` | Generated and optional | Created by `scripts/load-env.sh` | Temporary export helper; do not edit manually. |
| `packages/portlet-v1/.env` | Optional | You create it only if needed | Only for manual Vite-specific overrides such as `VITE_API_BASE_URL`. The normal repo workflow does not require this file. |

## Simplest First-Clone Workflow

If you only want the shortest path to a working baseline, do this:

```bash
cp .env.example .env
nano .env
nano plugin-config.json
./scripts/init-template.sh
./scripts/validate-deployment-readiness.sh
DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh build-only
```

For the first working baseline, make sure these values are set in `.env`:

- `DOCKER_REGISTRY`
- `IMAGE_NAME`
- `IMAGE_TAG`
- `NAMESPACE`
- `RELEASE_NAME`
- `DX_HOSTNAME`
- `DX_USERNAME`
- `DX_PASSWORD`
- `API_KEY`
- `JWT_SECRET`

Set these as well if they apply to your workflow:

- `HELM_REGISTRY` when using remote Helm chart publishing or remote chart deployment
- `VALUES_FILE` when you want Helm to use a custom values file
- `DAM_URL`, `DAM_CALLBACK_URL`, `PLUGIN_AUTH_KEY`, and related plugin runtime values when you are registering with a real DAM environment

## What to Review in `plugin-config.json`

At minimum, replace the example metadata with your own values:

- `pluginName`
- `pluginDisplayName`
- `pluginDescription`
- `pluginAuthor`
- `damIntegration.supportedFileTypes`
- `kubernetes.namespace` if you want it to match your target namespace defaults

## Using Environment Profiles

If you prefer separate config files per environment, create the relevant profile file:

```bash
cp .env.dev.example .env.dev
nano .env.dev
```

Then use either of these patterns:

```bash
source scripts/load-env.sh dev
./scripts/build.sh --push
./scripts/deploy.sh
```

```bash
./scripts/build-and-deploy.sh dev
./scripts/deploy.sh dev
```

Notes:

- The root scripts auto-load `.env` when it exists.
- The profile shortcuts `./scripts/deploy.sh dev` and `./scripts/build-and-deploy.sh dev` load `.env.dev`, `.env.uat`, or `.env.prod` for you.
- If you are not using a profile shortcut or `source scripts/load-env.sh`, the scripts will fall back to `.env`.

## Generated Files You Should Not Chase in a Fresh Clone

These files are mentioned in some detailed docs, but they are not supposed to exist immediately after cloning:

- `.template-config.json`
- `docs/DATABASE_SETUP.md`
- `.env.loaded`

If you do not see them yet, that is expected.

## Standard Baseline Deployment Path

After config is in place, the standard sequence is:

```bash
./scripts/init-template.sh
./scripts/validate-deployment-readiness.sh
./scripts/build.sh --push
./scripts/deploy.sh
./scripts/register-plugin-with-dam.sh -n <namespace>
```

If you are using a named profile instead of `.env`, use the profile-aware form:

```bash
./scripts/build-and-deploy.sh dev
./scripts/register-plugin-with-dam.sh -n <namespace>
```

## Related Docs

- [getting-started.md](./getting-started.md)
- [deployment-overview.md](./deployment-overview.md)
- [plugin-registration.md](./plugin-registration.md)
- [ENVIRONMENT_SETUP.md](./ENVIRONMENT_SETUP.md)