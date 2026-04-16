# DAM Plugin Deployment Guide

## Quick Start

Deploy the plugin with auto-registration in one command:

```bash
# Set your configuration
export REGISTRY="us-central1-docker.pkg.dev/your-project/dam-plugins"
export DAM_URL="http://<DamServiceDNS>:<DamPort>"
export DAM_ADMIN_TOKEN="your-admin-token"

# Build, push, and deploy
./scripts/build-and-deploy.sh
```

## Prerequisites

- Docker installed and configured
- kubectl configured with cluster access
- Helm 3.x installed
- Access to a container registry
- DX DAM deployed in Kubernetes

## Step-by-Step Deployment

### 1. Build the Docker Image

```bash
cd packages
docker build \
    --platform linux/amd64 \
    -t your-registry/dam-plugin:latest \
    -f Dockerfile \
    .
```

### 2. Push to Registry

```bash
docker push your-registry/dam-plugin:latest
```

### 3. Deploy with Helm

#### Production Deployment (Internal ClusterIP)

```bash
helm install dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins \
    --create-namespace \
    --set image.repository=your-registry/dam-plugin \
    --set image.tag=latest \
    --set dam.url="http://<DamServiceDNS>:<DamPort>" \
    --set dam.adminToken="your-admin-token" \
    --set plugin.autoRegister=true \
    -f helm/dam-plugin/values-prod.yaml
```

#### Development Deployment (With Ingress)

```bash
helm install dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins-dev \
    --create-namespace \
    --set image.repository=your-registry/dam-plugin \
    --set image.tag=latest \
    --set dam.url="https://dam-dev.example.com" \
    --set dam.adminToken="your-admin-token" \
    --set ingress.enabled=true \
    --set ingress.hosts[0].host="plugin-dev.example.com"
```

## Configuration

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DAM_URL` | Internal cluster URL for DAM | `http://<DamServiceDNS>:<DamPort>` |
| `DAM_ADMIN_TOKEN` | Admin token for registration | `your-secret-token` |
| `PLUGIN_NAME` | Unique plugin identifier | `dam-vision-plugin` |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTO_REGISTER` | Enable auto-registration | `true` |
| `LOG_LEVEL` | Logging level | `info` |
| `EXTERNAL_API_KEY` | External service API key | - |

## Verify Deployment

### Check Pod Status

```bash
kubectl get pods -n dam-plugins -l app.kubernetes.io/name=dam-plugin
```

### View Logs

```bash
# All pods
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin --tail=100

# Specific pod
kubectl logs -n dam-plugins <pod-name> -f
```

### Check Registration

```bash
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin | grep -A 10 "Registration"
```

### Test Health Endpoint

```bash
# Port forward
kubectl port-forward -n dam-plugins svc/dam-plugin 3000:3000

# Test in another terminal
curl http://localhost:3000/health
curl http://localhost:3000/api/v1/info
```

## Network Architecture

### Internal Cluster Communication (Recommended)

```
┌─────────────────────┐
│   DX DAM            │
│   (dx-dam namespace)│
└──────────┬──────────┘
           │
           │ ClusterIP Service
           │ http://dam-plugin.dam-plugins:3000
           │
┌──────────▼──────────┐
│   DAM Plugin        │
│   (dam-plugins ns)  │
└─────────────────────┘
```

**Advantages:**
- ✅ No external exposure
- ✅ Lower latency
- ✅ No TLS overhead
- ✅ Network Policy control
- ✅ No load balancer costs

### Service DNS Names

Within the cluster, the plugin is accessible via:

- **Full DNS**: `http://dam-plugin.dam-plugins.svc.cluster.local:3000`
- **Short DNS**: `http://dam-plugin.dam-plugins:3000`
- **Same namespace**: `http://dam-plugin:3000` (if DAM is in same namespace)

## Auto-Registration

The plugin automatically registers with DX DAM on startup:

1. **Plugin starts** and waits to be healthy
2. **Fetches plugin info** from `/api/v1/info` endpoint
3. **Checks if already registered** with DAM
4. **Registers or updates** plugin configuration
5. **Ready to process** assets from DAM

