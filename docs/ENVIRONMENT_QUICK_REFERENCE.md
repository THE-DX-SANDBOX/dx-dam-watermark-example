# Environment Configuration Quick Reference

The root scripts auto-load `.env` when it exists. The `.env.local`, `.env.dev`, `.env.uat`, and `.env.prod` files are optional named profiles for commands such as `./scripts/deploy.sh dev` or `source scripts/load-env.sh dev`.

## 🚀 Quick Commands

### First Time Setup

```bash
# Simplest baseline workflow
cp .env.example .env
nano .env
```

Or use a named environment profile:

```bash
# Local development
cp .env.local.example .env.local
nano .env.local
source scripts/load-env.sh local

# Development cluster
cp .env.dev.example .env.dev
nano .env.dev
source scripts/load-env.sh dev

# UAT/Staging
cp .env.uat.example .env.uat
nano .env.uat  # Use K8s secrets!
source scripts/load-env.sh uat

# Production
cp .env.prod.example .env.prod
nano .env.prod  # Use K8s secrets!
source scripts/load-env.sh prod
```

### Daily Development

```bash
# Load environment and start coding
source scripts/load-env.sh local
npm run dev

# Check current environment
echo $NODE_ENV
echo $PORT

# Reload after changes
source scripts/load-env.sh local
```

### Deployment

```bash
# Deploy to dev
source scripts/load-env.sh dev
./scripts/build.sh --push
./scripts/deploy.sh dev

# Deploy to production
source scripts/load-env.sh prod
./scripts/build.sh --push
./scripts/deploy.sh prod
```

## 📊 Environment Comparison

| Feature | Local | Dev | UAT | Production |
|---------|-------|-----|-----|------------|
| **Credentials** | File | File/Secrets | Secrets | Secrets |
| **Log Level** | debug | debug/info | info | error |
| **CORS** | `*` | Restricted | Restricted | Restricted |
| **Database** | localhost | Cluster | Cluster | HA Cluster |
| **Replicas** | 1 | 1-2 | 2-3 | 3+ |
| **Rate Limiting** | Disabled | Optional | Enabled | Enabled |
| **Monitoring** | Optional | Optional | Required | Required |
| **Git Tracked** | ❌ No | ❌ No | ❌ No | ❌ No |

## 🔒 Security Checklist

### Local Development ✅
- [ ] Copied `.env.local.example` to `.env.local`
- [ ] Using development-only credentials
- [ ] `.env.local` is in `.gitignore`

### Development Cluster ⚠️
- [ ] Copied `.env.dev.example` to `.env.dev`
- [ ] Transitioning to Kubernetes secrets
- [ ] `.env.dev` is in `.gitignore`
- [ ] CORS restricted to known origins

### UAT/Staging 🔐
- [ ] Copied `.env.uat.example` to `.env.uat`
- [ ] **ALL credentials in Kubernetes secrets**
- [ ] `.env.uat` is in `.gitignore`
- [ ] Production-like configuration
- [ ] Secrets verified: `kubectl get secrets -n <Namespace>`

### Production 🔐🔐🔐
- [ ] Copied `.env.prod.example` to `.env.prod`
- [ ] **ALL credentials in Kubernetes secrets**
- [ ] `.env.prod` is in `.gitignore`
- [ ] Semantic versioning: `APP_VERSION=1.2.3`
- [ ] Error-only logging
- [ ] CORS limited to production origin
- [ ] Rate limiting enabled
- [ ] Health checks configured
- [ ] Secrets audited and rotated
- [ ] Rollback plan documented

## 🔑 Kubernetes Secrets Cheat Sheet

### Create Secrets

```bash
# Database
kubectl create secret generic dam-plugin-db \
  --from-literal=DB_USER=<db-username> \
  --from-literal=DB_PASSWORD='<db-password>' \
  -n <Namespace>

# API Keys
kubectl create secret generic dam-plugin-api \
  --from-literal=API_KEY='<api-key>' \
  --from-literal=JWT_SECRET='<jwt-secret-min-32-chars>' \
  --from-literal=DAM_API_KEY='<dam-api-key>' \
  -n <Namespace>

# External Services
kubectl create secret generic dam-plugin-external \
  --from-literal=EXTERNAL_API_KEY='<external-api-key>' \
  --from-literal=REDIS_PASSWORD='<redis-password>' \
  -n <Namespace>
```

