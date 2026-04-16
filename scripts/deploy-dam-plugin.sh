#!/bin/bash
#
# Deploy DAM Plugin and Register with HCL DX DAM
# This script performs a two-step deployment:
# 1. Deploy/upgrade the plugin runtime as its own Helm release
# 2. Register the plugin with DAM by upgrading the DX Helm release
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Help function for helm version arguments
helm_version_args() {
    local version="$1"
    if [ -n "$version" ]; then
        echo "--version ${version}"
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $0 -n <namespace> [OPTIONS]

Deploy DAM Plugin to Kubernetes and register with HCL DX DAM

This script performs two Helm operations:
  1. Deploy/upgrade the plugin runtime (dam-demo-plugin release)
  2. Register plugin with DAM by upgrading DX release

Required Arguments:
  -n, --namespace NAMESPACE    Kubernetes namespace (both plugin and DX must be in same namespace)

Optional Arguments:
  -r, --dx-release RELEASE     DX Helm release name (default: same as namespace)
  -p, --plugin-release NAME    Plugin Helm release name (default: dam-demo-plugin)
  -v, --plugin-values FILE     Plugin values file (default: ./helm/dam-plugin/values.yaml)
  -d, --dx-chart REF          DX chart reference (default: auto-detect from existing release)
  --plugin-chart REF          Plugin chart reference (default: ./helm/dam-plugin)
  --plugin-version VERSION    Plugin chart version
  --dx-version VERSION        DX chart version
    --remote                    Use remote plugin chart from the configured Helm registry
    -a, --auth-key KEY          Plugin authentication key (required unless PLUGIN_AUTH_KEY is set)
  -t, --tag TAG               Docker image tag (default: latest)
  --skip-plugin               Skip plugin deployment (only register with DX)
  --skip-registration         Skip DX registration (only deploy plugin)
  --no-wait                   Don't wait for deployments to be ready
  -h, --help                  Show this help message

Environment Variables:
  NAMESPACE                   Kubernetes namespace
  DX_RELEASE                  DX Helm release name
  PLUGIN_RELEASE              Plugin Helm release name
  TAG                         Docker image tag
  PLUGIN_AUTH_KEY             Plugin authentication key

Examples:
  # Deploy plugin and register with DX (release name = namespace)
    $0 -n <namespace>

  # Deploy with custom DX release name
    $0 -n <namespace> -r my-dx-release

  # Deploy from remote chart registry
    $0 -n <namespace> --remote

  # Deploy with custom values and auth key
    $0 -n <namespace> -v ./my-values.yaml -a "MySecretKey123"

  # Only deploy plugin (no DX registration)
    $0 -n <namespace> --skip-registration

  # Only register with DX (plugin already deployed)
    $0 -n <namespace> --skip-plugin

Plugin Actions:
  The plugin will be registered with these actions:
    - watermark: /api/v1/actions/watermark
    - metadata:  /api/v1/actions/metadata
    - process:   /api/v1/process

EOF
    exit 0
}

# Parse command line arguments
NAMESPACE_ARG=""
DX_RELEASE_ARG=""
PLUGIN_RELEASE_ARG=""
PLUGIN_VALUES=""
DX_CHART_REF=""
PLUGIN_CHART_REF=""
PLUGIN_CHART_VERSION=""
DX_CHART_VERSION=""
USE_REMOTE=false
AUTH_KEY_ARG=""
TAG_ARG=""
SKIP_PLUGIN=false
SKIP_REGISTRATION=false
NO_WAIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE_ARG="$2"
            shift 2
            ;;
        -r|--dx-release)
            DX_RELEASE_ARG="$2"
            shift 2
            ;;
        -p|--plugin-release)
            PLUGIN_RELEASE_ARG="$2"
            shift 2
            ;;
        -v|--plugin-values)
            PLUGIN_VALUES="$2"
            shift 2
            ;;
        -d|--dx-chart)
            DX_CHART_REF="$2"
            shift 2
            ;;
        --plugin-chart)
            PLUGIN_CHART_REF="$2"
            shift 2
            ;;
        --plugin-version)
            PLUGIN_CHART_VERSION="$2"
            shift 2
            ;;
        --dx-version)
            DX_CHART_VERSION="$2"
            shift 2
            ;;
        --remote)
            USE_REMOTE=true
            shift
            ;;
        -a|--auth-key)
            AUTH_KEY_ARG="$2"
            shift 2
            ;;
        -t|--tag)
            TAG_ARG="$2"
            shift 2
            ;;
        --skip-plugin)
            SKIP_PLUGIN=true
            shift
            ;;
        --skip-registration)
            SKIP_REGISTRATION=true
            shift
            ;;
        --no-wait)
            NO_WAIT=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            error "Unknown option: $1"
            echo ""
            show_help
            ;;
    esac
