# Local Development & Testing Guide

## Quick Start

### 1. Start the Server

```bash
cd /Users/robertholt/Documents/Code/DAM-Demo
./scripts/start-local.sh
```

Or manually:
```bash
cd packages/server-v1
npm run dev
```

The server will start at **http://localhost:3000**

### 2. Run Tests

In a new terminal:
```bash
cd /Users/robertholt/Documents/Code/DAM-Demo
./scripts/test-local.sh
```

## Available Endpoints

Once the server is running, you can access:

- **API Explorer (Swagger UI):** http://localhost:3000/explorer
- **OpenAPI Spec:** http://localhost:3000/openapi.json
- **Health Check:** http://localhost:3000/health
- **Plugin Info:** http://localhost:3000/api/v1/info

## Water Muse API Endpoints

### Projects
```bash
# List all projects
curl http://localhost:3000/projects

# Create a project
curl -X POST http://localhost:3000/projects \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Design",
    "description": "Test project",
    "status": "active"
  }'

# Get a specific project
curl http://localhost:3000/projects/{id}

# Update a project
curl -X PATCH http://localhost:3000/projects/{id} \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'

# Delete a project
curl -X DELETE http://localhost:3000/projects/{id}
```

### Specifications
```bash
# Create a specification
curl -X POST http://localhost:3000/specifications \
  -H "Content-Type: application/json" \
  -d '{
    "projectId": "<project-id>",
    "name": "Canvas 1",
    "width": 800,
    "height": 600,
    "backgroundColor": "#ffffff",
    "specData": {}
  }'

# Get all specifications
curl http://localhost:3000/specifications

# Get active specifications
curl http://localhost:3000/specifications/active

# Render a specification
curl -X POST http://localhost:3000/specifications/{id}/render \
  -H "Content-Type: application/json" \
  -d '{
    "format": "png",
    "width": 800,
    "height": 600,
    "quality": 90
  }'
```

### Layers
```bash
# Create a layer
curl -X POST http://localhost:3000/layers \
  -H "Content-Type: application/json" \
  -d '{
    "specId": "<spec-id>",
    "name": "Background",
    "type": "image",
    "zIndex": 0,
    "visible": true,
    "x": 0,
    "y": 0,
    "width": 800,
    "height": 600,
    "layerData": {"imageUrl": "https://example.com/image.png"}
  }'

# Reorder layers
curl -X POST http://localhost:3000/layers/reorder \
  -H "Content-Type: application/json" \
  -d '{
    "specId": "<spec-id>",
    "layerIds": ["layer-1-id", "layer-2-id", "layer-3-id"]
  }'

# Duplicate a layer
curl -X POST http://localhost:3000/layers/{id}/duplicate \
  -H "Content-Type: application/json" \
  -d '{
    "offsetX": 10,
    "offsetY": 10
  }'
```

### Assets
```bash
# Upload an asset
curl -X POST http://localhost:3000/assets/upload \
  -F "file=@/path/to/image.png" \
  -F "projectId=<project-id>" \
  -F "type=image" \
  -F "tags=[\"design\",\"background\"]"

# List assets
curl http://localhost:3000/assets

# Search by tags
curl 'http://localhost:3000/assets/search?tags=design,background'

# Get storage stats
curl http://localhost:3000/assets/stats
```

### Templates
```bash
# Get public templates
curl http://localhost:3000/templates/public

# Get popular templates
curl 'http://localhost:3000/templates/popular?limit=10'

# Search templates
curl 'http://localhost:3000/templates/search?tags=grid,pattern'

# Track template usage
curl -X POST http://localhost:3000/templates/{id}/use
```

## Testing with the API Explorer

1. Open http://localhost:3000/explorer in your browser
2. Expand any endpoint (e.g., "ProjectController")
3. Click "Try it out"
4. Fill in the request body (if needed)
5. Click "Execute"
6. View the response

## Manual Testing Workflow

### Complete Test Flow

