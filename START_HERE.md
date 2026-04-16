# Start Here

This guide is the fastest path to a generic, working DAM plugin deployment using your own environment values.

## Prerequisites

Before you begin, ensure you have:

- Node.js and npm
- Docker
- kubectl configured for your target cluster
- Helm 3+
- DXClient if you will deploy a Script Portlet into DX
- access to a Kubernetes namespace
- access to an HCL DX environment if you will register or deploy into DX
- registry credentials for the image and chart repositories you plan to use

Optional:

- PostgreSQL client tools for testing database connectivity

## Step 1: Create Your Local Configuration

For a fresh clone, start by creating the root `.env` file. This is the config file the build and deploy scripts auto-load.

```bash
cp .env.example .env
nano .env
nano plugin-config.json
```

Optional: if you want separate environment profiles, also create the matching file such as `.env.dev` or `.env.prod`. Those profiles are used by `source scripts/load-env.sh <env>` and by shortcuts such as `./scripts/deploy.sh dev`.

Populate the placeholders with your own values. Review these first:

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

Review these files before moving on:

- `.env` for script and deployment configuration
- `plugin-config.json` for plugin identity and DAM-facing metadata

For non-local environments, use your cluster secret workflow rather than storing real production credentials in tracked files.

If you want the file-by-file setup map, read [docs/first-clone-setup.md](docs/first-clone-setup.md).

## Step 2: Initialize Project Metadata

Run the setup wizard to generate project-specific configuration and confirm the repo settings match your target deployment.

```bash
./scripts/init-template.sh
```

The initializer should be used to:

- set project naming
- collect deployment details
- confirm the target namespace and release names
- write local config files for your environment

## Step 3: Validate the Environment

```bash
./scripts/validate-deployment-readiness.sh
```

This should succeed before any deployment attempt. Fix validation errors first, especially around missing env values, registry settings, cluster access, and secrets.

## Step 4: Test the Baseline Build

```bash
DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh build-only
```

If that passes, run the actual build or deployment flow described in the docs.

## Step 5: Deploy and Register

Typical flow:

```bash
./scripts/build-and-deploy.sh
./scripts/register-plugin-with-dam.sh -n <namespace>
```

## What You Should Customize First

- `plugin-config.json` for plugin identity and runtime settings
- `packages/server-v1` for processing logic and API behavior
- `packages/portlet-v1` for UI behavior
- env files and secrets for deployment-specific configuration
- Helm values for resource sizing and cluster-specific overrides

## Docs to Read Next

- `docs/first-clone-setup.md`
- `docs/getting-started.md`
- `docs/architecture.md`
- `docs/deployment-overview.md`
- `docs/plugin-registration.md`
- `scripts/testing/README.md`

## 📖 What Gets Created

After initialization, you'll have:

### Configuration Files

- **`.env`** - Environment variables (DO NOT commit to git!)
- **`.template-config.json`** - Project metadata
- **`helm/dam-plugin/values.yaml`** - Updated with your settings

### Components (Based on Your Choices)

1. **Backend Service** (`packages/server-v1/`)
   - LoopBack 4 REST API
   - Deployed to Kubernetes
   - Health checks, OpenAPI docs

2. **Script Portlet** (`packages/portlet-v1/`) - _Optional_
   - React + TypeScript + Vite
   - Deployed to DX Portal via DXClient
   - Web UI for your application

3. **DAM Plugin** - _Optional_
   - Image/media processing
   - Integrates with HCL DAM
   - Custom transformation stacks

## 🔄 Development Workflow

### After Successful Initialization

