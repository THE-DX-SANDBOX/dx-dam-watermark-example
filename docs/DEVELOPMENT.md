# Development Guide

## Overview

This guide covers development workflows, architecture, and best practices for extending the DAM plugin template.

## Getting Started

### Prerequisites

- Node.js 20+
- npm 9+
- Docker Desktop (for containerized development)
- Visual Studio Code (recommended)

### Initial Setup

1. **Clone/Initialize the template:**
```bash
# Initialize with custom name
chmod +x scripts/init-plugin.sh
./scripts/init-plugin.sh
```

2. **Install dependencies:**
```bash
npm install
```

3. **Configure environment:**
```bash
cp .env.example .env
# Edit .env with your settings
```

4. **Start development server:**
```bash
npm run dev
```

The server will start with hot reload at http://localhost:3000

---

## Project Structure

```
DAM-template/
├── .github/
│   └── workflows/
│       └── ci.yml                 # CI/CD pipeline
├── docs/
│   ├── API.md                     # API documentation
│   ├── DEPLOYMENT.md              # Deployment guide
│   ├── DEVELOPMENT.md             # This file
│   └── REGISTRATION.md            # DAM registration guide
├── kubernetes/
│   ├── deployment.yaml            # K8s deployment
│   ├── service.yaml               # K8s service
│   ├── configmap.yaml             # Configuration
│   └── hpa.yaml                   # Auto-scaling
├── packages/
│   ├── server-v1/
│   │   ├── src/
│   │   │   ├── controllers/       # API endpoints
│   │   │   ├── models/            # Data models
│   │   │   ├── services/          # Business logic
│   │   │   ├── utils/             # Utilities
│   │   │   ├── __tests__/         # Tests
│   │   │   ├── application.ts     # LoopBack app
│   │   │   ├── index.ts           # Entry point
│   │   │   └── sequence.ts        # Request sequence
│   │   ├── public/                # Static files
│   │   ├── openapi/               # OpenAPI spec
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── Dockerfile                 # Container image
│   ├── docker-compose.yml         # Local environment
│   └── start_server.sh            # Startup script
├── scripts/
│   ├── init-plugin.sh             # Initialize plugin
│   ├── build.sh                   # Build image
│   ├── deploy.sh                  # Deploy to K8s
│   └── test-plugin.sh             # Test endpoint
├── plugin-config.json             # Plugin metadata
├── package.json                   # Root package
└── lerna.json                     # Monorepo config
```

---

## Architecture

### LoopBack 4 Framework