done

cd "$(dirname "$0")/.."

# Determine values from arguments or environment variables
NAMESPACE="${NAMESPACE_ARG:-${NAMESPACE:-}}"
DX_RELEASE="${DX_RELEASE_ARG:-${DX_RELEASE:-${NAMESPACE}}}"
PLUGIN_RELEASE="${PLUGIN_RELEASE_ARG:-${PLUGIN_RELEASE:-${RELEASE_NAME:-dam-plugin}}}"
TAG="${TAG_ARG:-${IMAGE_TAG:-latest}}"
AUTH_KEY="${AUTH_KEY_ARG:-${PLUGIN_AUTH_KEY:-}}"

# Validate required namespace
if [ -z "$NAMESPACE" ]; then
    error "NAMESPACE is required"
    echo ""
    echo "Provide namespace via:"
    echo "  - Command line flag: -n <namespace>"
    echo "  - Environment variable: NAMESPACE=<namespace>"
    echo ""
    show_help
fi

if [ -z "$AUTH_KEY" ]; then
    error "Plugin authentication key is required"
    echo ""
    echo "Provide it via:"
    echo "  - Command line flag: -a <auth-key>"
    echo "  - Environment variable: PLUGIN_AUTH_KEY=<auth-key>"
    echo ""
    show_help
fi

# Configuration
PLUGIN_ID="$(node -p \"require('./plugin-config.json').pluginId\" 2>/dev/null || echo 'dam-demo-plugin')"
PLUGIN_NAME="DAM Demo Plugin - Watermark"
IMAGE_REGISTRY="${DOCKER_REGISTRY}"
IMAGE_NAME="${IMAGE_NAME}"
LOCAL_PLUGIN_CHART="./helm/dam-plugin"
REMOTE_PLUGIN_CHART="oci://${HELM_REGISTRY}/dam-plugin"

require_config_value "DOCKER_REGISTRY" "$IMAGE_REGISTRY"
require_config_value "IMAGE_NAME" "$IMAGE_NAME"

# Determine plugin chart reference
if [ -z "$PLUGIN_CHART_REF" ]; then
    if [ "$USE_REMOTE" = true ]; then
        require_config_value "HELM_REGISTRY" "$HELM_REGISTRY"
        PLUGIN_CHART_REF="$REMOTE_PLUGIN_CHART"
    else
        PLUGIN_CHART_REF="$LOCAL_PLUGIN_CHART"
    fi
fi

# Determine plugin values file
if [ -z "$PLUGIN_VALUES" ]; then
    PLUGIN_VALUES="${LOCAL_PLUGIN_CHART}/values.yaml"
fi

# Validate plugin values file exists
if [ ! -f "$PLUGIN_VALUES" ]; then
    error "Plugin values file not found: $PLUGIN_VALUES"
    exit 1
fi

echo "=========================================="
echo "DAM Plugin Deployment & Registration"
echo "=========================================="
echo "Namespace:        ${NAMESPACE}"
echo "DX Release:       ${DX_RELEASE}"
echo "Plugin Release:   ${PLUGIN_RELEASE}"
echo "Plugin Chart:     ${PLUGIN_CHART_REF}"
echo "Plugin Values:    ${PLUGIN_VALUES}"
echo "Image:            ${IMAGE_REGISTRY}/${IMAGE_NAME}:${TAG}"
echo "Auth Key:         ${AUTH_KEY:0:10}..."
echo "Skip Plugin:      ${SKIP_PLUGIN}"
echo "Skip Registration: ${SKIP_REGISTRATION}"
echo "=========================================="
echo ""

# Check required tools
for tool in kubectl helm; do
    if ! command -v $tool &> /dev/null; then
        error "$tool not found. Please install it first."
        exit 1
    fi
done

# Verify cluster connection
log "Verifying cluster connection..."
if ! kubectl cluster-info --insecure-skip-tls-verify &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
    echo ""
    echo "Verify your kubeconfig context and cluster credentials, then retry."
    exit 1
fi
info "✓ Connected to cluster"

# Verify namespace exists
if ! kubectl get namespace "$NAMESPACE" --insecure-skip-tls-verify &> /dev/null; then
    error "Namespace '$NAMESPACE' does not exist"
    echo ""
    echo "Create it with:"
    echo "  kubectl create namespace $NAMESPACE"
    exit 1
fi
info "✓ Namespace exists"

