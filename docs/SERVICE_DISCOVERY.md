# HAProxy Service Discovery

## Overview

The DAM Plugin automatically discovers the HAProxy service for DAM registration using Kubernetes service discovery mechanisms. This eliminates the need to hardcode URLs and makes deployment more flexible.

## How It Works

The plugin uses multiple discovery methods in this order:

### 1. **Kubernetes DNS Resolution** (Preferred)

```bash
# Tries to resolve HAProxy service via DNS
nslookup <HAProxyServiceDNS>
```

If successful, uses: `http://<HAProxyServiceDNS>:<HAProxyPort>`

### 2. **Health Check Validation**

```bash
# Verifies HAProxy is reachable
curl http://<HAProxyServiceDNS>:<HAProxyPort>/health
```

### 3. **Kubernetes API Query**

If DNS fails, queries the Kubernetes API directly:

```bash
# Uses service account token to query K8s API
curl https://kubernetes.default.svc/api/v1/namespaces/dx-haproxy/services/dx-haproxy
```

Returns the ClusterIP and constructs the URL.

### 4. **Common Name Fallback**

Tries common HAProxy service naming patterns:
- `dx-haproxy.dx-haproxy`
- `haproxy.dx-haproxy`
- `dx-sm-haproxy.dx-haproxy`
- `dx-custom-haproxy.dx-haproxy`

### 5. **Manual Configuration**

Falls back to environment variable if set:
```bash
export HAPROXY_URL="http://my-haproxy:80"
```

## Configuration

### Enable Service Discovery (Default)

```yaml
# values.yaml
serviceDiscovery:
  enabled: true
  haproxyNamespace: "dx-haproxy"
  haproxyServiceName: "dx-haproxy"
  haproxyPort: "80"
  damPath: "/dx/api/dam"
```

### Manual Configuration

```yaml
# values.yaml
serviceDiscovery:
  enabled: false

dam:
  url: "http://<DamServiceDNS>:<DamPort>"
```

### Hybrid Approach

Use discovery but provide fallback:

```yaml
# values.yaml
serviceDiscovery:
  enabled: true
  haproxyUrl: "http://backup-haproxy:80"  # Fallback
  damPath: "/dx/api/dam"
```

## RBAC Permissions

Service discovery requires permissions to query Kubernetes API:

```yaml
# Automatically created by Helm
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dam-plugin-discovery
  namespace: dx-haproxy
rules:
- apiGroups: [""]
  resources: ["services", "endpoints"]
  verbs: ["get", "list", "watch"]
```

The plugin's ServiceAccount is bound to this role to enable cross-namespace service queries.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HAPROXY_NAMESPACE` | Namespace where HAProxy is deployed | `dx-haproxy` |
| `HAPROXY_SERVICE_NAME` | HAProxy service name | `dx-haproxy` |
| `HAPROXY_PORT` | HAProxy service port | `80` |
| `HAPROXY_URL` | Manual HAProxy URL (overrides discovery) | - |
| `DAM_PATH` | DAM API path after HAProxy | `/dx/api/dam` |
| `DAM_URL` | Full DAM URL (overrides all discovery) | - |

## URL Construction

After discovering HAProxy, the plugin constructs the DAM URL:

```
HAProxy Endpoint + DAM Path = DAM URL
http://dx-haproxy.dx-haproxy:80 + /dx/api/dam = http://dx-haproxy.dx-haproxy:80/dx/api/dam
```

## Deployment Examples

### Production with Auto-Discovery

```bash
helm install dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins \
    --set serviceDiscovery.enabled=true \
    --set serviceDiscovery.haproxyNamespace="dx-haproxy" \
    --set serviceDiscovery.haproxyServiceName="dx-haproxy"
```

### Development with Manual URL

```bash
helm install dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins-dev \
    --set serviceDiscovery.enabled=false \
    --set dam.url="https://dam-dev.example.com/api"
```

### Custom HAProxy Configuration

```bash
helm install dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins \
    --set serviceDiscovery.haproxyNamespace="custom-namespace" \
    --set serviceDiscovery.haproxyServiceName="my-haproxy" \
    --set serviceDiscovery.haproxyPort="8080" \
    --set serviceDiscovery.damPath="/api/v2/dam"
```

## Verification

### Check Discovery Logs

```bash
kubectl logs -n dam-plugins -l app.kubernetes.io/name=dam-plugin | grep "Discovering HAProxy"
```

Expected output:
```
=== Discovering HAProxy Service ===
Looking for: dx-haproxy in namespace: dx-haproxy
✅ Found HAProxy via DNS: <HAProxyServiceDNS>
```

### Test DNS Resolution

```bash
kubectl exec -it -n <Namespace> deployment/<PluginDeploymentName> -- nslookup <HAProxyServiceDNS>
```

### Test HAProxy Connectivity