### Registration Payload

The plugin sends this configuration to DAM:

```json
{
  "name": "dam-vision-plugin",
  "displayName": "DAM Vision Plugin",
  "version": "1.0.0",
  "enabled": true,
  "apiConfig": {
    "baseUrl": "http://dam-plugin.dam-plugins:3000",
    "apiVersion": "v1",
    "healthCheckPath": "/health",
    "processEndpoint": "/api/v1/process"
  },
  "authentication": {
    "type": "apiKey",
    "headerName": "X-API-Key"
  },
  "fileConfig": {
    "supportedMimeTypes": ["image/jpeg", "image/png"],
    "maxFileSizeMB": 100
  }
}
```

## Manual Registration

If auto-registration fails, you can manually register:

```bash
# Exec into a pod
kubectl exec -it -n dam-plugins deployment/dam-plugin -- /bin/bash

# Run registration script
/usr/local/bin/register-with-dam.sh
```

## Scaling

### Manual Scaling

```bash
kubectl scale deployment/dam-plugin -n dam-plugins --replicas=5
```

### Horizontal Pod Autoscaler

Already configured in `values.yaml`:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

View HPA status:

```bash
kubectl get hpa -n dam-plugins
```

## Updates

### Update Image

```bash
# Build new version
docker build -t your-registry/dam-plugin:v2.0.0 .
docker push your-registry/dam-plugin:v2.0.0

# Update deployment
helm upgrade dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins \
    --set image.tag=v2.0.0 \
    --reuse-values
```

### Rolling Update

```bash
kubectl rollout restart deployment/dam-plugin -n dam-plugins
kubectl rollout status deployment/dam-plugin -n dam-plugins
```

## Troubleshooting

### Plugin Not Registering

1. Check logs for registration errors:
```bash
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin | grep -i error
```

2. Verify DAM URL is accessible:
```bash
kubectl exec -it -n dam-plugins deployment/dam-plugin -- curl -v $DAM_URL/health
```

3. Check admin token is correct:
```bash
kubectl get secret -n dam-plugins dam-plugin -o jsonpath='{.data.damAdminToken}' | base64 -d
```

### Connection Refused

1. Check Network Policy:
```bash
kubectl get networkpolicy -n dam-plugins
```

2. Verify service exists:
```bash
kubectl get svc -n dam-plugins dam-plugin
```

3. Test connectivity:
```bash
kubectl run -it --rm debug \
    --image=curlimages/curl \
    --namespace=dx-dam \
    -- curl http://dam-plugin.dam-plugins:3000/health
```

### Plugin Not Processing Images

1. Check DAM can reach plugin:
```bash
kubectl logs -n dx-dam -l app=dx-dam | grep dam-plugin
```

2. Verify workflow is configured in DAM

3. Check plugin logs for incoming requests:
```bash
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin -f
```

## Uninstall

```bash
helm uninstall dam-plugin -n dam-plugins
kubectl delete namespace dam-plugins
```

## Security Best Practices

1. **Use ClusterIP** for internal services
2. **Enable Network Policy** to restrict access
3. **Rotate API keys** regularly
4. **Use secrets** for sensitive data
5. **Enable Pod Security Standards**
6. **Limit resources** to prevent resource exhaustion
7. **Use non-root user** in containers (already configured)
8. **Keep images updated** for security patches

## Production Checklist

- [ ] Docker image built and pushed to registry
- [ ] Helm values configured for production
- [ ] DAM URL set to internal cluster service
- [ ] Admin token stored securely
- [ ] Network Policy enabled
- [ ] Resource limits configured
- [ ] HPA enabled and tested
- [ ] Health checks passing
- [ ] Auto-registration successful
- [ ] Test image processed successfully
- [ ] Monitoring and logging configured
- [ ] Backup and disaster recovery plan

## Support

For issues or questions:
- Check logs: `kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin`
- Review documentation in `docs/` directory
- Check plugin health: `curl http://localhost:3000/health`
- Verify DAM connectivity: See troubleshooting section
