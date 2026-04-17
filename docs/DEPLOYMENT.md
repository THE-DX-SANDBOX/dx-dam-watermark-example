# Deployment Guide

## Overview

This guide covers deploying the DAM plugin to various environments including Docker, Docker Compose, and Kubernetes.

## Prerequisites

- Docker 20.10+
- Kubernetes 1.24+ (for K8s deployment)
- kubectl configured
- Node.js 20+ (for local development)

---

## Local Development

### Quick Start

1. **Install dependencies:**
```bash
npm install
cd packages/server-v1 && npm install
```

2. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Start development server:**
```bash
npm run dev
```

4. **Access the application:**
- API: http://localhost:3000
- Swagger UI: http://localhost:3000/explorer

---

## Docker Deployment

### Build Image

```bash
# Using build script
chmod +x scripts/build.sh
./scripts/build.sh

# Or manually
docker build -t dam-plugin:latest ./packages
```

### Run Container

```bash
docker run -d \
  --name dam-plugin \
  -p 3000:3000 \
  -e API_KEY=<api-key> \
  -e LOG_LEVEL=info \
  dam-plugin:latest
```

### Test Container

```bash
# Health check
curl http://localhost:3000/health

# Plugin info
curl http://localhost:3000/api/v1/info
```

---

## Docker Compose Deployment

### Start Services

```bash
cd packages
docker-compose up -d
```

### View Logs

```bash
docker-compose logs -f dam-plugin
```

### Stop Services

```bash
docker-compose down
```

### Production Compose

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'
services:
  dam-plugin:
    image: your-registry.com/dam-plugin:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=warn
    env_file:
      - .env.production
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

---

## Kubernetes Deployment

### Prerequisites

1. **Configure kubectl:**
```bash
kubectl config current-context
kubectl get nodes
```

2. **Create namespace:**
```bash
kubectl create namespace dam-plugins
```

### Using Deployment Script

```bash
# Initialize plugin
chmod +x scripts/init-plugin.sh
./scripts/init-plugin.sh

# Build and push image
export DOCKER_REGISTRY=your-registry.com
./scripts/build.sh
docker push <registry-host>/dam-plugin:latest

# Deploy to Kubernetes
chmod +x scripts/deploy.sh
./scripts/deploy.sh production dam-plugins
```

### Manual Deployment

1. **Create secrets:**
```bash
kubectl create secret generic dam-plugin-secrets \
  --from-literal=API_KEY=<api-key> \
  -n dam-plugins
```

2. **Update ConfigMap:**
```bash
# Edit kubernetes/configmap.yaml with your values
kubectl apply -f kubernetes/configmap.yaml -n dam-plugins
```

3. **Update Deployment image:**
```bash
# Edit kubernetes/deployment.yaml
# Update: image: your-registry.com/dam-plugin:latest
```

4. **Apply manifests:**
```bash
kubectl apply -f kubernetes/deployment.yaml -n dam-plugins
kubectl apply -f kubernetes/service.yaml -n dam-plugins
```

5. **Verify deployment:**
```bash
kubectl get pods -n dam-plugins
kubectl get svc -n dam-plugins
```

### Expose Service

**NodePort (Development):**
```bash
kubectl apply -f kubernetes/service.yaml -n dam-plugins
# Access via: http://<node-ip>:30300
```

**Ingress (Production):**
```bash
# Edit kubernetes/ingress.yaml with your domain
kubectl apply -f kubernetes/ingress.yaml -n dam-plugins
```

### Auto-scaling

```bash
kubectl apply -f kubernetes/hpa.yaml -n dam-plugins
kubectl get hpa -n dam-plugins
```

---

## Environment Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PORT` | Server port | `3000` |
| `HOST` | Server host | `0.0.0.0` |
| `NODE_ENV` | Environment | `production` |
| `API_KEY` | Authentication key | `secure-random-key` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `LOG_LEVEL` | Logging level | `info` |
| `MAX_FILE_SIZE` | Max upload size (bytes) | `104857600` (100MB) |
| `EXTERNAL_API_URL` | External service URL | - |
| `EXTERNAL_API_KEY` | External service key | - |

### Kubernetes Secrets

```bash
# Create from file
kubectl create secret generic dam-plugin-secrets \
  --from-file=api-key=./secrets/api-key.txt \
  --from-file=external-api-key=./secrets/external-api-key.txt \
  -n dam-plugins

# Create from literal
kubectl create secret generic dam-plugin-secrets \
  --from-literal=API_KEY=<api-key> \
  --from-literal=EXTERNAL_API_KEY=<external-api-key> \
  -n dam-plugins
```

---

## Monitoring & Logging

### View Logs

**Docker:**
```bash
docker logs -f dam-plugin
```