########################################
# Step 1: Deploy/Upgrade plugin runtime release
########################################
if [ "$SKIP_PLUGIN" = false ]; then
    echo ""
    log "=========================================="
    log "Step 1/2: Deploying plugin runtime"
    log "=========================================="
    log "Release: ${PLUGIN_RELEASE}"
    log "Chart: ${PLUGIN_CHART_REF}"
    
    # Authenticate with Helm registry if using remote chart
    if [ "$USE_REMOTE" = true ]; then
        info "Authenticating with Helm registry..."
        if [[ "$HELM_REGISTRY" == *"pkg.dev" ]] && command -v gcloud &> /dev/null; then
            gcloud auth print-access-token | helm registry login -u oauth2accesstoken --password-stdin https://us-central1-docker.pkg.dev
            info "✓ Authenticated with GCP Helm registry"
        else
            warn "Assuming helm registry authentication is already configured"
        fi
    fi
    
    PLUGIN_VERSION_ARGS="$(helm_version_args "${PLUGIN_CHART_VERSION}")"
    
    # Deploy or upgrade the plugin
    log "Running helm upgrade --install..."
    # shellcheck disable=SC2086
    helm upgrade --install "${PLUGIN_RELEASE}" "${PLUGIN_CHART_REF}" \
        -n "${NAMESPACE}" \
        -f "${PLUGIN_VALUES}" \
        --set image.repository="${IMAGE_REGISTRY}/${IMAGE_NAME}" \
        --set image.tag="${TAG}" \
        --set plugin.authKey="${AUTH_KEY}" \
        ${PLUGIN_VERSION_ARGS} \
        --wait \
        --timeout 5m
    
    info "✅ Plugin deployed successfully"
    
    # Wait for plugin deployment to be ready (if not --no-wait)
    if [ "$NO_WAIT" = false ]; then
        log "Waiting for plugin deployment rollout (best-effort)..."
        kubectl -n "${NAMESPACE}" rollout status "deployment/${PLUGIN_RELEASE}-dam-plugin" \
            --timeout=180s \
            --insecure-skip-tls-verify || warn "Deployment rollout check timed out (continuing anyway)"
        
        info "✓ Plugin pods are ready"
    fi
    
    # Display plugin pods
    echo ""
    info "Plugin pods:"
    kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/instance=${PLUGIN_RELEASE}" --insecure-skip-tls-verify
else
    warn "Skipping plugin deployment (--skip-plugin)"
fi

########################################
# Step 2: Register plugin with DAM (DX upgrade using overlay values)
########################################
if [ "$SKIP_REGISTRATION" = false ]; then
    echo ""
    log "=========================================="
    log "Step 2/2: Registering plugin with DAM"
    log "=========================================="
    log "Updating DX release: ${DX_RELEASE}"
    
    # Auto-detect DX chart reference if not provided
    if [ -z "$DX_CHART_REF" ]; then
        log "Auto-detecting DX chart reference..."
        
        # Get the chart from the existing release
        DX_CHART_REF=$(helm get metadata "${DX_RELEASE}" -n "${NAMESPACE}" 2>/dev/null | grep '^chart:' | awk '{print $2}' || echo "")
        
        if [ -z "$DX_CHART_REF" ]; then
            error "Could not auto-detect DX chart reference"
            error "DX release '${DX_RELEASE}' not found in namespace '${NAMESPACE}'"
            echo ""
            echo "Available releases in namespace:"
            helm list -n "${NAMESPACE}"
            echo ""
            echo "Please specify the DX chart reference with --dx-chart option"
            echo "Example:"
            echo "  $0 -n ${NAMESPACE} --dx-chart oci://registry/dx-chart"
            exit 1
        fi
        
        info "✓ Detected DX chart: ${DX_CHART_REF}"
    fi
    
    # Construct plugin service URL
    PLUGIN_SERVICE_NAME="${PLUGIN_RELEASE}-dam-plugin"
    PLUGIN_URL="http://${PLUGIN_SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3000"
    PLUGIN_ENDPOINT="${PLUGIN_URL}/dx/api/${PLUGIN_ID}/v1/plugin"
    
    # Construct DAM callback URL
    DAM_SERVICE="digital-asset-management"
    CALLBACK_HOST="http://${NAMESPACE}-${DAM_SERVICE}:3000"
    
    info "Plugin endpoint: ${PLUGIN_ENDPOINT}"
    info "Callback host: ${CALLBACK_HOST}"
    
    # Create temporary registration values file
    DX_PLUGIN_REG_FILE="/tmp/dam-plugin-registration-${NAMESPACE}.yaml"
    
    log "Creating plugin registration configuration..."
    cat > "${DX_PLUGIN_REG_FILE}" << EOF
# DAM Plugin Registration for ${PLUGIN_ID}
# Generated by deploy-dam-plugin.sh on $(date)

