# Architecture

The repository combines three runtime-facing code packages with deployment automation and DAM registration tooling.

## Major runtime components

### Backend service

The backend service in `packages/server-v1` is the operational core. It handles DAM-facing processing requests, exposes health and API endpoints, interacts with PostgreSQL, and runs the watermark or rendition logic.

Its implementation uses LoopBack 4 and TypeScript, and its package scripts generate an OpenAPI spec as part of the build.

### Script Portlet UI

The UI in `packages/portlet-v1` provides a React-based configuration experience suitable for a DX Script Portlet deployment. It uses Vite, React 18, and a component/tooling stack intended for interactive editing workflows.

### Shared package

The shared package in `packages/shared` provides common TypeScript contracts and deterministic tiling calculations. This is important because the UI preview and the backend renderer need to behave consistently.

## Delivery architecture

The repository also includes:

- Docker packaging through `packages/Dockerfile`
- Helm deployment through `helm/dam-plugin`
- raw Kubernetes manifests through `kubernetes`
- initialization, deployment, and DAM registration automation through `scripts`

## Why this architecture matters

The example app is valuable because it shows a complete path from authoring/configuration to backend processing to operational deployment and DAM integration. Readers should be able to understand not just how one feature works, but how a plugin-oriented solution is assembled end-to-end.

## Next page

Read [Components](./components.md) for a package-by-package breakdown or [Runtime Flow](./runtime-flow.md) for the request lifecycle.