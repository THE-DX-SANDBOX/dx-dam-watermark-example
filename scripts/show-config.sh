#!/bin/bash
# =============================================================================
# DAM Demo Configuration Viewer
# Shows all configuration parameters for the application
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${WHITE}  $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

print_section() {
  echo ""
  echo -e "${YELLOW}▶ $1${NC}"
  echo -e "${DIM}───────────────────────────────────────────────────────────────────────────────${NC}"
}

print_value() {
  local key="$1"
  local value="$2"
  local default="$3"
  
  if [ -z "$value" ]; then
    echo -e "  ${BLUE}$key${NC} = ${DIM}(not set, default: $default)${NC}"
  else
    echo -e "  ${BLUE}$key${NC} = ${GREEN}$value${NC}"
  fi
}

print_header "DAM DEMO APPLICATION CONFIGURATION"

# =============================================================================
# Load .env file if exists
# =============================================================================
if [ -f "$PROJECT_ROOT/.env" ]; then
  set -a
  source "$PROJECT_ROOT/.env"
  set +a
  echo -e "${DIM}  Loaded from: $PROJECT_ROOT/.env${NC}"
else
  echo -e "${YELLOW}  ⚠ No .env file found at $PROJECT_ROOT/.env${NC}"
fi

# =============================================================================
# Kubernetes Configuration
# =============================================================================
print_section "Kubernetes Configuration"
print_value "NAMESPACE" "$NAMESPACE" "default"
print_value "RELEASE_NAME" "$RELEASE_NAME" "dam-plugin"
print_value "KUBECONFIG" "$KUBECONFIG" "\$HOME/.kube/config"
print_value "DEPLOYMENT_NAME" "$DEPLOYMENT_NAME" "dam-plugin"

# =============================================================================
# Docker Registry Configuration
# =============================================================================
print_section "Docker Registry Configuration"
print_value "DOCKER_REGISTRY" "$DOCKER_REGISTRY" "<registry-host>/<repository>"
print_value "IMAGE_NAME" "$IMAGE_NAME" "dam-plugin"
print_value "IMAGE_TAG" "$IMAGE_TAG" "latest"

# =============================================================================
# Helm Configuration
# =============================================================================
print_section "Helm Configuration"
print_value "HELM_CHART_PATH" "$HELM_CHART_PATH" "./helm/dam-plugin"
print_value "VALUES_FILE" "$VALUES_FILE" "(none)"

# =============================================================================
# Server Configuration
# =============================================================================
print_section "Server Configuration"
print_value "PORT" "$PORT" "3000"
print_value "HOST" "$HOST" "0.0.0.0"
print_value "NODE_ENV" "$NODE_ENV" "development"
print_value "LOG_LEVEL" "$LOG_LEVEL" "info"

# =============================================================================
# Database Configuration
# =============================================================================
print_section "Database Configuration"
print_value "DB_HOST" "$DB_HOST" "localhost"
print_value "DB_PORT" "$DB_PORT" "5432"
print_value "DB_NAME" "$DB_NAME" "dam_demo"
print_value "DB_USER" "$DB_USER" "postgres"
if [ -n "$DB_PASSWORD" ]; then
  echo -e "  ${BLUE}DB_PASSWORD${NC} = ${GREEN}********${NC}"
else
  echo -e "  ${BLUE}DB_PASSWORD${NC} = ${DIM}(not set)${NC}"
fi

# =============================================================================
# DX Portal Configuration
# =============================================================================
print_section "DX Portal Configuration (Script Portlet Deployment)"
print_value "DX_PROTOCOL" "$DX_PROTOCOL" "https"
print_value "DX_HOSTNAME" "$DX_HOSTNAME" "(required)"
print_value "DX_PORT" "$DX_PORT" "443"
print_value "DX_USERNAME" "$DX_USERNAME" "(required)"
if [ -n "$DX_PASSWORD" ]; then
  echo -e "  ${BLUE}DX_PASSWORD${NC} = ${GREEN}********${NC}"
else
  echo -e "  ${BLUE}DX_PASSWORD${NC} = ${DIM}(not set)${NC}"
