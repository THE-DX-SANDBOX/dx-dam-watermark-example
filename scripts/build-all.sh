#!/bin/bash
# =============================================================================
# Build All Components (Backend + Portlet)
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
${BLUE}Build All Components${NC}

${YELLOW}Usage:${NC}
  $0 [OPTIONS]

${YELLOW}Options:${NC}
  --backend-only     Build only the backend service
  --portlet-only     Build only the script portlet
  --no-cache         Docker build without cache (backend only)
  --skip-install     Skip npm install
  -h, --help         Show this help message

${YELLOW}Examples:${NC}
  # Build everything
  $0

  # Build only backend
  $0 --backend-only

  # Build only portlet
  $0 --portlet-only

  # Clean build (no cache)
  $0 --no-cache

${YELLOW}Components:${NC}
  - Backend Service (packages/server-v1)
  - Script Portlet (packages/portlet-v1)
EOF
}

# Parse arguments
BACKEND_ONLY=false
PORTLET_ONLY=false
NO_CACHE=false
SKIP_INSTALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --backend-only) BACKEND_ONLY=true; shift ;;
    --portlet-only) PORTLET_ONLY=true; shift ;;
    --no-cache) NO_CACHE=true; shift ;;
    --skip-install) SKIP_INSTALL=true; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) log_error "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Determine what to build
BUILD_BACKEND=true
BUILD_PORTLET=true

if [ "$BACKEND_ONLY" = true ]; then
  BUILD_PORTLET=false
fi

if [ "$PORTLET_ONLY" = true ]; then
  BUILD_BACKEND=false
fi

cd "$PROJECT_ROOT"

echo ""
log_info "======================================"
log_info "Building DAM Demo Components"
log_info "======================================"
echo ""

# Build Backend Service
if [ "$BUILD_BACKEND" = true ]; then
  log_info "Building Backend Service..."
  
  if [ ! -d "packages/server-v1" ]; then
    log_error "Backend directory not found: packages/server-v1"
    exit 1
  fi
  
  cd packages/server-v1
  
  # Install dependencies
  if [ "$SKIP_INSTALL" = false ]; then
    if [ ! -d "node_modules" ]; then
      log_info "Installing backend dependencies..."
      npm install
    fi
  fi
  
  # Build TypeScript
  log_info "Compiling TypeScript..."
  npm run build
  
  log_success "Backend service built successfully"
  echo ""
  
  cd "$PROJECT_ROOT"
fi

# Build Script Portlet
if [ "$BUILD_PORTLET" = true ]; then
  log_info "Building Script Portlet..."
  
  if [ ! -d "packages/portlet-v1" ]; then
    log_error "Portlet directory not found: packages/portlet-v1"
    exit 1
  fi
  
  cd packages/portlet-v1
  
  # Install dependencies
  if [ "$SKIP_INSTALL" = false ]; then
    if [ ! -d "node_modules" ]; then
      log_info "Installing portlet dependencies..."
      npm install
    fi
  fi
  
  # Build with Vite
  log_info "Building React app..."
  npm run build
  
  log_success "Script portlet built successfully"
  log_info "Output: packages/portlet-v1/dist/"
  echo ""
  
  cd "$PROJECT_ROOT"
fi

# Summary
echo ""
log_success "======================================"
log_success "Build Complete!"
log_success "======================================"
echo ""

if [ "$BUILD_BACKEND" = true ]; then
  log_info "Backend: packages/server-v1/dist/"
fi

if [ "$BUILD_PORTLET" = true ]; then
  log_info "Portlet: packages/portlet-v1/dist/"
fi

echo ""
log_info "Next steps:"

if [ "$BUILD_BACKEND" = true ]; then
  log_info "  Backend: ./scripts/build.sh --push  (build Docker image)"
  log_info "           ./scripts/deploy.sh         (deploy to Kubernetes)"
fi

if [ "$BUILD_PORTLET" = true ]; then
  log_info "  Portlet: ./scripts/deploy-portlet.sh (deploy to DX Portal)"
fi

echo ""
