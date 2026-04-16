#!/bin/bash
#
# Plugin Initialization Script
# Run this script to customize the template for your new plugin
#

set -e

echo "=========================================="
echo "DAM Plugin Template Initialization"
echo "=========================================="
echo ""

# Get plugin information
read -p "Enter plugin name (lowercase, hyphens): " PLUGIN_NAME
read -p "Enter plugin display name: " PLUGIN_DISPLAY_NAME
read -p "Enter plugin description: " PLUGIN_DESCRIPTION
read -p "Enter your organization name: " PLUGIN_AUTHOR

# Validate input
if [ -z "$PLUGIN_NAME" ]; then
    echo "Error: Plugin name is required"
    exit 1
fi

echo ""
echo "Configuring plugin: $PLUGIN_NAME"
echo ""

# Update plugin-config.json
cat > plugin-config.json <<EOF
{
  "pluginName": "${PLUGIN_NAME}",
  "pluginDisplayName": "${PLUGIN_DISPLAY_NAME}",
  "pluginDescription": "${PLUGIN_DESCRIPTION}",
  "pluginAuthor": "${PLUGIN_AUTHOR}",
  "pluginVersion": "1.0.0",
  "apiVersion": "v1",
  "servicePort": 3000,
  "externalServiceConfig": {
    "apiKeyEnvVar": "EXTERNAL_API_KEY",
    "apiUrlEnvVar": "EXTERNAL_API_URL",
    "timeoutMs": 30000
  },
  "damIntegration": {
    "requiresAuthentication": true,
    "supportedFileTypes": ["image/jpeg", "image/png", "image/gif", "image/webp"],
    "maxFileSizeMB": 100,
    "callbackRequired": true
  },
  "kubernetes": {
    "namespace": "dam-plugins",
    "replicas": 2,
    "cpuRequest": "100m",
    "cpuLimit": "500m",
    "memoryRequest": "256Mi",
    "memoryLimit": "512Mi"
  }
}
EOF

# Update package.json
sed -i.bak "s/dam-plugin-template/${PLUGIN_NAME}/g" package.json
sed -i.bak "s/Your Organization/${PLUGIN_AUTHOR}/g" package.json
rm package.json.bak

# Update server package.json
sed -i.bak "s/@dam-plugin\/server-v1/@${PLUGIN_NAME}\/server-v1/g" packages/server-v1/package.json
rm packages/server-v1/package.json.bak

# Create .env file from example
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env file - please customize it with your configuration"
fi

# Initialize git repository if not already initialized
if [ ! -d .git ]; then
    git init
    echo "Initialized git repository"
fi

echo ""
echo "=========================================="
echo "✅ Plugin initialized successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Edit .env file with your configuration"
echo "2. Implement your processing logic in:"
echo "   packages/server-v1/src/services/plugin.service.ts"
echo "3. Customize request/response models in:"
echo "   packages/server-v1/src/models/"
echo "4. Run 'npm install' to install dependencies"
echo "5. Run 'npm run dev' to start development server"
echo ""
echo "For more information, see README.md"
echo ""
