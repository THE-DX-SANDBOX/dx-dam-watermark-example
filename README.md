# DX DAM Watermark Example

Production-style reference implementation for an HCL Digital Asset Management plugin, including a React-based Script Portlet UI, a LoopBack 4 backend service, shared TypeScript contracts, and Kubernetes and Helm deployment automation.

## What This Repository Provides

This repository is both:

- a working DAM watermark and rendition example
- a template for building custom DAM plugins with a UI, backend service, and deployment assets in one monorepo

The example shows how to:

- build and deploy a plugin-oriented backend service
- register a service with DAM
- package a Script Portlet UI for DX
- share contracts and rendering logic across frontend and backend
- operate the solution in Kubernetes

## Repository Layout

- `packages/server-v1`: LoopBack 4 API and processing logic
- `packages/portlet-v1`: React and Vite Script Portlet UI
- `packages/shared`: shared TypeScript models and reusable logic
- `docs`: VitePress documentation source
- `helm/dam-plugin`: Helm chart for Kubernetes deployment
- `kubernetes`: raw manifest alternative
- `scripts`: initialization, build, deploy, registration, and testing helpers

## Getting Started

Start with [docs/first-clone-setup.md](docs/first-clone-setup.md). That page maps the exact files a fresh clone must create or edit.

The short version is:

```bash
cp .env.example .env
nano .env
nano plugin-config.json
```

The root `.env` is the simplest and most important config file because the build and deploy scripts auto-load it. Environment-specific files such as `.env.dev` and `.env.prod` are optional profiles for multi-environment workflows.

At minimum, review and set these values before building or deploying:

- `DOCKER_REGISTRY`
- `HELM_REGISTRY`
- `IMAGE_NAME`
- `IMAGE_TAG`
- `K8S_NAMESPACE` or `NAMESPACE`
- `DX_HOSTNAME`
- `DX_USERNAME`
- `DX_PASSWORD`
- `API_KEY`
- `JWT_SECRET`

Use secrets or secret managers for sensitive production values. Do not commit populated env files.

Also review `plugin-config.json` before your first deployment so the plugin metadata and supported file types are not left at their example values.

### Guided Setup Flow

```bash
./scripts/init-template.sh
./scripts/validate-deployment-readiness.sh
./scripts/build-and-deploy.sh
```

### Docs Site

```bash
npm install
npm run docs:build
npm run docs:preview
```

Useful documentation entry points:

- `docs/first-clone-setup.md`
- `docs/index.md`
- `docs/getting-started.md`
- `docs/architecture.md`
- `docs/deployment-overview.md`
- `docs/plugin-registration.md`

## Common Commands

```bash
npm run docs:build
npm run docs:preview
npm run docs:dev
npm run dev
npm test
npm run lint
```

## Publishing the Docs Site

The repository includes a GitHub Actions workflow that builds the VitePress site and deploys it to GitHub Pages.

- Workflow: `.github/workflows/docs.yml`
- Build output: `docs/.vitepress/dist`

To publish the generated site instead of raw markdown, GitHub Pages must be configured to deploy from GitHub Actions.

## Community Standards

- Contributing guide: `CONTRIBUTING.md`
- Code of conduct: `CODE_OF_CONDUCT.md`
- Security policy: `SECURITY.md`
- Support guidance: `SUPPORT.md`

## License

This project is licensed under the Apache License, Version 2.0. See `LICENSE` for details.