```bash
# 1. Create a project
PROJECT_RESPONSE=$(curl -s -X POST http://localhost:3000/projects \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Design", "description": "Testing"}')
  
PROJECT_ID=$(echo $PROJECT_RESPONSE | jq -r '.id')
echo "Created project: $PROJECT_ID"

# 2. Create a specification
SPEC_RESPONSE=$(curl -s -X POST http://localhost:3000/specifications \
  -H "Content-Type: application/json" \
  -d "{
    \"projectId\": \"$PROJECT_ID\",
    \"name\": \"Canvas 1\",
    \"width\": 800,
    \"height\": 600,
    \"specData\": {\"backgroundColor\": \"#ffffff\"}
  }")
  
SPEC_ID=$(echo $SPEC_RESPONSE | jq -r '.id')
echo "Created specification: $SPEC_ID"

# 3. Create layers
curl -X POST http://localhost:3000/layers \
  -H "Content-Type: application/json" \
  -d "{
    \"specId\": \"$SPEC_ID\",
    \"name\": \"Background\",
    \"type\": \"shape\",
    \"zIndex\": 0,
    \"visible\": true,
    \"x\": 0,
    \"y\": 0,
    \"width\": 800,
    \"height\": 600,
    \"layerData\": {
      \"shapeType\": \"rectangle\",
      \"fillColor\": \"#ffffff\"
    }
  }"

# 4. Render the specification
curl -X POST http://localhost:3000/specifications/$SPEC_ID/render \
  -H "Content-Type: application/json" \
  -d '{"format": "png", "quality": 90}'
```

## Stopping the Server

Press `Ctrl+C` in the terminal where the server is running, or:

```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9
```

## Troubleshooting

### Port 3000 already in use

```bash
# Find what's using port 3000
lsof -i:3000

# Kill the process
lsof -ti:3000 | xargs kill -9
```

### Dependencies not installed

```bash
cd packages/server-v1
npm install
```

### Build errors

```bash
cd packages/server-v1
npm run clean
npm install
npm run build
```

### Database connection errors

The server requires PostgreSQL. Make sure your environment variables are set:

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=postgres
export DB_PASSWORD=your_password
export DB_NAME=damdb
```

Or create a `.env` file in `packages/server-v1/`:

```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=damdb
```

### Apply database schema

```bash
# If you have PostgreSQL running locally
psql -U postgres -d damdb < scripts/migration/water-muse-schema.sql

# Or with kubectl (if using Kubernetes)
kubectl exec -i deployment/postgres -- psql -U postgres -d damdb < scripts/migration/water-muse-schema.sql
```

## Development Tips

### Hot Reload

The server uses `ts-node-dev` which automatically reloads when you make changes to the code.

### Viewing Logs

All logs are visible in the terminal where you started the server.

### Testing Changes

1. Make your code changes
2. Save the file
3. Server automatically reloads
4. Test the endpoint in the API Explorer or with curl

### Using VS Code REST Client

Install the REST Client extension and create a `.http` file:

```http
### Health Check
GET http://localhost:3000/health

### Create Project
POST http://localhost:3000/projects
Content-Type: application/json

{
  "name": "Test Project",
  "description": "Testing from VS Code"
}

### List Projects
GET http://localhost:3000/projects
```

## Performance Testing

### Using Apache Bench

```bash
# Test health endpoint
ab -n 1000 -c 10 http://localhost:3000/health

# Test projects endpoint
ab -n 100 -c 5 http://localhost:3000/projects
```

### Using wrk

```bash
# Install wrk first: brew install wrk

# Load test
wrk -t4 -c100 -d30s http://localhost:3000/health
```

## Next Steps

1. **Start the frontend:**
   ```bash
   cd packages/portlet-v1
   npm run dev
   ```

2. **Update frontend to use API** - Replace localStorage calls in Context providers

3. **Test end-to-end** - Create projects, add layers, render images

4. **Deploy to Kubernetes** - Use the deployment scripts when ready

## Useful Commands

```bash
# View server logs
tail -f packages/server-v1/logs/*.log

# Check server process
ps aux | grep "ts-node-dev"

# Monitor port
watch -n 1 "lsof -i:3000"

# Test all endpoints quickly
./scripts/test-local.sh
```
