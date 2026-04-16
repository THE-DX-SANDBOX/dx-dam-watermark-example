# Repo Structure

The repository is organized as a monorepo with three primary packages and a set of operational directories around them.

## Top-level layout

### Core package directories

- `packages/server-v1` contains the backend API and processing logic.
- `packages/portlet-v1` contains the React-based Script Portlet UI.
- `packages/shared` contains shared TypeScript types and tiling logic used by both client and server.

### Operational and deployment directories

- `scripts` contains build, deploy, initialization, testing, and registration scripts.
- `helm/dam-plugin` contains Helm chart assets for Kubernetes deployment.
- `kubernetes` contains raw Kubernetes manifests as an alternative deployment path.
- `config` contains rendition-related configuration assets.

### Documentation and guidance

- `README.md` is the high-level repo entry point.
- `START_HERE.md` and `docs/first-clone-setup.md` guide first-time setup.
- [Home](./index.md) contains the curated implementation and operations documentation.
- `.ai` contains structured project context that is useful both for AI assistants and for maintainers seeking architecture detail.

## Why the repo is split this way

The split is designed to isolate the parts of the system that change at different rates:

- the UI can evolve independently from the processing service
- the service can change without duplicating shared contracts in the portlet
- deployment and operational automation can be versioned alongside the code they operate on

## Key control files

- `package.json` defines root scripts for bootstrap, build, deploy, test, and docs publishing.
- `lerna.json` defines the Lerna monorepo package layout.
- `plugin-config.json` defines the DAM plugin metadata and several integration defaults.
- `packages/Dockerfile` defines the production container image build.