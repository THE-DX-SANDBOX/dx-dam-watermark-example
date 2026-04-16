#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${YELLOW}⚠️  .env file not found${NC}"
    echo "Run ./scripts/init-template.sh first"
    exit 1
fi

PID_FILE="$PROJECT_ROOT/.postgres-port-forward.pid"

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if port forwarding is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        print_info "Port forwarding already running (PID: $PID)"
        print_info "PostgreSQL accessible at: localhost:5432"
        echo ""
        print_info "Connection string:"
        echo "  postgresql://$DB_USER:***@localhost:5432/$DB_NAME"
        echo ""
        print_info "To stop: pkill -f 'kubectl port-forward.*postgresql'"
        exit 0
    else
        rm -f "$PID_FILE"
    fi
fi

# Check if any port forwarding is active
if pgrep -f "kubectl port-forward.*postgresql.*5432" > /dev/null; then
    print_info "Port forwarding already active"
    print_info "PostgreSQL accessible at: localhost:5432"
    exit 0
fi

print_info "Starting PostgreSQL port forwarding..."

# Find PostgreSQL service or pod
SVC=$(kubectl get svc -n "$NAMESPACE" -o name 2>/dev/null | grep -i postgres | head -n 1 | cut -d'/' -f2 || echo "")

if [ -n "$SVC" ]; then
    print_info "Using service: $SVC"
    kubectl port-forward -n "$NAMESPACE" svc/"$SVC" 5432:5432 > /dev/null 2>&1 &
else
    # Find pod
    POD=$(kubectl get pods -n "$NAMESPACE" -o name 2>/dev/null | grep -i postgres | head -n 1 | cut -d'/' -f2 || echo "")
    if [ -n "$POD" ]; then
        print_info "Using pod: $POD"
        kubectl port-forward -n "$NAMESPACE" "$POD" 5432:5432 > /dev/null 2>&1 &
    else
        print_error "PostgreSQL not found in namespace $NAMESPACE"
        exit 1
    fi
fi

PF_PID=$!
echo $PF_PID > "$PID_FILE"

sleep 2

if ps -p $PF_PID > /dev/null; then
    print_success "Port forwarding active (PID: $PF_PID)"
    print_info "PostgreSQL accessible at: localhost:5432"
    echo ""
    print_info "Connect with psql:"
    echo "  PGPASSWORD='$DB_PASSWORD' psql -h localhost -U $DB_USER -d $DB_NAME"
    echo ""
    print_info "Connection string:"
    echo "  postgresql://$DB_USER:***@localhost:5432/$DB_NAME"
    echo ""
    print_info "To stop: pkill -f 'kubectl port-forward.*postgresql'"
else
    print_error "Port forwarding failed to start"
    rm -f "$PID_FILE"
    exit 1
fi
