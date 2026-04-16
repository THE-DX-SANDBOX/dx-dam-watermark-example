#!/bin/bash
#
# Register DAM Plugin with DX Digital Asset Management ConfigMap
# Updates the dam.config.dam.extensibility_plugin_config.json key
#

set -e

# Help function
show_help() {
    cat << EOF
Usage: $0 -n <namespace> [OPTIONS]

Register DAM Plugin with DX Digital Asset Management ConfigMap

Environment Variables (from .env):
  NAMESPACE             Kubernetes namespace (default: $NAMESPACE)
  PLUGIN_URL            Plugin service URL (default: auto-detected)
  PLUGIN_CONFIG_FILE    Plugin config file (default: $PLUGIN_CONFIG_FILE)

Optional Arguments:
  -n, --namespace NAMESPACE    Override namespace from .env
  --plugin-url URL             Plugin service URL (default: auto-detected)
  --plugin-name NAME           Plugin name (default: from plugin-config.json)
  --auth-key KEY               Plugin auth key (default: empty)
  --rendition-stack STACK      Rendition stack to register in (keyword|supplemental|thumbnail|transformation) (default: keyword)
  --mime-types TYPES           Comma-separated MIME types to register for (default: image/jpeg,image/png,image/gif)
  --force                      Force re-registration even if plugin exists
  --show-config                Show current plugin configuration and exit
  --show-renditions            Show current rendition configuration and exit
  -h, --help                   Show this help message

Examples:
  # Show current plugin configuration
    $0 -n <namespace> --show-config

  # Register plugin with auto-detection
    $0 -n <namespace>

  # Register with custom URL
    $0 -n <namespace> -p http://dam-plugin.<namespace>.svc.cluster.local:3000

  # Force re-registration
    $0 -n <namespace> -f

EOF
    exit 0
}

# Parse command line arguments
NAMESPACE=""
PLUGIN_URL=""
PLUGIN_NAME=""
AUTH_KEY=""
RENDITION_STACK="keyword"
MIME_TYPES="image/jpeg,image/png,image/gif"
FORCE_REGISTER=false
SHOW_CONFIG=false
SHOW_RENDITIONS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --plugin-url)
            PLUGIN_URL="$2"
            shift 2
            ;;
        --plugin-name)
            PLUGIN_NAME="$2"
            shift 2
            ;;
        --auth-key)
            AUTH_KEY="$2"
            shift 2
            ;;
        --rendition-stack)
            RENDITION_STACK="$2"
            shift 2
            ;;
        --mime-types)
            MIME_TYPES="$2"
            shift 2
            ;;
        --force)
            FORCE_REGISTER=true
            shift
            ;;
        --show-config)
            SHOW_CONFIG=true
            shift
            ;;
        --show-renditions)
            SHOW_RENDITIONS=true
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

cd "$(dirname "$0")/.."

# Find the DX release
echo "🔍 Finding DX release..."
DX_RELEASE=$(helm list -n "$NAMESPACE" --output json 2>/dev/null | jq -r '.[] | select(.chart | startswith("dx-demo-pack")) | .name' | head -n 1)

if [ -z "$DX_RELEASE" ]; then
    echo "❌ Error: No DX release found in namespace $NAMESPACE"
    echo "Available releases:"
    helm list -n "$NAMESPACE"
    exit 1
fi

echo "✓ Found DX release: $DX_RELEASE"

# Get the ConfigMap name
CONFIGMAP_NAME="${DX_RELEASE}-digital-asset-management"

echo "🔍 Checking ConfigMap: $CONFIGMAP_NAME"

if ! kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "❌ Error: ConfigMap $CONFIGMAP_NAME not found in namespace $NAMESPACE"
    exit 1
fi

# If show-config flag, display and exit
if [ "$SHOW_CONFIG" = true ]; then
    echo ""
    echo "=========================================="
    echo "Current DAM Plugin Configuration"
    echo "=========================================="
    echo ""
    kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_plugin_config\.json}' | jq '.'
    exit 0
fi

