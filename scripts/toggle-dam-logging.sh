#!/bin/bash

# Toggle DAM Logging Script
# Enables or disables debug logging for Digital Asset Management (DAM) component
# Based on HCL DX Helm logging configuration: https://help.hcl-software.com/digital-experience/9.5/CF231/deployment/manage/container_configuration/troubleshooting/configure_access_helm_logs/

set -e

# Configuration
RELEASE_NAME="${RELEASE_NAME:-}"
NAMESPACE="${NAMESPACE:-default}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to find the DX release
find_dx_release() {
    if [ -z "$RELEASE_NAME" ]; then
        echo -e "${BLUE}Finding DX release in namespace $NAMESPACE...${NC}"
        RELEASE_NAME=$(helm list -n "$NAMESPACE" -o json | grep -o '"name":"[^"]*","namespace":"[^"]*","revision":"[^"]*","updated":"[^"]*","status":"[^"]*","chart":"dx-demo-pack[^"]*"' | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
        
        if [ -z "$RELEASE_NAME" ]; then
            echo -e "${RED}Error: Could not find DX release with chart 'dx-demo-pack' in namespace $NAMESPACE${NC}"
            echo -e "${YELLOW}Available releases:${NC}"
            helm list -n "$NAMESPACE"
            exit 1
        fi
        
        echo -e "${GREEN}Found DX release: $RELEASE_NAME${NC}"
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $0 <command> [OPTIONS]

Commands:
  enable    Enable debug logging for DAM
  disable   Disable debug logging (set to info level)
  status    Show current logging configuration

Options:
  -n, --namespace NAMESPACE    Kubernetes namespace (default: $NAMESPACE)
  -r, --release RELEASE        Helm release name (default: $RELEASE_NAME)
  -h, --help                   Show this help message

Examples:
  # Enable debug logging
  $0 enable

  # Disable debug logging
  $0 disable

  # Check current status
  $0 status

  # Use custom namespace and release
  $0 enable -n my-namespace -r my-release

Logging Levels:
  - info:  Standard operational logging (default)
  - debug: Detailed diagnostic logging
  - error: Only error messages

Log String Format:
  Digital Asset Management uses the format:
    - "api:server-v1:<pattern>=<level>"
    - "worker:server-v1:<pattern>=<level>"

  Where:
    - api:    API server component
    - worker: Background worker component
    - *:      Wildcard for all sub-components
    - dist:   Distribution-specific logging

EOF
    exit 0
}

# Parse command
COMMAND="${1}"
shift || true

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Validate command
if [[ "$COMMAND" != "enable" && "$COMMAND" != "disable" && "$COMMAND" != "status" ]]; then
    echo -e "${RED}Error: Invalid command '$COMMAND'${NC}"
    show_help
fi

# Check dependencies
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm not found. Please install Helm.${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Find the DX release before proceeding
find_dx_release

# Function to get current logging configuration
get_current_config() {
    echo -e "${BLUE}Fetching current logging configuration...${NC}"
    
    # Check if the global configmap exists
    if kubectl get configmap "${RELEASE_NAME}-global" -n "$NAMESPACE" &> /dev/null; then
        echo -e "${GREEN}Current DAM logging configuration from ${RELEASE_NAME}-global ConfigMap:${NC}"
        LOG_CONFIG=$(kubectl get configmap "${RELEASE_NAME}-global" -n "$NAMESPACE" -o jsonpath='{.data.log\.digitalAssetManagement}' 2>/dev/null)
        if [ -n "$LOG_CONFIG" ]; then
            echo "  $LOG_CONFIG"
        else
            echo "  Not configured"
        fi
        echo ""
    else
        echo -e "${YELLOW}Global ConfigMap not found. Logging may be using default values.${NC}"
    fi
    
    # Get values from helm
    echo -e "${BLUE}Current Helm values for DAM logging:${NC}"
    helm get values "$RELEASE_NAME" -n "$NAMESPACE" 2>/dev/null | grep -A 5 "digitalAssetManagement:" || echo "  Not configured in Helm values"
    echo ""
}

# Function to enable debug logging
enable_debug() {
    echo "=========================================="
    echo "Enabling Debug Logging for DAM"
    echo "=========================================="
    echo "Release: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    LOG_VALUE="api:server-v1:*=debug,worker:server-v1:*=debug,api:server-v1:dist=debug,worker:server-v1:dist=debug"
    
    echo -e "${YELLOW}Applying debug logging configuration...${NC}"
    echo "log.digitalAssetManagement=$LOG_VALUE"
    echo ""
    
    # Apply the configuration directly to ConfigMap
    kubectl patch configmap "${RELEASE_NAME}-global" \
        -n "$NAMESPACE" \
        --type merge \
        -p "{\"data\":{\"log.digitalAssetManagement\":\"$LOG_VALUE\"}}"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Debug logging enabled successfully!${NC}"
        echo ""
        echo -e "${YELLOW}Note: The logging configuration is applied without pod restart.${NC}"
        echo -e "${YELLOW}Changes should take effect within a few seconds.${NC}"
        echo ""
        echo "To view logs:"
        echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=dam-plugin -f"
        echo ""
    else
        echo -e "${RED}❌ Failed to enable debug logging${NC}"
        exit 1
    fi
}

# Function to disable debug logging (set to info)
disable_debug() {
    echo "=========================================="
    echo "Disabling Debug Logging for DAM"
    echo "=========================================="
    echo "Release: $RELEASE_NAME"
    echo "Namespace: $NAMESPACE"
    echo ""
    
    LOG_VALUE="api:server-v1:*=info,worker:server-v1:*=info"
    
    echo -e "${YELLOW}Applying info logging configuration...${NC}"
    echo "log.digitalAssetManagement=$LOG_VALUE"
    echo ""
    
    # Apply the configuration directly to ConfigMap
    kubectl patch configmap "${RELEASE_NAME}-global" \
        -n "$NAMESPACE" \
        --type merge \
        -p "{\"data\":{\"log.digitalAssetManagement\":\"$LOG_VALUE\"}}"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Debug logging disabled (set to info level)!${NC}"
        echo ""
        echo -e "${YELLOW}Note: The logging configuration is applied without pod restart.${NC}"
        echo -e "${YELLOW}Changes should take effect within a few seconds.${NC}"
        echo ""
    else
        echo -e "${RED}❌ Failed to disable debug logging${NC}"
        exit 1
    fi
}

# Execute command
case "$COMMAND" in
    enable)
        enable_debug
        get_current_config
        ;;
    disable)
        disable_debug
        get_current_config
        ;;
    status)
        get_current_config
        ;;
esac

echo "=========================================="
echo "Additional Commands:"
echo "=========================================="
echo ""
echo "View all DAM logs:"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=dam-plugin --all-containers -f"
echo ""
echo "View specific pod logs:"
echo "  kubectl logs -n $NAMESPACE <pod-name> -f"
echo ""
echo "View logs from all DX components:"
echo "  kubectl logs -n $NAMESPACE -l release=$RELEASE_NAME --tail=-1 --all-containers"
echo ""
