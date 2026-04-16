#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
else
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Run ./scripts/init-template.sh first"
    exit 1
fi

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           PostgreSQL Database Creation Script                ║
║                                                               ║
║     Creates database and user with proper permissions        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if psql is installed
check_psql() {
    if ! command -v psql &> /dev/null; then
        print_warning "psql client not found"
        echo ""
        echo "Install PostgreSQL client:"
        echo "  macOS:   brew install postgresql@15"
        echo "  Ubuntu:  sudo apt-get install postgresql-client"
        echo "  Windows: Download from https://www.postgresql.org/download/"
        return 1
    fi
    
    print_success "psql client found: $(psql --version | head -n1)"
    return 0
}

# Find PostgreSQL pod in cluster
find_postgres_pod() {
    print_info "Searching for PostgreSQL pod in namespace: $NAMESPACE"
    
    # Try common label selectors
    local selectors=(
        "app=postgresql"
        "app.kubernetes.io/name=postgresql"
        "component=postgresql"
        "app=${NAMESPACE}-dx-postgres"
    )
    
    for selector in "${selectors[@]}"; do
        POD=$(kubectl get pods -n "$NAMESPACE" -l "$selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$POD" ]; then
            print_success "Found PostgreSQL pod: $POD (selector: $selector)"
            return 0
        fi
    done
    
    # Try pattern matching
    POD=$(kubectl get pods -n "$NAMESPACE" -o name 2>/dev/null | grep -i postgres | head -n 1 | cut -d'/' -f2 || echo "")
    if [ -n "$POD" ]; then
        print_success "Found PostgreSQL pod: $POD (pattern match)"
        return 0
    fi
    
    print_error "PostgreSQL pod not found in namespace $NAMESPACE"
    print_info "Available pods:"
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "  (none)"
    return 1
}

# Test PostgreSQL connectivity via kubectl
test_postgres_kubectl() {
    print_info "Testing PostgreSQL connection via kubectl..."
    
    if kubectl exec "$POD" -n "$NAMESPACE" -- \
        psql -U postgres -c "SELECT version();" > /dev/null 2>&1; then
        print_success "PostgreSQL is accessible via kubectl"
        return 0
    else
        print_error "Cannot connect to PostgreSQL via kubectl"
        return 1
    fi
}

