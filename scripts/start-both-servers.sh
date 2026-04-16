#!/bin/bash

# Start Both Backend and Frontend Servers
# Backend: http://localhost:3000
# Frontend: http://localhost:5173

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$PROJECT_ROOT/packages/server-v1"
FRONTEND_DIR="$PROJECT_ROOT/packages/portlet-v1"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting Water Muse Development Servers${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Kill any existing servers
echo -e "${YELLOW}Cleaning up existing servers...${NC}"
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:5173 | xargs kill -9 2>/dev/null || true
sleep 1

# Start backend server
echo -e "${BLUE}▶ Starting backend server (port 3000)...${NC}"
cd "$SERVER_DIR"
npm run dev > /tmp/backend-server.log 2>&1 &
BACKEND_PID=$!
echo -e "${GREEN}  Backend PID: $BACKEND_PID${NC}"

# Wait for backend to be ready
echo -e "${YELLOW}  Waiting for backend to start...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:3000/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Backend server ready!${NC}"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Backend server failed to start${NC}"
        echo -e "${YELLOW}Check logs: tail -f /tmp/backend-server.log${NC}"
        exit 1
    fi
done
echo ""

# Start frontend server
echo -e "${BLUE}▶ Starting frontend server (port 5173)...${NC}"
cd "$FRONTEND_DIR"
npm run dev > /tmp/frontend-server.log 2>&1 &
FRONTEND_PID=$!
echo -e "${GREEN}  Frontend PID: $FRONTEND_PID${NC}"

# Wait for frontend to be ready
echo -e "${YELLOW}  Waiting for frontend to start...${NC}"
for i in {1..30}; do
    if lsof -Pi :5173 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Frontend server ready!${NC}"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Frontend server failed to start${NC}"
        echo -e "${YELLOW}Check logs: tail -f /tmp/frontend-server.log${NC}"
        kill $BACKEND_PID 2>/dev/null
        exit 1
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ Both servers are running!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Backend (API):${NC}"
echo -e "  URL:          http://localhost:3000"
echo -e "  API Explorer: http://localhost:3000/explorer"
echo -e "  Health:       http://localhost:3000/health"
echo -e "  Logs:         tail -f /tmp/backend-server.log"
echo ""
echo -e "${GREEN}Frontend (UI):${NC}"
echo -e "  URL:          http://localhost:5173"
echo -e "  Logs:         tail -f /tmp/frontend-server.log"
echo ""
echo -e "${YELLOW}To stop both servers:${NC}"
echo -e "  kill $BACKEND_PID $FRONTEND_PID"
echo -e "  or run: ./scripts/stop-servers.sh"
echo ""
echo -e "${BLUE}Press Ctrl+C to stop monitoring (servers will continue running)${NC}"
echo ""

# Save PIDs for later cleanup
echo "$BACKEND_PID" > /tmp/backend-server.pid
echo "$FRONTEND_PID" > /tmp/frontend-server.pid

# Monitor logs
trap "echo ''; echo 'Servers still running. Use ./scripts/stop-servers.sh to stop them.'; exit 0" INT

tail -f /tmp/backend-server.log /tmp/frontend-server.log
