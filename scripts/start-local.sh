#!/bin/bash

# Start Water Muse Backend Server Locally
# Usage: ./scripts/start-local.sh

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$PROJECT_ROOT/packages/server-v1"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting Water Muse Backend Server${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if dependencies are installed
if [ ! -d "$SERVER_DIR/node_modules" ]; then
    echo -e "${YELLOW}⚠️  Dependencies not installed. Installing...${NC}"
    cd "$SERVER_DIR"
    npm install
    echo ""
fi

# Check if server is already running
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${YELLOW}⚠️  Server already running on port 3000${NC}"
    echo -e "   Kill it with: lsof -ti:3000 | xargs kill -9"
    echo ""
    exit 1
fi

echo -e "${GREEN}Starting server...${NC}"
echo -e "${BLUE}Server will be available at:${NC}"
echo -e "  ${GREEN}http://localhost:3000${NC}"
echo -e "  ${GREEN}http://localhost:3000/explorer${NC} (API Explorer)"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

cd "$SERVER_DIR"
npm run dev
