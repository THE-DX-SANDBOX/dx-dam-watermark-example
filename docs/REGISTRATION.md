# Plugin Registration Guide

## Overview

This guide explains how to register your DAM plugin with HCL Digital Asset Management (DAM) system.

## Prerequisites

- DAM plugin deployed and accessible
- DAM admin credentials
- Plugin endpoint URL
- API key configured

---

## Registration Process

### Step 1: Verify Plugin Deployment

Before registering, ensure your plugin is running and accessible:

```bash
# Test health endpoint
curl http://your-plugin-host:3000/health

# Expected response:
# {"status":"ok","timestamp":"2024-01-15T10:30:00.000Z"}

# Test info endpoint
curl http://your-plugin-host:3000/api/v1/info

# Expected response with plugin metadata
```

### Step 2: Gather Plugin Information

Collect the following information from your plugin:

```bash
# Get plugin configuration
cat plugin-config.json
```

Required information:
- **Plugin Name**: Unique identifier
- **Plugin Display Name**: User-friendly name
- **Plugin Version**: Semantic version
- **Plugin URL**: Base URL (e.g., `https://<plugin-hostname>`)
- **API Version**: API version (e.g., `v1`)
- **API Key**: Authentication key
- **Supported File Types**: MIME types
- **Max File Size**: In megabytes

### Step 3: Access DAM Admin Console

1. **Login to HCL DAM:**
```
https://your-dam-instance.com/admin
```

2. **Navigate to Plugins:**
```
Admin → Configuration → Plugins → Add New Plugin
```

### Step 4: Configure Plugin Registration

#### Using DAM UI

Fill in the plugin registration form:

**Basic Information:**
```
Name: my-vision-plugin
Display Name: My Vision Plugin
Description: Custom vision analysis for digital assets
Version: 1.0.0
Status: Enabled
```

**API Configuration:**
```
Base URL: <plugin-base-url>
API Version: v1
Health Check Path: /health
Info Endpoint: /api/v1/info
Process Endpoint: /api/v1/process
```

**Authentication:**
```
Authentication Type: API Key
Header Name: X-API-Key
API Key: <api-key>
```

**File Configuration:**
```
Supported MIME Types:
  - image/jpeg
  - image/png
  - image/gif
  - image/webp

Max File Size (MB): 100
Processing Timeout (seconds): 30
```

**Callback Configuration:**
```
Callback Required: Yes
Callback Timeout (seconds): 10
Retry on Failure: Yes
Max Retries: 3
Retry Delay (seconds): 5
```

#### Using DAM REST API

Register plugin via API:

```bash
curl -X POST https://<dam-hostname>/api/admin/plugins \
  -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "<plugin-name>",
    "displayName": "<plugin-display-name>",
    "description": "<plugin-description>",
    "version": "1.0.0",
    "enabled": true,
    "apiConfig": {
      "baseUrl": "<plugin-base-url>",
      "apiVersion": "v1",
      "healthCheckPath": "/health",
      "infoEndpoint": "/api/v1/info",
      "processEndpoint": "/api/v1/process"
    },
    "authentication": {
      "type": "apiKey",
      "headerName": "X-API-Key",
      "apiKey": "<api-key>"
    },
    "fileConfig": {
      "supportedMimeTypes": [
        "image/jpeg",
        "image/png",
        "image/gif",
        "image/webp"
      ],
      "maxFileSizeMB": 100,
      "processingTimeoutSeconds": 30
    },
    "callbackConfig": {
      "required": true,
      "timeoutSeconds": 10,
      "retryOnFailure": true,
      "maxRetries": 3,
      "retryDelaySeconds": 5
    }
  }'
```

#### Using Configuration File

Create `dam-plugin-registration.json`:

```json
{
  "plugin": {
    "name": "<plugin-name>",
    "displayName": "<plugin-display-name>",
    "description": "<plugin-description>",
    "version": "1.0.0",
    "enabled": true,
    "apiConfig": {
      "baseUrl": "https://<plugin-hostname>",
      "apiVersion": "v1",
      "endpoints": {
        "health": "/health",
        "info": "/api/v1/info",
        "process": "/api/v1/process"
      },
      "authentication": {
        "type": "apiKey",
        "headerName": "X-API-Key",
        "apiKey": "${API_KEY}"
      }
    },
    "capabilities": {
      "supportedFileTypes": [
        "image/jpeg",
        "image/png",
        "image/gif",
        "image/webp"
      ],
      "maxFileSizeMB": 100,
      "asyncProcessing": true,
      "callbackRequired": true,
      "features": [
        "tagging",
        "metadata-extraction",
        "content-analysis"
      ]
    },
    "settings": {
      "processingTimeoutSeconds": 30,
      "callbackTimeoutSeconds": 10,
      "retryPolicy": {
        "enabled": true,
        "maxRetries": 3,
        "retryDelaySeconds": 5,
        "backoffMultiplier": 2
      }
    }
  }
}
```

Import configuration:

```bash
# Using DAM CLI
dam-cli plugin import -f dam-plugin-registration.json

# Using API
curl -X POST https://your-dam-instance.com/api/admin/plugins/import \
  -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @dam-plugin-registration.json
```

