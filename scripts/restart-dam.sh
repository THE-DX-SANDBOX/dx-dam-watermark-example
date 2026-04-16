#!/bin/bash
#
# Restart Digital Asset Management deployment
#

set -e

# Help function
show_help() {
    cat << EOF
Usage: $0 -n <namespace>

Restart the Digital Asset Management deployment to pick up ConfigMap changes

Required Arguments:
  -n, --namespace NAMESPACE    Kubernetes namespace where DX is deployed

Options:
  -w, --wait                   Wait for rollout to complete
  -h, --help                   Show this help message

Examples:
  # Restart DAM deployment
    $0 -n <namespace>

  # Restart and wait for completion
    $0 -n <namespace> --wait

EOF
    exit 0
}

# Parse command line arguments
NAMESPACE=""
WAIT_FOR_ROLLOUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_FOR_ROLLOUT=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "❌ Error: Unknown option: $1"
            echo ""
            show_help
            ;;
    esac
done

# Validate required arguments
if [ -z "$NAMESPACE" ]; then
    echo "❌ Error: Namespace is required (-n flag)"
    echo ""
    show_help
fi

echo "=========================================="
echo "Restart Digital Asset Management"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo ""

# Find the DX release
echo "🔍 Finding DX release..."
DX_RELEASE=$(helm list -n "$NAMESPACE" --output json 2>/dev/null | jq -r '.[] | select(.chart | startswith("dx-demo-pack")) | .name' | head -n 1)

if [ -z "$DX_RELEASE" ]; then
    echo "❌ Error: No DX release found in namespace $NAMESPACE"
    exit 1
fi

echo "✓ Found DX release: $DX_RELEASE"

# Find DAM deployment or statefulset
echo ""
echo "🔍 Finding Digital Asset Management resource..."

# Try deployment first
DAM_RESOURCE=$(kubectl get deployment -n "$NAMESPACE" -l app="${DX_RELEASE}-digital-asset-management" -o name 2>/dev/null | head -n 1)

# If not found, try statefulset
if [ -z "$DAM_RESOURCE" ]; then
    DAM_RESOURCE=$(kubectl get statefulset -n "$NAMESPACE" "${DX_RELEASE}-digital-asset-management" -o name 2>/dev/null)
fi

if [ -z "$DAM_RESOURCE" ]; then
    echo "❌ Error: No DAM deployment or statefulset found"
    echo ""
    echo "Available deployments:"
    kubectl get deployments -n "$NAMESPACE"
    echo ""
    echo "Available statefulsets:"
    kubectl get statefulsets -n "$NAMESPACE"
    exit 1
fi

echo "✓ Found resource: $DAM_RESOURCE"

# Get current status
echo ""
echo "📊 Current resource status:"
kubectl get "$DAM_RESOURCE" -n "$NAMESPACE"

# Restart the resource
echo ""
echo "🔄 Restarting resource..."
kubectl rollout restart "$DAM_RESOURCE" -n "$NAMESPACE"

echo ""
echo "✅ Restart initiated!"

# Wait for rollout if requested
if [ "$WAIT_FOR_ROLLOUT" = true ]; then
    echo ""
    echo "⏳ Waiting for rollout to complete..."
    kubectl rollout status "$DAM_RESOURCE" -n "$NAMESPACE" --timeout=5m
    
    echo ""
    echo "📊 Updated resource status:"
    kubectl get "$DAM_RESOURCE" -n "$NAMESPACE"
    echo ""
    echo "✅ Rollout complete!"
else
    echo ""
    echo "To monitor rollout status:"
    echo "  kubectl rollout status $DAM_RESOURCE -n $NAMESPACE"
    echo ""
    echo "To view pods:"
    echo "  kubectl get pods -n $NAMESPACE -l app=${DX_RELEASE}-digital-asset-management"
fi

echo ""
