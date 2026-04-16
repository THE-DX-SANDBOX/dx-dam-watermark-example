#!/bin/bash
# =============================================================================
# Deploy Script Portlet to HCL DX Portal via DXClient
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

show_help() {
  cat << EOF
${BLUE}Deploy Script Portlet to DX Portal${NC}

${YELLOW}Usage:${NC}
  $0 [OPTIONS]

${YELLOW}Options:${NC}
  --hostname HOST            DX hostname (default: from .env)
  --port PORT                DX port (default: from .env)
  --protocol PROTOCOL        DX protocol (default: from .env)
  --username USER            DX username (default: from .env)
  --password PASS            DX password (default: from .env)
  --content-name NAME        WCM content name (default: from .env)
  --site-area AREA          WCM site area (default: from .env)
  --build                    Build portlet before deploying
  --skip-install            Skip npm install
  -h, --help                 Show this help message

${YELLOW}Examples:${NC}
  # Deploy with .env configuration
  $0

  # Build and deploy
  $0 --build

  # Deploy to specific DX instance
  $0 --hostname dx.example.com --username <dx-admin-username> --password <dx-admin-password>

  # Deploy with custom WCM location
  $0 --content-name "My DAM Demo" --site-area "Custom/Applications"

${YELLOW}Environment Variables:${NC}
  Reads from .env file in project root:
  - DX_PROTOCOL (default: https)
  - DX_HOSTNAME (required)
  - DX_PORT (default: 443)
  - DX_USERNAME (required)
  - DX_PASSWORD (required)
  - WCM_CONTENT_NAME (default: "DAM Demo")
  - WCM_SITE_AREA (default: "Applications")
  - PORTLET_MAIN_HTML (default: index.html)
  - PORTLET_BUILD_DIR (default: ./packages/portlet-v1/dist)

${YELLOW}Requirements:${NC}
  - DXClient must be installed and in PATH
  - Node.js and npm for building
  - Access to HCL DX Portal instance
EOF
}

# Load environment configuration
if [ -f "$PROJECT_ROOT/.env" ]; then
  log_info "Loading configuration from .env"
  set -a
  source "$PROJECT_ROOT/.env"
  set +a
else
  log_warning "No .env file found, using defaults"
fi

# Parse arguments
BUILD=false
SKIP_INSTALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --hostname) DX_HOSTNAME="$2"; shift 2 ;;
    --port) DX_PORT="$2"; shift 2 ;;
    --protocol) DX_PROTOCOL="$2"; shift 2 ;;
    --username) DX_USERNAME="$2"; shift 2 ;;
    --password) DX_PASSWORD="$2"; shift 2 ;;
    --content-name) WCM_CONTENT_NAME="$2"; shift 2 ;;
    --site-area) WCM_SITE_AREA="$2"; shift 2 ;;
    --build) BUILD=true; shift ;;
    --skip-install) SKIP_INSTALL=true; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) log_error "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Set defaults
DX_PROTOCOL="${DX_PROTOCOL:-https}"
DX_PORT="${DX_PORT:-443}"
WCM_CONTENT_NAME="${WCM_CONTENT_NAME:-DAM Demo}"
WCM_SITE_AREA="${WCM_SITE_AREA:-Applications}"
PORTLET_MAIN_HTML="${PORTLET_MAIN_HTML:-index.html}"
PORTLET_BUILD_DIR="${PORTLET_BUILD_DIR:-./packages/portlet-v1/dist}"

# Validate required parameters
if [ -z "$DX_HOSTNAME" ]; then
  log_error "DX_HOSTNAME is required"
  log_info "Set it in .env file or use --hostname flag"
  exit 1
fi

if [ -z "$DX_USERNAME" ] || [ -z "$DX_PASSWORD" ]; then
  log_error "DX credentials are required"
  log_info "Set DX_USERNAME and DX_PASSWORD in .env or use flags"
  exit 1
fi

# Check DXClient is installed
if ! command -v dxclient &> /dev/null; then
  log_error "DXClient is not installed or not in PATH"
  log_info "Install from: https://help.hcl-software.com/digital-experience/9.5/containerization/dxclient.html"
  exit 1
fi

# Display deployment configuration
log_info "Deploying Script Portlet..."
log_info "  Content: ${WCM_CONTENT_NAME}"
log_info "  Site Area: ${WCM_SITE_AREA}"
log_info "  DX Host: ${DX_PROTOCOL}://${DX_HOSTNAME}:${DX_PORT}"
log_info "  Build Dir: ${PORTLET_BUILD_DIR}"
echo ""

# Navigate to portlet directory
PORTLET_DIR="$PROJECT_ROOT/packages/portlet-v1"

if [ ! -d "$PORTLET_DIR" ]; then
  log_error "Portlet directory not found: $PORTLET_DIR"
  exit 1
fi

cd "$PORTLET_DIR"

# Install dependencies if needed
if [ "$SKIP_INSTALL" = false ]; then
  if [ ! -d "node_modules" ]; then
    log_info "Installing dependencies..."
    npm install
    log_success "Dependencies installed"
  fi
fi

# Build if requested
if [ "$BUILD" = true ]; then
  log_info "Building portlet..."
  npm run build
  log_success "Build complete"
fi

# Resolve build directory path
if [[ "$PORTLET_BUILD_DIR" = /* ]]; then
  # Absolute path
  BUILD_DIR="$PORTLET_BUILD_DIR"
else
  # Relative path from project root
  BUILD_DIR="$PROJECT_ROOT/$PORTLET_BUILD_DIR"
fi

# Check build directory exists
if [ ! -d "$BUILD_DIR" ]; then
  log_error "Build directory not found: $BUILD_DIR"
  log_error "Run with --build flag or manually build portlet:"
  log_error "  cd packages/portlet-v1 && npm run build"
  exit 1
fi

# Check main HTML file exists
if [ ! -f "$BUILD_DIR/$PORTLET_MAIN_HTML" ]; then
  log_error "Main HTML file not found: $BUILD_DIR/$PORTLET_MAIN_HTML"
  exit 1
fi

log_info "Deploying to DX Portal..."

# Deploy using dxclient
# Note: Password may contain special characters, so we handle it carefully
DXCLIENT_CMD=(
  dxclient deploy-scriptapplication push
  -dxUsername "$DX_USERNAME"
  -dxPassword "$DX_PASSWORD"
  -wcmContentName "$WCM_CONTENT_NAME"
  -wcmSiteArea "$WCM_SITE_AREA"
  -mainHtmlFile "$PORTLET_MAIN_HTML"
  -contentRoot "$BUILD_DIR"
  -dxProtocol "$DX_PROTOCOL"
  -hostname "$DX_HOSTNAME"
  -dxPort "$DX_PORT"
)

# Execute deployment
if "${DXCLIENT_CMD[@]}"; then
  echo ""
  log_success "✅ Script Portlet deployed successfully!"
  echo ""
  log_info "Access your portlet at:"
  log_info "  ${DX_PROTOCOL}://${DX_HOSTNAME}/wps/myportal"
  echo ""
  log_info "WCM Content Location:"
  log_info "  Site Area: ${WCM_SITE_AREA}"
  log_info "  Content: ${WCM_CONTENT_NAME}"
  echo ""
else
  log_error "Deployment failed"
  log_info "Check DXClient logs for details"
  exit 1
fi
