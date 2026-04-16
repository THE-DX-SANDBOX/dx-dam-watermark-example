#!/bin/bash
#
# Verify DAM Plugin Registration and Functionality
#

set -e

NAMESPACE="${1:-default}"
POD_NAME="$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=dam-plugin -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"

echo "================================================"
echo "DAM Plugin Verification for namespace: $NAMESPACE"
echo "================================================"
echo ""

# 1. Check pod status
echo "1. Checking dam-plugin pod status..."
kubectl get pods -n "$NAMESPACE" | grep dam-plugin
echo ""

# 2. Check service
echo "2. Checking dam-plugin service..."
kubectl get svc -n "$NAMESPACE" | grep dam-plugin
echo ""

# 3. Check plugin health
echo "3. Testing plugin health endpoint..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -s "http://dam-plugin:3000/api/dam-plugin/health" 2>/dev/null || echo "Could not reach health endpoint"
echo ""
echo ""

# 4. Check plugin info
echo "4. Testing plugin info endpoint..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- curl -s "http://dam-plugin:3000/api/dam-plugin/api/v1/info" 2>/dev/null | jq . || echo "Could not reach info endpoint"
echo ""

# 5. Check plugin registration
echo "5. Checking plugin registration in DAM ConfigMap..."
DX_RELEASE=$(helm list -n "$NAMESPACE" --output json 2>/dev/null | jq -r '.[] | select(.chart | startswith("dx-demo-pack")) | .name' | head -n 1)
CONFIGMAP_NAME="${DX_RELEASE:-$NAMESPACE}-digital-asset-management"

PLUGINS=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_plugin_config\.json}' 2>/dev/null | jq 'keys' || echo "[]")
echo "Registered plugins: $PLUGINS"
echo ""

# 6. Check dam-demo-plugin specifically
echo "6. Checking dam-demo-plugin configuration..."
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_plugin_config\.json}' 2>/dev/null | jq '.["dam-demo-plugin"] // "NOT REGISTERED"' || echo "Could not read configmap"
echo ""

# 7. Check rendition configuration
echo "7. Checking rendition configuration for image/jpeg..."
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_rendition_config\.json}' 2>/dev/null | jq '.["image/jpeg"].rendition[0].transformationStack // []' || echo "Could not read configmap"
echo ""

# 8. Check DAM pod status
echo "8. Checking DAM pod status..."
kubectl get pods -n "$NAMESPACE" | grep digital-asset-management
echo ""

echo "================================================"
echo "Verification complete!"
echo "================================================"
echo ""
echo "To test watermark functionality, upload an image with 'house' in the filename to DAM."
echo "The plugin will automatically apply a watermark to images matching this pattern."
echo ""
