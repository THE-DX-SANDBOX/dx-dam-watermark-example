# Template Initialization & Validation Guide

## Overview

This guide walks you through initializing and validating the DX Universal Template before making any code changes.

## Workflow

```
1. Initialize Template (Collect Info) →
2. Validate Configuration →  
3. Test Deployment (Dry Run) →
4. Deploy to Cluster →
5. Validate Running System →
6. Make Custom Changes
```

## Step-by-Step Process

### Step 1: Initialize Template

Run the interactive initialization script:

```bash
./scripts/init-template.sh
```

This will:
- ✅ Ask questions about your project
- ✅ Collect configuration details
- ✅ Test connections (K8s, DX Portal, Docker)
- ✅ Generate `.env` and `.template-config.json`
- ✅ Update Helm values
- ✅ Run pre-flight validation

**What it collects:**

**Project Details:**
- Project name and description
- Project type (DAM Plugin / Script Portlet / API / Hybrid)
- Version information

**Kubernetes:**
- Namespace (validates exists or creates)
- Release name
- Current cluster context

**Docker Registry:**
- Registry URL
- Image name and tag
- Tests Docker connectivity

**DX Portal** (if portlet enabled):
- Hostname, protocol, port
- Username and password
- Tests portal reachability
- WCM content name and site area

**DAM Plugin** (if enabled):
- Plugin name and version
- Supported MIME types
- Rendition stack configuration

**Backend Service:**
- Service port
- Replica count
- Resource limits (CPU/Memory)
- Autoscaling settings

**External Services** (optional):
- External APIs
- Database configuration
- Redis configuration

### Step 2: Review Generated Configuration

Check the generated files:

```bash
# Review environment variables
cat .env

# Review template configuration
cat .template-config.json | jq .

# Review Helm values
cat helm/dam-plugin/values.yaml
```

**Edit if needed:**
```bash
nano .env
```

### Step 3: Validate Configuration

Run the validation script:

```bash
./scripts/validate-deployment-readiness.sh
```

This checks:
- ✅ Configuration files exist and are valid
- ✅ Required tools installed (node, docker, kubectl, helm, dxclient)
- ✅ Kubernetes cluster accessible
- ✅ Namespace exists
- ✅ Docker daemon running
- ✅ PostgreSQL database accessible (if configured)
- ✅ Database exists and credentials work
- ✅ Project structure correct
- ✅ Dependencies installed
- ✅ Helm chart valid
- ✅ DX Portal reachable (if portlet enabled)
- ✅ Security (`.env` not tracked by git)

**Fix any errors before proceeding!**

### Step 3.5: Setup Database (If New Project)

If you configured PostgreSQL during initialization and need to create the database:

```bash
# If the initialization wizard generated a database guide for you
cat docs/DATABASE_SETUP.md

# Method 1: Using kubectl exec (recommended)
kubectl exec -it -n YOUR_NAMESPACE deployment/YOUR_NAMESPACE-dx-postgres -- psql -U postgres

# Then run the SQL commands shown in the guide to:
# - Create database
# - Create user
# - Grant permissions
```

**Important:** Complete database setup before deploying the backend!

### Step 4: Install Dependencies

```bash
# Backend
cd packages/server-v1
npm install

# Install PostgreSQL connector if using database
npm install --save loopback-connector-postgresql

cd ../..

# Portlet (if enabled)
cd packages/portlet-v1
npm install
cd ../..
```

### Step 5: Test Build (Dry Run)

Test the build process without actually deploying:

```bash
DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh build-only
```

This will:
- ✅ Validate build process
- ✅ Compile TypeScript
- ✅ Build Docker image
- ✅ Show what would be pushed
- ❌ NOT push to registry
- ❌ NOT deploy to cluster

### Step 6: Deploy Backend to Cluster

If dry run passed, deploy for real:

```bash
# Build and push image
./scripts/build.sh --push

# Deploy to Kubernetes
./scripts/deploy.sh

# Wait for deployment
kubectl wait --for=condition=available --timeout=300s \
  deployment/$RELEASE_NAME -n $NAMESPACE
```

Or use the all-in-one script:

```bash
./scripts/build-and-deploy.sh
```

### Step 7: Validate Backend Deployment

```bash
# Check pods
kubectl get pods -n $NAMESPACE

# Check service
kubectl get svc -n $NAMESPACE

# Port forward and test
./scripts/port-forward.sh &
sleep 3

# Test health endpoint
curl http://localhost:3000/health

# Test API
./scripts/testing/quick-test-api.sh

# Kill port forward
pkill -f "kubectl port-forward"
```

### Step 8: Deploy Portlet (if enabled)

```bash
./scripts/deploy-portlet.sh --build
```

This will:
- Build React app
- Deploy to DX Portal WCM
- Create/update Script Application

### Step 9: Register DAM Plugin (if enabled)

```bash
./scripts/register-plugin-with-dam.sh
```

Verify registration:
```bash
kubectl get configmap $NAMESPACE-digital-asset-management \
  -n $NAMESPACE \
  -o jsonpath='{.data.config\.json}' | jq .
```

### Step 10: Full End-to-End Test

Run the complete test suite:

```bash
./scripts/testing/test-template-end-to-end.sh
```

