#!/bin/bash
# =============================================================================
# DX Universal Template - Interactive Initialization Script
# =============================================================================
# This script collects configuration, tests connections, and sets up the
# project for deployment.
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration storage
CONFIG_FILE="${PROJECT_ROOT}/.template-config.json"
ENV_FILE="${PROJECT_ROOT}/.env"

# =============================================================================
# Helper Functions
# =============================================================================

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     DX Universal Template - Interactive Setup                ║
║                                                               ║
║     This wizard will guide you through configuring your      ║
║     HCL DX project template.                                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

prompt_input() {
    local prompt=$1
    local default=$2
    local variable_name=$3
    local is_secret=${4:-false}
    
    if [ -n "$default" ]; then
        echo -e -n "${CYAN}$prompt ${NC}[${YELLOW}$default${NC}]: "
    else
        echo -e -n "${CYAN}$prompt: ${NC}"
    fi
    
    if [ "$is_secret" = true ]; then
        read -s user_input
        echo ""
    else
        read user_input
    fi
    
    if [ -z "$user_input" ]; then
        eval "$variable_name='$default'"
    else
        eval "$variable_name='$user_input'"
    fi
}

prompt_yes_no() {
    local prompt=$1
    local default=${2:-"n"}
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -e -n "${CYAN}$prompt ${NC}[${GREEN}Y${NC}/${YELLOW}n${NC}]: "
        else
            echo -e -n "${CYAN}$prompt ${NC}[${YELLOW}y${NC}/${GREEN}N${NC}]: "
        fi
        
        read yn
        
        if [ -z "$yn" ]; then
            yn=$default
        fi
        
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

prompt_choice() {
    local prompt=$1
    shift
    local options=("$@")
    
    echo -e "${CYAN}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${YELLOW}$((i+1))${NC}) ${options[$i]}"
    done
    
    while true; do
        echo -e -n "${CYAN}Enter choice (1-${#options[@]}): ${NC}"
        read choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice-1))]}"
            return 0
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and ${#options[@]}.${NC}"
        fi
    done
}

validate_hostname() {
    local hostname=$1
    if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]] || [[ $hostname =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_namespace() {
    local ns=$1
    if [[ $ns =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

test_connection() {
    local type=$1
    
    case $type in
        "kubernetes")
            if kubectl cluster-info &> /dev/null; then
                print_success "Kubernetes cluster connection successful"
                return 0
            else
                print_error "Cannot connect to Kubernetes cluster"
                return 1
            fi
            ;;
        "dx-portal")
            local hostname=$2
            local protocol=$3
            local port=$4
            local url="${protocol}://${hostname}:${port}/wps/portal"
            
            if curl -k -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
                print_success "DX Portal is reachable at $url"
                return 0
            else
                print_warning "Cannot reach DX Portal at $url (may require VPN/firewall)"
                return 1
            fi
            ;;
        "docker")
            if docker info &> /dev/null; then
                print_success "Docker daemon is running"
                return 0
            else
                print_warning "Docker daemon not accessible"
                return 1
            fi
            ;;
    esac
}


# =============================================================================
# Configuration Collection Functions
# =============================================================================

select_project_type() {
    print_section "Step 1: Project Type"
    
    print_info "What components do you need?"
    echo ""
    echo -e "  ${YELLOW}1${NC}) ${GREEN}Full Stack (Recommended)${NC}"
    echo -e "     - Script Portlet (React UI in DX Portal)"
    echo -e "     - Backend API (Kubernetes)"
    echo -e "     - Optional: DAM Plugin"
    echo ""
    echo -e "  ${YELLOW}2${NC}) ${GREEN}Backend API Only${NC}"
    echo -e "     - REST API service"
    echo -e "     - No UI components"
    echo ""
    echo -e "  ${YELLOW}3${NC}) ${GREEN}Script Portlet + Backend${NC}"
    echo -e "     - UI and API, no DAM"
    echo ""
    
    PROJECT_TYPE=$(prompt_choice "Select project type" \
        "Full Stack (Portlet + Backend + DAM)" \
        "Backend API Only" \
        "Script Portlet + Backend (No DAM)")
    
    case "$PROJECT_TYPE" in
        "Full Stack"*)
            ENABLE_PORTLET=true
            ENABLE_API=true
            ENABLE_DAM=true
            ;;
        "Backend API Only")
            ENABLE_PORTLET=false
            ENABLE_API=true
            ENABLE_DAM=false
            ;;
        "Script Portlet + Backend"*)
            ENABLE_PORTLET=true
            ENABLE_API=true
            ENABLE_DAM=false
            ;;
    esac
    
    print_success "Project Type: $PROJECT_TYPE"
}