```
┌──────────────────────────────────────────┐
│ 1. Initialize (./scripts/init-template.sh) │
│    ✓ Configure project                     │
│    ✓ Test connections                      │
│    ✓ Setup database                        │
│    ✓ Generate config files                 │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│ 2. Setup Database (if new project)        │
│    ✓ Create database                       │
│    ✓ Create user & grant permissions      │
│    ✓ Test connection                       │
│    If generated, use docs/DATABASE_SETUP.md│
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│ 3. Validate (./scripts/validate-*.sh)     │
│    ✓ Check configuration                   │
│    ✓ Verify tools                          │
│    ✓ Test connectivity                     │
│    ✓ Verify database                       │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│ 4. Test Deploy (Stock Template)           │
│    ✓ Build backend                         │
│    ✓ Deploy to K8s                         │
│    ✓ Verify endpoints                      │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│ 5. Customize & Develop                     │
│    • Add your business logic               │
│    • Modify UI components                  │
│    • Add database models                   │
│    • Test locally (port-forward)           │
└──────────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────────┐
│ 6. Deploy Changes                          │
│    • Build updated code                    │
│    • Push to registry                      │
│    • Deploy to cluster                     │
│    • Validate                              │
└──────────────────────────────────────────┘
```

## 🎨 Customization

### Backend (LoopBack 4)

```bash
cd packages/server-v1

# Install PostgreSQL connector (if not already installed)
npm install --save loopback-connector-postgresql

# Add a new controller
lb4 controller

# Add a model
lb4 model

# Add a repository (connects model to database)
lb4 repository

# Create a datasource (PostgreSQL config)
lb4 datasource
# Name: postgres
# Connector: PostgreSQL
# It will use DB_HOST, DB_PORT, etc. from .env

# Test locally
npm run dev
```

**💾 Database Integration:**
- PostgreSQL connection details are in `.env`
- Use `lb4 model` and `lb4 repository` to create database-backed models
- If initialization generated it, use [docs/DATABASE_SETUP.md](docs/DATABASE_SETUP.md) for DB creation guidance; otherwise use [docs/POSTGRESQL_INTEGRATION.md](docs/POSTGRESQL_INTEGRATION.md)

### Portlet (React)

```bash
cd packages/portlet-v1

# Start dev server
npm run dev

# Add new page
# Create src/pages/YourPage.tsx
# Update src/App.tsx routes

# Build for production
npm run build
```

### Deploy Changes

```bash
# Build and push the backend image
./scripts/build.sh --push

# Deploy backend
./scripts/deploy.sh

# Deploy portlet
./scripts/deploy-portlet.sh --build

# Or use the one-step pipeline
./scripts/build-and-deploy.sh
```

## 🧪 Testing

### Local Testing

```bash
# Port forward to backend
./scripts/port-forward.sh

# Test health endpoint
curl http://localhost:3000/health

# Test API endpoints
./scripts/testing/quick-test-api.sh
```

### Full Test Suite

```bash
# Comprehensive end-to-end tests
./scripts/testing/test-template-end-to-end.sh

# Quick tests
./scripts/testing/quick-test-build.sh
./scripts/testing/quick-test-deploy.sh
./scripts/testing/quick-test-api.sh
```

## 📚 Documentation

- **[Initialization Guide](scripts/INITIALIZATION_GUIDE.md)** - Detailed init walkthrough
- **[Environment Setup](docs/ENVIRONMENT_SETUP.md)** - Environment configuration
- **[Portlet Deployment](docs/PORTLET_DEPLOYMENT.md)** - Script portlet guide
- **[Testing Guide](scripts/testing/README.md)** - Testing framework
- **[Architecture Overview](docs/architecture.md)** - Technical details

## 🔧 Common Tasks

### View Logs

```bash
# Backend logs
kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME -f

# All pods in namespace
kubectl logs -n $NAMESPACE --all-containers=true -l app=$RELEASE_NAME
```

### Update Configuration

```bash
# Edit .env
nano .env

# Re-validate
./scripts/validate-deployment-readiness.sh

# Apply changes (rebuild and redeploy)
./scripts/build-and-deploy.sh
```

### Rollback Deployment

```bash
# Helm rollback
helm rollback $RELEASE_NAME -n $NAMESPACE

# Or redeploy previous image
IMAGE_TAG=previous-tag ./scripts/deploy.sh
```

### Clean Up

```bash
# Undeploy from Kubernetes
./scripts/undeploy.sh

# Remove local builds
rm -rf packages/*/dist packages/*/node_modules
```