This validates:
- ✅ Backend builds successfully
- ✅ Docker image created
- ✅ Helm chart deploys
- ✅ Pods become ready
- ✅ Service has endpoints
- ✅ API endpoints respond
- ✅ Port forwarding works
- ✅ DAM integration configured (if enabled)

## Troubleshooting

### Initialization Issues

**Problem:** Namespace doesn't exist
```bash
kubectl create namespace my-namespace
```

**Problem:** Cannot connect to K8s cluster
```bash
# Check context
kubectl config current-context

# Switch context
kubectl config use-context my-context

# Check access
kubectl cluster-info
```

**Problem:** DX Portal unreachable
- Check VPN connection
- Verify hostname/port
- Try: `curl -k https://your-dx-host:443/wps/portal`

### Validation Issues

**Problem:** `.env` tracked by git
```bash
git rm --cached .env
git commit -m "Remove .env from git"
```

**Problem:** Helm chart invalid
```bash
helm lint helm/dam-plugin
# Fix errors shown
```

**Problem:** Dependencies not installed
```bash
cd packages/server-v1 && npm install
cd packages/portlet-v1 && npm install
```

### Deployment Issues

**Problem:** Pods not starting
```bash
# Check pod status
kubectl get pods -n $NAMESPACE

# Check logs
kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME

# Check events
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'
```

**Problem:** Image pull failed
```bash
# Authenticate with GCP
gcloud auth configure-docker us-central1-docker.pkg.dev

# Check image exists
docker images | grep $IMAGE_NAME

# Push manually
docker push $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
```

**Problem:** Service has no endpoints
```bash
# Check pod labels
kubectl get pods -n $NAMESPACE --show-labels

# Check service selector
kubectl get svc $RELEASE_NAME -n $NAMESPACE -o yaml | grep -A 5 selector

# Labels should match!
```

### Portlet Deployment Issues

**Problem:** dxclient fails
```bash
# Check credentials
echo $DX_USERNAME
echo $DX_HOSTNAME

# Test DX Portal access
curl -k https://$DX_HOSTNAME:$DX_PORT/wps/portal

# Check WCM library exists
# (via DX Portal UI)
```

**Problem:** Portlet build failed
```bash
cd packages/portlet-v1
npm run build

# Check for errors
# Fix and rebuild
```

## Conflict Detection

The initialization process detects and prevents conflicts:

### ✅ Prevents

1. **Namespace conflicts**
   - Checks if namespace exists
   - Offers to create if missing
   - Validates name format

2. **Port conflicts**
   - Validates port numbers
   - Checks for common conflicts

3. **Configuration conflicts**
   - Validates JSON syntax
   - Checks for required fields
   - Tests connections before committing

4. **Git conflicts**
   - Ensures `.env` not tracked
   - Creates backups before overwriting
   - Validates `.gitignore` patterns

5. **Resource conflicts**
   - Checks if Helm release exists
   - Offers upgrade vs install
   - Validates resource limits

### ⚠️ Warnings

1. **Overwriting existing config**
   - Backs up existing `.env`
   - Confirms before proceeding

2. **Missing external services**
   - Database not reachable
   - External API not responding
   - Allows proceeding with warning

3. **Resource limits**
   - Low memory/CPU requests
   - Suggests adjustments

## Re-initialization

To re-configure an existing project:

```bash
./scripts/init-template.sh
```

It will:
1. Detect existing configuration
2. Offer to backup
3. Prompt for overwrite confirmation
4. Backup existing files with timestamp
5. Run initialization again

Backup files: `.env.backup.YYYYMMDD_HHMMSS`

## Best Practices

### Before Making Code Changes

1. ✅ Run initialization
2. ✅ Validate configuration
3. ✅ Test deployment with stock code
4. ✅ Verify all endpoints work
5. ✅ Take snapshots/backups
6. ✅ **Then** start customizing

### During Development

1. Keep `.env` updated
2. Re-run validation after config changes
3. Test in dry-run mode first
4. Use port-forwarding for local testing
5. Check logs frequently

### Before Production

1. Run full test suite
2. Validate all integrations
3. Check resource limits
4. Review security settings
5. Test failover scenarios

## Next Steps

After successful initialization and validation:

1. **Customize Backend**
   - Add your business logic
   - Create new controllers
   - Add database models
   - Integrate external services

2. **Customize Portlet** (if enabled)
   - Design your UI
   - Add pages/components
   - Integrate with backend API
   - Add routing

3. **Customize DAM Plugin** (if enabled)
   - Implement processing logic
   - Add transformation stacks
   - Handle file types
   - Configure callbacks

4. **Iterate**
   - Make changes
   - Test locally
   - Deploy to dev
   - Validate
   - Repeat

## Summary

The initialization and validation workflow ensures:

- ✅ **No guesswork** - Interactive prompts guide you
- ✅ **No conflicts** - Tests connections and validates config
- ✅ **No blind deployments** - Dry-run testing before real deployment
- ✅ **No broken baselines** - Stock code deploys successfully first
- ✅ **No security lapses** - Validates `.gitignore` and credentials
- ✅ **No missing dependencies** - Checks all tools and packages
- ✅ **Clear next steps** - Guided path from init to deployment

Start with `./scripts/init-template.sh` and follow the prompts!
