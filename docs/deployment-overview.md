# Deployment Overview

Deployment in this repository is a sequence, not a single command. The scripts automate most of it, but the underlying flow matters.

## Deployment sequence

1. Initialize the project configuration.
2. Build the application artifacts and container image.
3. Push the image and optionally Helm chart.
4. Deploy the service to Kubernetes.
5. Deploy the Script Portlet if the UI is part of the solution.
6. Register the plugin with DAM.
7. Verify health, service reachability, and DAM registration.

## Main scripts

- `scripts/init-template.sh` initializes repo configuration.
- `scripts/build.sh` builds the image and optional registry artifacts.
- `scripts/deploy.sh` drives Kubernetes deployment.
- `scripts/deploy-portlet.sh` handles portlet deployment.
- `scripts/build-and-deploy.sh` orchestrates the common end-to-end path.

## Deployment assets

- `packages/Dockerfile` defines the runtime image.
- `helm/dam-plugin` contains the Helm chart.
- `kubernetes` contains raw manifests.

## Verification checkpoints

After deployment you should be able to verify:

- the service health endpoint responds
- the service is reachable inside the cluster
- the DAM registration step can resolve the service URL
- the portlet can reach the backend if the UI is enabled

## Detailed docs

For step-by-step operations guidance, continue with:

- [Plugin Registration](./plugin-registration.md)
- [Deployment Details](./DEPLOYMENT.md)
- [Portlet Deployment](./PORTLET_DEPLOYMENT.md)