# DAM Plugin Deployment Scripts

## 🚀 Quick Start

```bash
# 1. Make scripts executable (first time only)
npm run setup

# 2. Create root config from the template
cp .env.example .env

# 3. Edit the required values
nano .env

# 4. Build and push Docker image
./scripts/build.sh --push

# 5. Deploy to Kubernetes
npm run deploy
```

If you are using an environment profile such as `.env.dev`, create that file from the matching example and use the profile-aware shortcuts:

```bash
cp .env.dev.example .env.dev
nano .env.dev
npm run deploy:dev
```

## 📋 Available Scripts

### Build Scripts

| Script | Command | Description |
|--------|---------|-------------|
| `build.sh` | `./scripts/build.sh` | Build Docker image locally |
| Build & Push | `./scripts/build.sh --push` | Build and push to registry |

### Deployment Scripts

| Script | Command | Description |
|--------|---------|-------------|
| `deploy.sh` | `npm run deploy` | Deploy with Helm to existing namespace |
| Deploy Dev | `npm run deploy:dev` | Deploy to development |
| Deploy Staging | `npm run deploy:staging` | Deploy to staging |
| Deploy Prod | `npm run deploy:prod` | Deploy to production |
| Quick Deploy | `npm run deploy:quick` | Deploy without rebuilding |

### Pipeline Scripts

| Script | Command | Description |
|--------|---------|-------------|
| `build-and-deploy.sh` | `npm run pipeline` | Full build and deploy |
| Pipeline Dev | `npm run pipeline:dev` | Build + deploy to dev |
| Pipeline Staging | `npm run pipeline:staging` | Build + deploy to staging |
| Pipeline Prod | `npm run pipeline:prod` | Build + deploy to prod |

### Testing & Management

| Script | Command | Description |
|--------|---------|-------------|
| `test-plugin.sh` | `npm run test:plugin` | Test deployed plugin |
| `undeploy.sh` | `npm run undeploy` | Remove deployment (keeps namespace) |

## 🔧 Configuration

### Environment Variables

```bash
# Registry Configuration
export DOCKER_REGISTRY="<registry-host>/<repository>"
export IMAGE_NAME="dam-plugin"
export IMAGE_TAG="v1.0.0"

# Kubernetes Configuration
export NAMESPACE="dam-plugins"
export RELEASE_NAME="dam-plugin"

# Secrets (optional - will prompt if not set)
export DAM_ADMIN_TOKEN="your-admin-token"
export PLUGIN_API_KEY="your-api-key"

# Options
export SKIP_BUILD="true"     # Skip Docker build
export SKIP_TESTS="true"     # Skip tests
export SKIP_SECRETS="true"   # Don't prompt for secrets
```

## 📝 Deployment Workflows

### Development Workflow

```bash
# Quick iteration - deploy only
npm run deploy:dev

# Full pipeline with tests
npm run pipeline:dev

# Test the deployment
npm run test:plugin
```

### Production Workflow

```bash
# 1. Build and push
DOCKER_REGISTRY="your-registry" IMAGE_TAG="v1.0.0" npm run docker:build:push

# 2. Deploy to production
NAMESPACE="dam-plugins-prod" npm run deploy:prod

# 3. Verify
kubectl get pods -n dam-plugins-prod
kubectl logs -f -n dam-plugins-prod -l app.kubernetes.io/name=dam-plugin
```

## 🔒 Namespace Protection

**IMPORTANT**: All scripts are designed to:
- ✅ Create namespace if it doesn't exist
- ✅ Use existing namespace without modification
- ❌ **NEVER** delete namespaces

The `undeploy.sh` script only removes the Helm release and explicitly does NOT delete the namespace.

## 🧪 Testing

### Local Testing (Port Forward)

```bash
# Start port forward and run tests
npm run test:plugin

# Manual testing
kubectl port-forward -n dam-plugins svc/dam-plugin-dam-plugin 3000:3000
curl http://localhost:3000/health
curl http://localhost:3000/api/v1/info
```

### Test with Image Upload

```bash
# Provide path to test image
./scripts/test-plugin.sh /path/to/test-image.jpg
```

## 📊 Monitoring

### View Logs

```bash
# Real-time logs
kubectl logs -f -n dam-plugins -l app.kubernetes.io/name=dam-plugin

# Check registration
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin | grep "Registration"

# Check HAProxy discovery
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin | grep "HAProxy"
```

### Check Status

```bash
# Pods
kubectl get pods -n dam-plugins

# Services
kubectl get svc -n dam-plugins

# HPA (if enabled)
kubectl get hpa -n dam-plugins

# Events
kubectl get events -n dam-plugins --sort-by='.lastTimestamp'
```

## 🐛 Troubleshooting

### Build Failures

```bash
# Check Docker is running
docker ps

# Check GCP authentication
gcloud auth list
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build without cache
docker build --no-cache ...
```

### Deployment Failures

```bash
# Check Helm release status
helm list -n dam-plugins
helm status dam-plugin -n dam-plugins

# Check pod status
kubectl describe pod -n dam-plugins -l app.kubernetes.io/name=dam-plugin

# Check events
kubectl get events -n dam-plugins --sort-by='.lastTimestamp'
```

### Registration Failures

```bash
# Check HAProxy discovery
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin | grep "Discovering HAProxy"

# Check DAM connectivity
kubectl exec -n dam-plugins deployment/dam-plugin-dam-plugin -- \
    curl -v http://dx-haproxy.dx-haproxy:80/health

# Manual registration
kubectl exec -n dam-plugins deployment/dam-plugin-dam-plugin -- \
    /usr/local/bin/register-with-dam.sh
```

## 🔄 Update/Rollback

### Update Deployment

```bash
# Update with new image
IMAGE_TAG="v1.0.1" npm run deploy:dev

# Update configuration only
helm upgrade dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins \
    --reuse-values \
    --set plugin.autoRegister=false
```

### Rollback

```bash
# View history
helm history dam-plugin -n dam-plugins

# Rollback to previous
helm rollback dam-plugin -n dam-plugins

# Rollback to specific revision
helm rollback dam-plugin 2 -n dam-plugins
```

## 📦 Complete Example

```bash
# Complete deployment from scratch
cd /Users/robertholt/Documents/Code/DAM-Demo

# 1. Setup (first time only)
npm run setup

# 2. Create config
cp .env.example .env
nano .env

# 3. Build and deploy
npm run pipeline

# 4. Test
npm run test:plugin

# 5. View logs
kubectl logs -f -n dam-plugins -l app.kubernetes.io/name=dam-plugin

# 6. When done (removes deployment, keeps namespace)
npm run undeploy
```

## 📚 Additional Resources

- [DEPLOYMENT.md](../DEPLOYMENT.md) - Complete deployment guide
- [SERVICE_DISCOVERY.md](../docs/SERVICE_DISCOVERY.md) - HAProxy discovery details
- [REGISTRATION.md](../docs/REGISTRATION.md) - Registration process
- [Helm values](../helm/dam-plugin/values.yaml) - Configuration options
