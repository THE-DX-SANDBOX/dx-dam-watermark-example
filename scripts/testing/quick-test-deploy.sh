#!/bin/bash
# Quick test: Deploy only (assumes image already exists)

cd "$(dirname "$0")/../.."

echo "Running deploy-only tests..."
echo ""

SKIP_PUSH=true ./scripts/testing/test-template-end-to-end.sh deploy-only
