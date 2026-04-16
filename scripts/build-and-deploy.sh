#!/bin/bash
#
# Build and Deploy Pipeline
#

set -e

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Help function
show_help() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [OPTIONS]

Build and deploy DAM Plugin in one step

Environment Variables (from .env):
  NAMESPACE       Kubernetes namespace (default: $NAMESPACE)
  IMAGE_TAG       Docker image tag (default: $IMAGE_TAG)

Optional Arguments:
    ENVIRONMENT                    Optional config profile: local | dev | uat | prod
  -n, --namespace NAMESPACE    Override namespace from .env
  -t, --tag TAG                Override image tag from .env
  --skip-tests                 Skip running tests
  --skip-build                 Skip Docker build (deploy only)
  -h, --help                   Show this help message

Examples:
  # Build and deploy using .env configuration
  $0

    # Build and deploy using .env.dev
    $0 dev

  # Build and deploy to production
  $0 -n production -t v1.2.3

  # Deploy only (skip build)
  $0 --skip-build

  # Skip tests
  $0 --skip-tests

EOF
    exit 0
}

cd "$PROJECT_ROOT"

echo "========================================="
echo "DAM Plugin - Build and Deploy Pipeline"
echo "========================================="

# Configuration
SKIP_BUILD="false"
SKIP_TESTS="false"
ENVIRONMENT=""

# Parse command line arguments
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
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS="true"
            shift
            ;;
        --skip-build)
            SKIP_BUILD="true"
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

echo "Namespace: ${NAMESPACE}"
echo "Image Tag: ${IMAGE_TAG}"
echo "Environment: ${ENVIRONMENT:-default}"
echo "Skip Build: ${SKIP_BUILD}"
echo "Skip Tests: ${SKIP_TESTS}"
echo ""

# Step 1: Run tests (unless skipped)
if [ "$SKIP_TESTS" != "true" ]; then
    echo "=== Running Tests ==="
    if [ -d "packages/server-v1" ]; then
        cd packages/server-v1
        npm test || {
            echo "❌ Tests failed"
            exit 1
        }
        cd ../..
        echo "✅ Tests passed"
    else
        echo "⚠️  No test directory found, skipping tests"
    fi
    echo ""
fi

# Step 2: Build Docker image (unless skipped)
if [ "$SKIP_BUILD" != "true" ]; then
    echo "=== Building Docker Image ==="
    # Build with --helm flag if UPDATE_HELM is set
    if [ "$UPDATE_HELM" = "true" ]; then
        ./scripts/build.sh --push --helm
    else
        ./scripts/build.sh --push
    fi
    echo ""
else
    echo "⚠️  Skipping build (SKIP_BUILD=true)"
    echo ""
fi

# Step 3: Deploy with Helm
echo "=== Deploying to Kubernetes ==="
DEPLOY_ARGS=()

if [ -n "$NAMESPACE" ]; then
    DEPLOY_ARGS+=(--namespace "$NAMESPACE")
fi

if [ -n "$IMAGE_TAG" ]; then
    DEPLOY_ARGS+=(--tag "$IMAGE_TAG")
fi

./scripts/deploy.sh "${DEPLOY_ARGS[@]}"

echo ""
echo "========================================="
echo "Pipeline Complete!"
echo "========================================="

