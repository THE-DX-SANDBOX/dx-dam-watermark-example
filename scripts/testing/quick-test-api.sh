#!/bin/bash
# Quick test: API endpoints via port forwarding

cd "$(dirname "$0")/../.."

# Load environment
source .env

echo "=========================================="
echo "Quick API Test"
echo "=========================================="
echo ""

# Kill any existing port forwarding
echo "Cleaning up existing port forwards..."
pkill -f "kubectl port-forward.*$DEPLOYMENT_NAME" 2>/dev/null || true
sleep 2

# Start port forwarding
echo "Starting port forwarding..."
kubectl port-forward -n "$NAMESPACE" \
    deployment/"$DEPLOYMENT_NAME" \
    "$LOCAL_PORT:$REMOTE_PORT" > /tmp/pf-test.log 2>&1 &

PF_PID=$!
echo "Port forwarding started (PID: $PF_PID)"

# Wait for port forwarding to establish
echo "Waiting for port forwarding to establish..."
sleep 5

# Test endpoints
BASE_URL="http://localhost:$LOCAL_PORT"

echo ""
echo "Testing API endpoints..."
echo "=========================================="

echo ""
echo "1. Health Check:"
echo "   GET $BASE_URL/health"
curl -s "$BASE_URL/health" | jq . 2>/dev/null || curl -s "$BASE_URL/health"

echo ""
echo "2. OpenAPI Spec:"
echo "   GET $BASE_URL/openapi.json"
curl -s "$BASE_URL/openapi.json" | jq .info 2>/dev/null || echo "OpenAPI spec not available"

echo ""
echo "3. Plugin Info:"
echo "   GET $BASE_URL/dx/api/dam-plugin/v1"
curl -s "$BASE_URL/dx/api/dam-plugin/v1" | jq . 2>/dev/null || curl -s "$BASE_URL/dx/api/dam-plugin/v1"

echo ""
echo "=========================================="
echo "API test complete"
echo ""

# Cleanup
echo "Stopping port forwarding..."
kill $PF_PID 2>/dev/null || true
rm -f /tmp/pf-test.log

echo "Done!"
