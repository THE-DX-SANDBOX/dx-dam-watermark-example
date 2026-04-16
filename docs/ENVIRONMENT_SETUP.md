# Environment Configuration Guide

This guide explains how to set up environment-specific configuration for the DAM Plugin across different deployment environments.

## Overview

The DAM Plugin uses environment-specific configuration files to manage settings across different deployment stages:

- **Local** (`.env.local`) - Development on your laptop
- **Dev** (`.env.dev`) - Shared development Kubernetes cluster
- **UAT** (`.env.uat`) - Staging/QA environment
- **Production** (`.env.prod`) - Live production environment

## How the Scripts Read Configuration

There are two valid configuration workflows in this repository:

1. Use a single root `.env` file created from `.env.example`.
   This is the simplest path, and it is the file auto-loaded by the build and deploy scripts.
2. Use environment-specific profile files such as `.env.dev` or `.env.prod`.
   Load them with `source scripts/load-env.sh <env>` or use the profile-aware shortcuts such as `./scripts/deploy.sh dev` and `./scripts/build-and-deploy.sh prod`.

If you do nothing else after cloning, create `.env` first. The profile files are optional convenience layers for teams that need separate settings per environment.

## Security Model

| Environment | Credential Storage | Git Tracked | CORS | Log Level |
|------------|-------------------|-------------|------|-----------|
| **Local** | `.env.local` file | ❌ No | `*` (any) | `debug` |
| **Dev** | `.env.dev` + K8s secrets | ❌ No | Restricted | `debug`/`info` |
| **UAT** | **Kubernetes secrets** | ❌ No | Restricted | `info` |
| **Production** | **Kubernetes secrets** | ❌ No | Restricted | `error` |

### What Gets Committed to Git?

✅ **Tracked (committed):**
- `.env.example` - Master template
- `.env.local.example` - Local dev template
- `.env.dev.example` - Dev cluster template
- `.env.uat.example` - UAT template
- `.env.prod.example` - Production template
- `scripts/load-env.sh` - Environment loader

❌ **Not tracked (in .gitignore):**
- `.env` - Root script-ready config used by build and deploy commands
- `.env.local` - Your actual local config
- `.env.dev` - Your actual dev config
- `.env.uat` - Your actual UAT config
- `.env.prod` - Your actual production config
- Any files with real credentials

## Quick Start

### Simplest Script-Driven Setup

```bash
cp .env.example .env
nano .env
```

Use this when you want the shortest path to a working baseline and do not need separate environment profiles yet.

### 1. Choose Your Environment

**For local development:**
```bash
# Copy template
cp .env.local.example .env.local

# Edit with your settings
nano .env.local

# Set environment variables for current shell
source scripts/load-env.sh local
```

**For development cluster:**
```bash
cp .env.dev.example .env.dev
nano .env.dev
source scripts/load-env.sh dev
```

**For UAT/Staging:**
```bash
cp .env.uat.example .env.uat
nano .env.uat  # Must use Kubernetes secrets for credentials!
source scripts/load-env.sh uat
```

**For production:**
```bash
cp .env.prod.example .env.prod
nano .env.prod  # Must use Kubernetes secrets for credentials!
source scripts/load-env.sh prod
```

### 2. Customize Settings

Edit your environment file and replace placeholder values:

```bash
# Example: .env.local
PORT=3000
NODE_ENV=development
LOG_LEVEL=debug

# Local database (use Docker Compose or local Postgres)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dam_plugin_local
DB_USER=postgres
DB_PASSWORD=local_dev_password

# Development API keys (not for production!)
API_KEY=dev-api-key-12345
JWT_SECRET=local-jwt-secret-for-development-only-min-32-chars

# HCL DX DAM (local DX instance)
DAM_HOST=http://localhost:10039
DAM_API_KEY=your-local-dam-api-key
```

### 3. Load Environment

The `load-env.sh` script safely loads your environment configuration:

```bash
# Load and export variables
source scripts/load-env.sh local

# Verify it worked
echo $NODE_ENV  # Should print: development
echo $PORT      # Should print: 3000
```

## Environment-Specific Configuration

### Local Development (`.env.local`)

**Purpose:** Development on your laptop, rapid iteration, debugging

