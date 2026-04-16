#!/bin/bash
#
# Undeploy DAM Plugin from Kubernetes
#

set -e

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Undeploy (uninstall) DAM Plugin from Kubernetes

Environment Variables (from .env):
  NAMESPACE       Kubernetes namespace (default: $NAMESPACE)
  RELEASE_NAME    Helm release name (default: $RELEASE_NAME)

Optional Arguments:
  -n, --namespace NAMESPACE    Override namespace from .env
  -r, --release RELEASE        Override release name from .env
  -y, --yes                    Skip confirmation prompt
  -h, --help                   Show this help message

Examples:
  # Undeploy using .env configuration
  $0

  # Undeploy from different namespace
  $0 -n production

  # Undeploy without confirmation
  $0 -y

  # Undeploy specific release
  $0 -r my-dam-plugin

EOF
    exit 0
}

# Parse command line arguments
SKIP_CONFIRM=false

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
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

cd "$PROJECT_ROOT"

echo "=================================="
echo "Undeploying DAM Plugin"
echo "=================================="
echo "Namespace: ${NAMESPACE}"
echo "Release: ${RELEASE_NAME}"
echo ""

# Confirmation
if [ "$SKIP_CONFIRM" = false ]; then
    read -p "Are you sure you want to uninstall the Helm release? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_warning "Undeploy cancelled"
        exit 0
    fi
fi

# Uninstall Helm release
log_info "Uninstalling Helm Release..."
if helm list -n ${NAMESPACE} | grep -q ${RELEASE_NAME}; then
    helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}
    log_success "Helm release '${RELEASE_NAME}' uninstalled from namespace '${NAMESPACE}'"
else
    log_warning "Helm release '${RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
fi

echo ""
echo "=================================="
log_success "Undeploy Complete"
echo "=================================="
echo ""
echo "NOTE: Namespace '${NAMESPACE}' was NOT deleted."
echo "      Resources remain available for future deployments."
echo ""
echo "If you need to delete the namespace manually:"
echo "  kubectl delete namespace ${NAMESPACE}"
echo ""