collect_project_details() {
    print_section "Step 2: Project Details"
    
    # Load from existing .env if available
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE" 2>/dev/null || true
    fi
    
    prompt_input "Project Name (lowercase-with-hyphens)" "${PROJECT_NAME:-my-dx-project}" PROJECT_NAME
    prompt_input "Project Display Name" "${PROJECT_DISPLAY_NAME:-My DX Project}" PROJECT_DISPLAY_NAME
    prompt_input "Project Version" "1.0.0" PROJECT_VERSION
    
    print_success "Project: $PROJECT_NAME ($PROJECT_VERSION)"
}

collect_kubernetes_config() {
    print_section "Step 3: Kubernetes Configuration"
    
    # Test K8s connection first
    if ! test_connection "kubernetes"; then
        print_warning "Kubernetes cluster not accessible"
        if ! prompt_yes_no "Continue anyway?" "n"; then
            print_error "Kubernetes access required. Please configure kubectl and try again."
            exit 1
        fi
    fi
    
    # Get current context
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [ -n "$CURRENT_CONTEXT" ]; then
        print_info "Current context: $CURRENT_CONTEXT"
    fi
    
    # Namespace
    while true; do
        prompt_input "Kubernetes Namespace" "${NAMESPACE:-$PROJECT_NAME}" K8S_NAMESPACE
        
        if validate_namespace "$K8S_NAMESPACE"; then
            if kubectl get namespace "$K8S_NAMESPACE" &> /dev/null; then
                print_success "Namespace '$K8S_NAMESPACE' exists"
                break
            else
                print_warning "Namespace '$K8S_NAMESPACE' does not exist"
                if prompt_yes_no "Create namespace?" "y"; then
                    if kubectl create namespace "$K8S_NAMESPACE"; then
                        print_success "Namespace created"
                        break
                    else
                        print_error "Failed to create namespace"
                    fi
                else
                    print_info "Please create namespace manually or choose existing one"
                fi
            fi
        else
            print_error "Invalid namespace. Must be lowercase alphanumeric with hyphens."
        fi
    done
    
    # Release name
    prompt_input "Helm Release Name" "${RELEASE_NAME:-$PROJECT_NAME}" RELEASE_NAME
    
    print_success "Kubernetes: $K8S_NAMESPACE/$RELEASE_NAME"
}

collect_docker_config() {
    print_section "Step 4: Docker Registry"
    
    # Test Docker
    test_connection "docker"
    
    print_info "Common registries:"
    echo "  - GCP: us-central1-docker.pkg.dev/PROJECT/REPO"
    echo "  - Docker Hub: docker.io/USERNAME"
    echo "  - AWS ECR: ACCOUNT.dkr.ecr.REGION.amazonaws.com/REPO"
    echo ""
    
    prompt_input "Docker Registry URL" \
        "${DOCKER_REGISTRY:-<registry-host>/<repository>}" \
        DOCKER_REGISTRY
    
    prompt_input "Image Name" "${IMAGE_NAME:-$PROJECT_NAME}" IMAGE_NAME
    prompt_input "Image Tag" "${IMAGE_TAG:-latest}" IMAGE_TAG
    
    FULL_IMAGE="${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    print_success "Image: $FULL_IMAGE"
}

collect_dx_portal_config() {
    if [ "$ENABLE_PORTLET" = false ]; then
        print_info "Skipping DX Portal (no portlet enabled)"
        return
    fi
    
    print_section "Step 5: DX Portal Configuration"
    
    # Protocol
    DX_PROTOCOL=$(prompt_choice "DX Protocol" "https" "http")
    
    # Hostname
    while true; do
        prompt_input "DX Portal Hostname" "${DX_HOSTNAME:-<dx-hostname>}" DX_HOSTNAME
        
        if validate_hostname "$DX_HOSTNAME"; then
            break
        else
            print_error "Invalid hostname format"
        fi
    done
    
    # Port
    if [ "$DX_PROTOCOL" = "https" ]; then
        DEFAULT_PORT=443
    else
        DEFAULT_PORT=10042
    fi
    prompt_input "DX Port" "${DX_PORT:-$DEFAULT_PORT}" DX_PORT
    
    # Test connection
    print_info "Testing DX Portal connection..."
    test_connection "dx-portal" "$DX_HOSTNAME" "$DX_PROTOCOL" "$DX_PORT"
    
    # Credentials
    print_warning "DX Portal credentials (stored in .env - keep secure!)"
    prompt_input "DX Username" "${DX_USERNAME:-<dx-username>}" DX_USERNAME
    prompt_input "DX Password" "${DX_PASSWORD:-<dx-password>}" DX_PASSWORD true
    
    # WCM Configuration
    prompt_input "WCM Content Name" "${WCM_CONTENT_NAME:-$PROJECT_DISPLAY_NAME}" WCM_CONTENT_NAME
    prompt_input "WCM Site Area" "${WCM_SITE_AREA:-Applications}" WCM_SITE_AREA
    
    print_success "DX Portal: ${DX_PROTOCOL}://${DX_HOSTNAME}:${DX_PORT}"
}

