# Script Portlet Deployment Guide

## ✅ What's Ready

The Script Portlet has been successfully created and built:

- **Source Code**: [packages/portlet-v1/src/](packages/portlet-v1/src/)
- **Built Output**: [packages/portlet-v1/dist/](packages/portlet-v1/dist/) (487B index.html + assets)
- **Deployment Script**: [scripts/deploy-portlet.sh](scripts/deploy-portlet.sh)
- **Build Script**: [scripts/build-all.sh](scripts/build-all.sh)

## 🎯 Features

The React-based Script Portlet includes:

- **Home Page**: Backend service status, feature showcase
- **Image Upload**: Interface for testing DAM plugin image processing
- **Navigation**: Client-side routing with React Router (HashRouter)
- **API Integration**: Connects to backend service via configurable base URL
- **TypeScript**: Full type safety
- **Responsive Design**: Mobile-friendly CSS

## 📋 Before Deploying

### 1. Update DX Portal Configuration

Edit [.env](.env) and update these values:

```bash
# DX Portal Configuration
DX_PROTOCOL=https                    # or http for local dev
DX_HOSTNAME=<DXHostname>             # Your actual DX hostname
DX_PORT=443                          # 443 for https, 10042 for local
DX_USERNAME=<dx-admin-username>      # Your DX admin username
DX_PASSWORD=<dx-admin-password>      # Your DX admin password

# Script Portlet Configuration
WCM_CONTENT_NAME="DAM Demo"          # Name in WCM
WCM_SITE_AREA="Applications"         # WCM Site Area path
```

**Finding Your DX Hostname:**

Option 1 - Check HAProxy LoadBalancer:
```bash
kubectl get svc <DXHAProxyServiceName> -n <Namespace>
# External IP: <LoadBalancerIp>
# Try: https://<LoadBalancerIp> or check DNS for this IP
```

Option 2 - Check existing projects:
```bash
# Look at other DX projects for the hostname pattern
grep -r "DX_HOSTNAME" ~/Documents/Code/build-deploy-tools/
```

Option 3 - Common patterns:
- `<DXHostname>`
- `<AlternateDXHostname>`
- `<LoadBalancerIp>` (direct IP)

### 2. Verify DXClient Installation

DXClient is already installed:
```bash
$ dxclient --version
231.0.0 ✓
```

## 🚀 Deployment Commands

### Quick Deploy (Recommended)

```bash
# Deploy portlet (will prompt if DX config is missing)
./scripts/deploy-portlet.sh --build
```

### Step-by-Step Deployment

```bash
# 1. Build only
./scripts/build-all.sh --portlet-only

# 2. Deploy to DX Portal
./scripts/deploy-portlet.sh

# 3. Or deploy with custom configuration
./scripts/deploy-portlet.sh \
  --hostname <DXHostname> \
  --username <dx-admin-username> \
  --password <dx-admin-password> \
  --content-name "DAM Demo" \
  --site-area "Applications"
```

### Rebuild and Redeploy

```bash
# Clean rebuild
rm -rf packages/portlet-v1/dist packages/portlet-v1/node_modules
./scripts/deploy-portlet.sh --build
```

## 🔍 What Happens During Deployment

1. **Validation**: Checks DX configuration and DXClient installation
2. **Dependencies**: Installs npm packages (if needed)
3. **Build**: Compiles React app with Vite (if `--build` flag used)
4. **Package**: Prepares dist/ folder for deployment
5. **Deploy**: Uses DXClient to push to WCM as Script Application
6. **Verification**: Confirms successful deployment

## 📍 Accessing the Deployed Portlet

After successful deployment:

1. **DX Portal**: Navigate to `https://<DX_HOSTNAME>/wps/myportal`
2. **WCM Content**: Check `Applications > DAM Demo` in Web Content Manager
3. **Add to Page**: Use DX Portal page editor to add the Script Application to a page

## 🔧 Configuration Options

### Environment Variables

The standard deployment path uses the root `.env` file for DX deployment settings such as `DX_HOSTNAME`, `DX_USERNAME`, and `DX_PASSWORD`.

If you need to override Vite-specific frontend variables, create `packages/portlet-v1/.env` manually. That file is optional.

Example optional Vite overrides:

```bash
VITE_ROOT_ELEMENT_ID=dx-scriptapp-dam-demo-root  # Unique DOM element ID
VITE_API_BASE_URL=/api/dam-demo                  # Backend API path
```

### Backend Integration

The portlet expects the backend service to be accessible at:
- **Development**: `http://localhost:3000` (via proxy)
- **Production**: `/api/dam-demo` (via DX Portal or direct K8s service)

To connect to your deployed backend (currently at `<PluginServiceName>` in `<Namespace>`):

Option 1 - Direct K8s service URL:
```bash
VITE_API_BASE_URL=http://<PluginServiceDNS>:<PluginPort>
```

Option 2 - Via HAProxy/Ingress (if configured):
```bash
VITE_API_BASE_URL=https://<DXHostname>/api/dam-demo
```

## 🐛 Troubleshooting

### Build Errors

```bash
# Clear caches and rebuild
rm -rf packages/portlet-v1/node_modules packages/portlet-v1/dist
cd packages/portlet-v1
npm install
npm run build
```

### Deployment Errors

**"DXClient not found"**
- DXClient is installed at `/opt/homebrew/bin/dxclient`
- If not in PATH: `export PATH="/opt/homebrew/bin:$PATH"`

**"Authentication failed"**
- Verify DX_USERNAME and DX_PASSWORD in .env
- Check DX instance is running: `kubectl get pods -n <Namespace>`

**"Connection refused"**
- Verify DX_HOSTNAME is correct
- Check port (443 for HTTPS, 10042 for local dev)
- Try direct IP: `<LoadBalancerIp>`

### Runtime Errors

**"Root element not found"**
- Check VITE_ROOT_ELEMENT_ID matches HTML element ID
- Verify portlet is properly embedded in DX page

**"API calls failing"**
- Check VITE_API_BASE_URL points to running backend
- Verify backend is accessible: `kubectl get pods -n <Namespace> | grep <PluginDeploymentName>`
- Test backend health: `kubectl port-forward -n <Namespace> deploy/<PluginDeploymentName> 3000:3000` then `curl http://localhost:3000/health`

## 📊 Next Steps

After deploying the Script Portlet:

1. **Test Image Upload**: Use the "Upload Image" page to test DAM plugin integration
2. **Configure Backend URL**: Update VITE_API_BASE_URL if backend is not accessible
3. **Customize Content**: Edit React components in [packages/portlet-v1/src/](packages/portlet-v1/src/)
4. **Add Features**: Extend the portlet with additional pages/functionality
5. **Production Deploy**: Use the root `.env` or an environment profile such as `.env.dev`, `.env.uat`, or `.env.prod`

## 🔗 Related Documentation

- [Backend Service Deployment](../scripts/README.md)
- [Testing Framework](../scripts/testing/README.md)
- [Architecture Overview](./architecture.md)
- [Environment Setup](../docs/ENVIRONMENT_SETUP.md)
- [DXClient Documentation](https://help.hcl-software.com/digital-experience/9.5/containerization/dxclient.html)

---

**Status**: ✅ Script Portlet built and ready to deploy. Update DX_HOSTNAME in .env and run `./scripts/deploy-portlet.sh --build`
