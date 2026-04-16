#!/bin/bash
#
# Complete build and deployment pipeline for DAM Plugin
# Builds Docker image, pushes to registry, builds Helm chart, and deploys
#

set -e

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

show_help() {
    cat << EOF
Usage: $0 -n <namespace> [OPTIONS]

Complete build and deployment pipeline for DAM Plugin

This script will:
  1. Build Docker image
  2. Push to GCP Artifact Registry
  3. Build and push Helm chart
  4. Deploy plugin runtime
  5. Register plugin with DX DAM

Required Arguments:
  -n, --namespace NAMESPACE    Target namespace for deployment

Optional Arguments:
  -r, --dx-release RELEASE     DX Helm release name (default: same as namespace)
  -t, --tag TAG                Docker image tag (default: latest)
  -a, --auth-key KEY          Plugin authentication key
  --skip-build                Skip Docker/Helm build (use existing)
  --skip-push                 Build but don't push to registry
  --local-chart               Use local chart instead of remote
  -h, --help                  Show this help

Examples:
  # Full pipeline
    $0 -n <namespace>

  # With custom tag and DX release
    $0 -n <namespace> -t v1.2.3 -r my-dx-release

  # Deploy only (skip build)
    $0 -n <namespace> --skip-build --local-chart

EOF
    exit 0
}

# Parse arguments
NAMESPACE=""
DX_RELEASE=""
TAG="latest"
AUTH_KEY=""
SKIP_BUILD=false
SKIP_PUSH=false
USE_LOCAL_CHART=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--dx-release)
            DX_RELEASE="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -a|--auth-key)
            AUTH_KEY="$2"
            shift 2
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-push)
            SKIP_PUSH=true
            shift
            ;;
        --local-chart)
            USE_LOCAL_CHART=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

if [ -z "$NAMESPACE" ]; then
    echo "Error: NAMESPACE is required"
    echo ""
    show_help
fi

cd "$(dirname "$0")/.."

echo "=========================================="
echo "DAM Plugin Build & Deploy Pipeline"
echo "=========================================="
echo "Namespace:     ${NAMESPACE}"
echo "DX Release:    ${DX_RELEASE:-${NAMESPACE}}"
echo "Tag:           ${TAG}"
echo "Skip Build:    ${SKIP_BUILD}"
echo "Local Chart:   ${USE_LOCAL_CHART}"
echo "=========================================="
echo ""

# Step 1: Build
if [ "$SKIP_BUILD" = false ]; then
    log "Step 1/2: Building Docker image and Helm chart"
    
    if [ "$SKIP_PUSH" = false ]; then
        TAG="${TAG}" ./scripts/build.sh --push --helm
    else
        TAG="${TAG}" ./scripts/build.sh
    fi
    
    info "✅ Build complete"
else
    info "Skipping build (--skip-build)"
fi

# Step 2: Deploy
log "Step 2/2: Deploying plugin and registering with DAM"

DEPLOY_ARGS="-n ${NAMESPACE} -t ${TAG}"

if [ -n "$DX_RELEASE" ]; then
    DEPLOY_ARGS="${DEPLOY_ARGS} -r ${DX_RELEASE}"
fi

if [ -n "$AUTH_KEY" ]; then
    DEPLOY_ARGS="${DEPLOY_ARGS} -a ${AUTH_KEY}"
fi

if [ "$USE_LOCAL_CHART" = false ] && [ "$SKIP_BUILD" = false ] && [ "$SKIP_PUSH" = false ]; then
    DEPLOY_ARGS="${DEPLOY_ARGS} --remote"
fi

# shellcheck disable=SC2086
./scripts/deploy-dam-plugin.sh ${DEPLOY_ARGS}

echo ""
log "=========================================="
log "✅ Pipeline Complete!"
log "=========================================="
echo ""
echo "Plugin has been built, deployed, and registered with DAM"
echo ""

echo ""
echo "========================================="
echo "Pipeline Complete!"
echo "========================================="
