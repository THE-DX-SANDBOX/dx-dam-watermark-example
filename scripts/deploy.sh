#!/bin/bash
#
# Deploy to Kubernetes using Helm
#

set -e

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Help function
show_help() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

Deploy DAM Plugin to Kubernetes using Helm

Environment Variables (from .env):
  NAMESPACE          Kubernetes namespace (default: $NAMESPACE)
  RELEASE_NAME       Helm release name (default: $RELEASE_NAME)
  DOCKER_REGISTRY    Docker registry URL (default: $DOCKER_REGISTRY)
  IMAGE_NAME         Docker image name (default: $IMAGE_NAME)
  IMAGE_TAG          Docker image tag (default: $IMAGE_TAG)
  HELM_CHART_PATH    Path to Helm chart (default: $HELM_CHART_PATH)
  VALUES_FILE        Custom values file (default: $VALUES_FILE)

Optional Arguments:
    ENVIRONMENT                    Optional config profile: local | dev | uat | prod
  -n, --namespace NAMESPACE    Override namespace from .env
  -r, --release RELEASE        Override release name from .env
  -t, --tag TAG                Override image tag from .env
  -v, --values FILE            Override values file from .env
  --remote                     Deploy from remote registry (skip local build)
  -h, --help                   Show this help message

Examples:
  # Deploy using .env configuration
  $0

    # Deploy using .env.dev
    $0 dev

  # Override namespace
  $0 -n production

  # Override image tag
  $0 -t v1.2.3

  # Use custom values file
  $0 -v ./helm/dam-plugin/values-prod.yaml

  # Deploy without building (use existing remote image)
  $0 --remote

  # Deploy to production with custom tag and values
  $0 -n production -t v1.2.3 -v ./helm/values-prod.yaml

Common Issues:
  - Image not found: Run ./scripts/build.sh --push first
  - Permission denied: Check kubectl permissions with kubectl auth can-i create pods -n \$NAMESPACE
  - Helm not found: Install from https://helm.sh/docs/intro/install/
  - Namespace missing: Create with kubectl create namespace \$NAMESPACE

EOF
    exit 0
}

# Parse command line arguments
USE_REMOTE="false"
ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        local|dev|uat|prod)
            if [ -n "$ENVIRONMENT" ]; then
                log_error "Environment already set to $ENVIRONMENT"
                show_help
            fi
            ENVIRONMENT="$1"
            shift
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -v|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        --remote)
            USE_REMOTE="true"
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

if [ -n "$ENVIRONMENT" ]; then
    load_environment_file "$ENVIRONMENT"
fi

cd "$PROJECT_ROOT"

# Load plugin configuration
PLUGIN_NAME=$(node -p "require('./plugin-config.json').pluginName" 2>/dev/null || echo "dam-plugin")

require_config_value "DOCKER_REGISTRY" "$DOCKER_REGISTRY"
require_config_value "IMAGE_NAME" "$IMAGE_NAME"

# Construct full image name
FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
HELM_CHART_PATH="./helm/dam-plugin"

if [ "$USE_REMOTE" = "true" ]; then
    require_config_value "HELM_REGISTRY" "$HELM_REGISTRY"
    HELM_CHART_PATH="oci://${HELM_REGISTRY}/dam-plugin"
fi

echo "=========================================="
echo "Deploying with Helm"
echo "=========================================="
echo "Plugin: $PLUGIN_NAME"
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Image: $FULL_IMAGE"
echo "Chart Source: $HELM_CHART_PATH"
echo "Values File: $([ -n "$VALUES_FILE" ] && echo "$VALUES_FILE" || echo "default (from chart)")"
echo "=========================================="
echo ""

# Check if helm is available
if ! command -v helm &> /dev/null; then
    log_error "helm not found. Please install Helm first."
    echo "   https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Build and push image if not using remote
if [ "$USE_REMOTE" = "false" ]; then
    log_info "Building Docker image..."
    ./scripts/build.sh -t "$IMAGE_TAG"
    log_success "Docker image built successfully"
else
    log_info "Using remote image: $FULL_IMAGE"
fi

# Validate custom values file if provided
if [ -n "$VALUES_FILE" ] && [ ! -f "$VALUES_FILE" ]; then
    log_error "Custom values file not found at $VALUES_FILE"
    exit 1
fi

# Deploy using Helm
echo ""
log_info "Deploying with Helm..."

# Build helm command
HELM_CMD="helm upgrade --install \"$RELEASE_NAME\" \"$HELM_CHART_PATH\" \
    --namespace \"$NAMESPACE\" \
    --set image.repository=\"${DOCKER_REGISTRY}/${IMAGE_NAME}\" \
    --set image.tag=\"$IMAGE_TAG\""

# Add custom values file if provided
if [ -n "$VALUES_FILE" ]; then
    HELM_CMD="$HELM_CMD --values \"$VALUES_FILE\""
fi

echo $HELM_CMD
HELM_CMD="$HELM_CMD --wait --timeout 5m"

# Execute helm command
eval $HELM_CMD

# Force rollout restart to ensure latest image is pulled (especially for :latest tag)
echo ""
echo "🔄 Forcing rollout restart to pull latest image..."
kubectl rollout restart deployment/$RELEASE_NAME -n "$NAMESPACE"
kubectl rollout status deployment/$RELEASE_NAME -n "$NAMESPACE" --timeout=5m

# Get deployment status
echo ""
echo "=========================================="
echo "✅ Deployment complete!"
echo "=========================================="
echo ""
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo ""
kubectl get pods -n "$NAMESPACE" -l app=dam-plugin --insecure-skip-tls-verify
echo ""
kubectl get svc -n "$NAMESPACE" -l app=dam-plugin --insecure-skip-tls-verify
echo ""
echo "Helm release info:"
helm list -n "$NAMESPACE"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/dam-plugin -n $NAMESPACE --insecure-skip-tls-verify"
echo ""
echo "To port-forward:"
echo "  kubectl port-forward svc/dam-plugin 3000:80 -n $NAMESPACE --insecure-skip-tls-verify"
echo ""
echo "To uninstall:"
echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""
