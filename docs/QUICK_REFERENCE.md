# Quick Reference Card

## 🚀 First Time Setup (3 Steps)

```bash
# 1. Initialize (interactive wizard)
./scripts/init-template.sh

# 2. Validate configuration
./scripts/validate-deployment-readiness.sh

# 3. Deploy
./scripts/build-and-deploy.sh
```

## 📖 Essential Documentation

| Document | Purpose |
|----------|---------|
| [START_HERE.md](../START_HERE.md) | Main entry point, quick start |
| [scripts/INITIALIZATION_GUIDE.md](../scripts/INITIALIZATION_GUIDE.md) | Detailed setup walkthrough |
| [docs/INITIALIZATION_SYSTEM.md](INITIALIZATION_SYSTEM.md) | System implementation details |
| [docs/ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) | Environment configuration |
| [docs/PORTLET_DEPLOYMENT.md](PORTLET_DEPLOYMENT.md) | Script portlet guide |
| [scripts/testing/README.md](../scripts/testing/README.md) | Testing framework |

## 🔧 Common Commands

### Configuration
```bash
# Initialize project
./scripts/init-template.sh

# Validate setup
./scripts/validate-deployment-readiness.sh

# View current config
cat .env
cat .template-config.json | jq .
```

### Building
```bash
# Build everything
./scripts/build-all.sh

# Build backend only
./scripts/build-all.sh --backend-only

# Build portlet only
./scripts/build-all.sh --portlet-only

# Build Docker image
./scripts/build.sh --push
```

### Deploying
```bash
# Deploy backend to Kubernetes
./scripts/deploy.sh

# Deploy portlet to DX Portal
./scripts/deploy-portlet.sh --build

# Deploy everything
./scripts/build-and-deploy.sh

# Dry run (no push/deploy)
DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh build-only
```

### Testing
```bash
# Full test suite
./scripts/testing/test-template-end-to-end.sh

# Quick tests
./scripts/testing/quick-test-build.sh
./scripts/testing/quick-test-deploy.sh
./scripts/testing/quick-test-api.sh

# Validate template
./scripts/testing/validate-template.sh
```

### Local Development
```bash
# Port forward to backend
./scripts/port-forward.sh

# Test health
curl http://localhost:3000/health

# Test API
curl http://localhost:3000/api/v1/process

# Run backend locally
cd packages/server-v1
npm run dev
```

### Kubernetes
```bash
# View pods
kubectl get pods -n $NAMESPACE

# View services
kubectl get svc -n $NAMESPACE

# View logs
kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME -f

# Describe pod
kubectl describe pod -n $NAMESPACE <pod-name>

# Port forward manually
kubectl port-forward -n $NAMESPACE deployment/$RELEASE_NAME 3000:3000
```

### Helm
```bash
# List releases
helm list -n $NAMESPACE

# Get values
helm get values $RELEASE_NAME -n $NAMESPACE

# Rollback
helm rollback $RELEASE_NAME -n $NAMESPACE

# Uninstall
./scripts/undeploy.sh
```

## 🚨 Troubleshooting

### Configuration Issues
```bash
# Re-initialize (backs up existing)
./scripts/init-template.sh

# Check what's wrong
./scripts/validate-deployment-readiness.sh

# Verify .env exists
cat .env
```

### Build Issues
```bash
# Clean build
rm -rf packages/*/dist packages/*/node_modules

# Reinstall
cd packages/server-v1 && npm install && npm run build
cd ../portlet-v1 && npm install && npm run build
```

### Deployment Issues
```bash
# Check pod status
kubectl get pods -n $NAMESPACE

# Check logs
kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME

# Check events
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'

# Redeploy
./scripts/deploy.sh
```

### Connection Issues
```bash
# Test Kubernetes
kubectl cluster-info
kubectl get nodes

# Test Docker
docker info

# Test DX Portal
curl -k https://$DX_HOSTNAME:$DX_PORT/wps/portal
```

## 📋 Checklist - Before Deploying

- [ ] Ran `./scripts/init-template.sh`
- [ ] Validated with `./scripts/validate-deployment-readiness.sh`
- [ ] All checks passed (or only warnings)
- [ ] Dependencies installed (`npm install`)
- [ ] Dry-run test passed
- [ ] Credentials are correct
- [ ] Namespace exists
- [ ] `.env` not committed to git

## 🎯 Workflow Diagram

```
Clone Template
      ↓
Run ./scripts/init-template.sh (Interactive wizard)
      ↓
Run ./scripts/validate-deployment-readiness.sh (Check setup)
      ↓
Install dependencies (npm install)
      ↓
DRY_RUN=true test (No deploy, just test build)
      ↓
Deploy stock template (Verify baseline works)
      ↓
Customize code (Make your changes)
      ↓
Test locally (Port forward, npm run dev)
      ↓
Build & Deploy (./scripts/build-and-deploy.sh)
      ↓
Validate (Check logs, test endpoints)
```

## 🔑 Key Files

| File | Purpose | Commit? |
|------|---------|---------|
| `.env` | Environment variables & credentials | ❌ NO |
| `.template-config.json` | Project metadata | ✅ YES |
| `.gitignore` | Excludes .env from git | ✅ YES |
| `START_HERE.md` | Getting started guide | ✅ YES |
| `helm/dam-plugin/values.yaml` | Helm configuration | ✅ YES |
| `packages/*/node_modules` | Dependencies | ❌ NO |
| `packages/*/dist` | Build output | ❌ NO |

## 💡 Pro Tips

1. **Always validate after config changes**
   ```bash
   ./scripts/validate-deployment-readiness.sh
   ```

2. **Use dry-run for testing**
   ```bash
   DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh
   ```

3. **Port-forward for local dev**
   ```bash
   ./scripts/port-forward.sh &
   # Now access http://localhost:3000
   ```

4. **Check logs frequently**
   ```bash
   kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME -f
   ```

5. **Use semantic versioning for images**
   ```bash
   IMAGE_TAG=v1.0.1 ./scripts/build.sh --push
   ```

6. **Keep .env out of git**
   ```bash
   # Verify
   git ls-files .env  # Should error "did not match any files"
   ```

## 📞 Getting Help

1. Check [START_HERE.md](../START_HERE.md)
2. Run validation: `./scripts/validate-deployment-readiness.sh`
3. Review logs: `kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME`
4. Check [scripts/INITIALIZATION_GUIDE.md](../scripts/INITIALIZATION_GUIDE.md)
5. Review test output: `./scripts/testing/test-template-end-to-end.sh`

## 🎓 Learning Path

**Beginner:**
1. Read [START_HERE.md](../START_HERE.md)
2. Run `./scripts/init-template.sh`
3. Follow prompts
4. Deploy stock template
5. Verify it works

**Intermediate:**
1. Understand [architecture.md](./architecture.md)
2. Customize backend controllers
3. Modify portlet UI
4. Add new API endpoints
5. Test locally with port-forwarding

**Advanced:**
1. Add new components
2. Integrate external services
3. Configure autoscaling
4. Set up CI/CD pipelines
5. Optimize resource limits
