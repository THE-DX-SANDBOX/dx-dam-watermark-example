# DAM Demo Script Portlet

React-based Script Application for HCL DX Portal. Provides a web interface for interacting with the DAM Demo backend service.

## Features

- **Home Dashboard**: View backend service status and application features
- **Image Upload**: Upload and process images through the DAM plugin
- **React Router**: Client-side navigation using HashRouter (DX Portal compatible)
- **TypeScript**: Full type safety
- **Vite**: Fast development and optimized production builds

## Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## Environment Variables

Configuration in `.env` file:

- `VITE_ROOT_ELEMENT_ID`: Unique DOM element ID for the React app (default: `dx-scriptapp-dam-demo-root`)
- `VITE_API_BASE_URL`: Backend API base URL (default: `/api/dam-demo`)

## DX Portal Deployment

The portlet is deployed to HCL DX Portal using DXClient:

```bash
# From project root
./scripts/deploy-portlet.sh

# With build
./scripts/deploy-portlet.sh --build

# Custom configuration
./scripts/deploy-portlet.sh \
  --hostname dx.example.com \
  --content-name "DAM Demo" \
  --site-area "Applications"
```

## Architecture

- **Entry Point**: `src/main.tsx` - Initializes React app in unique DOM element
- **Router**: HashRouter for DX Portal compatibility (avoids server-side routing conflicts)
- **API Integration**: Configured via environment variables
- **Styling**: CSS modules with responsive design

## Build Output

The `dist/` folder contains:
- `index.html`: Main HTML with unique root element ID
- `assets/`: Bundled JS, CSS, and images
- All assets use relative paths for DX Portal compatibility

## Integration with Backend

The portlet connects to the backend service deployed on Kubernetes:
- Development: Direct API calls via proxy
- Production: Calls through DX Portal API gateway or direct to K8s service

## DX Portal Considerations

1. **Unique Element ID**: Uses `dx-scriptapp-dam-demo-root` to avoid conflicts
2. **Hash Router**: Uses `#` based routing compatible with DX Portal
3. **Relative Paths**: All assets use relative paths
4. **WCM Integration**: Deployed as Script Application in WCM