collect_backend_config() {
    print_section "Step 6: Backend Service"
    
    prompt_input "Service Port" "${SERVICE_PORT:-3000}" SERVICE_PORT
    prompt_input "Number of Replicas" "${REPLICAS:-1}" REPLICAS
    
    print_info "Resource Limits"
    prompt_input "CPU Request (e.g., 250m)" "${CPU_REQUEST:-250m}" CPU_REQUEST
    prompt_input "CPU Limit (e.g., 500m)" "${CPU_LIMIT:-500m}" CPU_LIMIT
    prompt_input "Memory Request (e.g., 256Mi)" "${MEMORY_REQUEST:-256Mi}" MEMORY_REQUEST
    prompt_input "Memory Limit (e.g., 512Mi)" "${MEMORY_LIMIT:-512Mi}" MEMORY_LIMIT
    
    if prompt_yes_no "Enable autoscaling?" "y"; then
        AUTOSCALING_ENABLED=true
        prompt_input "Minimum Replicas" "1" AUTOSCALING_MIN
        prompt_input "Maximum Replicas" "10" AUTOSCALING_MAX
        prompt_input "Target CPU %" "80" AUTOSCALING_CPU
    else
        AUTOSCALING_ENABLED=false
    fi
    
    print_success "Backend: Port $SERVICE_PORT, $REPLICAS replica(s)"
}

collect_database_config() {
    print_section "Step 7: PostgreSQL Database (Optional)"
    
    print_info "Each HCL DX instance includes a PostgreSQL database for custom applications."
    print_info "New projects typically require a new database to be created."
    echo ""
    
    if ! prompt_yes_no "Configure PostgreSQL database?" "y"; then
        ENABLE_DATABASE=false
        return
    fi
    
    ENABLE_DATABASE=true
    
    # Database connection details
    print_info "PostgreSQL Connection Details"
    echo ""
    
    # Smart default: DB name based on project name
    DB_NAME_DEFAULT=$(echo "$PROJECT_NAME" | tr '-' '_')
    
    # Smart default: Use namespace-postgres service (common DX pattern)
    DB_HOST_DEFAULT="${K8S_NAMESPACE}-dx-postgres"
    
    prompt_input "PostgreSQL Host" "${DB_HOST:-$DB_HOST_DEFAULT}" DB_HOST
    prompt_input "PostgreSQL Port" "${DB_PORT:-5432}" DB_PORT
    prompt_input "Database Name" "${DB_NAME:-$DB_NAME_DEFAULT}" DB_NAME
    prompt_input "Database User" "${DB_USER:-$DB_NAME_DEFAULT}" DB_USER
    prompt_input "Database Password" "${DB_PASSWORD:-changeme}" DB_PASSWORD true
    
    # SSL/TLS
    if prompt_yes_no "Use SSL/TLS for database connection?" "y"; then
        DB_SSL=true
    else
        DB_SSL=false
    fi
    
    # Connection pooling
    prompt_input "Max Connections (pool size)" "${DB_MAX_CONNECTIONS:-10}" DB_MAX_CONNECTIONS
    
    print_success "Database: postgresql://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    
    # Test connection
    echo ""
    if prompt_yes_no "Test database connection?" "y"; then
        test_database_connection
    fi
    
    # Offer to create database
    echo ""
    print_info "Database Creation"
    print_warning "If this is a new project, you may need to create the database."
    echo ""
    
    if prompt_yes_no "Would you like to create the database now?" "y"; then
        create_database_now
    else
        print_info "You can create the database later with: ./scripts/create-database.sh"
        echo ""
        if prompt_yes_no "Would you like the database setup guide saved?" "y"; then
            show_database_creation_guide
        fi
    fi
}

