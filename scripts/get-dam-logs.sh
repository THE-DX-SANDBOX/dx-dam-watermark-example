#!/bin/bash
#
# Get Digital Asset Management logs locally
#

set -e

# Default values
NAMESPACE=""
OUTPUT_FILE="dam-logs-latest.txt"
TAIL_LINES=2000
FOLLOW=false
CONTAINER="digital-asset-management"

# Help function
show_help() {
    cat << EOF
Usage: $0 -n <namespace> [OPTIONS]

Get Digital Asset Management logs and save them locally

Environment Variables (from .env):
  NAMESPACE   Kubernetes namespace (default: $NAMESPACE)

Optional Arguments:
  -n, --namespace NAMESPACE    Override namespace from .env
  -o, --output FILE            Output file name (default: dam-logs-latest.txt)
  -t, --tail LINES             Number of lines to tail (default: 2000, use 'all' for all logs)
  -F, --follow                 Follow logs in real-time (live streaming)
  -c, --container NAME         Container name (default: digital-asset-management)
  -h, --help                   Show this help message

Examples:
  # Get last 2000 lines using .env configuration
  $0

  # Follow logs live
  $0 -F

  # Get last 5000 lines to custom file
  $0 -t 5000 -o my-logs.txt

  # Get last 5000 lines to custom file
    $0 -n <namespace> -t 5000 -o my-logs.txt

  # Get all logs
    $0 -n <namespace> -t all

  # Follow logs in real-time (Ctrl+C to stop)
    $0 -n <namespace> -f

  # Follow and save to file
    $0 -n <namespace> -f -o streaming-logs.txt

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
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -t|--tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -F|--follow)
            FOLLOW=true
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
echo "Get DAM Logs"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Container: $CONTAINER"
echo "Output File: $OUTPUT_FILE"

# Find the DX release
echo ""
echo "🔍 Finding DX release..."
DX_RELEASE=$(helm list -n "$NAMESPACE" --output json 2>/dev/null | jq -r '.[] | select(.chart | startswith("dx-demo-pack")) | .name' | head -n 1)

if [ -z "$DX_RELEASE" ]; then
    echo "❌ Error: No DX release found in namespace $NAMESPACE"
    exit 1
fi

echo "✓ Found DX release: $DX_RELEASE"

# Find DAM pod
echo ""
echo "🔍 Finding DAM pod..."
DAM_POD=$(kubectl get pods -n "$NAMESPACE" -l app="${DX_RELEASE}-digital-asset-management" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$DAM_POD" ]; then
    echo "❌ Error: No DAM pod found"
    echo ""
    echo "Available pods:"
    kubectl get pods -n "$NAMESPACE" | grep digital
    exit 1
fi

echo "✓ Found pod: $DAM_POD"

# Check if container exists
echo ""
echo "🔍 Checking container..."
if ! kubectl get pod "$DAM_POD" -n "$NAMESPACE" -o jsonpath="{.spec.containers[*].name}" | grep -q "$CONTAINER"; then
    echo "❌ Error: Container '$CONTAINER' not found in pod"
    echo ""
    echo "Available containers:"
    kubectl get pod "$DAM_POD" -n "$NAMESPACE" -o jsonpath="{.spec.containers[*].name}" | tr ' ' '\n'
    exit 1
fi

echo "✓ Found container: $CONTAINER"

# Get logs
echo ""
echo "📥 Fetching logs..."

if [ "$FOLLOW" = true ]; then
    echo "📡 Following logs in real-time (Ctrl+C to stop)..."
    echo "💾 Streaming to: $(pwd)/$OUTPUT_FILE"
    echo ""
    
    # Follow logs and save to file
    kubectl logs -n "$NAMESPACE" "$DAM_POD" -c "$CONTAINER" -f | tee "$OUTPUT_FILE"
else
    # Get static logs
    if [ "$TAIL_LINES" = "all" ]; then
        echo "📋 Fetching all logs..."
        kubectl logs -n "$NAMESPACE" "$DAM_POD" -c "$CONTAINER" > "$OUTPUT_FILE"
    else
        echo "📋 Fetching last $TAIL_LINES lines..."
        kubectl logs -n "$NAMESPACE" "$DAM_POD" -c "$CONTAINER" --tail="$TAIL_LINES" > "$OUTPUT_FILE"
    fi
    
    # Check if logs were fetched
    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
        LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
        
        echo ""
        echo "=========================================="
        echo "✅ Logs saved successfully!"
        echo "=========================================="
        echo "📁 File: $(pwd)/$OUTPUT_FILE"
        echo "📏 Size: $FILE_SIZE"
        echo "📊 Lines: $LINE_COUNT"
        echo ""
        echo "View logs:"
        echo "  cat $OUTPUT_FILE"
        echo "  less $OUTPUT_FILE"
        echo "  tail -f $OUTPUT_FILE"
        echo ""
        echo "Search logs:"
        echo "  grep 'plugin' $OUTPUT_FILE"
        echo "  grep -i 'error' $OUTPUT_FILE"
        echo ""
    else
        echo "❌ Error: Failed to save logs"
        exit 1
    fi
fi