```bash
kubectl exec -it -n dam-plugins deployment/dam-plugin -- \
    curl -v http://dx-haproxy.dx-haproxy:80/health
```

### Manual Discovery Test

```bash
kubectl exec -it -n dam-plugins deployment/dam-plugin -- \
    /usr/local/bin/register-with-dam.sh
```

## Troubleshooting

### Discovery Fails

**Symptom**: Log shows "Could not discover HAProxy service"

**Solutions**:

1. **Check HAProxy is deployed**:
```bash
kubectl get svc -n dx-haproxy
```

2. **Verify service name matches**:
```bash
# Update values if needed
--set serviceDiscovery.haproxyServiceName="actual-service-name"
```

3. **Check RBAC permissions**:
```bash
kubectl get role -n dx-haproxy dam-plugin-discovery
kubectl get rolebinding -n dx-haproxy dam-plugin-discovery
```

4. **Test DNS manually**:
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
    nslookup <HAProxyServiceDNS>
```

### RBAC Permission Denied

**Symptom**: "Forbidden: User cannot get services in namespace"

**Solution**: Ensure RBAC resources are created:

```bash
kubectl get role -n dx-haproxy
kubectl get rolebinding -n dx-haproxy

# Recreate if missing
helm upgrade dam-plugin ./helm/dam-plugin \
    --namespace dam-plugins \
    --set serviceDiscovery.enabled=true
```

### Wrong HAProxy Found

**Symptom**: Plugin connects to wrong HAProxy instance

**Solution**: Use explicit configuration:

```bash
helm upgrade dam-plugin ./helm/dam-plugin \
    --set serviceDiscovery.haproxyNamespace="correct-namespace" \
    --set serviceDiscovery.haproxyServiceName="correct-service"
```

### Network Policy Blocking

**Symptom**: "Connection refused" or timeout

**Solution**: Update Network Policy to allow HAProxy namespace:

```yaml
# values.yaml
networkPolicy:
  enabled: true
  allowedNamespaces:
    - dx-dam
    - dx-haproxy  # Add HAProxy namespace
```

## Architecture Diagram

```
┌─────────────────────────────────┐
│   DAM Plugin Pod                │
│   (dam-plugins namespace)       │
├─────────────────────────────────┤
│                                 │
│  1. DNS Query                   │
│     ↓                           │
│  2. K8s API Query (if needed)   │
│     ↓                           │
│  3. Health Check Validation     │
│     ↓                           │
│  4. Construct DAM URL           │
│                                 │
└──────────────┬──────────────────┘
               │
               │ Discovers
               ↓
┌─────────────────────────────────┐
│   HAProxy Service               │
│   (dx-haproxy namespace)        │
├─────────────────────────────────┤
│  Type: ClusterIP               │
│  Port: 80                      │
│  DNS: dx-haproxy.dx-haproxy    │
└──────────────┬──────────────────┘
               │
               │ Routes to
               ↓
┌─────────────────────────────────┐
│   DX DAM Service                │
│   (dx-dam namespace)            │
├─────────────────────────────────┤
│  Endpoint: /dx/api/dam         │
│  Registration API               │
└─────────────────────────────────┘
```

## Benefits

1. **No Hardcoded URLs** - Works across different clusters
2. **Automatic Updates** - Adapts if HAProxy service changes
3. **Multiple Fallbacks** - Robust discovery mechanism
4. **Cross-Namespace** - Can discover services in other namespaces
5. **Manual Override** - Can still use explicit configuration
6. **Self-Healing** - Re-discovers on pod restart

## Security Considerations

- RBAC limits permissions to only `get`, `list`, `watch` on services
- Cross-namespace access is explicit (only HAProxy namespace)
- Service account token is securely mounted by Kubernetes
- Network policies still control actual network communication
- Discovery happens at startup, not during request processing

## Advanced Configuration

### Multiple HAProxy Instances

```yaml
# Try primary first, fallback to secondary
serviceDiscovery:
  enabled: true
  haproxyServiceName: "primary-haproxy"
  haproxyUrl: "http://secondary-haproxy.backup:80"  # Fallback
```

### Custom Discovery Script

You can extend the discovery logic in `scripts/register-with-dam.sh`:

```bash
# Add custom discovery logic
discover_custom_haproxy() {
    # Your custom logic here
    # Query external DNS, consul, etc.
    echo "http://custom-discovered-url:80"
}
```

### Service Mesh Integration

If using Istio/Linkerd, discovery works seamlessly:

```yaml
serviceDiscovery:
  enabled: true
  haproxyServiceName: "<HAProxyServiceDNS>"
  # Service mesh handles routing automatically
```

## Summary

HAProxy service discovery provides a flexible, automated way to locate the DAM API endpoint through HAProxy without manual configuration. The multi-method approach ensures reliability across different cluster configurations while maintaining security through RBAC and network policies.