create_database_now() {
    print_info "Attempting to create database automatically..."
    echo ""
    
    # Find PostgreSQL pod
    local pod_found=false
    local postgres_pod=""
    
    print_info "Searching for PostgreSQL pod in namespace: $K8S_NAMESPACE"
    
    # Try common label selectors
    for selector in "app=postgresql" "app.kubernetes.io/name=postgresql" "component=postgresql" "app=${K8S_NAMESPACE}-dx-postgres"; do
        postgres_pod=$(kubectl get pods -n "$K8S_NAMESPACE" -l "$selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$postgres_pod" ]; then
            print_success "Found PostgreSQL pod: $postgres_pod"
            pod_found=true
            break
        fi
    done
    
    # Try pattern matching if not found
    if [ "$pod_found" = false ]; then
        postgres_pod=$(kubectl get pods -n "$K8S_NAMESPACE" -o name 2>/dev/null | grep -i postgres | head -n 1 | cut -d'/' -f2 || echo "")
        if [ -n "$postgres_pod" ]; then
            print_success "Found PostgreSQL pod: $postgres_pod"
            pod_found=true
        fi
    fi
    
    if [ "$pod_found" = false ]; then
        print_warning "PostgreSQL pod not found in namespace $K8S_NAMESPACE"
        print_info "You can create the database manually later with:"
        echo "  ./scripts/create-database.sh"
        return 1
    fi
    
    # Test connection
    print_info "Testing PostgreSQL connectivity..."
    if ! kubectl exec "$postgres_pod" -n "$K8S_NAMESPACE" -- psql -U postgres -c "SELECT 1" > /dev/null 2>&1; then
        print_warning "Cannot connect to PostgreSQL - database creation skipped"
        print_info "You can create the database manually later with:"
        echo "  ./scripts/create-database.sh"
        return 1
    fi
    
    print_success "PostgreSQL is accessible"
    
    # Check if database exists
    local db_exists=$(kubectl exec "$postgres_pod" -n "$K8S_NAMESPACE" -- \
        psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null || echo "")
    
    if [ "$db_exists" = "1" ]; then
        print_warning "Database '$DB_NAME' already exists"
        return 0
    fi
    
    # Create user if not exists
    print_info "Creating database user '$DB_USER'..."
    kubectl exec "$postgres_pod" -n "$K8S_NAMESPACE" -- \
        psql -U postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || \
        kubectl exec "$postgres_pod" -n "$K8S_NAMESPACE" -- \
        psql -U postgres -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null
    
    # Create database
    print_info "Creating database '$DB_NAME'..."
    if kubectl exec "$postgres_pod" -n "$K8S_NAMESPACE" -- \
        psql -U postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>/dev/null; then
        
        # Grant privileges
        print_info "Granting privileges..."
        kubectl exec "$postgres_pod" -n "$K8S_NAMESPACE" -- \
            psql -U postgres -d "$DB_NAME" <<-'EOSQL' 2>/dev/null
                GRANT ALL PRIVILEGES ON SCHEMA public TO $DB_USER;
                ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO $DB_USER;
                ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO $DB_USER;
EOSQL
        
        print_success "Database created successfully!"
        print_info "Database: $DB_NAME"
        print_info "User: $DB_USER"
        
        # Setup port forwarding hint
        echo ""
        print_info "For local development, use port forwarding:"
        echo "  ./scripts/port-forward-db.sh"
        
        return 0
    else
        print_error "Database creation failed"
        print_info "You can create it manually later with:"
        echo "  ./scripts/create-database.sh"
        return 1
    fi
}

test_database_connection() {
    print_info "Testing PostgreSQL connection..."
    
    # Try to connect using psql if available
    if command -v psql &> /dev/null; then
        local conn_string="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
        
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "postgres" -c "SELECT 1;" &> /dev/null; then
            print_success "PostgreSQL server is reachable"
            
            # Check if database exists
            if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
                print_success "Database '$DB_NAME' exists"
            else
                print_warning "Database '$DB_NAME' does not exist yet"
                print_info "You'll need to create it before deploying"
            fi
        else
            print_warning "Cannot connect to PostgreSQL server"
            print_info "This may be expected if connecting from outside the cluster"
            print_info "Database connectivity will be verified during deployment"
        fi
    else
        print_warning "psql not installed - skipping connection test"
        print_info "Install PostgreSQL client to test connections: brew install postgresql"
    fi
}