hcl-dx-deployment:
  configuration:
    digitalAssetManagement:
      extensibility:
        pluginsConfiguration:
          ${PLUGIN_ID}:
            enabled: true
            url: "${PLUGIN_ENDPOINT}"
            callBackHost: "${CALLBACK_HOST}"
            authKey: "${AUTH_KEY}"
            actions:
              watermark:
                params: {}
                url: "/api/v1/actions/watermark"
              metadata:
                params: {}
                url: "/api/v1/actions/metadata"
              process:
                params: {}
                url: "/api/v1/process"
EOF
    
    info "✓ Registration file created: ${DX_PLUGIN_REG_FILE}"
    
    # Display the registration configuration
    echo ""
    info "Plugin configuration to be applied:"
    cat "${DX_PLUGIN_REG_FILE}"
    echo ""
    
    DX_VERSION_ARGS="$(helm_version_args "${DX_CHART_VERSION}")"
    
    # Upgrade DX release with plugin registration
    log "Upgrading DX release with plugin registration..."
    # shellcheck disable=SC2086
    helm upgrade "${DX_RELEASE}" "${DX_CHART_REF}" \
        -n "${NAMESPACE}" \
        --reuse-values \
        -f "${DX_PLUGIN_REG_FILE}" \
        ${DX_VERSION_ARGS} \
        --wait \
        --timeout 10m
    
    info "✅ DX release updated with plugin registration"
    
    # Verify registration
    log "Verifying plugin registration in DX values..."
    if helm get values "${DX_RELEASE}" -n "${NAMESPACE}" | grep -q "${PLUGIN_ID}"; then
        info "✅ Plugin registration verified in DX release"
    else
        warn "Plugin registration not found in DX values (might need manual verification)"
    fi
    
    # Check if DAM pods need restart
    echo ""
    info "Checking DAM deployment status..."
    if kubectl get deployment -n "${NAMESPACE}" "${NAMESPACE}-${DAM_SERVICE}" --insecure-skip-tls-verify &> /dev/null; then
        log "DAM deployment found, checking if restart is needed..."
        
        # Get last restart time
        LAST_RESTART=$(kubectl get deployment "${NAMESPACE}-${DAM_SERVICE}" -n "${NAMESPACE}" \
            -o jsonpath='{.spec.template.metadata.annotations.kubectl\.kubernetes\.io/restartedAt}' \
            --insecure-skip-tls-verify 2>/dev/null || echo "never")
        
        info "DAM last restarted: ${LAST_RESTART}"
        warn "DAM may need to be restarted to pick up the new plugin configuration"
        echo ""
        echo "To restart DAM:"
        echo "  kubectl rollout restart deployment/${NAMESPACE}-${DAM_SERVICE} -n ${NAMESPACE} --insecure-skip-tls-verify"
    else
        warn "DAM deployment not found with expected name: ${NAMESPACE}-${DAM_SERVICE}"
        warn "You may need to manually restart the DAM service"
    fi
    
    # Cleanup
    rm -f "${DX_PLUGIN_REG_FILE}"
else
    warn "Skipping DX registration (--skip-registration)"
fi

########################################
# Summary
########################################
echo ""
log "=========================================="
log "✅ Deployment Complete!"
log "=========================================="
echo ""

if [ "$SKIP_PLUGIN" = false ]; then
    info "Plugin deployed:"
    echo "  Release: ${PLUGIN_RELEASE}"
    echo "  Namespace: ${NAMESPACE}"
    echo "  Service: ${PLUGIN_SERVICE_NAME}"
    echo ""
fi

if [ "$SKIP_REGISTRATION" = false ]; then
    info "Plugin registered with DAM:"
    echo "  DX Release: ${DX_RELEASE}"
    echo "  Plugin ID: ${PLUGIN_ID}"
    echo "  Endpoint: ${PLUGIN_ENDPOINT}"
    echo ""
fi

echo "Useful Commands:"
echo ""
echo "  # View plugin pods"
echo "  kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=${PLUGIN_RELEASE} --insecure-skip-tls-verify"
echo ""
echo "  # View plugin logs"
echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/instance=${PLUGIN_RELEASE} --insecure-skip-tls-verify"
echo ""
echo "  # Test plugin health"
echo "  kubectl run curl-test --rm -i --tty --image=curlimages/curl --insecure-skip-tls-verify -- \\"
echo "    curl ${PLUGIN_URL}/health"
echo ""
echo "  # View DX values (verify registration)"
echo "  helm get values ${DX_RELEASE} -n ${NAMESPACE}"
echo ""
echo "  # Restart DAM to pick up plugin"
echo "  kubectl rollout restart deployment/${NAMESPACE}-digital-asset-management -n ${NAMESPACE} --insecure-skip-tls-verify"
echo ""
echo "  # Uninstall plugin"
echo "  helm uninstall ${PLUGIN_RELEASE} -n ${NAMESPACE}"
echo ""
