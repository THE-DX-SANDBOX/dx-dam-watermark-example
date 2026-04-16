# Water Muse Dual-Server Development Setup

## Overview

The Water Muse application runs as two separate servers:

1. **Backend API Server** (LoopBack 4) - Port 3000
2. **Frontend UI Server** (React + Vite) - Port 5173

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Browser                              │
│              http://localhost:5173                      │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ HTTP Requests
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Frontend Dev Server (Vite)                    │
│                  Port: 5173                             │
│  ┌──────────────────────────────────────────────┐      │
│  │  React Application                           │      │
│  │  - Water Muse UI                             │      │
│  │  - Canvas Editor                             │      │
│  │  - Layer Management                          │      │
│  └──────────────────────────────────────────────┘      │
│                     │                                    │
│                     │ API Proxy                          │
│                     │ /api/* → http://localhost:3000     │
│                     │ /projects/* → http://localhost:3000│
│                     │ /specifications/* → ...            │
└─────────────────────┼────────────────────────────────────┘
                     │
                     │ Proxied API Calls
                     ▼
┌─────────────────────────────────────────────────────────┐
│            Backend API Server (LoopBack 4)              │
│                  Port: 3000                             │
│  ┌──────────────────────────────────────────────┐      │
│  │  REST API                                    │      │
│  │  - Projects                                  │      │
│  │  - Specifications                            │      │
│  │  - Layers                                    │      │
│  │  - Assets                                    │      │
│  │  - Templates                                 │      │
│  │  - Plugin                                    │      │
│  └──────────────────────────────────────────────┘      │
│  ┌──────────────────────────────────────────────┐      │
│  │  Services                                    │      │
│  │  - RenderingService                          │      │
│  │  - AssetStorageService                       │      │
│  │  - PluginService                             │      │
│  └──────────────────────────────────────────────┘      │
│  ┌──────────────────────────────────────────────┐      │
│  │  In-Memory Database                          │      │
│  │  (Data resets on restart)                    │      │
│  └──────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

## Configuration

### Backend (packages/server-v1)

**CORS Configuration** ([src/index.ts](packages/server-v1/src/index.ts))
```typescript
cors: {
  origin: ['http://localhost:5173', 'http://127.0.0.1:5173'],
  credentials: true,
}
```

**Services Bound** ([src/application.ts](packages/server-v1/src/application.ts))
```typescript
this.bind('services.RenderingService').toClass(RenderingService);
this.bind('services.AssetStorageService').toClass(AssetStorageService);
this.bind('services.PluginService').toClass(PluginService);
```

**Datasource**: In-memory (no PostgreSQL required for local dev)

### Frontend (packages/portlet-v1)

**API Proxy Configuration** ([vite.config.ts](packages/portlet-v1/vite.config.ts))
```typescript
server: {
  port: 5173,
  proxy: {
    '/api': {
      target: 'http://localhost:3000',
      changeOrigin: true,
      secure: false,
    },
    '/projects': {
      target: 'http://localhost:3000',
      changeOrigin: true,
      secure: false,
    },
    '/specifications': {
      target: 'http://localhost:3000',
      changeOrigin: true,
      secure: false,
    },
    '/layers': {
      target: 'http://localhost:3000',
      changeOrigin: true,
      secure: false,
    },
    '/assets': {
      target: 'http://localhost:3000',
      changeOrigin: true,
      secure: false,
    },
    '/templates': {
      target: 'http://localhost:3000',
      changeOrigin: true,
      secure: false,
    },
  }
}
```

## Starting the Servers

### Option 1: Use the Combined Script (Recommended)

```bash
./scripts/start-both-servers.sh
```

This script will:
1. Kill any existing servers on ports 3000 and 5173
2. Start the backend and wait for it to be healthy
3. Start the frontend and wait for it to be ready
4. Display log output from both servers
5. Save PIDs for cleanup

### Option 2: Start Manually

**Terminal 1 - Backend:**
```bash
cd packages/server-v1
npm run dev
```

**Terminal 2 - Frontend:**
```bash
cd packages/portlet-v1
npm run dev
```

## Stopping the Servers

### Option 1: Use the Stop Script
```bash
./scripts/stop-servers.sh
```

### Option 2: Kill by PID
```bash
kill $(cat /tmp/backend-server.pid)
kill $(cat /tmp/frontend-server.pid)
```

### Option 3: Kill by Port
```bash
lsof -ti:3000 | xargs kill -9
lsof -ti:5173 | xargs kill -9
```

## Accessing the Application

### Frontend (User Interface)
- **URL**: http://localhost:5173
- **Description**: Water Muse canvas editor and UI

### Backend (API)
- **Health Check**: http://localhost:3000/health
- **API Explorer**: http://localhost:3000/explorer
- **Plugin Info**: http://localhost:3000/api/v1/info

### API Endpoints

All API calls from the frontend are automatically proxied to the backend:

- `GET http://localhost:5173/projects` → `GET http://localhost:3000/projects`
- `POST http://localhost:5173/specifications` → `POST http://localhost:3000/specifications`
- etc.

## Logs

### Backend Logs
```bash
tail -f /tmp/backend-server.log
```

### Frontend Logs
```bash
tail -f /tmp/frontend-server.log
```

### Both Logs
```bash
tail -f /tmp/backend-server.log /tmp/frontend-server.log
```

## Troubleshooting

### Backend won't start
1. Check if port 3000 is in use: `lsof -i:3000`
2. Check logs: `cat /tmp/backend-server.log`
3. Verify services are bound in [application.ts](packages/server-v1/src/application.ts)

### Frontend won't start
1. Check if port 5173 is in use: `lsof -i:5173`
2. Check logs: `cat /tmp/frontend-server.log`
3. Verify proxy config in [vite.config.ts](packages/portlet-v1/vite.config.ts)

### CORS Errors
- Verify CORS configuration in [src/index.ts](packages/server-v1/src/index.ts)
- Ensure origin includes both `http://localhost:5173` and `http://127.0.0.1:5173`

### API Calls Not Working
1. Check proxy configuration in [vite.config.ts](packages/portlet-v1/vite.config.ts)
2. Verify backend is running: `curl http://localhost:3000/health`
3. Check browser console for errors
4. Verify API route matches proxy pattern

### Data Not Persisting
This is expected! The backend uses an in-memory datasource for local development:
- Data is stored in memory only
- Data is lost when the server restarts
- To persist data, configure PostgreSQL datasource

## Development Workflow

1. **Start both servers**: `./scripts/start-both-servers.sh`
2. **Open frontend**: http://localhost:5173
3. **Make changes**:
   - Backend changes auto-reload with ts-node-dev
   - Frontend changes hot-reload with Vite HMR
4. **Test API**: Use API Explorer at http://localhost:3000/explorer
5. **Stop servers**: `./scripts/stop-servers.sh`

## Next Steps

### Integrate with PostgreSQL
1. Install PostgreSQL locally
2. Create database: `createdb watermuse`
3. Update [postgres.datasource.ts](packages/server-v1/src/datasources/postgres.datasource.ts)
4. Run migrations (if any)

### Update Frontend to Use API
Currently, the frontend uses localStorage. To integrate with the backend:

1. Update Context providers:
   - [SpecificationContext.tsx](packages/portlet-v1/src/context/SpecificationContext.tsx)
   - Create API service layer

2. Replace localStorage calls with API calls:
   ```typescript
   // Before
   localStorage.setItem('projects', JSON.stringify(projects))
   
   // After
   await fetch('/projects', {
     method: 'POST',
     headers: { 'Content-Type': 'application/json' },
     body: JSON.stringify(project)
   })
   ```

3. Add error handling and loading states
4. Test end-to-end workflows

## Files Modified for Dual-Server Setup

1. [packages/server-v1/src/index.ts](packages/server-v1/src/index.ts) - Added CORS
2. [packages/server-v1/src/application.ts](packages/server-v1/src/application.ts) - Bound PluginService
3. [packages/server-v1/src/services/index.ts](packages/server-v1/src/services/index.ts) - Exported PluginService
4. [packages/portlet-v1/vite.config.ts](packages/portlet-v1/vite.config.ts) - Added API proxy
5. [scripts/start-both-servers.sh](scripts/start-both-servers.sh) - Created startup script
6. [scripts/stop-servers.sh](scripts/stop-servers.sh) - Created stop script

## Summary

✅ Backend running on port 3000 with CORS enabled
✅ Frontend running on port 5173 with API proxy configured  
✅ All API routes proxied from frontend to backend
✅ In-memory database for local development (no PostgreSQL needed)
✅ Both servers can be started/stopped together
✅ Logs available for debugging

The two-server setup allows:
- Independent development of frontend and backend
- Hot reloading on both sides
- Easy debugging with separate logs
- Realistic API communication patterns
- Seamless transition to production (just change proxy target)