# If show-renditions flag, display and exit
if [ "$SHOW_RENDITIONS" = true ]; then
    echo ""
    echo "=========================================="
    echo "Current DAM Rendition Configuration"
    echo "=========================================="
    echo ""
    kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_rendition_config\.json}' | jq '.'
    exit 0
fi

# Load plugin configuration from plugin-config.json if name not provided
if [ -z "$PLUGIN_NAME" ]; then
    CONFIG_FILE="./plugin-config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ Error: plugin-config.json not found and --plugin-name not provided"
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        echo "❌ Error: node is required to parse plugin-config.json"
        exit 1
    fi
    
    PLUGIN_NAME=$(node -p "require('$CONFIG_FILE').pluginName || 'dam-demo-plugin'")
fi

echo ""
echo "=========================================="
echo "Register DAM Plugin with DX"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Plugin Name: $PLUGIN_NAME"
echo "ConfigMap: $CONFIGMAP_NAME"
echo ""

# Auto-detect plugin URL if not provided
if [ -z "$PLUGIN_URL" ]; then
    echo "🔍 Auto-detecting plugin service URL..."
    
    # Check if dam-plugin service exists
    if kubectl get service dam-plugin -n "$NAMESPACE" &> /dev/null; then
        SERVICE_PORT=$(kubectl get service dam-plugin -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
        PLUGIN_URL="http://dam-plugin.${NAMESPACE}.svc.cluster.local:${SERVICE_PORT}"
        echo "✓ Detected plugin URL: $PLUGIN_URL"
    else
        echo "❌ Error: dam-plugin service not found and --plugin-url not provided"
        echo "Available services:"
        kubectl get services -n "$NAMESPACE" | grep dam
        exit 1
    fi
fi

# Get current plugin configuration
echo ""
echo "📋 Checking current plugin configuration..."

CURRENT_CONFIG=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_plugin_config\.json}' 2>/dev/null || echo "{}")

# Check if plugin already exists
PLUGIN_EXISTS=$(echo "$CURRENT_CONFIG" | jq -e ".\"$PLUGIN_NAME\"" > /dev/null 2>&1 && echo "true" || echo "false")

if [ "$PLUGIN_EXISTS" = "true" ] && [ "$FORCE_REGISTER" = false ]; then
    echo ""
    echo "⚠️  Plugin '$PLUGIN_NAME' is already registered!"
    echo ""
    echo "Current configuration:"
    echo "$CURRENT_CONFIG" | jq ".\"$PLUGIN_NAME\""
    echo ""
    read -p "Do you want to update the existing registration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Registration cancelled."
        exit 0
    fi
fi

# Create plugin registration entry following the HCL DAM format
CALLBACK_HOST="http://${DX_RELEASE}-digital-asset-management:3000"

PLUGIN_ENTRY=$(cat <<EOF
{
  "actions": {
    "process": {
      "params": {},
      "url": "/api/v1/process"
    }
  },
  "authKey": "$AUTH_KEY",
  "callBackHost": "$CALLBACK_HOST",
  "enable": true,
  "url": "$PLUGIN_URL"
}
EOF
)

echo ""
echo "📝 Plugin registration configuration:"
echo "$PLUGIN_ENTRY" | jq '.'

# Update the plugin configuration
echo ""
echo "🔄 Updating ConfigMap with plugin registration..."

# Add or update the plugin in the configuration
NEW_CONFIG=$(echo "$CURRENT_CONFIG" | jq ".\"$PLUGIN_NAME\" = $PLUGIN_ENTRY")

# Create a temporary file for the JSON (to handle escaping properly)
TEMP_FILE=$(mktemp)
echo "$NEW_CONFIG" > "$TEMP_FILE"

# Patch the ConfigMap with the new configuration
kubectl patch configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\"dam.config.dam.extensibility_plugin_config.json\":$(cat "$TEMP_FILE" | jq -R -s .)}}"

rm -f "$TEMP_FILE"

echo ""
echo "=========================================="
echo "✅ Plugin Registration Complete!"
echo "=========================================="
echo ""
echo "Plugin: $PLUGIN_NAME"
echo "URL: $PLUGIN_URL"
echo "ConfigMap: $CONFIGMAP_NAME"
echo ""
echo "📋 Updated plugin configuration:"
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_plugin_config\.json}' | jq ".\"$PLUGIN_NAME\""
echo ""