# Create database via kubectl exec
create_database_kubectl() {
    print_info "Creating database via kubectl exec..."
    
    # Check if database exists
    DB_EXISTS=$(kubectl exec "$POD" -n "$NAMESPACE" -- \
        psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null || echo "")
    
    if [ "$DB_EXISTS" = "1" ]; then
        print_warning "Database '$DB_NAME' already exists"
        
        read -p "Drop and recreate? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing database"
        else
            print_info "Dropping database..."
            kubectl exec "$POD" -n "$NAMESPACE" -- \
                psql -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" || return 1
            print_success "Database dropped"
            DB_EXISTS=""
        fi
    fi
    
    # Check if user exists
    USER_EXISTS=$(kubectl exec "$POD" -n "$NAMESPACE" -- \
        psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';" 2>/dev/null || echo "")
    
    if [ "$USER_EXISTS" != "1" ]; then
        print_info "Creating user '$DB_USER'..."
        kubectl exec "$POD" -n "$NAMESPACE" -- \
            psql -U postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" || return 1
        print_success "User created"
    else
        print_info "User '$DB_USER' already exists"
        
        # Update password
        print_info "Updating password..."
        kubectl exec "$POD" -n "$NAMESPACE" -- \
            psql -U postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" || return 1
    fi
    
    # Create database if it doesn't exist
    if [ "$DB_EXISTS" != "1" ] || [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Creating database '$DB_NAME'..."
        kubectl exec "$POD" -n "$NAMESPACE" -- \
            psql -U postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" || return 1
        print_success "Database created"
    fi
    
    # Grant privileges
    print_info "Granting privileges..."
    kubectl exec "$POD" -n "$NAMESPACE" -- \
        psql -U postgres -d "$DB_NAME" <<-'EOSQL' || return 1
            GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
            GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO $DB_USER;
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO $DB_USER;
            ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON FUNCTIONS TO $DB_USER;
EOSQL
    
    print_success "Privileges granted"
    
    # Test connection
    print_info "Testing user connection..."
    if kubectl exec "$POD" -n "$NAMESPACE" -- \
        psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT current_database(), current_user;" > /dev/null 2>&1; then
        print_success "User can connect to database"
        return 0
    else
        print_error "User cannot connect to database"
        return 1
    fi
}

# Setup port forwarding for local access
setup_port_forward() {
    print_info "Setting up port forwarding for local access..."
    
    # Check if port forwarding is already active
    if pgrep -f "kubectl port-forward.*postgresql.*5432" > /dev/null; then
        print_warning "Port forwarding already active"
        print_info "To restart: pkill -f 'kubectl port-forward.*postgresql'; ./scripts/create-database.sh"
        return 0
    fi
    
    # Find PostgreSQL service
    SVC=$(kubectl get svc -n "$NAMESPACE" -o name 2>/dev/null | grep -i postgres | head -n 1 | cut -d'/' -f2 || echo "")
    
    if [ -n "$SVC" ]; then
        print_info "Using service: $SVC"
        kubectl port-forward -n "$NAMESPACE" svc/"$SVC" 5432:5432 > /dev/null 2>&1 &
    else
        print_warning "PostgreSQL service not found, using pod directly"
        kubectl port-forward -n "$NAMESPACE" "$POD" 5432:5432 > /dev/null 2>&1 &
    fi
    
    PF_PID=$!
    echo $PF_PID > "$PROJECT_ROOT/.postgres-port-forward.pid"
    
    sleep 2
    
    if ps -p $PF_PID > /dev/null; then
        print_success "Port forwarding active (PID: $PF_PID)"
        print_info "PostgreSQL accessible at: localhost:5432"
        print_info "To stop: pkill -f 'kubectl port-forward.*postgresql'"
        return 0
    else
        print_error "Port forwarding failed to start"
        rm -f "$PROJECT_ROOT/.postgres-port-forward.pid"
        return 1
    fi
}

# Test local connection via port forward
test_local_connection() {
    print_info "Testing local connection via port forward..."
    
    # Wait a moment for port forward to stabilize
    sleep 1
    
    if PGPASSWORD="$DB_PASSWORD" psql -h localhost -p 5432 -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
        print_success "Local connection successful"
        print_info "Connection string: postgresql://$DB_USER:***@localhost:5432/$DB_NAME"
        return 0
    else
        print_warning "Local connection failed (port forwarding may need time to establish)"
        print_info "Try again in a few seconds with:"
        echo "  PGPASSWORD='$DB_PASSWORD' psql -h localhost -U $DB_USER -d $DB_NAME"
        return 1
    fi
}

# Generate connection info
generate_connection_info() {
    mkdir -p "$PROJECT_ROOT/database"
    
    cat > "$PROJECT_ROOT/database/CONNECTION_INFO.md" << EOF
# Database Connection Information

Generated: $(date)

## Database Details

- **Database Name:** $DB_NAME
- **Database User:** $DB_USER
- **Host (in-cluster):** $DB_HOST
- **Port:** $DB_PORT
- **SSL Mode:** ${DB_SSL:-false}

## Connection Strings

### For Application (in Kubernetes)
\`\`\`
postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=${DB_SSL:-disable}
\`\`\`

### For Local Development (via port-forward)
\`\`\`bash
# Start port forwarding (if not already running)
./scripts/port-forward-db.sh

# Connection string
postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}
\`\`\`

## Using psql

### Connect via kubectl (inside cluster)
\`\`\`bash
kubectl exec -it $POD -n $NAMESPACE -- psql -U $DB_USER -d $DB_NAME
\`\`\`

### Connect locally (via port-forward)
\`\`\`bash
# Make sure port forwarding is active
./scripts/port-forward-db.sh

# Connect with psql
PGPASSWORD='$DB_PASSWORD' psql -h localhost -p 5432 -U $DB_USER -d $DB_NAME
\`\`\`

## Environment Variables

Set in your \`.env\` file:

\`\`\`bash
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_SSL=${DB_SSL:-false}
\`\`\`

## Database Management

### List all tables
\`\`\`bash
kubectl exec $POD -n $NAMESPACE -- psql -U $DB_USER -d $DB_NAME -c "\\dt"
\`\`\`

### Backup database
\`\`\`bash
kubectl exec $POD -n $NAMESPACE -- pg_dump -U $DB_USER $DB_NAME > backup.sql
\`\`\`

### Restore database
\`\`\`bash
cat backup.sql | kubectl exec -i $POD -n $NAMESPACE -- psql -U $DB_USER -d $DB_NAME
\`\`\`

### Drop database (careful!)
\`\`\`bash
kubectl exec $POD -n $NAMESPACE -- psql -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
\`\`\`

## Troubleshooting

### Port forward not working
\`\`\`bash
# Kill existing port forwards
pkill -f 'kubectl port-forward.*postgresql'

# Start new port forward
./scripts/port-forward-db.sh
\`\`\`

### Connection refused
\`\`\`bash
# Check if pod is running
kubectl get pods -n $NAMESPACE | grep postgres

# Check pod logs
kubectl logs $POD -n $NAMESPACE
\`\`\`

### Authentication failed
\`\`\`bash
# Reset password
kubectl exec $POD -n $NAMESPACE -- \\
  psql -U postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
\`\`\`

---
For more help, see docs/DATABASE_SETUP.md
EOF

    print_success "Connection info saved to: database/CONNECTION_INFO.md"
}

# Main execution
main() {
    print_banner
    
    echo "Configuration:"
    echo "  Namespace: $NAMESPACE"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo "  Host: $DB_HOST"
    echo ""
    
    # Check prerequisites
    local has_psql=false
    if check_psql; then
        has_psql=true
    else
        print_warning "Continuing without local psql client (kubectl exec will be used)"
    fi
    
    # Find PostgreSQL pod
    if ! find_postgres_pod; then
        print_error "Cannot proceed without PostgreSQL pod"
        exit 1
    fi
    
    # Test connection
    if ! test_postgres_kubectl; then
        print_error "Cannot connect to PostgreSQL"
        exit 1
    fi
    
    # Create database
    echo ""
    if ! create_database_kubectl; then
        print_error "Database creation failed"
        exit 1
    fi
    
    # Setup port forwarding
    echo ""
    if setup_port_forward; then
        echo ""
        # Test local connection
        if [ "$has_psql" = true ]; then
            test_local_connection || true
        fi
    fi
    
    # Generate connection info
    echo ""
    generate_connection_info
    
    echo ""
    print_success "Database setup complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Install LoopBack PostgreSQL connector:"
    echo "     cd packages/server-v1 && npm install --save loopback-connector-postgresql"
    echo ""
    echo "  2. Test connection locally:"
    echo "     PGPASSWORD='$DB_PASSWORD' psql -h localhost -U $DB_USER -d $DB_NAME"
    echo ""
    echo "  3. Run database migrations:"
    echo "     cd packages/server-v1 && npm run migrate"
    echo ""
    echo "  4. Start your application:"
    echo "     npm start"
    echo ""
    print_info "Connection details: database/CONNECTION_INFO.md"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        cat << EOF
PostgreSQL Database Creation Script

Usage: $0 [OPTIONS]

OPTIONS:
    --help, -h      Show this help message
    --status        Check database status without creating
    --drop          Drop database and user (requires confirmation)
    --port-forward  Setup port forwarding only

EXAMPLES:
    # Create database and setup port forwarding
    $0

    # Check if database exists
    $0 --status

    # Drop database
    $0 --drop

    # Setup port forwarding only
    $0 --port-forward

EOF
        exit 0
        ;;
    --status)
        find_postgres_pod || exit 1
        
        DB_EXISTS=$(kubectl exec "$POD" -n "$NAMESPACE" -- \
            psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null || echo "")
        
        if [ "$DB_EXISTS" = "1" ]; then
            print_success "Database '$DB_NAME' exists"
        else
            print_warning "Database '$DB_NAME' does not exist"
        fi
        
        USER_EXISTS=$(kubectl exec "$POD" -n "$NAMESPACE" -- \
            psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';" 2>/dev/null || echo "")
        
        if [ "$USER_EXISTS" = "1" ]; then
            print_success "User '$DB_USER' exists"
        else
            print_warning "User '$DB_USER' does not exist"
        fi
        exit 0
        ;;
    --drop)
        find_postgres_pod || exit 1
        
        print_warning "This will DROP database '$DB_NAME' and user '$DB_USER'"
        read -p "Are you sure? Type 'yes' to confirm: " confirm
        
        if [ "$confirm" != "yes" ]; then
            print_info "Cancelled"
            exit 0
        fi
        
        print_info "Dropping database..."
        kubectl exec "$POD" -n "$NAMESPACE" -- \
            psql -U postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
        
        print_info "Dropping user..."
        kubectl exec "$POD" -n "$NAMESPACE" -- \
            psql -U postgres -c "DROP USER IF EXISTS $DB_USER;"
        
        print_success "Database and user dropped"
        exit 0
        ;;
    --port-forward)
        find_postgres_pod || exit 1
        setup_port_forward
        print_info "Port forwarding is running in the background"
        print_info "To stop: pkill -f 'kubectl port-forward.*postgresql'"
        exit 0
        ;;
    *)
        main
        ;;
esac
