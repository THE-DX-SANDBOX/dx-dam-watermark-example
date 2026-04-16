#!/bin/bash
set -e

echo "=================================="
echo "Local Watermark Plugin Test"
echo "=================================="

# Check if server is running
if ! curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "❌ Server not running on localhost:3000"
    echo ""
    echo "Start the server with:"
    echo "  cd packages/server-v1"
    echo "  npm install"
    echo "  npm run dev"
    exit 1
fi

echo "✅ Server is running"
echo ""

# Create test directory
TEST_DIR="/tmp/dam-plugin-test"
mkdir -p ${TEST_DIR}

echo "=== Creating Test Images ==="

# Create test images
if command -v convert &> /dev/null; then
    convert -size 800x600 xc:skyblue \
        -gravity center -pointsize 72 -fill white \
        -annotate +0+0 "Test House" \
        ${TEST_DIR}/my_house_photo.jpg
    
    convert -size 800x600 xc:lightgreen \
        -gravity center -pointsize 72 -fill white \
        -annotate +0+0 "Landscape" \
        ${TEST_DIR}/mountain_view.jpg
    
    echo "✅ Created test images with ImageMagick"
else
    curl -s "https://via.placeholder.com/800x600/87CEEB/FFFFFF?text=House" \
        -o ${TEST_DIR}/my_house_photo.jpg
    curl -s "https://via.placeholder.com/800x600/90EE90/FFFFFF?text=Mountain" \
        -o ${TEST_DIR}/mountain_view.jpg
    
    echo "✅ Downloaded test images"
fi

echo ""
echo "=== Test 1: House Image (should be watermarked) ==="

RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/process \
    -F "file=@${TEST_DIR}/my_house_photo.jpg" \
    -F "callbackUrl=http://localhost:3000/test-callback")

echo "$RESPONSE" | jq '.'

if echo "$RESPONSE" | jq -e '.processingInfo.watermarkApplied == true' > /dev/null; then
    echo "✅ Test passed: Watermark applied"
    
    # Save watermarked image if returned
    if echo "$RESPONSE" | jq -e '.processedFile' > /dev/null; then
        echo "$RESPONSE" | jq -r '.processedFile' | base64 -d > ${TEST_DIR}/my_house_photo_watermarked.jpg
        echo "📸 Watermarked image saved: ${TEST_DIR}/my_house_photo_watermarked.jpg"
    fi
else
    echo "❌ Test failed: Watermark not applied"
fi

echo ""
echo "=== Test 2: Non-House Image (should NOT be watermarked) ==="

RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/process \
    -F "file=@${TEST_DIR}/mountain_view.jpg" \
    -F "callbackUrl=http://localhost:3000/test-callback")

echo "$RESPONSE" | jq '.'

if echo "$RESPONSE" | jq -e '.processingInfo.watermarkApplied == false' > /dev/null; then
    echo "✅ Test passed: Watermark correctly skipped"
else
    echo "❌ Test failed: Incorrect watermark behavior"
fi

echo ""
echo "=== Test Complete ==="
echo "Test images: ${TEST_DIR}"
echo ""
echo "View watermarked image:"
echo "  open ${TEST_DIR}/my_house_photo_watermarked.jpg"
echo ""
