# API Reference

## Overview

The DAM Plugin provides a REST API for processing digital assets and integrating with HCL Digital Asset Management (DAM).

**Base URL:** `http://your-plugin-host:3000`

**Authentication:** API Key via `X-API-Key` header

## Endpoints

### Health Check

Check if the service is running and healthy.

**Endpoint:** `GET /health`

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**cURL Example:**
```bash
curl http://localhost:3000/health
```

---

### Process Asset

Process a digital asset file and return results asynchronously via callback.

**Endpoint:** `POST /api/v1/process`

**Authentication:** Required (X-API-Key header)

**Content-Type:** `multipart/form-data`

**Request Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | File | Yes | The asset file to process |
| `callBackURL` | String | Yes | URL to receive processing results |
| `options` | JSON String | No | Processing options |

**Options Object:**
```json
{
  "quality": 0.85,
  "maxTags": 10,
  "language": "en"
}
```

**Response (202 Accepted):**
```json
{
  "status": "accepted",
  "message": "File processing initiated",
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "fileName": "example.jpg",
  "fileSize": 1024000,
  "processingTime": 125
}
```

**Callback Payload:**

The plugin will send a POST request to your `callBackURL` with the following structure:

```json
{
  "requestId": "550e8400-e29b-41d4-a716-446655440000",
  "status": "success",
  "fileName": "example.jpg",
  "results": {
    "tags": ["landscape", "mountain", "nature"],
    "metadata": {
      "width": 1920,
      "height": 1080,
      "format": "jpeg",
      "confidence": 0.92
    },
    "customData": {}
  },
  "processingTime": 1250,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:3000/api/v1/process \
  -H "X-API-Key: your-api-key-here" \
  -F "file=@/path/to/image.jpg" \
  -F "callBackURL=http://your-dam-server/callback" \
  -F 'options={"quality": 0.85, "maxTags": 10}'
```

**Error Response (400 Bad Request):**
```json
{
  "error": {
    "statusCode": 400,
    "name": "BadRequest",
    "message": "File is required"
  }
}
```

**Error Response (401 Unauthorized):**
```json
{
  "error": {
    "statusCode": 401,
    "name": "Unauthorized",
    "message": "Invalid API key"
  }
}
```

**Error Response (500 Internal Server Error):**
```json
{
  "error": {
    "statusCode": 500,
    "name": "InternalServerError",
    "message": "Processing failed: reason here"
  }
}
```

---

### Get Plugin Info

Retrieve plugin metadata and capabilities.

**Endpoint:** `GET /api/v1/info`

**Response:**
```json
{
  "pluginName": "my-dam-plugin",
  "pluginVersion": "1.0.0",
  "apiVersion": "v1",
  "description": "Custom DAM processing plugin",
  "supportedFileTypes": ["image/jpeg", "image/png", "image/gif"],
  "maxFileSizeMB": 100,
  "requiresAuthentication": true,
  "callbackRequired": true,
  "capabilities": {
    "tags": true,
    "metadata": true,
    "customProcessing": true
  }
}
```

**cURL Example:**
```bash
curl http://localhost:3000/api/v1/info
```

---

## OpenAPI Specification

The API is documented using OpenAPI 3.0 specification. You can access:

- **Swagger UI:** `http://your-plugin-host:3000/explorer`
- **OpenAPI JSON:** `http://your-plugin-host:3000/openapi.json`

---

## Rate Limiting

The plugin may implement rate limiting based on:
- API Key
- IP Address
- Request volume

Recommended: Implement exponential backoff for retries.

---

## Best Practices

### Error Handling

Always check the HTTP status code and handle errors appropriately:

```javascript
const response = await fetch('http://localhost:3000/api/v1/process', {
  method: 'POST',
  headers: {
    'X-API-Key': apiKey
  },
  body: formData
});

if (!response.ok) {
  const error = await response.json();
  console.error('Processing failed:', error);
  return;
}

const result = await response.json();
console.log('Request ID:', result.requestId);
```

