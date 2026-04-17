# DAM Plugin Template - Complete Setup Guide

## What Is This?

This is a **production-ready template** for creating HCL Digital Asset Management (DAM) plugins. It provides everything you need to:
- Build custom asset processing plugins
- Deploy to Docker and Kubernetes
- Integrate with HCL DAM system
- Scale in production environments

## Repository Contents

✅ **40+ Production-Ready Files** including:
- Complete LoopBack 4 REST API application
- Docker multi-stage build configuration
- Kubernetes deployment manifests
- CI/CD pipeline (GitHub Actions)
- Comprehensive documentation (API, Deployment, Development, Registration)
- Automated build and deployment scripts
- Unit test examples and structure

## Getting Started in 5 Minutes

### Step 1: Initialize Your Plugin

```bash
cd DAM-template

# Make scripts executable
chmod +x scripts/*.sh

# Run initialization (prompts for plugin details)
./scripts/init-plugin.sh
```

**You'll be asked for:**
- Plugin name (e.g., `my-vision-plugin`)
- Display name (e.g., `My Vision Plugin`)
- Description (e.g., `Analyzes images using AI`)
- Organization name (e.g., `My Company`)

### Step 2: Install Dependencies

```bash
npm install
```

### Step 3: Start Development Server

```bash
npm run dev
```

Your plugin is now running at:
- **API:** http://localhost:3000
- **Swagger UI:** http://localhost:3000/explorer
- **Health Check:** http://localhost:3000/health

### Step 4: Test It

```bash
# In another terminal
./scripts/test-plugin.sh path/to/test-image.jpg
```

## Core Files to Customize

### 1. **Main Business Logic** ⭐ MOST IMPORTANT
**File:** `packages/server-v1/src/services/plugin.service.ts`

This is where you implement your plugin's core functionality:

```typescript
// LINE 123-150: Replace this stub with your implementation
async analyzeAsset(
  file: Express.Multer.File,
  options?: ProcessingOptions
): Promise<AnalysisResult> {
  // TODO: Your implementation here
  // Examples:
  // - Call Google Vision API
  // - Run ML model inference
  // - Extract metadata
  // - Analyze content
}
```

### 2. **Plugin Configuration**
**File:** `plugin-config.json`

```json
{
  "pluginName": "your-plugin-name",
  "pluginDescription": "What your plugin does",
  "supportedFileTypes": ["image/jpeg", "image/png"],
  "maxFileSizeMB": 100
}
```

### 3. **Environment Configuration**
**File:** `.env`

```bash
PORT=3000
API_KEY=<api-key>
EXTERNAL_API_URL=<external-api-url>
EXTERNAL_API_KEY=<external-api-key>
LOG_LEVEL=info
```

### 4. **Request/Response Models** (Optional)
- Request schema: `packages/server-v1/src/models/request/plugin-req.ts`
- Response schema: `packages/server-v1/src/models/response/plugin-res.ts`

## Building & Deploying

### Local Development

```bash
npm run dev           # Start with hot reload
npm test             # Run tests
npm run lint         # Check code style
```

### Docker

```bash
# Build image
./scripts/build.sh

# Or with custom name/tag
./scripts/build.sh my-registry.com/my-plugin v1.0.0

# Run locally
docker run -p 3000:3000 \
  -e API_KEY=test-key \
  my-plugin:latest
```

### Kubernetes

```bash
# Deploy to development
./scripts/deploy.sh development

# Deploy to production
./scripts/deploy.sh production dam-plugins

# Check status
kubectl get pods -n dam-plugins
kubectl logs -f deployment/dam-plugin -n dam-plugins
```

### CI/CD (GitHub Actions)

The template includes a complete CI/CD pipeline in `.github/workflows/ci.yml`.

**Required GitHub Secrets:**
```
DOCKER_REGISTRY=<registry-host>
DOCKER_USERNAME=<registry-username>
DOCKER_PASSWORD=<registry-password>
KUBE_CONFIG=<base64-encoded-kubeconfig>
```

Workflow automatically:
1. Runs tests on push
2. Builds Docker image
3. Pushes to registry
4. Deploys to Kubernetes (on main branch)

## API Endpoints

### 1. Health Check
```bash
GET /health

Response:
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### 2. Process Asset (Main Endpoint)
```bash
POST /api/v1/process
Headers: X-API-Key: your-api-key
Body: multipart/form-data
  - file: <file>
  - callBackURL: http://dam-server/callback
  - options: {"quality": 0.85, "maxTags": 10}

Response (202 Accepted):
{
  "status": "accepted",
  "requestId": "uuid",
  "fileName": "image.jpg",
  "fileSize": 1024000
}
```

### 3. Plugin Info
```bash
GET /api/v1/info

Response:
{
  "pluginName": "my-plugin",
  "pluginVersion": "1.0.0",
  "supportedFileTypes": ["image/jpeg", "image/png"],
  "maxFileSizeMB": 100
}
```

## Architecture

```
┌─────────────┐
│   DAM       │ 1. Upload asset with callback URL
│   System    │───────────────────────┐
└─────────────┘                       │
       ▲                              ▼
       │                    ┌─────────────────┐
       │ 4. Callback        │  Your Plugin    │
       │    with results    │  (This Template)│
       └────────────────────│                 │
                            │ - Validate      │
                            │ - Process file  │
                            │ - Call AI/ML    │
                            │ - Format results│
                            └────────┬────────┘
                                     │
                            2. Call external API
                                     │
                                     ▼
                            ┌─────────────────┐
                            │  External API   │
                            │ (Vision/ML/etc) │
                            └─────────────────┘
                                     │
                            3. Receive results
