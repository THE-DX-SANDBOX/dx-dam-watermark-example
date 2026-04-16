#!/bin/bash
# =============================================================================
# Deployment Readiness Validation Script
# =============================================================================
# Checks configuration, tools, connectivity, and project structure
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load config if exists
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
CHECKS=0

print_check() {
    local status=$1
    local message=$2
    
    ((CHECKS++))
    
    case $status in
        "pass")
            echo -e "${GREEN}✅${NC} $message"
            ;;
        "fail")
            echo -e "${RED}❌${NC} $message"
            ((ERRORS++))
            ;;
        "warn")
            echo -e "${YELLOW}⚠️${NC} $message"
            ((WARNINGS++))
            ;;
        "info")
            echo -e "${BLUE}ℹ️${NC} $message"
            ;;
    esac
}

echo ""
echo "=========================================="
echo "  Deployment Readiness Validation"
echo "=========================================="
echo ""

# 1. Configuration Files
echo "━━━ Configuration Files ━━━"

if [ -f "$PROJECT_ROOT/.template-config.json" ]; then
    print_check "pass" ".template-config.json exists"
    
    # Validate JSON
    if command -v jq &> /dev/null; then
        if jq empty "$PROJECT_ROOT/.template-config.json" 2>/dev/null; then
            print_check "pass" ".template-config.json is valid JSON"
        else
            print_check "fail" ".template-config.json contains invalid JSON"
        fi
    fi
else
    print_check "fail" ".template-config.json missing - run ./scripts/init-template.sh"
fi

if [ -f "$PROJECT_ROOT/.env" ]; then
    print_check "pass" ".env exists"
else
    print_check "fail" ".env missing - run ./scripts/init-template.sh"
fi

echo ""

# 2. Required Tools
echo "━━━ Required Tools ━━━"

check_tool() {
    if command -v "$1" &> /dev/null; then
        local version=$($1 --version 2>&1 | head -n 1 || echo "installed")
        print_check "pass" "$1 installed"
    else
        print_check "fail" "$1 not installed"
    fi
}

check_tool "node"
check_tool "npm"
check_tool "docker"
check_tool "kubectl"
check_tool "helm"

if [ -n "${WCM_CONTENT_NAME:-}" ]; then
    check_tool "dxclient"
fi

echo ""

# 3. Kubernetes Connectivity
echo "━━━ Kubernetes Connectivity ━━━"

if kubectl cluster-info &> /dev/null; then
    print_check "pass" "Kubernetes cluster accessible"
    
    CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
    print_check "info" "Current context: $CONTEXT"
    
    if [ -n "${NAMESPACE:-}" ]; then
        if kubectl get namespace "$NAMESPACE" &> /dev/null; then
            print_check "pass" "Namespace '$NAMESPACE' exists"
        else
            print_check "fail" "Namespace '$NAMESPACE' not found"
        fi
    else
        print_check "warn" "NAMESPACE not set in .env"
    fi
else
    print_check "fail" "Cannot connect to Kubernetes cluster"
fi

echo ""

# 4. Docker Configuration
echo "━━━ Docker Configuration ━━━"

if docker info &> /dev/null; then
    print_check "pass" "Docker daemon running"
else
    print_check "fail" "Docker daemon not accessible"
fi

if [ -n "${DOCKER_REGISTRY:-}" ]; then
    print_check "pass" "Docker registry configured: $DOCKER_REGISTRY"
else
    print_check "fail" "DOCKER_REGISTRY not set in .env"
fi

if [ -n "${IMAGE_NAME:-}" ]; then
    print_check "pass" "Image name configured: $IMAGE_NAME"
else
    print_check "fail" "IMAGE_NAME not set in .env"
fi

echo ""

# 5. Project Structure
echo "━━━ Project Structure ━━━"

if [ -d "$PROJECT_ROOT/packages/server-v1" ]; then
    print_check "pass" "Backend service directory exists"
    
    if [ -f "$PROJECT_ROOT/packages/server-v1/package.json" ]; then
        print_check "pass" "Backend package.json exists"
        
        if [ -d "$PROJECT_ROOT/packages/server-v1/node_modules" ]; then
            print_check "pass" "Backend dependencies installed"
        else
            print_check "warn" "Backend dependencies not installed - run 'npm install'"
        fi
        
        if [ -d "$PROJECT_ROOT/packages/server-v1/dist" ]; then
            print_check "pass" "Backend built (dist/ exists)"
        else
            print_check "warn" "Backend not built - run 'npm run build'"
        fi
    else
        print_check "fail" "Backend package.json missing"
    fi
else
    print_check "fail" "Backend service directory missing"
fi

if [ -n "${WCM_CONTENT_NAME:-}" ]; then
    if [ -d "$PROJECT_ROOT/packages/portlet-v1" ]; then
        print_check "pass" "Portlet directory exists"
        
        if [ -f "$PROJECT_ROOT/packages/portlet-v1/package.json" ]; then
            print_check "pass" "Portlet package.json exists"
            
            if [ -d "$PROJECT_ROOT/packages/portlet-v1/node_modules" ]; then
                print_check "pass" "Portlet dependencies installed"
            else
                print_check "warn" "Portlet dependencies not installed"
            fi
            
            if [ -d "$PROJECT_ROOT/packages/portlet-v1/dist" ]; then
                print_check "pass" "Portlet built (dist/ exists)"
            else
                print_check "warn" "Portlet not built"
            fi
        fi
    else
        print_check "warn" "Portlet directory missing - will be created during deployment"
    fi
fi

echo ""