fi

# =============================================================================
# Script Portlet Configuration
# =============================================================================
print_section "Script Portlet Configuration"
print_value "WCM_CONTENT_NAME" "$WCM_CONTENT_NAME" "DAM Demo"
print_value "WCM_SITE_AREA" "$WCM_SITE_AREA" "Script Application Library/Script Applications/"
print_value "PORTLET_MAIN_HTML" "$PORTLET_MAIN_HTML" "index.html"
print_value "PORTLET_BUILD_DIR" "$PORTLET_BUILD_DIR" "./packages/portlet-v1/dist"

# =============================================================================
# API Configuration
# =============================================================================
print_section "API Configuration"
print_value "VITE_API_BASE_URL" "$VITE_API_BASE_URL" "http://localhost:3000 (dev) / https://<dx-hostname>/dam-demo-api (prod)"
print_value "API_TIMEOUT" "$API_TIMEOUT" "30000"

# =============================================================================
# Port Forwarding Configuration
# =============================================================================
print_section "Port Forwarding Configuration"
print_value "LOCAL_PORT" "$LOCAL_PORT" "3000"
print_value "REMOTE_PORT" "$REMOTE_PORT" "3000"

# =============================================================================
# DAM Integration Configuration
# =============================================================================
print_section "DAM Integration Configuration"
print_value "DAM_CONFIGMAP_SUFFIX" "$DAM_CONFIGMAP_SUFFIX" "digital-asset-management"
print_value "DAM_LOG_LEVEL" "$DAM_LOG_LEVEL" "debug"
print_value "PLUGIN_CONFIG_FILE" "$PLUGIN_CONFIG_FILE" "./plugin-config.json"
print_value "PLUGIN_URL" "$PLUGIN_URL" "(auto-detected)"

# =============================================================================
# Current Kubernetes Status (if kubectl available)
# =============================================================================
if command -v kubectl &> /dev/null; then
  print_section "Current Kubernetes Status (namespace: ${NAMESPACE:-default})"
  
  NS="${NAMESPACE:-default}"
  
  # Check dam-plugin pods
  echo -e "  ${MAGENTA}DAM Plugin Pods:${NC}"
  kubectl get pods -n "$NS" 2>/dev/null | grep -E "dam-plugin|dam-demo" | while read line; do
    echo -e "    $line"
  done
  
  # Check PostgreSQL pod
  echo ""
  echo -e "  ${MAGENTA}PostgreSQL Pod:${NC}"
  kubectl get pods -n "$NS" 2>/dev/null | grep -i postgres | while read line; do
    echo -e "    $line"
  done
  
  # Check port forwarding processes
  echo ""
  echo -e "  ${MAGENTA}Active Port Forwards:${NC}"
  pf=$(ps aux 2>/dev/null | grep "kubectl port-forward" | grep -v grep)
  if [ -n "$pf" ]; then
    echo "$pf" | while read line; do
      echo -e "    ${GREEN}✓${NC} $(echo $line | awk '{for(i=11;i<=NF;i++) printf $i" "}')"
    done
  else
    echo -e "    ${DIM}(none active)${NC}"
  fi
fi

# =============================================================================
# Quick Commands Reference
# =============================================================================
print_section "Quick Commands"
echo -e "  ${DIM}# Start frontend dev server${NC}"
echo -e "  cd packages/portlet-v1 && npm run dev"
echo ""
echo -e "  ${DIM}# Start backend server${NC}"
echo -e "  cd packages/server-v1 && npm run dev"
echo ""
echo -e "  ${DIM}# Port forward to PostgreSQL${NC}"
echo -e "  kubectl port-forward -n ${NAMESPACE:-default} svc/${NAMESPACE:-default}-dx-postgres 5432:5432"
echo ""
echo -e "  ${DIM}# Deploy Script Portlet${NC}"
echo -e "  ./scripts/deploy-portlet.sh --build"
echo ""
echo -e "  ${DIM}# Build and push Docker image${NC}"
echo -e "  ./scripts/build-and-deploy.sh"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