### Manage Secrets

```bash
# List secrets
kubectl get secrets -n <Namespace>

# View secret details (not values)
kubectl describe secret <ApiSecretName> -n <Namespace>

# View secret values (base64)
kubectl get secret <ApiSecretName> -n <Namespace> -o yaml

# Decode a value
kubectl get secret <ApiSecretName> -n <Namespace> \
  -o jsonpath='{.data.API_KEY}' | base64 -d

# Update secret
kubectl create secret generic dam-plugin-api \
  --from-literal=API_KEY='<new-api-key>' \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart pods to use new secret
kubectl rollout restart deployment/<PluginDeploymentName> -n <Namespace>

# Delete secret
kubectl delete secret <ApiSecretName> -n <Namespace>
```

## 🛠️ Troubleshooting

### Variables not loading?
```bash
# Use 'source' to export to current shell
source scripts/load-env.sh local  # ✅ Correct
./scripts/load-env.sh local        # ❌ Won't work

# Verify file exists
ls -la .env.local

# Check file content
head .env.local
```

### Pod can't find secret?
```bash
# Verify secret exists
kubectl get secret <ApiSecretName> -n <Namespace>

# Check deployment references correct secret
kubectl describe deployment <PluginDeploymentName> -n <Namespace> | grep -A 5 secret

# Verify secret name matches in Helm values
grep -r "secretName" helm/
```

### Database connection failing?
```bash
# Check database service
kubectl get svc -n <Namespace> | grep <PostgresServiceName>

# Verify DB credentials in secret
kubectl get secret <DbSecretName> -n <Namespace> -o yaml

# Test connection from pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -n <Namespace> -- \
  psql -h <DbHost> -U <DbUser>
```

### CORS errors?
```bash
# Check CORS setting
source scripts/load-env.sh prod
echo $CORS_ORIGIN

# Must match DX server URL exactly
CORS_ORIGIN=https://<dx-hostname>  # ✅
CORS_ORIGIN=*                            # ❌ Not for production

# Restart after changing
kubectl rollout restart deployment/<PluginDeploymentName> -n <Namespace>
```

## 📝 Common Patterns

### Running Locally with Docker Compose

```bash
# Load local environment
source scripts/load-env.sh local

# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f dam-plugin

# Stop services
docker-compose down
```

### Building and Deploying

```bash
# Load target environment
source scripts/load-env.sh prod

# Build Docker image
./scripts/build.sh

# Deploy to cluster
./scripts/deploy.sh prod

# Watch rollout
kubectl rollout status deployment/<PluginDeploymentName> -n <Namespace>

# Check logs
kubectl logs -f deployment/<PluginDeploymentName> -n <Namespace>
```

### Testing API

```bash
# Local
curl http://localhost:3000/health

# Development cluster
curl https://<dx-dev-hostname>/api/dam-plugin/health

# Production
curl https://<dx-hostname>/api/dam-plugin/health
```

## 📚 Related Documentation

- [ENVIRONMENT_SETUP.md](./ENVIRONMENT_SETUP.md) - Complete setup guide
- [README.md](../README.md) - Project overview
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment details
- [.env.example](../.env.example) - All available variables

## ⚠️ Remember

1. **Never commit actual credentials** - Only `.env.*.example` files are tracked
2. **Use secrets for UAT/Prod** - Required for security
3. **Test in lower environments first** - Local → Dev → UAT → Prod
4. **Rotate secrets regularly** - Quarterly minimum
5. **Different credentials per environment** - Never reuse production credentials

---

**Quick Help:**
- Need help? Check [ENVIRONMENT_SETUP.md](./ENVIRONMENT_SETUP.md) for detailed guide
- Can't find a variable? See [.env.example](../.env.example) for all options
- Secret issues? See Kubernetes Secrets Cheat Sheet above
