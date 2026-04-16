#!/bin/bash
set -e

echo "=================================="
echo "Testing Watermark Plugin"
echo "=================================="

NAMESPACE=${NAMESPACE:-"dam-plugins"}
RELEASE_NAME=${RELEASE_NAME:-"dam-plugin"}
LOCAL_PORT=${LOCAL_PORT:-"3000"}
SERVICE_NAME="${RELEASE_NAME}-dam-plugin"

# Setup port forward
echo "Setting up port forward..."
kubectl port-forward -n ${NAMESPACE} svc/${SERVICE_NAME} ${LOCAL_PORT}:3000 &
PF_PID=$!

cleanup() {
    echo ""
    echo "Stopping port forward..."
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

sleep 3

# Create test directory
TEST_DIR="/tmp/dam-plugin-test"
mkdir -p ${TEST_DIR}

echo ""
echo "=== Creating Test Images ==="

# Create test images
if command -v convert &> /dev/null; then
    # Image with "house" in name
    convert -size 800x600 xc:skyblue \
        -gravity center -pointsize 72 -fill white \
        -annotate +0+0 "Test House" \
        ${TEST_DIR}/beautiful_house_photo.jpg
    echo "✅ Created: beautiful_house_photo.jpg"

    # Image without "house" in name
    convert -size 800x600 xc:lightgreen \
        -gravity center -pointsize 72 -fill white \
        -annotate +0+0 "Test Image" \
        ${TEST_DIR}/landscape_photo.jpg
    echo "✅ Created: landscape_photo.jpg"
else
    echo "⚠️  ImageMagick not found. Using placeholder service..."
    
    # Download sample images
    curl -s "https://via.placeholder.com/800x600/87CEEB/FFFFFF?text=Test+House" \
        -o ${TEST_DIR}/beautiful_house_photo.jpg
    echo "✅ Downloaded: beautiful_house_photo.jpg"
    
    curl -s "https://via.placeholder.com/800x600/90EE90/FFFFFF?text=Test+Image" \
        -o ${TEST_DIR}/landscape_photo.jpg
    echo "✅ Downloaded: landscape_photo.jpg"
fi

echo ""
echo "=== Test 1: Image with 'house' in filename ==="
echo "File: beautiful_house_photo.jpg"
echo "Expected: Should get watermarked"
echo ""

RESPONSE=$(curl -s -X POST http://localhost:${LOCAL_PORT}/api/v1/process \
    -F "file=@${TEST_DIR}/beautiful_house_photo.jpg" \
    -F "callbackUrl=http://example.com/callback" \
    -H "X-API-Key: test-key")

echo "Response:"
echo "$RESPONSE" | jq '.'

# Check if watermark was applied
if echo "$RESPONSE" | jq -e '.processingInfo.watermarkApplied == true' > /dev/null; then
    echo "✅ Watermark applied successfully!"
    
    # Save watermarked image
    if echo "$RESPONSE" | jq -e '.processedFile' > /dev/null; then
        echo "$RESPONSE" | jq -r '.processedFile' | base64 -d > ${TEST_DIR}/beautiful_house_photo_watermarked.jpg
        echo "📸 Watermarked image saved: ${TEST_DIR}/beautiful_house_photo_watermarked.jpg"
    fi
else
    echo "❌ Watermark was not applied"
fi

echo ""
echo "=== Test 2: Image without 'house' in filename ==="
echo "File: landscape_photo.jpg"
echo "Expected: Should NOT get watermarked"
echo ""

RESPONSE=$(curl -s -X POST http://localhost:${LOCAL_PORT}/api/v1/process \
    -F "file=@${TEST_DIR}/landscape_photo.jpg" \
    -F "callbackUrl=http://example.com/callback" \
    -H "X-API-Key: test-key")

echo "Response:"
echo "$RESPONSE" | jq '.'

# Check if watermark was NOT applied
if echo "$RESPONSE" | jq -e '.processingInfo.watermarkApplied == false' > /dev/null; then
    echo "✅ Watermark correctly skipped!"
else
    echo "❌ Watermark behavior incorrect"
fi

echo ""
echo "=== Test 3: Check tags ==="
echo ""

# Test that house image gets 'house' and 'watermarked' tags
RESPONSE=$(curl -s -X POST http://localhost:${LOCAL_PORT}/api/v1/process \
    -F "file=@${TEST_DIR}/beautiful_house_photo.jpg" \
    -F "callbackUrl=http://example.com/callback" \
    -H "X-API-Key: test-key")

TAGS=$(echo "$RESPONSE" | jq -r '.tags | join(", ")')
echo "Tags for beautiful_house_photo.jpg: $TAGS"

if echo "$TAGS" | grep -q "house" && echo "$TAGS" | grep -q "watermarked"; then
    echo "✅ Correct tags applied!"
else
    echo "❌ Missing expected tags"
fi

echo ""
echo "=== Test Summary ==="
echo "Test images location: ${TEST_DIR}"
echo ""
echo "View watermarked image:"
echo "  open ${TEST_DIR}/beautiful_house_photo_watermarked.jpg"
echo ""
echo "To manually test:"
echo "  curl -X POST http://localhost:3000/api/v1/process \\"
echo "    -F 'file=@${TEST_DIR}/beautiful_house_photo.jpg' \\"
echo "    -F 'callbackUrl=http://example.com/callback'"
echo ""

wait $PF_PID