**Characteristics:**
- Relaxed security (development-only credentials OK)
- Verbose logging (`LOG_LEVEL=debug`)
- CORS open to all origins (`CORS_ORIGIN=*`)
- Local services (localhost database, Redis)
- No Kubernetes required

**Example:**
```bash
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug
DEBUG=plugin:*

# Local database
DB_HOST=localhost
DB_PORT=5432
DB_PASSWORD=local_dev_only

# Development API keys
API_KEY=local-dev-key
JWT_SECRET=local-jwt-secret-at-least-32-characters-long

# Local DX instance
DAM_HOST=http://localhost:10039
DAM_API_KEY=local-dam-api-key
```

**Running locally:**
```bash
# With Docker Compose (recommended)
docker-compose up

# Or directly with npm
source scripts/load-env.sh local
npm run dev
```

---

### Development Cluster (`.env.dev`)

**Purpose:** Shared development Kubernetes cluster, team collaboration, integration testing

**Characteristics:**
- Debug/info logging enabled
- Credentials: Mix of `.env.dev` file + Kubernetes secrets (transition phase)
- CORS restricted to known development origins
- Deployed to `<Namespace>` namespace
- Auto-deploy on git push (CI/CD)

**Example:**
```bash
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug

# Kubernetes cluster settings
K8S_NAMESPACE=<Namespace>
K8S_SERVICE_NAME=dam-plugin-dev

# Non-sensitive config (OK in file)
DB_HOST=<DbHost>
DB_PORT=5432
DB_NAME=dam_plugin_dev

# TODO: Move these to Kubernetes secrets
DB_USER=plugin_user
DB_PASSWORD=CHANGE_ME_TO_K8S_SECRET

# API keys - SHOULD be in Kubernetes secrets
API_KEY=dev-cluster-api-key
JWT_SECRET=dev-jwt-secret-min-32-chars

# HCL DX Dev Cluster
DAM_HOST=https://dx-dev.your-company.com
DAM_API_KEY=dev-dam-api-key

CORS_ORIGIN=https://dx-dev.your-company.com,http://localhost:3000
```

**Deploying to dev:**
```bash
# Load dev environment
source scripts/load-env.sh dev

# Build and deploy
./scripts/build.sh --push
./scripts/deploy.sh dev
```

---

### UAT/Staging (`.env.uat`)

**Purpose:** Pre-production testing, QA validation, performance testing

**Characteristics:**
- Production-like configuration
- **ALL credentials MUST be in Kubernetes secrets**
- Info-level logging only
- CORS strictly limited
- Mirrors production architecture
- Rate limiting enabled

**Example:**
```bash
NODE_ENV=uat
PORT=3000
LOG_LEVEL=info

# Kubernetes cluster
K8S_NAMESPACE=<Namespace>
K8S_SERVICE_NAME=dam-plugin-uat

# Non-sensitive configuration
DB_HOST=<DbHost>
DB_PORT=5432
DB_NAME=dam_plugin_uat

# REQUIRED: Use Kubernetes secrets for all credentials
# DB_USER: from secret 'dam-plugin-db' key 'DB_USER'
# DB_PASSWORD: from secret 'dam-plugin-db' key 'DB_PASSWORD'
# API_KEY: from secret 'dam-plugin-api' key 'API_KEY'
# JWT_SECRET: from secret 'dam-plugin-api' key 'JWT_SECRET'
# DAM_API_KEY: from secret 'dam-plugin-api' key 'DAM_API_KEY'

# HCL DX UAT
DAM_HOST=https://dx-uat.your-company.com

CORS_ORIGIN=https://dx-uat.your-company.com
RATE_LIMIT_MAX=100
RATE_LIMIT_WINDOW=15m
```

**Creating UAT secrets:**
```bash
# Database credentials
kubectl create secret generic dam-plugin-db \
  --from-literal=DB_USER=plugin_user_uat \
  --from-literal=DB_PASSWORD='uat-secure-password' \
   -n <Namespace>

# API credentials
kubectl create secret generic dam-plugin-api \
  --from-literal=API_KEY='uat-api-key' \
  --from-literal=JWT_SECRET='uat-jwt-secret-min-32-chars' \
  --from-literal=DAM_API_KEY='uat-dam-api-key' \
   -n <Namespace>
```

---

### Production (`.env.prod`)