The plugin is built on [LoopBack 4](https://loopback.io/), a highly extensible Node.js framework.

**Key Concepts:**

1. **Application** - Main application class
2. **Controllers** - Handle HTTP requests
3. **Services** - Business logic layer
4. **Models** - Data structures
5. **Repositories** - Data access (if using database)
6. **Sequence** - Request/response lifecycle

### Request Flow

```
HTTP Request
    ↓
Sequence (middleware)
    ↓
Controller (API endpoint)
    ↓
Service (business logic)
    ↓
External API (optional)
    ↓
Callback to DAM
    ↓
HTTP Response
```

### Component Overview

```typescript
// Application Setup
src/application.ts    → Bootstrap LoopBack app
src/sequence.ts       → CORS, logging, error handling

// API Layer
src/controllers/      → REST endpoints
src/models/          → Request/response schemas

// Business Logic
src/services/        → Processing logic
src/utils/           → Helper functions

// Testing
src/__tests__/       → Unit & integration tests
```

---

## Development Workflow

### 1. Implement Your Processing Logic

The main extension point is [plugin.service.ts](../packages/server-v1/src/services/plugin.service.ts):

```typescript
/**
 * TODO: Replace this stub with your actual implementation
 * 
 * This is where you integrate with external services like:
 * - Computer vision APIs (Google Vision, AWS Rekognition, Azure Vision)
 * - OCR services
 * - ML models
 * - Content moderation
 * - Custom analysis
 */
async analyzeAsset(
  file: Express.Multer.File,
  options?: ProcessingOptions
): Promise<AnalysisResult> {
  // Your implementation here
  
  // Example: Call external API
  const response = await axios.post(
    process.env.EXTERNAL_API_URL!,
    {
      image: file.buffer.toString('base64'),
      options: options
    },
    {
      headers: {
        'Authorization': `Bearer ${process.env.EXTERNAL_API_KEY}`
      }
    }
  );
  
  return {
    tags: response.data.tags,
    metadata: response.data.metadata
  };
}
```

### 2. Update Request/Response Models

Customize data structures in [models/](../packages/server-v1/src/models/):

**Request Model** (`models/request/plugin-req.ts`):
```typescript
export interface PluginRequest {
  file: Express.Multer.File;
  callBackURL: string;
  options?: {
    // Add your custom options
    detectFaces?: boolean;
    extractText?: boolean;
    moderateContent?: boolean;
  };
}
```

**Response Model** (`models/response/plugin-res.ts`):
```typescript
export interface PluginResult {
  tags: string[];
  metadata: Record<string, any>;
  customData?: {
    // Add your custom results
    faces?: FaceDetection[];
    text?: ExtractedText;
    moderation?: ModerationResults;
  };
}
```

### 3. Add New Endpoints (Optional)

Create additional endpoints in [plugin.controller.ts](../packages/server-v1/src/controllers/plugin.controller.ts):

```typescript
@get('/api/v1/status/{requestId}')
@response(200, {
  description: 'Get processing status',
  content: {
    'application/json': {
      schema: {
        type: 'object',
        properties: {
          requestId: {type: 'string'},
          status: {type: 'string'},
          progress: {type: 'number'}
        }
      }
    }
  }
})
async getStatus(
  @param.path.string('requestId') requestId: string
): Promise<object> {
  return this.pluginService.getStatus(requestId);
}
```

### 4. Write Tests

Add tests in [__tests__/](../packages/server-v1/src/__tests__/):

```typescript
describe('PluginService', () => {
  let service: PluginService;

  beforeEach(() => {
    service = new PluginService();
  });

  it('should process valid file', async () => {
    const file = createMockFile('test.jpg');
    const result = await service.processAsset(
      file,
      'http://callback.url'
    );
    
    expect(result.status).toBe('accepted');
    expect(result.requestId).toBeDefined();
  });

  it('should validate API key', () => {
    expect(() => service.validateApiKey('invalid'))
      .toThrow('Invalid API key');
  });
});
```

### 5. Run Tests

```bash
# Unit tests
npm test

# With coverage
npm run test:coverage

# Watch mode
npm run test:watch

# Specific test file
npm test -- plugin.service.test.ts
```

### 6. Update Configuration

Edit [plugin-config.json](../plugin-config.json):

```json
{
  "pluginName": "my-vision-plugin",
  "pluginDisplayName": "My Vision Plugin",
  "pluginDescription": "Analyzes images using custom ML model",
  "supportedFileTypes": [
    "image/jpeg",
    "image/png",
    "video/mp4"
  ],
  "maxFileSizeMB": 200
}
```

---

## Development Commands

```bash
# Install dependencies
npm install

# Start development server (with hot reload)
npm run dev

# Build TypeScript
npm run build

# Run linter
npm run lint

# Fix linting issues
npm run lint:fix

# Run tests
npm test

# Test with coverage
npm run test:coverage

# Clean build artifacts
npm run clean

# Generate OpenAPI spec
npm run openapi:generate
```

---

## Debugging

### VS Code Launch Configuration

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Debug Plugin",
      "runtimeArgs": [
        "-r",
        "ts-node/register"
      ],
      "args": [
        "${workspaceFolder}/packages/server-v1/src/index.ts"
      ],
      "env": {
        "NODE_ENV": "development",
        "PORT": "3000"
      },
      "sourceMaps": true,
      "cwd": "${workspaceFolder}/packages/server-v1",
      "console": "integratedTerminal"
    }
  ]
}
```

### Debug Logging

Add debug logs in your code:

```typescript
import {inject} from '@loopback/core';
import {get} from '@loopback/rest';
import {logger} from '../utils/logger';

export class PluginController {
  async processFile() {
    logger.debug('Processing file', {
      fileName: file.originalname,
      fileSize: file.size
    });
    
    try {
      const result = await this.service.process(file);
      logger.info('Processing complete', {requestId: result.requestId});
      return result;
    } catch (error) {
      logger.error('Processing failed', {error: error.message});
      throw error;
    }
  }
}
```

### Remote Debugging (Kubernetes)

```bash
# Port forward to pod
kubectl port-forward pod/<pod-name> 9229:9229 -n dam-plugins

# Update deployment to enable debugging
env:
- name: NODE_OPTIONS
  value: "--inspect=0.0.0.0:9229"
```

---

## Code Style

### TypeScript Guidelines

```typescript
// Use interfaces for data structures
interface ProcessingOptions {
  quality: number;
  maxTags: number;
}

// Use types for unions/intersections
type FileType = 'image' | 'video' | 'document';

// Use async/await over promises
async function processFile(file: File): Promise<Result> {
  const data = await readFile(file);
  return analyze(data);
}