### Callback Handling

Your callback endpoint must:
1. Accept POST requests
2. Return 200 OK to acknowledge receipt
3. Handle failures gracefully
4. Store results durably

```javascript
app.post('/callback', express.json(), (req, res) => {
  const { requestId, status, results } = req.body;
  
  // Store results
  database.store(requestId, results);
  
  // Acknowledge receipt
  res.status(200).json({ received: true });
});
```

### Timeouts

- Default processing timeout: 30 seconds
- Callback timeout: 10 seconds
- Configure timeouts based on your asset sizes

---

## Authentication

### API Key

Include your API key in the `X-API-Key` header:

```
X-API-Key: your-secret-api-key-here
```

### Managing API Keys

API keys are configured in:
- Environment variable: `API_KEY`
- Kubernetes Secret: `dam-plugin-secrets`
- Config file: `/etc/secrets/api-key`

---

## Monitoring

### Metrics

The plugin exposes metrics at `/metrics` (Prometheus format):

- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request duration
- `processing_duration_seconds` - Asset processing time
- `callback_success_total` - Successful callbacks
- `callback_failure_total` - Failed callbacks

### Health Checks

Monitor the `/health` endpoint for service availability:

```bash
# Kubernetes liveness probe
kubectl get pods -n dam-plugins -w

# Direct health check
curl http://localhost:3000/health
```

---

## Examples

### Node.js Example

```javascript
const FormData = require('form-data');
const fs = require('fs');
const axios = require('axios');

async function processAsset(filePath, callbackUrl) {
  const form = new FormData();
  form.append('file', fs.createReadStream(filePath));
  form.append('callBackURL', callbackUrl);
  form.append('options', JSON.stringify({
    quality: 0.85,
    maxTags: 10
  }));

  try {
    const response = await axios.post(
      'http://localhost:3000/api/v1/process',
      form,
      {
        headers: {
          ...form.getHeaders(),
          'X-API-Key': process.env.API_KEY
        }
      }
    );
    
    console.log('Request ID:', response.data.requestId);
    return response.data;
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
    throw error;
  }
}
```

### Python Example

```python
import requests

def process_asset(file_path, callback_url, api_key):
    with open(file_path, 'rb') as f:
        files = {'file': f}
        data = {
            'callBackURL': callback_url,
            'options': '{"quality": 0.85, "maxTags": 10}'
        }
        headers = {'X-API-Key': api_key}
        
        response = requests.post(
            'http://localhost:3000/api/v1/process',
            files=files,
            data=data,
            headers=headers
        )
        
        if response.status_code == 202:
            result = response.json()
            print(f"Request ID: {result['requestId']}")
            return result
        else:
            print(f"Error: {response.json()}")
            raise Exception('Processing failed')
```

### cURL Full Example

```bash
#!/bin/bash

API_KEY="your-api-key"
FILE_PATH="image.jpg"
CALLBACK_URL="http://dam-server/webhook/callback"

curl -X POST http://localhost:3000/api/v1/process \
  -H "X-API-Key: $API_KEY" \
  -F "file=@$FILE_PATH" \
  -F "callBackURL=$CALLBACK_URL" \
  -F 'options={"quality": 0.85, "maxTags": 10, "language": "en"}' \
  -w "\nHTTP Status: %{http_code}\n"
```

---

## Troubleshooting

### Common Errors

**401 Unauthorized**
- Check API key is correct
- Verify `X-API-Key` header is set

**413 Payload Too Large**
- File exceeds maximum size (100MB default)
- Reduce file size or increase limit

**500 Internal Server Error**
- Check plugin logs: `kubectl logs -f deployment/dam-plugin`
- Verify external API connectivity
- Check configuration

**Callback not received**
- Verify callback URL is accessible
- Check firewall rules
- Review callback endpoint logs
