# DAM Plugin Build & Deployment Instructions

## Prerequisites

1. **Google Cloud SDK** - Required for pushing to GCP registries
   ```bash
   # Install gcloud CLI: https://cloud.google.com/sdk/install
   gcloud auth login
   gcloud config set project <GCPProjectId>
   ```

2. **Helm CLI** - Required for Helm chart operations
   ```bash
   # Install Helm: https://helm.sh/docs/intro/install/
   brew install helm
   ```

3. **Docker** - For building container images
   ```bash
   docker version
   ```

## Build Options

### Local Build (No Push)
Build Docker image locally without pushing to registry:
```bash
./scripts/build.sh
```

### Build & Push Docker Image
Build and push Docker image to GCP Artifact Registry:
```bash
./scripts/build.sh --push
```

### Build & Push Docker + Helm Chart
Build and push both Docker image and Helm chart to GCP:
```bash
./scripts/build.sh --push --helm
```

### Using npm Scripts
```bash
# Build and push Docker image
npm run docker:build:push

# Build and push Docker + Helm chart  
npm run docker:build:helm

# Full pipeline with deployment
npm run pipeline:helm
```

## GCP Registry Configuration

The build script uses the following GCP registries:

- **Docker Registry**: `<DockerRegistry>`
- **Helm Registry**: `<HelmRegistry>`

### Authentication

The build script automatically authenticates with GCP when using `--push` or `--helm`:

```bash
# Docker authentication
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://us-central1-docker.pkg.dev

# Helm authentication  
gcloud auth print-access-token | helm registry login -u oauth2accesstoken --password-stdin https://us-central1-docker.pkg.dev
```

## Deployment

### Deploy to Kubernetes using Helm

Deploy from local Helm chart:
```bash
# Deploy to namespace (using flag)
./scripts/deploy.sh -n dam-plugins

# Deploy using environment variable
NAMESPACE=dam-plugins ./scripts/deploy.sh

# Deploy with custom values file
./scripts/deploy.sh -n dam-plugins -v ./custom-values.yaml

# Deploy with specific tag
./scripts/deploy.sh -n production -t v1.2.3

# Deploy everything via environment variables
NAMESPACE=production TAG=v1.2.3 ./scripts/deploy.sh -v ./prod-values.yaml
```

Deploy from remote GCP Helm repository:
```bash
# Deploy from GCP Helm registry (requires prior push with --helm)
./scripts/deploy.sh -n production --remote

# With custom values
./scripts/deploy.sh -n production -r -v ./prod-values.yaml
```

### Using Helm Directly

Install from local chart:
```bash
helm upgrade --install dam-plugin ./helm/dam-plugin \
  --namespace dev \
   --set image.repository=<ImageRepository> \
  --set image.tag=latest \
  --wait
```

Install from GCP registry:
```bash
helm upgrade --install dam-plugin <HelmChartRepository> \
  --namespace dev \
   --set image.repository=<ImageRepository> \
  --set image.tag=latest \
  --wait
```

### Uninstall

```bash
helm uninstall dam-plugin -n <namespace>
```

## Testing

### Test Watermark Plugin (Kubernetes)
```bash
npm run test:watermark
```

### Test Watermark Plugin (Local)
```bash
# Start the service locally first
npm start

# In another terminal
npm run test:local
```

## Build Artifacts

The build process creates the following artifacts:

- **./build/dam-plugin-1.0.0.tgz** - Packaged Helm chart
- **Docker Image** - Pushed to GCP Artifact Registry
- **Helm Chart** - Pushed to GCP Helm Repository (OCI format)

## Troubleshooting

### gcloud not found
```bash
# Install Google Cloud SDK
https://cloud.google.com/sdk/install

# Verify installation
gcloud --version
```

### helm not found
```bash
# Install Helm
brew install helm  # macOS
# or visit: https://helm.sh/docs/intro/install/

# Verify installation
helm version
```

### Authentication Issues
```bash
# Re-authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Verify authentication
gcloud auth list
```

### Docker Push Fails
```bash
# Manually configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev

# Test Docker push
docker push <ImageRepository>:latest
```

## Environment Variables

You can override defaults using environment variables:

```bash
# Override registry
REGISTRY=my-registry.example.com ./scripts/build.sh

# Override image name
IMAGE_NAME=my-custom-name ./scripts/build.sh

# Override tag
TAG=v2.0.0 ./scripts/build.sh --push

# Override platform (for multi-arch builds)
PLATFORM=linux/arm64 ./scripts/build.sh
```

## CI/CD Integration

For CI/CD pipelines, use the following pattern:

```bash
# Authenticate using service account
gcloud auth activate-service-account --key-file=${GCP_KEY_FILE}

# Build and push
./scripts/build.sh --push --helm

# Deploy
./scripts/deploy.sh production
```