```

## Documentation

### Quick Reference
- **[API.md](docs/API.md)** - Complete API reference with curl examples
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Docker, K8s, cloud deployment
- **[DEVELOPMENT.md](docs/DEVELOPMENT.md)** - Architecture, coding guidelines
- **[REGISTRATION.md](docs/REGISTRATION.md)** - Register plugin with DAM

### Key Sections

**For Developers:**
1. Read [DEVELOPMENT.md](docs/DEVELOPMENT.md) - Understanding the codebase
2. Edit `plugin.service.ts` - Implement your logic
3. Run tests - `npm test`

**For DevOps:**
1. Read [DEPLOYMENT.md](docs/DEPLOYMENT.md) - Deployment options
2. Configure `kubernetes/*.yaml` - Update for your infrastructure
3. Set up CI/CD - Configure GitHub secrets

**For DAM Admins:**
1. Read [REGISTRATION.md](docs/REGISTRATION.md) - Plugin registration
2. Configure DAM - Add plugin to DAM system
3. Test integration - Verify asset processing works

## Technology Stack

- **Framework:** LoopBack 4 (TypeScript)
- **Runtime:** Node.js 20 (Alpine Linux)
- **API:** REST with OpenAPI 3.0
- **Testing:** Jest with ts-jest
- **Container:** Docker multi-stage build
- **Orchestration:** Kubernetes
- **CI/CD:** GitHub Actions
- **Monitoring:** Health checks, Prometheus metrics

## File Structure Summary

```
DAM-template/
├── packages/server-v1/src/
│   ├── controllers/plugin.controller.ts   ← API endpoints
│   ├── services/plugin.service.ts         ← YOUR LOGIC HERE ⭐
│   ├── models/                            ← Data structures
│   └── __tests__/                         ← Tests
├── kubernetes/                            ← K8s manifests
│   ├── deployment.yaml                    ← Pod configuration
│   ├── service.yaml                       ← Load balancer
│   └── configmap.yaml                     ← Config & secrets
├── scripts/                               ← Automation
│   ├── init-plugin.sh                     ← Run this first
│   ├── build.sh                           ← Build Docker image
│   └── deploy.sh                          ← Deploy to K8s
├── docs/                                  ← Documentation
│   ├── API.md                             ← API reference
│   ├── DEPLOYMENT.md                      ← Deployment guide
│   ├── DEVELOPMENT.md                     ← Dev guide
│   └── REGISTRATION.md                    ← DAM integration
├── plugin-config.json                     ← Plugin settings
├── .env.example                           ← Environment template
└── README.md                              ← Main README
```

## Common Use Cases

### 1. **Image Analysis Plugin**
```typescript
// Integrate with Google Vision, AWS Rekognition, Azure Vision
async analyzeAsset(file) {
  const vision = new VisionAPI();
  const labels = await vision.detectLabels(file.buffer);
  return { tags: labels, metadata: {...} };
}
```

### 2. **OCR Plugin**
```typescript
// Extract text from documents/images
async analyzeAsset(file) {
  const ocr = new OCRService();
  const text = await ocr.extractText(file.buffer);
  return { text, confidence: 0.95 };
}
```

### 3. **Content Moderation Plugin**
```typescript
// Check for inappropriate content
async analyzeAsset(file) {
  const moderator = new ModerationAPI();
  const result = await moderator.analyze(file.buffer);
  return { safe: result.safe, categories: result.flags };
}
```

### 4. **Custom ML Model Plugin**
```typescript
// Run custom TensorFlow/PyTorch model
async analyzeAsset(file) {
  const model = await loadModel();
  const predictions = await model.predict(file.buffer);
  return { predictions, confidence: 0.89 };
}
```

## Troubleshooting

### "Port 3000 already in use"
```bash
lsof -i :3000
kill -9 <PID>
```

### "Module not found"
```bash
rm -rf node_modules package-lock.json
npm install
```

### "Docker build fails"
```bash
docker system prune -a
./scripts/build.sh
```

### "Kubernetes pod not starting"
```bash
kubectl describe pod <pod-name> -n dam-plugins
kubectl logs <pod-name> -n dam-plugins
```

## Next Steps

1. ✅ **Initialize:** Run `./scripts/init-plugin.sh`
2. ✅ **Install:** Run `npm install`
3. ✅ **Customize:** Edit `plugin.service.ts` with your logic
4. ✅ **Test:** Run `npm test` and `./scripts/test-plugin.sh`
5. ✅ **Build:** Run `./scripts/build.sh`
6. ✅ **Deploy:** Run `./scripts/deploy.sh`
7. ✅ **Register:** Follow [REGISTRATION.md](docs/REGISTRATION.md)

## Support

- **Issues:** Report bugs or request features on GitHub
- **Documentation:** Check [docs/](docs/) folder
- **HCL DAM:** https://help.hcltechsw.com/digital-asset-management/
- **LoopBack 4:** https://loopback.io/doc/en/lb4/

## License

MIT License - See [LICENSE](LICENSE) file

---

**Ready to build your DAM plugin?** Run `./scripts/init-plugin.sh` to get started! 🚀
