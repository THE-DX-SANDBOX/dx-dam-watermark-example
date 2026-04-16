#!/bin/bash
#
# Test Plugin Script
# Sends a test request to the plugin endpoint
#

set -e

# Source common configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Test DAM Plugin endpoint with a sample image

Environment Variables (from .env):
  API_KEY         API key for authentication (default: $API_KEY)

Optional Arguments:
  -u, --url URL           Plugin URL (default: http://localhost:3000)
  -f, --file FILE         Test image file (required)
  --callback URL          Callback URL (optional)
  -k, --api-key KEY       Override API key from .env
  -h, --help              Show this help message

Examples:
  # Test with image file
  $0 -f test-image.jpg

  # Test with custom URL
  $0 -u http://localhost:8080 -f test.jpg

  # Test with callback
  $0 -f test.jpg --callback http://localhost:3001/callback

  # Port forward first, then test
  ./scripts/port-forward.sh &
  sleep 5
  $0 -f ~/Downloads/houseImage.jpg

EOF
    exit 0
}

# Default values
PLUGIN_URL="http://localhost:${LOCAL_PORT}"
TEST_FILE=""
CALLBACK_URL=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            PLUGIN_URL="$2"
            shift 2
            ;;
        -f|--file)
            TEST_FILE="$2"
            shift 2
            ;;
        --callback)
            CALLBACK_URL="$2"
            shift 2
            ;;
        -k|--api-key)
            API_KEY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            # Backward compatibility: first arg is file
            if [ -z "$TEST_FILE" ]; then
                TEST_FILE="$1"
            else
                log_error "Unknown option: $1"
                show_help
            fi
            shift
            ;;
    esac
done

# Validate test file
if [ -z "$TEST_FILE" ]; then
    log_error "Test file is required"
    show_help
fi

URL="${PLUGIN_URL}/api/v1/process"

echo "=========================================="
echo "Testing DAM Plugin"
echo "=========================================="
echo "Endpoint: $URL"
echo "File: $TEST_FILE"
echo "Callback: $CALLBACK_URL"
echo "=========================================="
echo ""

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo "❌ Test file not found: $TEST_FILE"
    echo "Please provide a valid test file"
    exit 1
fi

# Test health endpoint
echo "🏥 Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${URL%/api/v1/process}/health")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed (HTTP $HTTP_CODE)"
    exit 1
fi

# Test plugin endpoint
echo ""
echo "🔄 Sending test request..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST "$URL" \
    -H "X-API-Key: $API_KEY" \
    -F "file=@${TEST_FILE}" \
    -F "callBackURL=${CALLBACK_URL}")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo ""
echo "Response (HTTP $HTTP_CODE):"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"

echo ""
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Plugin test successful"
else
    echo "❌ Plugin test failed (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""
