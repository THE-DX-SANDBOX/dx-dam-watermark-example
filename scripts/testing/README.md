# Template Testing Guide

This directory contains comprehensive testing tools for validating the DAM-Demo template framework.

## Overview

These tests validate the **template framework**, not the application logic. They ensure:
- ✅ Build process works correctly
- ✅ Docker images can be created and pushed
- ✅ Kubernetes deployment succeeds
- ✅ Services are accessible
- ✅ API endpoints respond correctly
- ✅ Port forwarding works for local testing

## Quick Start

### 1. Validate Template Structure

```bash
# Check if all required files and directories exist
./scripts/testing/validate-template.sh
```

### 2. Test Build Process

```bash
# Test backend build and Docker image creation (no push/deploy)
./scripts/testing/quick-test-build.sh
```

### 3. Test Deployment

```bash
# Test Kubernetes deployment (assumes image exists)
SKIP_PUSH=true ./scripts/testing/quick-test-deploy.sh
```

### 4. Test API Endpoints

```bash
# Test API via port forwarding (assumes deployment exists)
./scripts/testing/quick-test-api.sh
```

### 5. Full End-to-End Test

```bash
# Run complete pipeline: build → push → deploy → test
./scripts/testing/test-template-end-to-end.sh

# Dry run (shows what would be executed)
DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh
```

## Test Modes

The main test script supports different modes:

### Full Pipeline (default)
```bash
./scripts/testing/test-template-end-to-end.sh full
```
Runs: Build → Docker Build → Push → Deploy → API Tests

### Build Only
```bash
./scripts/testing/test-template-end-to-end.sh build-only
```
Tests: Backend build and Docker image creation (no push)

### Deploy Only
```bash
./scripts/testing/test-template-end-to-end.sh deploy-only
```
Tests: Helm chart validation and Kubernetes deployment

### Backend Only
```bash
./scripts/testing/test-template-end-to-end.sh backend-only
```
Tests: Backend build and deployment (no frontend/portlet)

## Environment Variables

Control test behavior with environment variables:

```bash
# Dry run - shows what would be executed without doing it
DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh

# Skip Docker push (useful for testing build/deploy locally)
SKIP_PUSH=true ./scripts/testing/test-template-end-to-end.sh

# Skip Kubernetes deployment
SKIP_DEPLOY=true ./scripts/testing/test-template-end-to-end.sh

# Combine flags
DRY_RUN=true SKIP_PUSH=true ./scripts/testing/test-template-end-to-end.sh
```

## What Gets Tested

### Pre-flight Checks ✈️
- Required tools installed (node, npm, docker, kubectl, helm)
- Environment variables configured
- Kubernetes cluster accessible
- Namespace exists
- Docker running

### Build Tests 🔨
- Backend dependencies install
- TypeScript compilation
- dist/ folder created correctly
- Required files present
- OpenAPI spec generation
- Docker image builds successfully
- Image size reported

### Docker Registry Tests 📦
- GCP authentication configured
- Image tagged correctly
- Image pushes to registry

### Deployment Tests 🚀
- Helm chart linting
- Template rendering
- Deployment installation/upgrade
- Pods become ready
- Service exists and has endpoints

### Integration Tests 🔗
- Port forwarding establishes
- Health endpoint responds
- OpenAPI spec accessible
- Plugin API endpoints respond
- DAM ConfigMap exists
- Plugin registration checked
- Ingress configuration validated

## Troubleshooting

### Port Forwarding Issues

```bash
# Check if port is already in use
lsof -i :3000

# Kill existing port forward
pkill -f "kubectl port-forward"

# Or use the quick test which handles this
./scripts/testing/quick-test-api.sh
```

### Deployment Not Ready

```bash
# Check pod status
kubectl get pods -n $NAMESPACE

# Check pod logs
kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME

# Check events
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'

# Describe deployment
kubectl describe deployment $RELEASE_NAME -n $NAMESPACE
```

### Docker Push Fails

```bash
# Authenticate with GCP Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Check current authentication
gcloud auth list

# Test if you can push
docker pull hello-world
docker tag hello-world <DockerRegistry>/test
docker push <DockerRegistry>/test
```

### Build Fails

```bash
# Clean and rebuild
cd packages/server-v1
rm -rf node_modules dist
npm install
npm run build

# Check for TypeScript errors
npm run build -- --listFiles
```

### Test Script Not Executable

```bash
# Make scripts executable
chmod +x scripts/testing/*.sh

# Or use the make-executable helper
./scripts/make-executable.sh
```

## Test Output

The test scripts provide color-coded output:

- 🟢 **Green checkmark** - Test passed
- 🔴 **Red X** - Test failed
- 🟡 **Yellow warning** - Warning or skipped
- 🔵 **Blue info** - Information message

Example output:
```
==========================================
Testing Backend Build
==========================================

▶ Running: Backend: Install dependencies
✅ Backend: Install dependencies

▶ Running: Backend: TypeScript compilation
✅ Backend: TypeScript compilation

✅ Backend: dist/ folder created
✅ Backend: dist/index.js exists
✅ Backend: dist/application.js exists
⚠️  Backend: OpenAPI spec not found
```

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Validate Template
  run: ./scripts/testing/validate-template.sh

- name: Test Build
  run: ./scripts/testing/test-template-end-to-end.sh build-only

- name: Test Deployment
  run: |
    SKIP_PUSH=true \
    ./scripts/testing/test-template-end-to-end.sh deploy-only
```

## Best Practices

1. **Always run validation first**
   ```bash
   ./scripts/testing/validate-template.sh
   ```

2. **Use dry-run for safety**
   ```bash
   DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh
   ```

3. **Test incrementally**
   - Build → Deploy → API → Full
   - Fix issues at each stage before proceeding

4. **Skip unnecessary steps**
   - Use SKIP_PUSH when testing locally
   - Use SKIP_DEPLOY when testing build changes

5. **Check logs on failure**
   - Scripts show relevant logs automatically
   - Use kubectl commands for deeper investigation

## Adding New Tests

To add tests for new components (e.g., portlets):

1. Add test function in `test-template-end-to-end.sh`:
   ```bash
   test_portlet_build() {
       print_header "Testing Portlet Build"
       # Your test code here
   }
   ```

2. Add to test execution flow:
   ```bash
   if [[ "$TEST_MODE" == "full" ]] || [[ "$TEST_MODE" == "portlet-only" ]]; then
       test_portlet_build || true
   fi
   ```

3. Create quick test script:
   ```bash
   # scripts/testing/quick-test-portlet.sh
   ./scripts/testing/test-template-end-to-end.sh portlet-only
   ```

## Support

For issues or questions:
1. Check this README
2. Review test output carefully
3. Check Kubernetes logs: `kubectl logs -n $NAMESPACE deployment/$RELEASE_NAME`
4. Review [main documentation](../../docs/)

## Files in This Directory

- `test-template-end-to-end.sh` - Main comprehensive test suite
- `validate-template.sh` - Structure validation checklist
- `quick-test-build.sh` - Quick build testing
- `quick-test-deploy.sh` - Quick deployment testing
- `quick-test-api.sh` - Quick API endpoint testing
- `README.md` - This file

---

**Last Updated:** January 30, 2026