# Register plugin in rendition configuration
echo "========================================="
echo "Registering Plugin in Rendition Config"
echo "========================================="
echo "Stack: ${RENDITION_STACK}Stack"
echo "MIME Types: $MIME_TYPES"
echo ""

# Get current rendition configuration
CURRENT_RENDITION_CONFIG=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.dam\.config\.dam\.extensibility_rendition_config\.json}' 2>/dev/null || echo "{}")

# Create plugin operation entry for renditions
PLUGIN_OPERATION=$(cat <<EOF
{
  "operation": {
    "process": {}
  },
  "plugin": "$PLUGIN_NAME"
}
EOF
)

echo "📝 Plugin operation entry:"
echo "$PLUGIN_OPERATION" | jq '.'
echo ""

echo "🔄 Adding plugin to rendition stacks..."

# Update rendition config for each MIME type
NEW_RENDITION_CONFIG="$CURRENT_RENDITION_CONFIG"

IFS=',' read -ra MIME_ARRAY <<< "$MIME_TYPES"
for MIME_TYPE in "${MIME_ARRAY[@]}"; do
    echo "  Processing: $MIME_TYPE"
    
    # Check if MIME type exists in config
    MIME_EXISTS=$(echo "$NEW_RENDITION_CONFIG" | jq -e ".\"$MIME_TYPE\"" > /dev/null 2>&1 && echo "true" || echo "false")
    
    if [ "$MIME_EXISTS" = "true" ]; then
        # Get the first rendition (usually "Original")
        STACK_KEY="${RENDITION_STACK}Stack"
        
        # Check if plugin already exists in the stack
        PLUGIN_IN_STACK=$(echo "$NEW_RENDITION_CONFIG" | jq -e ".\"$MIME_TYPE\".rendition[0].\"$STACK_KEY\" | map(select(.plugin == \"$PLUGIN_NAME\")) | length" 2>/dev/null || echo "0")
        
        if [ "$PLUGIN_IN_STACK" = "0" ]; then
            # Add plugin to the stack
            NEW_RENDITION_CONFIG=$(echo "$NEW_RENDITION_CONFIG" | jq ".\"$MIME_TYPE\".rendition[0].\"$STACK_KEY\" += [$PLUGIN_OPERATION]")
            echo "    ✓ Added to ${STACK_KEY}"
        else
            echo "    ⚠️  Already in ${STACK_KEY}"
        fi
    else
        echo "    ⚠️  MIME type not found in rendition config"
    fi
done

echo ""
echo "🔄 Updating rendition configuration in ConfigMap..."

# Create temporary file for rendition config
RENDITION_TEMP_FILE=$(mktemp)
echo "$NEW_RENDITION_CONFIG" > "$RENDITION_TEMP_FILE"

# Patch the ConfigMap with the new rendition configuration
kubectl patch configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --type merge -p "{\"data\":{\"dam.config.dam.extensibility_rendition_config.json\":$(cat "$RENDITION_TEMP_FILE" | jq -R -s .)}}"

rm -f "$RENDITION_TEMP_FILE"

echo ""
echo "✅ Rendition configuration updated!"
echo ""

# Check if DAM pods need restart
echo "🔍 Checking if DAM service needs restart..."
DAM_DEPLOYMENT=$(kubectl get deployment -n "$NAMESPACE" -l app="${DX_RELEASE}-digital-asset-management" -o name 2>/dev/null | head -n 1)

if [ -n "$DAM_DEPLOYMENT" ]; then
    echo ""
    echo "Found DAM deployment. Configuration changes may require a restart."
    read -p "Do you want to restart the DAM deployment now? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        kubectl rollout restart "$DAM_DEPLOYMENT" -n "$NAMESPACE"
        echo "✓ Rollout restart initiated"
        echo ""
        echo "Monitor rollout status with:"
        echo "  kubectl rollout status $DAM_DEPLOYMENT -n $NAMESPACE"
    fi
else
    echo "⚠️  Could not find DAM deployment. You may need to manually restart the service."
fi

echo ""
echo "Plugin registration complete!"
echo ""
