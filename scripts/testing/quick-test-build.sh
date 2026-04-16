#!/bin/bash
# Quick test: Build only

cd "$(dirname "$0")/../.."

echo "Running build-only tests..."
echo ""

./scripts/testing/test-template-end-to-end.sh build-only
