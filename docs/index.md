# DAM Demo Repository Docs

This site documents the repository as a complete HCL DX and HCL DAM reference implementation. The goal is to explain what the app does, how the monorepo is organized, how the major components fit together, and how to build, deploy, register, and customize it.

## What this repo is

This repository is a universal template for building HCL Digital Experience solutions that combine:

- A backend service that runs in Kubernetes
- An optional DX Script Portlet UI
- An optional HCL DAM rendition plugin
- Shared contracts and rendering logic across client and server

The concrete example included here is a configurable DAM watermarking workflow. That example is important, but the repo is broader than a watermark demo. It is intended to show the structure, tooling, and deployment pattern for a full plugin-based solution.

## What you can learn here

- What the example app is supposed to provide
- How the repo is organized and why the packages are split the way they are
- How the backend service, portlet, and shared package interact
- How deployment works across Docker, Helm, and Kubernetes
- How plugin registration with DAM works
- Where to customize the example for a different use case

## Start with these pages

- [First Clone Setup](./first-clone-setup.md)
- [Getting Started](./getting-started.md)
- [What This App Does](./what-this-app-does.md)
- [Repo Structure](./repo-structure.md)
- [Architecture](./architecture.md)
- [Plugin Registration](./plugin-registration.md)

## Existing detailed docs

The repo already contains a large set of detailed markdown documents. This docs site curates the most important flows first and links to the existing deep dives where appropriate.

- [Development](./DEVELOPMENT.md)
- [Deployment Details](./DEPLOYMENT.md)
- [Portlet Deployment](./PORTLET_DEPLOYMENT.md)
- [Registration Guide](./REGISTRATION.md)
- [AI Rendition Integration](./AI_RENDITION_INTEGRATION.md)