show_database_creation_guide() {
    echo ""
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "  Database Creation Guide"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    cat << EOF
${CYAN}Method 1: Using kubectl exec (Recommended)${NC}

# Connect to PostgreSQL pod
kubectl exec -it -n ${K8S_NAMESPACE} deployment/${K8S_NAMESPACE}-dx-postgres -- psql -U postgres

# Create database and user
CREATE DATABASE ${DB_NAME};
CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};

# Grant schema permissions (PostgreSQL 15+)
\\c ${DB_NAME}
GRANT ALL ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};

\\q

${CYAN}Method 2: Using port-forward + psql${NC}

# Port forward to PostgreSQL
kubectl port-forward -n ${K8S_NAMESPACE} svc/${DB_HOST} 5432:5432 &

# Connect with psql
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE ${DB_NAME};"
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

# Kill port-forward
pkill -f "kubectl port-forward.*5432"

${CYAN}Method 3: Using DX Portal Admin Tools${NC}

1. Log in to DX Portal Admin Console
2. Navigate to Database Management
3. Create new database: ${DB_NAME}
4. Create user: ${DB_USER}
5. Grant permissions

${YELLOW}Important Notes:${NC}

• Default postgres superuser credentials are typically in a K8s secret:
  kubectl get secret -n ${K8S_NAMESPACE} ${K8S_NAMESPACE}-dx-postgres -o jsonpath='{.data.postgres-password}' | base64 -d

• Database will be accessible within the cluster at:
  ${DB_HOST}:${DB_PORT}

• For external access, use kubectl port-forward

• Store production credentials in Kubernetes secrets:
  kubectl create secret generic ${PROJECT_NAME}-db-credentials \\
    --from-literal=username=${DB_USER} \\
    --from-literal=password=${DB_PASSWORD} \\
    --from-literal=database=${DB_NAME} \\
    -n ${K8S_NAMESPACE}

EOF
    
    echo ""
    if prompt_yes_no "Save this guide to docs/DATABASE_SETUP.md?" "y"; then
        mkdir -p "${PROJECT_ROOT}/docs"
        cat > "${PROJECT_ROOT}/docs/DATABASE_SETUP.md" << 'DBSETUP_EOF'
# PostgreSQL Database Setup Guide

## Quick Setup

### Using kubectl exec (Recommended)

```bash
# 1. Connect to PostgreSQL pod
kubectl exec -it -n NAMESPACE deployment/NAMESPACE-dx-postgres -- psql -U postgres

# 2. Create database and user
CREATE DATABASE DBNAME;
CREATE USER DBUSER WITH PASSWORD 'PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE DBNAME TO DBUSER;

# 3. Grant schema permissions (PostgreSQL 15+)
\c DBNAME
GRANT ALL ON SCHEMA public TO DBUSER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO DBUSER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO DBUSER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO DBUSER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO DBUSER;

\q
```

### Using port-forward + psql

```bash
# 1. Port forward to PostgreSQL
kubectl port-forward -n NAMESPACE svc/NAMESPACE-dx-postgres 5432:5432 &

# 2. Get postgres superuser password
POSTGRES_PASSWORD=$(kubectl get secret -n NAMESPACE NAMESPACE-dx-postgres -o jsonpath='{.data.postgres-password}' | base64 -d)

# 3. Create database and user
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -p 5432 -U postgres << EOF
CREATE DATABASE DBNAME;
CREATE USER DBUSER WITH PASSWORD 'PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE DBNAME TO DBUSER;
\c DBNAME
GRANT ALL ON SCHEMA public TO DBUSER;
EOF

# 4. Kill port-forward
pkill -f "kubectl port-forward.*5432"
```

## Verification

### Test Connection

```bash
# From local machine (with port-forward)
PGPASSWORD='PASSWORD' psql -h localhost -p 5432 -U DBUSER -d DBNAME -c "SELECT version();"

# From within Kubernetes
kubectl run -it --rm psql-test --image=postgres:15 --restart=Never -n NAMESPACE -- \
  psql -h NAMESPACE-dx-postgres -p 5432 -U DBUSER -d DBNAME -c "SELECT version();"
```

### List Databases

```bash
kubectl exec -it -n NAMESPACE deployment/NAMESPACE-dx-postgres -- psql -U postgres -c "\l"
```

### Check User Permissions

```bash
kubectl exec -it -n NAMESPACE deployment/NAMESPACE-dx-postgres -- psql -U postgres -d DBNAME -c "\du DBUSER"
```

