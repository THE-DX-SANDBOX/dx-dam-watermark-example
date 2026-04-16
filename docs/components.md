# Components

This page explains the responsibilities of the three main code packages and the deployment packaging around them.

## `packages/server-v1`

Purpose: backend API and processing engine.

Key characteristics:

- LoopBack 4 application
- TypeScript on Node 20
- PostgreSQL integration
- image and media processing dependencies such as Sharp and Canvas
- OpenAPI generation during build

What readers should understand:

- this package is where core business logic and DAM processing logic live
- it contains the REST surface and most of the runtime behavior
- it is the main place to customize backend processing

## `packages/portlet-v1`

Purpose: browser UI packaged for Script Portlet usage.

Key characteristics:

- React 18 and Vite
- HashRouter and relative-path-friendly configuration for portal deployment
- interactive editing experience for the example workflow

What readers should understand:

- this package is where configuration and management UX live
- it is the main place to customize the user-facing app behavior
- it talks to the backend service rather than duplicating backend logic

## `packages/shared`

Purpose: shared contracts and shared math.

Key characteristics:

- TypeScript-only package
- shared types used by multiple packages
- deterministic tiling and placement logic reused across client and server

What readers should understand:

- this package prevents drift between preview logic and processing logic
- it is the right place for shared domain models and reusable calculations

## Deployment packaging

The code packages are supported by operational assets:

- `packages/Dockerfile` builds the runtime image
- `helm/dam-plugin` packages the service for Helm-based deployment
- `kubernetes` provides raw manifest equivalents
- `scripts` coordinates the build, deploy, portlet deployment, and DAM registration workflows