**Kubernetes:**
```bash
# Current logs
kubectl logs -f deployment/dam-plugin -n dam-plugins

# Previous logs (if pod crashed)
kubectl logs deployment/dam-plugin --previous -n dam-plugins

# All pods
kubectl logs -l app=dam-plugin -n dam-plugins --tail=100
```

### Port Forwarding

```bash
# Forward local port to pod
kubectl port-forward svc/dam-plugin 3000:80 -n dam-plugins

# Access at: http://localhost:3000
```

### Prometheus Metrics

The plugin exposes metrics at `/metrics`:

```bash
curl http://localhost:3000/metrics
```

### Log Aggregation

Configure log forwarding to your logging system:

**Fluentd/Fluent Bit:**
```yaml
# Add to deployment
annotations:
  fluentbit.io/parser: json
```

**CloudWatch/Stackdriver:**
```yaml
# Use appropriate DaemonSet for log collection
```

---

## Scaling

### Manual Scaling

```bash
# Scale to 5 replicas
kubectl scale deployment dam-plugin --replicas=5 -n dam-plugins

# Verify
kubectl get pods -n dam-plugins
```

### Auto-scaling (HPA)

```bash
# Apply HPA
kubectl apply -f kubernetes/hpa.yaml -n dam-plugins

# Monitor
kubectl get hpa -n dam-plugins -w

# Describe
kubectl describe hpa dam-plugin -n dam-plugins
```

### Vertical Scaling

Update resource limits in [deployment.yaml](../kubernetes/deployment.yaml):

```yaml
resources:
  requests:
    cpu: 200m      # Increased from 100m
    memory: 512Mi  # Increased from 256Mi
  limits:
    cpu: 1000m     # Increased from 500m
    memory: 1Gi    # Increased from 512Mi
```

---

## Updates & Rollbacks

### Rolling Update

```bash
# Update image
kubectl set image deployment/dam-plugin \
  dam-plugin=your-registry.com/dam-plugin:v1.1.0 \
  -n dam-plugins

# Monitor rollout
kubectl rollout status deployment/dam-plugin -n dam-plugins
```

### Rollback

```bash
# View history
kubectl rollout history deployment/dam-plugin -n dam-plugins

# Rollback to previous version
kubectl rollout undo deployment/dam-plugin -n dam-plugins

# Rollback to specific revision
kubectl rollout undo deployment/dam-plugin --to-revision=2 -n dam-plugins
```

---

## Security

### Network Policies

Create network policy to restrict traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dam-plugin-network-policy
  namespace: dam-plugins
spec:
  podSelector:
    matchLabels:
      app: dam-plugin
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: dam-system
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443  # HTTPS
```

### Pod Security

```yaml
# Add to deployment spec
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 1001
  seccompProfile:
    type: RuntimeDefault
containers:
- name: dam-plugin
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
```

---

## Backup & Disaster Recovery

### Configuration Backup

```bash
# Backup all resources
kubectl get all,cm,secrets -n dam-plugins -o yaml > backup.yaml

# Backup specific resources
kubectl get deployment dam-plugin -n dam-plugins -o yaml > deployment-backup.yaml
kubectl get cm dam-plugin-config -n dam-plugins -o yaml > config-backup.yaml
```

### Restore

```bash
kubectl apply -f backup.yaml -n dam-plugins
```

---

## Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n dam-plugins

# Check events
kubectl get events -n dam-plugins --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name> -n dam-plugins
```

### Service not accessible

```bash
# Check service
kubectl get svc dam-plugin -n dam-plugins
kubectl describe svc dam-plugin -n dam-plugins

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://dam-plugin.dam-plugins.svc.cluster.local/health
```

### Image pull errors

```bash
# Check image pull secrets
kubectl get secrets -n dam-plugins

# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry-host> \
  --docker-username=<registry-username> \
  --docker-password=<registry-password> \
  -n dam-plugins

# Add to deployment
spec:
  imagePullSecrets:
  - name: regcred
```

---

## Production Checklist

- [ ] Configure proper resource limits
- [ ] Set up auto-scaling (HPA)
- [ ] Configure ingress with TLS
- [ ] Set up monitoring and alerts
- [ ] Configure log aggregation
- [ ] Implement backup strategy
- [ ] Set up network policies
- [ ] Configure pod security policies
- [ ] Set up CI/CD pipeline
- [ ] Document runbooks
- [ ] Test disaster recovery
- [ ] Configure rate limiting
- [ ] Set up health checks
- [ ] Implement graceful shutdown

---

## Next Steps

- [API Reference](API.md)
- [Development Guide](DEVELOPMENT.md)
- [Plugin Registration](REGISTRATION.md)
