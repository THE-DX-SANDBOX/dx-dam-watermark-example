#!/bin/bash
cd "$(dirname "$0")"
chmod +x build.sh
chmod +x deploy.sh
chmod +x build-and-deploy-pipeline.sh
chmod +x quick-deploy.sh
chmod +x undeploy.sh
chmod +x test-plugin.sh
chmod +x register-with-dam.sh
echo "✅ All scripts are now executable"
