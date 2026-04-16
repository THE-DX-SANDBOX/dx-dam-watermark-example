#!/bin/bash

# Script to update HAProxy configmap to add dam-plugin backend
# This adds routing for /api/dam-plugin to the dam-plugin service

NAMESPACE=${NAMESPACE:-default}
CONFIGMAP_NAME="${NAMESPACE}-dx-sm-haproxy"
CONFIG_KEY="${NAMESPACE}-dx-sm.haproxy.cfg"

echo "=== Updating HAProxy Config for DAM Plugin ==="
echo "Namespace: $NAMESPACE"
echo "ConfigMap: $CONFIGMAP_NAME"

# Get current config
echo ""
echo "1. Fetching current HAProxy configuration..."
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath="{.data['${CONFIG_KEY}']}" > /tmp/haproxy-current.cfg

if [ ! -s /tmp/haproxy-current.cfg ]; then
    echo "ERROR: Could not fetch HAProxy config or it's empty"
    exit 1
fi

# Check if dam-plugin is already configured
if grep -q "is_dam_plugin" /tmp/haproxy-current.cfg; then
    echo "dam-plugin ACL already exists in config"
else
    echo "2. Adding dam-plugin ACL and routing rules..."
    
    # Add the ACL after the blog_api ACL
    sed -i.bak '/acl blog_api path_beg \/api/a\
\
  # DAM Plugin API - passthrough routing (no rewrite)\
  acl is_dam_plugin path_beg /api/dam-plugin' /tmp/haproxy-current.cfg
    
    # Add the use_backend before the blog backend
    sed -i.bak '/use_backend blog if blog_api/i\
  # Route to DAM Plugin before generic /api (more specific path first)\
  use_backend dam-plugin if is_dam_plugin\
' /tmp/haproxy-current.cfg
fi

# Check if dam-plugin backend exists
if grep -q "backend dam-plugin" /tmp/haproxy-current.cfg; then
    echo "dam-plugin backend already exists in config"
else
    echo "3. Adding dam-plugin backend..."
    
    # Add the backend at the end of the file
    cat >> /tmp/haproxy-current.cfg << EOF

# DAM Plugin backend - passthrough (no path rewrite)
backend dam-plugin
  server-template dam-plugin 1 dam-plugin.${NAMESPACE}.svc.cluster.local:3000 check resolvers kube-dns init-addr none
EOF
fi

echo ""
echo "4. Updated configuration (showing relevant sections):"
echo "--- ACL Section ---"
grep -A2 "is_dam_plugin" /tmp/haproxy-current.cfg | head -5
echo ""
echo "--- Backend Section ---"
grep -A2 "backend dam-plugin" /tmp/haproxy-current.cfg

echo ""
echo "5. Creating new configmap from updated config..."

# Create a temp configmap yaml
cat > /tmp/haproxy-configmap-patch.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $CONFIGMAP_NAME
  namespace: $NAMESPACE
data:
  ${CONFIG_KEY}: |
$(cat /tmp/haproxy-current.cfg | sed 's/^/    /')
EOF

echo ""
echo "6. Applying updated configmap..."
kubectl apply -f /tmp/haproxy-configmap-patch.yaml

if [ $? -eq 0 ]; then
    echo ""
    echo "7. Restarting HAProxy pod to pick up new config..."
    kubectl rollout restart deployment/${NAMESPACE}-dx-sm-haproxy -n $NAMESPACE
    
    echo ""
    echo "=== HAProxy update complete! ==="
    echo ""
    echo "The dam-plugin service should now be accessible at:"
    echo "  https://<dx-hostname>/api/dam-plugin/"
else
    echo "ERROR: Failed to apply configmap"
    exit 1
fi
