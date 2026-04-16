#!/bin/bash
#
# Build Docker image for DAM Plugin
#

set -e

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Build Docker image for DAM Plugin

Environment Variables (from .env):
  DOCKER_REGISTRY   Docker registry URL (default: $DOCKER_REGISTRY)
  IMAGE_NAME        Docker image name (default: $IMAGE_NAME)
  IMAGE_TAG         Docker image tag (default: $IMAGE_TAG)

Optional Arguments:
  -t, --tag TAG     Override image tag from .env
  -p, --push        Push image to registry after build
  --no-cache        Build without using cache
  --helm            Also build and push Helm chart
  -h, --help        Show this help message

Examples:
  # Build using .env configuration
  $0

  # Build and push
  $0 --push

  # Build with custom tag
  $0 -t v1.2.3 --push

  # Build without cache
  $0 --no-cache

  # Build image and Helm chart
  $0 --push --helm

EOF
    exit 0
}

cd "$PROJECT_ROOT"

echo "=================================="
echo "Building DAM Plugin Docker Image"
echo "=================================="

# Parse command line arguments
PUSH_IMAGE=false
UPDATE_HELM=false
NO_CACHE=""
TAG_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG_OVERRIDE="$2"
            shift 2
            ;;
        -p|--push)
            PUSH_IMAGE=true
            shift
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --helm)
            UPDATE_HELM=true
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

# Use tag override if provided, otherwise use .env value
if [ -n "$TAG_OVERRIDE" ]; then
    IMAGE_TAG="$TAG_OVERRIDE"
fi

# Configuration (from .env or defaults)
PLATFORM=${PLATFORM:-"linux/amd64"}

require_config_value "DOCKER_REGISTRY" "$DOCKER_REGISTRY"
require_config_value "IMAGE_NAME" "$IMAGE_NAME"

if [ "$UPDATE_HELM" = "true" ]; then
    require_config_value "HELM_REGISTRY" "$HELM_REGISTRY"
fi

FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

log_info "Registry: ${DOCKER_REGISTRY}"
log_info "Image: ${IMAGE_NAME}"
log_info "Tag: ${IMAGE_TAG}"
log_info "Platform: ${PLATFORM}"
log_info "Push: ${PUSH_IMAGE}"
log_info "Update Helm: ${UPDATE_HELM}"
log_info "No Cache: ${NO_CACHE:-false}"
echo ""

# Clean previous build artifacts
echo "==> Cleaning previous build artifacts..."
rm -rf ./build
mkdir -p ./build
echo "✓ Build directory ready"

# Step 1: Authenticate with registry if needed
if [ "$PUSH_IMAGE" = "true" ] || [ "$UPDATE_HELM" = "true" ]; then
    echo ""
    echo "=== Checking registry authentication ==="

    REGISTRY_HOST="${DOCKER_REGISTRY%%/*}"
    HELM_REGISTRY_HOST="${HELM_REGISTRY%%/*}"

    if [ "$PUSH_IMAGE" = "true" ] && [[ "$REGISTRY_HOST" == *"pkg.dev" ]]; then
        if ! command -v gcloud &> /dev/null; then
            echo "❌ Error: gcloud CLI not found for Artifact Registry authentication"
            echo "Install Google Cloud SDK or authenticate Docker to your registry manually."
            exit 1
        fi
        gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin "https://${REGISTRY_HOST}"
        echo "✓ Docker registry authenticated via gcloud"
    elif [ "$PUSH_IMAGE" = "true" ]; then
        echo "ℹ️  Assuming Docker is already authenticated to ${REGISTRY_HOST}"
    fi

    if [ "$UPDATE_HELM" = "true" ]; then
        if ! command -v helm &> /dev/null; then
            echo "❌ Error: helm CLI not found"
            echo "Please install Helm: https://helm.sh/docs/intro/install/"
            exit 1
        fi

        if [[ "$HELM_REGISTRY_HOST" == *"pkg.dev" ]]; then
            if ! command -v gcloud &> /dev/null; then
                echo "❌ Error: gcloud CLI not found for Artifact Registry authentication"
                echo "Install Google Cloud SDK or authenticate Helm to your registry manually."
                exit 1
            fi
            gcloud auth print-access-token | helm registry login -u oauth2accesstoken --password-stdin "https://${HELM_REGISTRY_HOST}"
            echo "✓ Helm registry authenticated via gcloud"
        else
            echo "ℹ️  Assuming Helm is already authenticated to ${HELM_REGISTRY_HOST}"
        fi
    fi
fi

# Step 2: Build TypeScript code
echo ""
echo "=== Building TypeScript ==="
cd packages/server-v1
npm run build
cd ../..
echo "✅ TypeScript built successfully"

# Step 3: Build Docker Image
echo ""
echo "=== Building Docker Image ==="

# Use buildx for multi-platform support
if docker buildx version &> /dev/null; then
    echo "Using docker buildx..."
    
    # Create builder if it doesn't exist
    docker buildx create --name dam-plugin-builder --use 2>/dev/null || docker buildx use dam-plugin-builder
    
    if [ "$PUSH_IMAGE" = "true" ]; then
        docker buildx build \
            --platform ${PLATFORM} \
            --tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \
            --tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest \
            --push \
            ${NO_CACHE} \
            -f packages/Dockerfile \
            ./packages
    else
        docker buildx build \
            --platform ${PLATFORM} \
            --tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \
            --tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest \
            --load \
            ${NO_CACHE} \
            -f packages/Dockerfile \
            ./packages
    fi
else
    echo "Using standard docker build..."
    docker build \
        --tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} \
        --tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest \
        ${NO_CACHE} \
        -f packages/Dockerfile \
        ./packages
fi

echo ""
echo "✅ Docker image built successfully"
echo "   ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Step 4: Build and push Helm chart (if requested)
if [ "$UPDATE_HELM" = "true" ]; then
    echo ""
    echo "=== Building Helm Chart ==="
    
    HELM_CHART_PATH="./helm/dam-plugin"
    
    if [ ! -d "$HELM_CHART_PATH" ]; then
        echo "❌ Error: Helm chart not found at $HELM_CHART_PATH"
        exit 1
    fi
    
    # Package the Helm chart
    echo "Packaging Helm chart..."
    helm package ${HELM_CHART_PATH} -d ./build
    
    # Find the packaged chart
    CHART_PACKAGE=$(ls -t ./build/dam-plugin-*.tgz | head -n 1)
    
    if [ -z "$CHART_PACKAGE" ]; then
        echo "❌ Error: Failed to package Helm chart"
        exit 1
    fi
    
    echo "✓ Chart packaged: $CHART_PACKAGE"
    
    # Push to Helm registry
    echo ""
    echo "=== Pushing Helm Chart to Registry ==="
    helm push ${CHART_PACKAGE} oci://${HELM_REGISTRY}
    echo "✓ Helm chart pushed successfully"
    echo "   oci://${HELM_REGISTRY}/dam-plugin"
fi

echo ""
echo "✅ Build complete!"
echo ""
echo "Image: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

if [ "$UPDATE_HELM" = "true" ]; then
    echo "Helm Chart: oci://${HELM_REGISTRY}/dam-plugin"
fi

echo ""
echo "Next steps:"
echo "  To deploy: ./scripts/deploy.sh <namespace>"