## ❓ Troubleshooting

### "Namespace not found"

```bash
# Create namespace
kubectl create namespace my-namespace
```

### "Cannot connect to cluster"

```bash
# Check context
kubectl config current-context

# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context my-context
```

### "DXClient command not found"

```bash
# Install DXClient
# https://help.hcl-software.com/digital-experience/9.5/containerization/dxclient.html

# Or use Homebrew (if available)
brew install dxclient
```

### "Port forward failed"

```bash
# Check pod is running
kubectl get pods -n $NAMESPACE

# Check pod name
kubectl get pods -n $NAMESPACE -l app=$RELEASE_NAME

# Manual port forward
kubectl port-forward -n $NAMESPACE deployment/$RELEASE_NAME 3000:3000
```

### "Image pull failed"

```bash
# Authenticate with registry
# For GCP:
gcloud auth configure-docker us-central1-docker.pkg.dev

# For Docker Hub:
docker login

# Check image exists
docker images | grep $IMAGE_NAME
```

### Build Errors

```bash
# Clear caches
rm -rf packages/server-v1/node_modules packages/server-v1/dist
cd packages/server-v1
npm install
npm run build
```

## 🆘 Getting Help

### Quick References

```bash
# Show all available scripts
ls -la scripts/

# Show environment variables
cat .env

# Show project configuration
cat .template-config.json | jq .

# Show Helm values
cat helm/dam-plugin/values.yaml
```

### Documentation

| Guide | Purpose |
|-------|---------|
| [START_HERE.md](START_HERE.md) | This guide - getting started |
| [first-clone-setup.md](docs/first-clone-setup.md) | Required files and values for a fresh clone |
| [API_INTEGRATION.md](docs/API_INTEGRATION.md) | Connecting your UI to the backend |
| [INITIALIZATION_GUIDE.md](scripts/INITIALIZATION_GUIDE.md) | Detailed init wizard walkthrough |
| [POSTGRESQL_INTEGRATION.md](docs/POSTGRESQL_INTEGRATION.md) | Database setup and configuration |

### Need More Help?

1. Check documentation above
2. Run validation: `./scripts/validate-deployment-readiness.sh`
3. Check test suite: `./scripts/testing/test-template-end-to-end.sh`
4. Review migration logs: `/tmp/build.log`, `/tmp/npm-install.log`

## 🎯 Next Steps

**If this is your first time:**

1. ✅ Read this entire document
2. ✅ Run `./scripts/init-template.sh`
3. ✅ Run `./scripts/validate-deployment-readiness.sh`
4. ✅ Test locally: `cd packages/portlet-v1 && npm run dev`
5. ✅ Test deploy: `DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh`
6. ✅ Deploy for real: `./scripts/build-and-deploy.sh`
7. ✅ Verify: Access your DX Portal or API endpoints
8. ✅ Start customizing!

**If you've already initialized:**

1. Make your code changes
2. Test locally: `./scripts/port-forward.sh` + `npm run dev`
3. Build: `./scripts/build.sh --push`
4. Deploy: `./scripts/build-and-deploy.sh`
5. Validate: `./scripts/testing/quick-test-api.sh`

## 🌟 Pro Tips

- **Always test with stock template first** - Don't customize until baseline works
- **Use dry-run mode** - `DRY_RUN=true` tests without deploying
- **Keep .env out of git** - It's in `.gitignore` for a reason!
- **Use port-forwarding for dev** - Faster than redeploying
- **Run validation often** - Catch config issues early
- **Read the logs** - `kubectl logs` is your friend
- **Tag your images** - Use semantic versioning, not just "latest"

## 🚀 Ready to Start?

Run this command now:

```bash
./scripts/init-template.sh
```

Follow the prompts and you'll be deploying in 10 minutes!

---

**Template Version:** 1.0.0  
**Last Updated:** February 2, 2026  
**Questions?** Check [scripts/INITIALIZATION_GUIDE.md](scripts/INITIALIZATION_GUIDE.md)