## LoopBack 4 Integration

### Install PostgreSQL Connector

```bash
cd packages/server-v1
npm install --save loopback-connector-postgresql
```

### Configure Datasource

Create `packages/server-v1/src/datasources/postgres.datasource.ts`:

```typescript
import {inject, lifeCycleObserver, LifeCycleObserver} from '@loopback/core';
import {juggler} from '@loopback/repository';

const config = {
  name: 'postgres',
  connector: 'postgresql',
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'mydb',
  ssl: process.env.DB_SSL === 'true',
  max: parseInt(process.env.DB_MAX_CONNECTIONS || '10', 10),
};

@lifeCycleObserver('datasource')
export class PostgresDataSource extends juggler.DataSource
  implements LifeCycleObserver {
  static dataSourceName = 'postgres';
  static readonly defaultConfig = config;

  constructor(
    @inject('datasources.config.postgres', {optional: true})
    dsConfig: object = config,
  ) {
    super(dsConfig);
  }
}
```

### Create Models

```bash
cd packages/server-v1
lb4 model

# Follow prompts to create your model
# Then bind it to the postgres datasource
lb4 repository
```

## Production Best Practices

### Use Kubernetes Secrets

```bash
# Create secret with database credentials
kubectl create secret generic PROJECT-db-credentials \
  --from-literal=username=DBUSER \
  --from-literal=password=PASSWORD \
  --from-literal=database=DBNAME \
  -n NAMESPACE

# Update Helm chart to use secret
# In helm/dam-plugin/templates/deployment.yaml:
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: PROJECT-db-credentials
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: PROJECT-db-credentials
        key: password
  - name: DB_NAME
    valueFrom:
      secretKeyRef:
        name: PROJECT-db-credentials
        key: database
```

### Connection Pooling

```bash
# In .env
DB_MAX_CONNECTIONS=20
DB_IDLE_TIMEOUT=30000
DB_CONNECTION_TIMEOUT=5000
```

### SSL/TLS in Production

```bash
# Enable SSL
DB_SSL=true

# For self-signed certificates
DB_SSL_REJECT_UNAUTHORIZED=false
```

### Backup and Recovery

```bash
# Backup database
kubectl exec -n NAMESPACE deployment/NAMESPACE-dx-postgres -- \
  pg_dump -U postgres DBNAME > backup-$(date +%Y%m%d).sql

# Restore database
kubectl exec -i -n NAMESPACE deployment/NAMESPACE-dx-postgres -- \
  psql -U postgres DBNAME < backup-20260202.sql
```

## Troubleshooting

### Cannot Connect

```bash
# Check if PostgreSQL pod is running
kubectl get pods -n NAMESPACE | grep postgres

# Check PostgreSQL logs
kubectl logs -n NAMESPACE deployment/NAMESPACE-dx-postgres

# Test network connectivity
kubectl run -it --rm netshoot --image=nicolaka/netshoot -n NAMESPACE -- \
  nc -zv NAMESPACE-dx-postgres 5432
```

### Permission Denied

```bash
# Grant all privileges again
kubectl exec -it -n NAMESPACE deployment/NAMESPACE-dx-postgres -- \
  psql -U postgres -d DBNAME << EOF
GRANT ALL ON SCHEMA public TO DBUSER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO DBUSER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO DBUSER;
EOF
```

### Connection Pool Exhausted

```bash
# Increase max connections in .env
DB_MAX_CONNECTIONS=50

# Check current connections
kubectl exec -n NAMESPACE deployment/NAMESPACE-dx-postgres -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname='DBNAME';"
```

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [LoopBack PostgreSQL Connector](https://loopback.io/doc/en/lb4/PostgreSQL-connector.html)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
DBSETUP_EOF
        
        # Replace placeholders with actual values
        sed -i.bak "s/NAMESPACE/${K8S_NAMESPACE}/g" "${PROJECT_ROOT}/docs/DATABASE_SETUP.md"
        sed -i.bak "s/DBNAME/${DB_NAME}/g" "${PROJECT_ROOT}/docs/DATABASE_SETUP.md"
        sed -i.bak "s/DBUSER/${DB_USER}/g" "${PROJECT_ROOT}/docs/DATABASE_SETUP.md"
        sed -i.bak "s/PASSWORD/${DB_PASSWORD}/g" "${PROJECT_ROOT}/docs/DATABASE_SETUP.md"
        sed -i.bak "s/PROJECT/${PROJECT_NAME}/g" "${PROJECT_ROOT}/docs/DATABASE_SETUP.md"
        rm -f "${PROJECT_ROOT}/docs/DATABASE_SETUP.md.bak"
        
        print_success "Saved to docs/DATABASE_SETUP.md"
    fi
}