---

## Workflow Integration

### Step 5: Create Asset Processing Workflow

#### Option A: Automatic Processing

Configure DAM to automatically process assets on upload:

```javascript
// DAM Workflow Configuration
{
  "workflow": {
    "name": "auto-vision-analysis",
    "trigger": "asset.uploaded",
    "conditions": {
      "fileType": ["image/jpeg", "image/png", "image/gif"],
      "maxSize": 104857600
    },
    "actions": [
      {
        "type": "plugin.process",
        "plugin": "my-vision-plugin",
        "config": {
          "options": {
            "quality": 0.85,
            "maxTags": 10,
            "language": "en"
          }
        }
      },
      {
        "type": "metadata.update",
        "source": "plugin.results",
        "fields": {
          "tags": "results.tags",
          "metadata": "results.metadata"
        }
      }
    ]
  }
}
```

#### Option B: Manual Processing

Allow users to trigger processing manually:

```javascript
// DAM UI Configuration
{
  "assetActions": {
    "customActions": [
      {
        "id": "analyze-with-vision",
        "label": "Analyze with Vision AI",
        "plugin": "my-vision-plugin",
        "icon": "eye",
        "confirmMessage": "Analyze this asset with Vision AI?",
        "fileTypes": ["image/jpeg", "image/png", "image/gif"]
      }
    ]
  }
}
```

### Step 6: Configure Callback Handling

DAM must be configured to receive and process callbacks:

```javascript
// DAM Callback Handler Configuration
{
  "callbacks": {
    "my-vision-plugin": {
      "endpoint": "/webhooks/plugins/my-vision-plugin",
      "authentication": {
        "type": "hmac",
        "secret": "${CALLBACK_SECRET}"
      },
      "handlers": {
        "success": {
          "updateAssetMetadata": true,
          "fields": {
            "tags": "results.tags",
            "aiMetadata": "results.metadata",
            "processingTime": "processingTime"
          },
          "notification": {
            "enabled": true,
            "recipients": ["asset.owner"],
            "template": "plugin-processing-complete"
          }
        },
        "error": {
          "logError": true,
          "notification": {
            "enabled": true,
            "recipients": ["asset.owner", "admin"],
            "template": "plugin-processing-failed"
          }
        }
      }
    }
  }
}
```

---

## Testing Integration

### Test Plugin Registration

1. **Verify Plugin Status:**
```bash
# Check plugin health from DAM
curl -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  https://your-dam-instance.com/api/admin/plugins/my-vision-plugin/status

# Expected response:
{
  "name": "my-vision-plugin",
  "status": "healthy",
  "lastHealthCheck": "2024-01-15T10:30:00.000Z",
  "version": "1.0.0",
  "uptime": "99.9%"
}
```

2. **Test Asset Processing:**
```bash
# Upload test asset
ASSET_ID=$(curl -X POST https://your-dam-instance.com/api/assets \
  -H "Authorization: Bearer ${DAM_TOKEN}" \
  -F "file=@test-image.jpg" \
  | jq -r '.id')

# Trigger plugin processing
curl -X POST https://your-dam-instance.com/api/assets/${ASSET_ID}/process \
  -H "Authorization: Bearer ${DAM_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "plugin": "my-vision-plugin",
    "options": {
      "quality": 0.85,
      "maxTags": 10
    }
  }'

# Check processing status
curl -H "Authorization: Bearer ${DAM_TOKEN}" \
  https://your-dam-instance.com/api/assets/${ASSET_ID}/processing-status
```

3. **Verify Results:**
```bash
# Get asset with updated metadata
curl -H "Authorization: Bearer ${DAM_TOKEN}" \
  https://your-dam-instance.com/api/assets/${ASSET_ID}

# Expected response includes:
{
  "id": "asset-123",
  "filename": "test-image.jpg",
  "metadata": {
    "tags": ["landscape", "mountain", "nature"],
    "aiAnalysis": {
      "plugin": "my-vision-plugin",
      "confidence": 0.92,
      "processedAt": "2024-01-15T10:30:00.000Z"
    }
  }
}
```

---

## Monitoring & Maintenance

### Health Monitoring

DAM should periodically check plugin health:

```javascript
// DAM Health Check Configuration
{
  "healthChecks": {
    "my-vision-plugin": {
      "enabled": true,
      "interval": 60,  // seconds
      "timeout": 5,    // seconds
      "failureThreshold": 3,
      "successThreshold": 1,
      "alerts": {
        "enabled": true,
        "recipients": ["admin@example.com"],
        "channels": ["email", "slack"]
      }
    }
  }
}
```

### Usage Analytics

Track plugin usage in DAM:

```bash
# Get plugin statistics
curl -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  https://your-dam-instance.com/api/admin/plugins/my-vision-plugin/stats

# Response:
{
  "totalProcessed": 15234,
  "successRate": 98.5,
  "averageProcessingTime": 1250,
  "errorRate": 1.5,
  "lastUsed": "2024-01-15T10:30:00.000Z",
  "period": "30d"
}
```

### Log Integration

Configure log forwarding to DAM:

```javascript
// Plugin logging configuration
{
  "logging": {
    "level": "info",
    "destinations": [
      {
        "type": "dam",
        "endpoint": "https://your-dam-instance.com/api/logs",
        "authentication": {
          "type": "bearer",
          "token": "${DAM_LOG_TOKEN}"
        }
      }
    ]
  }
}
```

---

## Updating Plugin

### Version Updates

When updating your plugin:

1. **Deploy new version:**
```bash
# Build and deploy new version
./scripts/build.sh my-vision-plugin v1.1.0
./scripts/deploy.sh production
```

2. **Update registration in DAM:**
```bash
curl -X PATCH https://your-dam-instance.com/api/admin/plugins/my-vision-plugin \
  -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "1.1.0",
    "apiConfig": {
      "baseUrl": "https://<plugin-hostname>"
    }
  }'
```

3. **Test compatibility:**
```bash
# Run integration tests
npm run test:integration

# Test with DAM
curl -X POST https://<dam-hostname>/api/admin/plugins/<plugin-name>/test
```

### Rolling Back

If issues occur:

```bash
# Rollback deployment
kubectl rollout undo deployment/dam-plugin -n dam-plugins

# Revert DAM registration
curl -X PATCH https://<dam-hostname>/api/admin/plugins/<plugin-name> \
  -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"version": "1.0.0"}'
```

---

## Troubleshooting

### Plugin Not Appearing in DAM

**Check registration:**
```bash
curl -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  https://<dam-hostname>/api/admin/plugins
```

**Verify plugin is enabled:**
```bash
curl -X PATCH https://<dam-hostname>/api/admin/plugins/<plugin-name> \
  -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  -d '{"enabled": true}'
```

### Authentication Failures

**Verify API key:**
```bash
# Test authentication
curl -X GET https://<plugin-hostname>/api/v1/info \
  -H "X-API-Key: <api-key>"
```

**Check DAM configuration:**
```bash
curl -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  https://your-dam-instance.com/api/admin/plugins/my-vision-plugin/config
```

### Processing Failures

**Check plugin logs:**
```bash
kubectl logs -f deployment/dam-plugin -n dam-plugins
```

**Verify callback URL:**
```bash
# Ensure DAM callback endpoint is accessible
curl -X POST https://your-dam-instance.com/webhooks/plugins/my-vision-plugin \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

**Review error logs in DAM:**
```bash
curl -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  "https://your-dam-instance.com/api/admin/logs?plugin=my-vision-plugin&level=error"
```

---

## Security Considerations

### API Key Rotation

Regularly rotate API keys:

```bash
# Generate new key
NEW_KEY=$(openssl rand -hex 32)

# Update plugin
kubectl set env deployment/dam-plugin API_KEY=${NEW_KEY} -n dam-plugins

# Update DAM
curl -X PATCH https://your-dam-instance.com/api/admin/plugins/my-vision-plugin \
  -H "Authorization: Bearer ${DAM_ADMIN_TOKEN}" \
  -d "{\"authentication\": {\"apiKey\": \"${NEW_KEY}\"}}"
```

### Network Security

**Restrict access:**
```yaml
# Kubernetes NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dam-plugin-network-policy
spec:
  podSelector:
    matchLabels:
      app: dam-plugin
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: hcl-dam
    ports:
    - port: 3000
```

**Use TLS:**
```bash
# Configure ingress with TLS
kubectl apply -f kubernetes/ingress.yaml
```

---

## Best Practices

1. **Use descriptive plugin names** - Make them easily identifiable
2. **Document capabilities** - Clearly state what your plugin does
3. **Handle errors gracefully** - Provide meaningful error messages
4. **Implement proper logging** - Aid in debugging and monitoring
5. **Version your APIs** - Allow for backward compatibility
6. **Test thoroughly** - Before registering with production DAM
7. **Monitor performance** - Track processing times and success rates
8. **Implement retry logic** - Handle transient failures
9. **Secure credentials** - Use secrets management
10. **Document integration** - Maintain up-to-date documentation

---

## Additional Resources

- [API Documentation](API.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Development Guide](DEVELOPMENT.md)
- HCL DAM Documentation: https://help.hcltechsw.com/digital-asset-management/
- Plugin SDK: https://github.com/HCL-TECH-SOFTWARE/dam-plugin-sdk

---

## Support

For issues or questions:

1. Check plugin logs
2. Review DAM integration logs
3. Consult this documentation
4. Contact HCL Support
5. Open GitHub issue (if using template)

---

## Registration Checklist

- [ ] Plugin deployed and accessible
- [ ] Health endpoint responding
- [ ] API key configured
- [ ] Plugin info accurate
- [ ] Supported file types defined
- [ ] Processing timeout configured
- [ ] Callback handling tested
- [ ] DAM admin access obtained
- [ ] Plugin registered in DAM
- [ ] Workflow integration configured
- [ ] Test asset processed successfully
- [ ] Results received via callback
- [ ] Metadata updated in DAM
- [ ] Health monitoring enabled
- [ ] Error alerting configured
- [ ] Documentation updated
- [ ] Team trained on usage