**Purpose:** Live production environment serving real users

**Characteristics:**
- **STRICT security - ALL credentials in Kubernetes secrets**
- Error-only logging (`LOG_LEVEL=error`)
- CORS limited to production origins only
- Rate limiting enforced
- Health checks and monitoring enabled
- Semantic versioning required
- High availability (multiple replicas)

**Example:**
```bash
NODE_ENV=production
PORT=3000
LOG_LEVEL=error
APP_VERSION=1.2.3  # REQUIRED: Semantic versioning

# Kubernetes production cluster
K8S_NAMESPACE=<Namespace>
K8S_SERVICE_NAME=dam-plugin-prod
REPLICAS=3

# Non-sensitive configuration
DB_HOST=<DbHost>
DB_PORT=5432
DB_NAME=dam_plugin_prod
DB_SSL=true
DB_POOL_MIN=5
DB_POOL_MAX=20

# CRITICAL: ALL credentials MUST be in Kubernetes secrets
# DO NOT put any passwords, keys, or tokens in this file!
# Reference secrets in Helm values.yaml or deployment manifests

# HCL DX Production
DAM_HOST=https://dx.your-company.com

# Security settings
CORS_ORIGIN=https://dx.your-company.com
RATE_LIMIT_MAX=50
RATE_LIMIT_WINDOW=15m

# Monitoring
METRICS_ENABLED=true
METRICS_PORT=9090
HEALTH_CHECK_PATH=/health
```

**Production secrets management:**
```bash
# Create production secrets (do this manually, not in CI/CD)
kubectl create secret generic dam-plugin-db-prod \
  --from-literal=DB_USER=plugin_user_prod \
  --from-literal=DB_PASSWORD='STRONG_RANDOM_PASSWORD_HERE' \
   -n <Namespace>

kubectl create secret generic dam-plugin-api-prod \
  --from-literal=API_KEY='PRODUCTION_API_KEY' \
  --from-literal=JWT_SECRET='PRODUCTION_JWT_SECRET_MIN_32_CHARS' \
  --from-literal=DAM_API_KEY='PRODUCTION_DAM_API_KEY' \
   -n <Namespace>

# Verify secrets exist
kubectl get secrets -n <Namespace> | grep <PluginSecretPrefix>

# Deploy with production config
source scripts/load-env.sh prod
./scripts/deploy.sh prod
```

---

## Kubernetes Secrets Integration

### Why Kubernetes Secrets?

For UAT and Production environments, using Kubernetes secrets provides:

- ✅ Separation of config from code
- ✅ Encryption at rest (if configured)
- ✅ RBAC access control
- ✅ Audit logging
- ✅ Secret rotation without code changes
- ✅ No credentials in git repository

### Creating Secrets

**Database credentials:**
```bash
kubectl create secret generic dam-plugin-db \
   --from-literal=DB_HOST=<DbHost> \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=dam_plugin \
  --from-literal=DB_USER=plugin_user \
  --from-literal=DB_PASSWORD='your-secure-password' \
   -n <Namespace>
```

**API keys:**
```bash
kubectl create secret generic dam-plugin-api \
  --from-literal=API_KEY='your-api-key' \
  --from-literal=JWT_SECRET='your-jwt-secret-min-32-chars' \
  --from-literal=DAM_API_KEY='your-dam-api-key' \
   -n <Namespace>
```

**External services:**
```bash
kubectl create secret generic dam-plugin-external \
  --from-literal=EXTERNAL_API_KEY='external-api-key' \
  --from-literal=REDIS_PASSWORD='redis-password' \
   -n <Namespace>
```

### Referencing Secrets in Helm

Update `helm/values-prod.yaml`:

```yaml
# Deployment will mount these secrets as environment variables
secrets:
  database:
    secretName: dam-plugin-db
    keys:
      - DB_HOST
      - DB_PORT
      - DB_NAME
      - DB_USER
      - DB_PASSWORD
  
  api:
    secretName: dam-plugin-api
    keys:
      - API_KEY
      - JWT_SECRET
      - DAM_API_KEY
  
  external:
    secretName: dam-plugin-external
    keys:
      - EXTERNAL_API_KEY
      - REDIS_PASSWORD
```

The Helm chart templates will generate:

```yaml
# In deployment.yaml template
env:
  # From .env.prod file (non-sensitive)
  - name: NODE_ENV
    value: "production"
  - name: PORT
    value: "3000"
  
  # From Kubernetes secrets
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: dam-plugin-db
        key: DB_PASSWORD
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: dam-plugin-api
        key: API_KEY
  # ... etc
```

### Managing Secrets

**List secrets:**
```bash
kubectl get secrets -n <Namespace>
```

**Describe secret (doesn't show values):**
```bash
kubectl describe secret <ApiSecretName> -n <Namespace>
```

**View secret (base64 encoded):**
```bash
kubectl get secret <ApiSecretName> -n <Namespace> -o yaml
```

**Decode a specific value:**
```bash
kubectl get secret <ApiSecretName> -n <Namespace> \
  -o jsonpath='{.data.API_KEY}' | base64 -d
```

**Update a secret:**
```bash
# Option 1: Replace entire secret
kubectl create secret generic dam-plugin-api \
  --from-literal=API_KEY='new-api-key' \
  --dry-run=client -o yaml | kubectl apply -f -

# Option 2: Edit interactively
kubectl edit secret <ApiSecretName> -n <Namespace>

# Restart pods to pick up new values
kubectl rollout restart deployment/<PluginDeploymentName> -n <Namespace>
```

**Delete a secret:**
```bash
kubectl delete secret <ApiSecretName> -n <Namespace>
```

---

## Best Practices

### Security

1. **Never commit actual credentials to git**
   - Only `.env.*.example` templates are tracked
   - Actual `.env.*` files are in `.gitignore`

2. **Use Kubernetes secrets for UAT/Production**
   - Development: `.env.dev` file is OK (but secrets recommended)
   - UAT: Secrets REQUIRED
   - Production: Secrets REQUIRED

3. **Rotate credentials regularly**
   - Quarterly minimum for production
   - After any suspected compromise
   - When team members leave

4. **Different credentials per environment**
   - Never reuse production credentials in dev/uat
   - Use weak/simple credentials in local development only

5. **Restrict secret access**
   - Use Kubernetes RBAC to limit who can view secrets
   - Audit secret access regularly
   - Use sealed secrets or external secret managers for enterprises

### Configuration Management

1. **Keep templates up to date**
   - When adding new config variables, update all `.env.*.example` files
   - Document new variables in `.env.example`

2. **Validate required variables**
   - The `load-env.sh` script validates required variables
   - Add validation for new critical variables

3. **Use environment-appropriate settings**
   - Local: Verbose logging, relaxed security
   - Dev: Debug logging, some security
   - UAT: Production-like, strict security
   - Prod: Minimal logging, maximum security

4. **Document dependencies**
   - If adding external service, document in all templates
   - Include setup instructions in this guide

### Deployment

1. **Test in lower environments first**
   - Local → Dev → UAT → Production
   - Never deploy directly to production

2. **Verify secrets before deployment**
   ```bash
   # Check secrets exist
   kubectl get secrets -n <Namespace> | grep <PluginSecretPrefix>
   
   # Verify deployment references correct secrets
   kubectl get deployment <PluginDeploymentName> -n <Namespace> -o yaml | grep -A 5 secretKeyRef
   ```

3. **Monitor after deployment**
   - Check pod logs for startup errors
   - Verify health checks pass
   - Test API endpoints

4. **Have a rollback plan**
   ```bash
   # Rollback to previous version
   kubectl rollout undo deployment/<PluginDeploymentName> -n <Namespace>
   ```

---

## Troubleshooting

### Environment not loading

**Problem:** `source scripts/load-env.sh local` shows error

**Solutions:**
```bash
# Verify template exists
ls -la .env.*.example

# Copy template if missing
cp .env.local.example .env.local

# Check file permissions
chmod 644 .env.local
chmod +x scripts/load-env.sh

# Verify file has content
cat .env.local | head -10
```

### Variables not set after loading

**Problem:** `echo $PORT` returns empty

**Solutions:**
```bash
# Must use 'source' to export to current shell
source scripts/load-env.sh local  # ✅ Correct

# This won't work (runs in subshell):
./scripts/load-env.sh local  # ❌ Variables not exported

# Check if file is valid
bash -n scripts/load-env.sh  # Check for syntax errors
```

### Kubernetes secret not found

**Problem:** Pod fails with "secret not found" error

**Solutions:**
```bash
# List secrets in namespace
kubectl get secrets -n <Namespace>

# Check if secret exists with correct name
kubectl describe secret <ApiSecretName> -n <Namespace>

# Recreate secret if missing
kubectl create secret generic dam-plugin-api \
  --from-literal=API_KEY='your-api-key' \
   -n <Namespace>

# Check deployment references correct secret name
kubectl get deployment <PluginDeploymentName> -n <Namespace> -o yaml | grep secretKeyRef
```

### Can't connect to database

**Problem:** Application can't connect to database in cluster

**Solutions:**
```bash
# Verify database service exists
kubectl get svc -n <Namespace> | grep <PostgresServiceName>

# Test connection from a pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n <Namespace> -- \
   psql -h <DbHost> -U <DbUser> -d <DbName>

# Check if DB credentials are correct
kubectl get secret <DbSecretName> -n <Namespace> -o jsonpath='{.data.DB_USER}' | base64 -d
```

### CORS errors in browser

**Problem:** Browser shows CORS policy errors

**Solutions:**
```bash
# Check CORS_ORIGIN setting in environment
source scripts/load-env.sh prod
echo $CORS_ORIGIN  # Should match your DX server URL

# For production, must be specific:
CORS_ORIGIN=https://dx.your-company.com  # ✅ Correct
CORS_ORIGIN=*  # ❌ Not allowed in production

# Restart service after changing CORS
kubectl rollout restart deployment/<PluginDeploymentName> -n <Namespace>
```

---

## Migration Guide

### Migrating from `.env` to environment-specific files

If you have an existing `.env` file:

1. **Backup existing configuration:**
   ```bash
   cp .env .env.backup
   ```

2. **Identify your environment:**
   - Running locally? → Create `.env.local`
   - Deployed to dev cluster? → Create `.env.dev`

3. **Copy from appropriate template:**
   ```bash
   cp .env.local.example .env.local
   ```

4. **Migrate settings from old `.env`:**
   ```bash
   # Open both files side by side
   code .env.backup .env.local
   
   # Copy values from backup to new file
   # Don't forget to customize for your environment
   ```

5. **Test new configuration:**
   ```bash
   source scripts/load-env.sh local
   npm run dev
   ```

6. **Remove old `.env` file:**
   ```bash
   rm .env.backup
   ```

### Migrating to Kubernetes secrets

If you're moving credentials from environment files to secrets:

1. **Identify sensitive variables:**
   - Database passwords
   - API keys
   - JWT secrets
   - External service credentials

2. **Create Kubernetes secrets:**
   ```bash
   kubectl create secret generic dam-plugin-db \
     --from-literal=DB_PASSWORD='your-password' \
   -n <Namespace>
   ```

3. **Update Helm values to reference secrets:**
   ```yaml
   # helm/values-prod.yaml
   secrets:
     database:
       secretName: dam-plugin-db
       keys: [DB_PASSWORD]
   ```

4. **Remove credentials from environment file:**
   ```bash
   # Edit .env.prod - remove sensitive values
   nano .env.prod
   
   # Add comments showing they're in secrets:
   # DB_PASSWORD: from secret 'dam-plugin-db' key 'DB_PASSWORD'
   ```

5. **Deploy and verify:**
   ```bash
   ./scripts/deploy.sh prod
   
   # Check pod logs
   kubectl logs -f deployment/<PluginDeploymentName> -n <Namespace>
   ```

---

## Reference

### Available Environment Variables

See [.env.example](.env.example) for a complete list of all available configuration variables.

### Scripts

- `scripts/load-env.sh` - Load environment-specific configuration
- `scripts/build.sh` - Build Docker image
- `scripts/deploy.sh` - Deploy to Kubernetes

### Related Documentation

- [README.md](../README.md) - Project overview
- [API.md](./API.md) - API documentation
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment guide
- [SERVICE_DISCOVERY.md](./SERVICE_DISCOVERY.md) - Service routing and discovery

---

## Support

For issues or questions:

1. Check this guide's troubleshooting section
2. Review environment-specific example files
3. Check project documentation in `docs/`
4. Contact the development team

---

**Last Updated:** January 2025  
**Version:** 1.0.0
