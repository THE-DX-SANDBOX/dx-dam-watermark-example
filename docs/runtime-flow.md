# Runtime Flow

The runtime model has two primary flows: the configuration flow through the UI and the rendition-processing flow through DAM and the backend service.

## Configuration flow

1. A user interacts with the Script Portlet UI.
2. The portlet loads and edits project, specification, and layer data.
3. The portlet calls the backend service APIs.
4. The UI uses shared types and shared tiling logic so preview behavior matches backend processing behavior.

## DAM processing flow

1. DAM invokes the plugin service for an asset-processing action.
2. The backend service validates the request and locates the relevant processing or watermark specification.
3. The service performs the rendition work.
4. The service calls back to DAM with the processed result.

## Operational flow

1. The repo is initialized and configured.
2. The backend service is built into a container image.
3. The service is deployed to Kubernetes through Helm or raw manifests.
4. The plugin is registered with DAM so DAM knows where to route requests.
5. The portlet can be deployed to DX Portal if the UI is part of the solution.

## Why the shared package matters

The shared package exists to keep calculations and data contracts stable across the UI and backend. That is especially important for an example like watermarking where layout rules must preview and render consistently.