# =============================================================================
# File Generation
# =============================================================================

generate_config_files() {
    print_section "Generating Configuration Files"
    
    # Generate .template-config.json
    print_info "Creating .template-config.json..."
    cat > "$CONFIG_FILE" << EOF
{
  "projectName": "$PROJECT_NAME",
  "projectDisplayName": "$PROJECT_DISPLAY_NAME",
  "projectVersion": "$PROJECT_VERSION",
  "projectType": "$PROJECT_TYPE",
  "generatedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  
  "components": {
    "portlet": {
      "enabled": $ENABLE_PORTLET,
      "wcmContentName": "${WCM_CONTENT_NAME:-}",
      "wcmSiteArea": "${WCM_SITE_AREA:-}"
    },
    "backend": {
      "enabled": true,
      "port": ${SERVICE_PORT:-3000},
      "replicas": ${REPLICAS:-1}
    },
    "dam": {
      "enabled": $ENABLE_DAM
    }
  },
  
  "deployment": {
    "namespace": "$K8S_NAMESPACE",
    "releaseName": "$RELEASE_NAME",
    "registry": "$DOCKER_REGISTRY",
    "imageName": "$IMAGE_NAME",
    "imageTag": "$IMAGE_TAG"
  }
}
EOF
    
    print_success "Created .template-config.json"
    
    # Generate .env file
    print_info "Creating .env..."
    cat > "$ENV_FILE" << EOF
# =============================================================================
# Project Configuration - Generated by init-template.sh
# Generated: $(date)
# =============================================================================

# Project
PROJECT_NAME=$PROJECT_NAME
PROJECT_TYPE=$PROJECT_TYPE
NODE_ENV=development

# Kubernetes
NAMESPACE=$K8S_NAMESPACE
RELEASE_NAME=$RELEASE_NAME
KUBECONFIG=\$HOME/.kube/config

# Docker Registry
DOCKER_REGISTRY=$DOCKER_REGISTRY
IMAGE_NAME=$IMAGE_NAME
IMAGE_TAG=$IMAGE_TAG

# Backend Service
SERVICE_PORT=${SERVICE_PORT:-3000}
REPLICAS=${REPLICAS:-1}
HOST=0.0.0.0

# Helm Chart
HELM_CHART_PATH=./helm/dam-plugin
VALUES_FILE=

# Resource Limits
CPU_REQUEST=${CPU_REQUEST:-250m}
CPU_LIMIT=${CPU_LIMIT:-500m}
MEMORY_REQUEST=${MEMORY_REQUEST:-256Mi}
MEMORY_LIMIT=${MEMORY_LIMIT:-512Mi}

# Autoscaling
AUTOSCALING_ENABLED=${AUTOSCALING_ENABLED:-false}
AUTOSCALING_MIN=${AUTOSCALING_MIN:-1}
AUTOSCALING_MAX=${AUTOSCALING_MAX:-10}
AUTOSCALING_CPU=${AUTOSCALING_CPU:-80}

# Logging
LOG_LEVEL=info
DEBUG=

# Port Forwarding
LOCAL_PORT=${SERVICE_PORT:-3000}
REMOTE_PORT=${SERVICE_PORT:-3000}
DEPLOYMENT_NAME=$RELEASE_NAME

EOF

    # Add DX Portal config if portlet enabled
    if [ "$ENABLE_PORTLET" = true ]; then
        cat >> "$ENV_FILE" << EOF
# =============================================================================
# DX Portal Configuration
# =============================================================================
DX_PROTOCOL=${DX_PROTOCOL:-https}
DX_HOSTNAME=$DX_HOSTNAME
DX_PORT=${DX_PORT:-443}
DX_USERNAME=$DX_USERNAME
DX_PASSWORD=$DX_PASSWORD

# Script Portlet
WCM_CONTENT_NAME="$WCM_CONTENT_NAME"
WCM_SITE_AREA="$WCM_SITE_AREA"
PORTLET_MAIN_HTML=index.html
PORTLET_BUILD_DIR=./packages/portlet-v1/dist

EOF
    fi
    
    # Add Database config if enabled
    if [ "$ENABLE_DATABASE" = true ]; then
        cat >> "$ENV_FILE" << EOF
# =============================================================================
# PostgreSQL Database Configuration
# =============================================================================
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_SSL=$DB_SSL
DB_MAX_CONNECTIONS=${DB_MAX_CONNECTIONS:-10}

# PostgreSQL Connection URL (for LoopBack, Prisma, TypeORM, etc.)
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=$([ "$DB_SSL" = "true" ] && echo "require" || echo "disable")

# Connection Pool Settings
DB_POOL_MIN=2
DB_POOL_MAX=${DB_MAX_CONNECTIONS:-10}
DB_IDLE_TIMEOUT_MS=30000
DB_CONNECTION_TIMEOUT_MS=5000

EOF
    fi
    
    # Add DAM config if enabled
    if [ "$ENABLE_DAM" = true ]; then
        cat >> "$ENV_FILE" << EOF
# =============================================================================
# DAM Plugin Configuration
# =============================================================================
DAM_PLUGIN_ENABLED=true
DAM_CONFIGMAP_SUFFIX=digital-asset-management
DAM_LOG_LEVEL=info

EOF
    fi
    
    print_success "Created .env"
}

