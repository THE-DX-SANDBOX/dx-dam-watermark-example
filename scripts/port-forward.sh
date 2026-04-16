#!/bin/bash
#
# Port forward to DAM Plugin pod
#

set -e

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Port forward to DAM Plugin for local access

Environment Variables (from .env):
  NAMESPACE         Kubernetes namespace (default: $NAMESPACE)
  DEPLOYMENT_NAME   Deployment name (default: $DEPLOYMENT_NAME)
  LOCAL_PORT        Local port (default: $LOCAL_PORT)
  REMOTE_PORT       Remote port (default: $REMOTE_PORT)

Optional Arguments:
  -n, --namespace NAMESPACE    Override namespace from .env
  -l, --local-port PORT        Override local port from .env
  --remote-port PORT           Override remote port from .env
  -d, --deployment NAME        Override deployment name from .env
  -h, --help                   Show this help message

Examples:
  # Port forward using .env configuration
  $0

  # Override ports
  $0 -l 8080 -r 3000

  # Different namespace
  $0 -n production

  # Access plugin at http://localhost:\$LOCAL_PORT after running

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -l|--local-port)
            LOCAL_PORT="$2"
            shift 2
            ;;
        --remote-port)
            REMOTE_PORT="$2"
            shift 2
            ;;
        -d|--deployment)
            DEPLOYMENT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            # Backward compatibility: positional arguments
            if [ -z "$NAMESPACE_SET" ]; then
                NAMESPACE="$1"
                NAMESPACE_SET=true
            elif [ -z "$LOCAL_PORT_SET" ]; then
                LOCAL_PORT="$1"
                LOCAL_PORT_SET=true
            elif [ -z "$REMOTE_PORT_SET" ]; then
                REMOTE_PORT="$1"
                REMOTE_PORT_SET=true
            elif [ -z "$DEPLOYMENT_SET" ]; then
                DEPLOYMENT_NAME="$1"
                DEPLOYMENT_SET=true
            else
                log_error "Unknown option: $1"
                show_help
            fi
            shift
            ;;
    esac
done

echo "=========================================="
echo "DAM-Demo Port Forwarding"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Deployment: $DEPLOYMENT_NAME"
echo "Local Port: $LOCAL_PORT"
echo "Remote Port: $REMOTE_PORT"
echo "=========================================="
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed"
    exit 1
fi

# Check if the deployment exists
log_info "Checking if deployment exists..."
if ! kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} &> /dev/null; then
    log_error "Deployment '${DEPLOYMENT_NAME}' not found in namespace '${NAMESPACE}'"
    echo ""
    echo "Available deployments:"
    kubectl get deployments -n ${NAMESPACE}
    exit 1
fi

# Wait for pod to be ready
log_info "Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=${DEPLOYMENT_NAME} -n ${NAMESPACE} --timeout=60s

# Get the pod name
POD_NAME=$(kubectl get pod -l app.kubernetes.io/name=${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
log_success "Found pod: ${POD_NAME}"

# Check if port is already in use
if lsof -Pi :${LOCAL_PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}Error: Port ${LOCAL_PORT} is already in use${NC}"
    echo "Process using port ${LOCAL_PORT}:"
    lsof -Pi :${LOCAL_PORT} -sTCP:LISTEN
    exit 1
fi

# Start port forwarding
echo ""
echo -e "${GREEN}Starting port forwarding...${NC}"
echo -e "Access the application at: ${YELLOW}http://localhost:${LOCAL_PORT}${NC}"
echo -e "OpenAPI docs: ${YELLOW}http://localhost:${LOCAL_PORT}/openapi/openapi.json${NC}"
echo -e ""
echo -e "${YELLOW}Press Ctrl+C to stop port forwarding${NC}"
echo ""

# Trap to cleanup on exit
cleanup() {
    echo -e "\n${GREEN}Stopping port forwarding...${NC}"
    exit 0
}
trap cleanup INT TERM

# Start port forwarding (this blocks)
kubectl port-forward -n ${NAMESPACE} ${POD_NAME} ${LOCAL_PORT}:${REMOTE_PORT}