// Use proper error handling
try {
  const result = await riskyOperation();
  return result;
} catch (error) {
  logger.error('Operation failed', {error});
  throw new HttpErrors.InternalServerError('Processing failed');
}

// Use JSDoc comments
/**
 * Process an asset file
 * @param file The uploaded file
 * @param options Processing options
 * @returns Processing result
 */
async processAsset(
  file: Express.Multer.File,
  options?: ProcessingOptions
): Promise<ProcessingResult> {
  // Implementation
}
```

### Naming Conventions

- **Classes**: PascalCase (`PluginController`, `PluginService`)
- **Interfaces**: PascalCase (`PluginRequest`, `ProcessingOptions`)
- **Functions**: camelCase (`processAsset`, `validateApiKey`)
- **Constants**: UPPER_SNAKE_CASE (`MAX_FILE_SIZE`, `API_VERSION`)
- **Files**: kebab-case (`plugin.controller.ts`, `plugin-req.ts`)

---

## Adding Dependencies

```bash
# Add production dependency
cd packages/server-v1
npm install <package-name>

# Add dev dependency
npm install -D <package-name>

# Update root package.json if needed
cd ../..
npm install
```

### Recommended Libraries

**Image Processing:**
- `sharp` - High-performance image processing
- `jimp` - Pure JavaScript image manipulation

**HTTP Clients:**
- `axios` - Promise-based HTTP client (included)
- `node-fetch` - Fetch API for Node.js

**Validation:**
- `ajv` - JSON schema validation
- `joi` - Object schema validation

**Utilities:**
- `lodash` - Utility functions
- `dayjs` - Date manipulation

---

## Environment Variables

### Development (.env)

```bash
# Server
PORT=3000
HOST=0.0.0.0
NODE_ENV=development
LOG_LEVEL=debug

# Security
API_KEY=<dev-api-key>

# External Services
EXTERNAL_API_URL=https://api.example.com/v1
EXTERNAL_API_KEY=<dev-external-api-key>

# File Upload
MAX_FILE_SIZE=104857600  # 100MB in bytes
```

### Production

Use Kubernetes Secrets and ConfigMaps (see [DEPLOYMENT.md](DEPLOYMENT.md))

---

## Performance Optimization

### 1. File Upload Optimization

```typescript
// Stream processing instead of buffering
import {pipeline} from 'stream';
import {promisify} from 'util';

const pump = promisify(pipeline);

async function processStream(file: Express.Multer.File) {
  await pump(
    file.stream,
    transformStream(),
    destinationStream()
  );
}
```

### 2. Caching

```typescript
import {inject} from '@loopback/core';
import NodeCache from 'node-cache';

export class PluginService {
  private cache = new NodeCache({stdTTL: 600}); // 10 min TTL

  async getPluginInfo() {
    const cached = this.cache.get('plugin-info');
    if (cached) return cached;

    const info = await this.loadPluginInfo();
    this.cache.set('plugin-info', info);
    return info;
  }
}
```

### 3. Parallel Processing

```typescript
async function processBatch(files: File[]) {
  const results = await Promise.all(
    files.map(file => processFile(file))
  );
  return results;
}
```

---

## Security Best Practices

### 1. Input Validation

```typescript
import {HttpErrors} from '@loopback/rest';

function validateFile(file: Express.Multer.File) {
  const allowedTypes = ['image/jpeg', 'image/png'];
  
  if (!allowedTypes.includes(file.mimetype)) {
    throw new HttpErrors.BadRequest('Invalid file type');
  }
  
  if (file.size > MAX_FILE_SIZE) {
    throw new HttpErrors.PayloadTooLarge('File too large');
  }
}
```

### 2. API Key Management

```typescript
// Use environment variables
const apiKey = process.env.API_KEY;

// Validate on every request
if (apiKey !== providedKey) {
  throw new HttpErrors.Unauthorized('Invalid API key');
}

// Consider using JWT tokens for more security
import jwt from 'jsonwebtoken';

const token = jwt.sign({plugin: 'dam-plugin'}, SECRET_KEY);
```

### 3. Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

// Apply to routes
app.use('/api/', limiter);
```

---

## Troubleshooting

### Common Issues

**TypeScript compilation errors:**
```bash
# Clean and rebuild
npm run clean
npm run build
```

**Port already in use:**
```bash
# Find process using port 3000
lsof -i :3000
# Kill process
kill -9 <PID>
```

**Module not found:**
```bash
# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

---

## Next Steps

- [API Reference](API.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Plugin Registration](REGISTRATION.md)
- [LoopBack 4 Documentation](https://loopback.io/doc/en/lb4/)
