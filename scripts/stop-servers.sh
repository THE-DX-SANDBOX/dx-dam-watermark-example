#!/bin/bash

# Stop Both Backend and Frontend Servers

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping servers...${NC}"

# Kill by PID files if they exist
if [ -f /tmp/backend-server.pid ]; then
    BACKEND_PID=$(cat /tmp/backend-server.pid)
    kill $BACKEND_PID 2>/dev/null && echo -e "${GREEN}✅ Stopped backend (PID: $BACKEND_PID)${NC}"
    rm /tmp/backend-server.pid
fi

if [ -f /tmp/frontend-server.pid ]; then
    FRONTEND_PID=$(cat /tmp/frontend-server.pid)
    kill $FRONTEND_PID 2>/dev/null && echo -e "${GREEN}✅ Stopped frontend (PID: $FRONTEND_PID)${NC}"
    rm /tmp/frontend-server.pid
fi

# Kill by port as backup
lsof -ti:3000 | xargs kill -9 2>/dev/null && echo -e "${GREEN}✅ Stopped process on port 3000${NC}"
lsof -ti:5173 | xargs kill -9 2>/dev/null && echo -e "${GREEN}✅ Stopped process on port 5173${NC}"

echo -e "${GREEN}All servers stopped${NC}"