# =============================================================================
# Next Steps Display
# =============================================================================

show_next_steps() {
    print_section "🎉 Configuration Complete!"
    
    echo -e "${GREEN}"
    cat << EOF

Your DX project is configured and ready!

Project: $PROJECT_DISPLAY_NAME
Type: $PROJECT_TYPE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Install Dependencies
   cd packages/server-v1 && npm install
EOF

    if [ "$ENABLE_PORTLET" = true ]; then
        echo "   cd ../portlet-v1 && npm install"
    fi

    cat << EOF
   cd ../..

2. Validate Configuration
   ./scripts/validate-deployment-readiness.sh

3. Test Build (Dry Run)
   DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh build-only

4. Deploy to Kubernetes
   ./scripts/build-and-deploy.sh

5. Verify Deployment
   ./scripts/port-forward.sh
   curl http://localhost:${SERVICE_PORT:-3000}/health

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Configuration Files Created:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• .template-config.json  - Project metadata
• .env                   - Environment variables (DO NOT commit!)

⚠️  Security Reminder:
   .env contains credentials - keep it out of version control!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Documentation:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• START_HERE.md           - Quick start guide
• scripts/INITIALIZATION_GUIDE.md - Detailed walkthrough
• docs/                   - Full documentation

EOF
    echo -e "${NC}"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_banner
    
    # Check if already initialized
    if [ -f "$CONFIG_FILE" ] && [ -f "$ENV_FILE" ]; then
        print_warning "Template appears to be already initialized"
        print_info "Existing files found:"
        echo "  - .template-config.json"
        echo "  - .env"
        echo ""
        
        if ! prompt_yes_no "Re-initialize? (will backup existing config)" "n"; then
            print_info "Exiting without changes"
            exit 0
        fi
        
        print_warning "Backing up existing configuration..."
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Backup created"
    fi
    
    # Run initialization steps
    select_project_type
    collect_project_details
    collect_kubernetes_config
    collect_docker_config
    collect_dx_portal_config
    collect_backend_config
    collect_database_config
    
    # Confirm before generating
    print_section "Configuration Summary"
    echo -e "${CYAN}Project:${NC} $PROJECT_DISPLAY_NAME ($PROJECT_NAME)"
    echo -e "${CYAN}Type:${NC} $PROJECT_TYPE"
    echo -e "${CYAN}Namespace:${NC} $K8S_NAMESPACE"
    echo -e "${CYAN}Release:${NC} $RELEASE_NAME"
    echo -e "${CYAN}Image:${NC} ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    if [ "$ENABLE_DATABASE" = "true" ]; then
        echo -e "${CYAN}Database:${NC} postgresql://$DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    fi
    
    if [ "$ENABLE_PORTLET" = true ]; then
        echo -e "${CYAN}DX Portal:${NC} ${DX_PROTOCOL}://${DX_HOSTNAME}:${DX_PORT}"
        echo -e "${CYAN}Portlet:${NC} $WCM_CONTENT_NAME in $WCM_SITE_AREA"
    fi
    
    echo ""
    
    if ! prompt_yes_no "Generate configuration files?" "y"; then
        print_warning "Configuration cancelled"
        exit 0
    fi
    
    # Generate files
    generate_config_files
    
    # Show next steps
    show_next_steps
    
    print_success "Initialization complete! Run: ./scripts/validate-deployment-readiness.sh"
}

# Run main function
main "$@"

