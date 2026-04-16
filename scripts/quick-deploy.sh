#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "=================================="
echo "Quick Deploy (No Build)"
echo "=================================="
echo "This will deploy using the latest image from registry"
echo ""

ENVIRONMENT=${1:-"dev"}

# Skip build, just deploy
SKIP_BUILD=true ./scripts/deploy.sh ${ENVIRONMENT}
