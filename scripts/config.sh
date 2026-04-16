#!/bin/bash
#
# Common configuration for all DAM-Demo scripts
# Sources environment variables from .env when present
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source .env file if it exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Export all variables from .env
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

load_environment_file() {
    local environment_name="$1"
    local environment_file="$PROJECT_ROOT/.env.${environment_name}"

    if [ ! -f "$environment_file" ]; then
        log_error "Environment file not found: $environment_file"
        echo "Create it from .env.${environment_name}.example or use the root .env file instead."
        exit 1
    fi

    set -a
    source "$environment_file"
    set +a
    export LOADED_ENV="$environment_name"
}

# Default values (can be overridden by .env or command line)
: ${NAMESPACE:="default"}
: ${RELEASE_NAME:="dam-plugin"}
: ${DOCKER_REGISTRY:=""}
: ${HELM_REGISTRY:=""}
: ${IMAGE_NAME:="dam-plugin"}
: ${IMAGE_TAG:="latest"}
: ${HELM_CHART_PATH:="./helm/dam-plugin"}
: ${VALUES_FILE:=""}
: ${KUBECONFIG:="$HOME/.kube/config"}
: ${LOCAL_PORT:="3000"}
: ${REMOTE_PORT:="3000"}
: ${DEPLOYMENT_NAME:="dam-plugin"}
: ${PLUGIN_CONFIG_FILE:="./plugin-config.json"}
: ${PLUGIN_URL:=""}
: ${DAM_CONFIGMAP_SUFFIX:="digital-asset-management"}
: ${DAM_LOG_LEVEL:="debug"}

is_placeholder_value() {
    case "$1" in
        ""|*"<"*">"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_config_value() {
    local name="$1"
    local value="$2"

    if is_placeholder_value "$value"; then
        log_error "Required configuration '$name' is not set"
        echo "Set it in your local .env file or pass it explicitly before running this command."
        exit 1
    fi
}

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Helper function to print colored messages
log_info() {
    echo -e "${BLUE}ℹ️${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC}  $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

# Export functions for use in other scripts
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f is_placeholder_value
export -f require_config_value
export -f load_environment_file