# 6. Helm Configuration
echo "━━━ Helm Configuration ━━━"

if [ -f "$PROJECT_ROOT/helm/dam-plugin/Chart.yaml" ]; then
    print_check "pass" "Helm chart exists"
    
    if helm lint "$PROJECT_ROOT/helm/dam-plugin" &> /dev/null; then
        print_check "pass" "Helm chart is valid"
    else
        print_check "warn" "Helm chart has warnings (may be OK)"
    fi
else
    print_check "fail" "Helm chart missing"
fi

echo ""

# 7. DX Portal Configuration
if [ -n "${DX_HOSTNAME:-}" ]; then
    echo "━━━ DX Portal Configuration ━━━"
    
    print_check "pass" "DX hostname configured: $DX_HOSTNAME"
    
    if [ -n "${DX_USERNAME:-}" ]; then
        print_check "pass" "DX username configured"
    else
        print_check "fail" "DX_USERNAME not set"
    fi
    
    if [ -n "${DX_PASSWORD:-}" ]; then
        print_check "pass" "DX password configured"
    else
        print_check "fail" "DX_PASSWORD not set"
    fi
    
    echo ""
fi

# 8. Database Configuration
if [ "${ENABLE_DATABASE:-false}" = "true" ] || [ -n "${DB_HOST:-}" ]; then
    echo "━━━ PostgreSQL Database Configuration ━━━"
    
    if [ -n "${DB_HOST:-}" ]; then
        print_check "pass" "DB_HOST configured: $DB_HOST"
    else
        print_check "fail" "DB_HOST not set"
    fi
    
    if [ -n "${DB_PORT:-}" ]; then
        print_check "pass" "DB_PORT configured: $DB_PORT"
    else
        print_check "warn" "DB_PORT not set (will use default: 5432)"
    fi
    
    if [ -n "${DB_NAME:-}" ]; then
        print_check "pass" "DB_NAME configured: $DB_NAME"
    else
        print_check "fail" "DB_NAME not set"
    fi
    
    if [ -n "${DB_USER:-}" ]; then
        print_check "pass" "DB_USER configured"
    else
        print_check "fail" "DB_USER not set"
    fi
    
    if [ -n "${DB_PASSWORD:-}" ]; then
        print_check "pass" "DB_PASSWORD configured"
    else
        print_check "fail" "DB_PASSWORD not set"
    fi
    
    if [ -n "${DATABASE_URL:-}" ]; then
        print_check "pass" "DATABASE_URL configured"
    else
        print_check "warn" "DATABASE_URL not set (may be needed by some frameworks)"
    fi
    
    # Test PostgreSQL connection if psql is available
    if command -v psql &> /dev/null; then
        print_info "Testing PostgreSQL connection..."
        
        if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT:-5432}" -U "${DB_USER}" -d "postgres" -c "SELECT 1;" &> /dev/null 2>&1; then
            print_check "pass" "PostgreSQL server is reachable"
            
            # Check if database exists
            if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT:-5432}" -U "${DB_USER}" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "${DB_NAME}"; then
                print_check "pass" "Database '$DB_NAME' exists"
            else
                print_check "warn" "Database '$DB_NAME' does not exist - needs to be created"
                print_info "See docs/DATABASE_SETUP.md for guidance"
            fi
        else
            print_check "warn" "Cannot connect to PostgreSQL (may be expected if outside cluster)"
            print_info "Database connectivity will be verified during deployment"
        fi
    else
        print_check "info" "psql not installed - skipping connection test"
        print_info "Install PostgreSQL client to test: brew install postgresql"
    fi
    
    # Check for LoopBack connector
    if [ -f "$PROJECT_ROOT/packages/server-v1/package.json" ]; then
        if grep -q "loopback-connector-postgresql" "$PROJECT_ROOT/packages/server-v1/package.json" 2>/dev/null; then
            print_check "pass" "LoopBack PostgreSQL connector installed"
        else
            print_check "warn" "LoopBack PostgreSQL connector not installed"
            print_info "Install: cd packages/server-v1 && npm install --save loopback-connector-postgresql"
        fi
    fi
    
    echo ""
fi

# 9. Security Checks
echo "━━━ Security Checks ━━━"

if git ls-files --error-unmatch .env 2>/dev/null; then
    print_check "fail" ".env is tracked by git - should be in .gitignore!"
else
    print_check "pass" ".env is not tracked by git"
fi

if grep -q "^\.env$" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
    print_check "pass" ".env is in .gitignore"
else
    print_check "warn" ".env should be in .gitignore"
fi

echo ""

# Summary
echo "=========================================="
echo "  Validation Summary"
echo "=========================================="
echo ""
echo -e "Total Checks: $CHECKS"
echo -e "${GREEN}Passed: $((CHECKS - ERRORS - WARNINGS))${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Errors: $ERRORS${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Ready to deploy.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Install dependencies: cd packages/server-v1 && npm install"
    echo "  2. Test build: DRY_RUN=true ./scripts/testing/test-template-end-to-end.sh build-only"
    echo "  3. Deploy: ./scripts/build-and-deploy.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Some warnings found. Review above, but you may proceed.${NC}"
    echo ""
    echo "To fix warnings:"
    echo "  - Install missing dependencies: npm install"
    echo "  - Build projects: npm run build"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Errors found! Please fix the errors above before deploying.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Run initialization: ./scripts/init-template.sh"
    echo "  - Check kubectl access: kubectl cluster-info"
    echo "  - Ensure Docker is running: docker info"
    echo ""
    exit 1
fi
