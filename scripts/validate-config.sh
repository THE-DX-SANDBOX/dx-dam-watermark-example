#!/bin/bash
#
# Validate .env configuration
#

set -e

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate DAM-Demo configuration and check dependencies

This script checks:
  - .env file existence and values
  - Required tools (kubectl, helm, docker, node, jq)
  - Helm chart and plugin config files
  - Kubernetes namespace availability

Optional Arguments:
  -h, --help    Show this help message

Examples:
  # Validate configuration
  $0

  # View all current settings and validation results
  $0

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

echo "=========================================="
echo "DAM-Demo Configuration Validation"
echo "=========================================="
echo ""

# Check if .env exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    log_success ".env file found at: $PROJECT_ROOT/.env"
else
    log_warning ".env file not found at: $PROJECT_ROOT/.env"
    echo "  Using default values from config.sh"
fi

echo ""
echo "Current Configuration:"
echo "=========================================="
echo ""

echo "Kubernetes:"
echo "  NAMESPACE:           $NAMESPACE"
echo "  RELEASE_NAME:        $RELEASE_NAME"
echo "  KUBECONFIG:          $KUBECONFIG"
echo ""

echo "Docker:"
echo "  DOCKER_REGISTRY:     $DOCKER_REGISTRY"
echo "  IMAGE_NAME:          $IMAGE_NAME"
echo "  IMAGE_TAG:           $IMAGE_TAG"
echo "  Full Image:          ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
echo ""

echo "Helm:"
echo "  HELM_CHART_PATH:     $HELM_CHART_PATH"
echo "  VALUES_FILE:         ${VALUES_FILE:-<default>}"
echo ""

echo "Port Forwarding:"
echo "  DEPLOYMENT_NAME:     $DEPLOYMENT_NAME"
echo "  LOCAL_PORT:          $LOCAL_PORT"
echo "  REMOTE_PORT:         $REMOTE_PORT"
echo ""

echo "Plugin:"
echo "  PLUGIN_CONFIG_FILE:  $PLUGIN_CONFIG_FILE"
echo "  PLUGIN_URL:          ${PLUGIN_URL:-<auto-detect>}"
echo ""

echo "DAM:"
echo "  DAM_CONFIGMAP_SUFFIX: $DAM_CONFIGMAP_SUFFIX"
echo "  DAM_LOG_LEVEL:       $DAM_LOG_LEVEL"
echo ""

# Validation checks
echo "=========================================="
echo "Validation Checks:"
echo "=========================================="
echo ""

ERRORS=0

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | head -n1 || echo "Unknown")
    log_success "kubectl: $KUBECTL_VERSION"
else
    log_error "kubectl: Not installed"
    ((ERRORS++))
fi

# Check helm
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null || echo "Unknown")
    log_success "helm: $HELM_VERSION"
else
    log_error "helm: Not installed"
    ((ERRORS++))
fi

# Check docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker version --format '{{.Client.Version}}' 2>/dev/null || echo "Unknown")
    log_success "docker: v$DOCKER_VERSION"
else
    log_error "docker: Not installed"
    ((ERRORS++))
fi

# Check node
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version 2>/dev/null || echo "Unknown")
    log_success "node: $NODE_VERSION"
else
    log_error "node: Not installed"
    ((ERRORS++))
fi

# Check jq
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version 2>/dev/null || echo "Unknown")
    log_success "jq: $JQ_VERSION"
else
    log_error "jq: Not installed"
    ((ERRORS++))
fi

echo ""

# Check Helm chart
if [ -f "$PROJECT_ROOT/$HELM_CHART_PATH/Chart.yaml" ]; then
    log_success "Helm chart found at: $HELM_CHART_PATH"
else
    log_error "Helm chart not found at: $HELM_CHART_PATH"
    ((ERRORS++))
fi

# Check plugin config
if [ -f "$PROJECT_ROOT/$PLUGIN_CONFIG_FILE" ]; then
    log_success "Plugin config found at: $PLUGIN_CONFIG_FILE"
    if command -v node &> /dev/null; then
        PLUGIN_NAME=$(cd "$PROJECT_ROOT" && node -p "require('$PLUGIN_CONFIG_FILE').pluginName" 2>/dev/null || echo "ERROR")
        if [ "$PLUGIN_NAME" != "ERROR" ]; then
            echo "  Plugin Name: $PLUGIN_NAME"
        fi
    fi
else
    log_error "Plugin config not found at: $PLUGIN_CONFIG_FILE"
    ((ERRORS++))
fi

# Check namespace exists
if kubectl get namespace "$NAMESPACE" &> /dev/null 2>&1; then
    log_success "Namespace '$NAMESPACE' exists in cluster"
else
    log_warning "Namespace '$NAMESPACE' not found in cluster"
    echo "  Create with: kubectl create namespace $NAMESPACE"
fi

echo ""
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    log_success "Configuration is valid!"
else
    log_error "Found $ERRORS error(s) in configuration"
    exit 1
fi
echo "=========================================="
