#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Load environment
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

# Configuration
TEST_MODE=${1:-full}  # Options: full, build-only, deploy-only, backend-only
DRY_RUN=${DRY_RUN:-false}
SKIP_PUSH=${SKIP_PUSH:-false}
SKIP_DEPLOY=${SKIP_DEPLOY:-false}

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((TESTS_PASSED++))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ((TESTS_FAILED++))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_skip() {
    echo -e "${YELLOW}⏭️  $1${NC}"
    ((TESTS_SKIPPED++))
}

run_test() {
    local test_name=$1
    local test_command=$2
    
    echo ""
    echo -e "${BLUE}▶ Running: $test_name${NC}"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "DRY RUN: Would execute: $test_command"
        return 0
    fi
    
    if eval "$test_command"; then
        print_success "$test_name"
        return 0
    else
        print_error "$test_name"
        return 1
    fi
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

preflight_checks() {
    print_header "Pre-flight Checks"
    
    # Check required tools
    local required_tools=("node" "npm" "docker" "kubectl" "helm")
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            local version=$($tool --version 2>&1 | head -n 1)
            print_success "$tool installed: $version"
        else
            print_error "$tool not installed"
            return 1
        fi
    done
    
    # Check environment variables
    local required_vars=("NAMESPACE" "DOCKER_REGISTRY" "IMAGE_NAME")
    
    for var in "${required_vars[@]}"; do
        if [ -n "${!var}" ]; then
            print_success "$var is set: ${!var}"
        else
            print_error "$var is not set"
            return 1
        fi
    done
    
    # Check Kubernetes connection
    if kubectl cluster-info &> /dev/null; then
        print_success "Kubernetes cluster accessible"
    else
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    # Check namespace exists
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_success "Namespace '$NAMESPACE' exists"
    else
        print_error "Namespace '$NAMESPACE' does not exist"
        return 1
    fi
    
    # Check Docker is running
    if docker info &> /dev/null; then
        print_success "Docker is running"
    else
        print_error "Docker is not running"
        return 1
    fi
}

# =============================================================================
# Build Tests
# =============================================================================

test_backend_build() {
    print_header "Testing Backend Build"
    
    cd "$PROJECT_ROOT/packages/server-v1"
    
    # Test npm install
    run_test "Backend: Install dependencies" "npm install"
    
    # Test TypeScript compilation
    run_test "Backend: TypeScript compilation" "npm run build"
    
    # Test if dist folder exists
    if [ -d "dist" ]; then
        print_success "Backend: dist/ folder created"
    else
        print_error "Backend: dist/ folder not created"
        cd "$PROJECT_ROOT"
        return 1
    fi
    
    # Test if main files exist
    local required_files=("dist/index.js" "dist/application.js")
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_success "Backend: $file exists"
        else
            print_error "Backend: $file missing"
            cd "$PROJECT_ROOT"
            return 1
        fi
    done
    
    # Test OpenAPI generation
    if [ -f "public/openapi/openapi.json" ]; then
        print_success "Backend: OpenAPI spec generated"
    else
        print_warning "Backend: OpenAPI spec not found (may need npm run openapi:generate)"
    fi
    
    cd "$PROJECT_ROOT"
}

test_docker_build() {
    print_header "Testing Docker Build"
    
    cd "$PROJECT_ROOT/packages"
    
    local test_image="${IMAGE_NAME}:test-$(date +%s)"
    
    # Build Docker image
    run_test "Docker: Build image" \
        "docker build -t $test_image -f Dockerfile ."
    
    # Check if image exists
    if docker images | grep -q "$IMAGE_NAME"; then
        print_success "Docker: Image created"
        
        # Get image size
        local image_size=$(docker images --format "{{.Size}}" "$test_image")
        print_info "Docker: Image size: $image_size"
    else
        print_error "Docker: Image not found"
        cd "$PROJECT_ROOT"
        return 1
    fi
    
    # Clean up test image
    if [ "$DRY_RUN" != "true" ]; then
        print_info "Cleaning up test image..."
        docker rmi "$test_image" &> /dev/null || true
    fi
    
    cd "$PROJECT_ROOT"
}

test_docker_push() {
    print_header "Testing Docker Push"
    
    if [ "$SKIP_PUSH" = "true" ]; then
        print_skip "Docker push (SKIP_PUSH=true)"
        return 0
    fi
    
    local full_image="${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Authenticate with GCP
    print_info "Authenticating with GCP Artifact Registry..."
    if gcloud auth configure-docker us-central1-docker.pkg.dev &> /dev/null; then
        print_success "Docker: GCP authentication configured"
    else
        print_warning "Docker: GCP authentication may need to be run manually"
    fi
    
    # Build and tag image
    cd "$PROJECT_ROOT/packages"
    
    run_test "Docker: Build and tag for registry" \
        "docker build -t $full_image -f Dockerfile ."
    
    # Push image (skip in dry-run)
    if [ "$DRY_RUN" != "true" ]; then
        run_test "Docker: Push to registry" \
            "docker push $full_image"
    else
        print_info "DRY RUN: Would push $full_image"
    fi
    
    cd "$PROJECT_ROOT"
}

# =============================================================================
# Deployment Tests
# =============================================================================

test_helm_chart_validation() {
    print_header "Testing Helm Chart Validation"
    
    cd "$PROJECT_ROOT"
    
    # Lint Helm chart
    run_test "Helm: Lint chart" \
        "helm lint $HELM_CHART_PATH"
    
    # Dry-run install
    run_test "Helm: Dry-run install" \
        "helm install $RELEASE_NAME $HELM_CHART_PATH \
         --namespace $NAMESPACE \
         --dry-run \
         --debug 2>&1 | head -50"
    
    # Template rendering
    local template_dir="/tmp/helm-test-$$"
    run_test "Helm: Template rendering" \
        "helm template $RELEASE_NAME $HELM_CHART_PATH \
         --namespace $NAMESPACE \
         --output-dir $template_dir"
    
    # Check rendered templates
    if [ -d "$template_dir" ]; then
        print_success "Helm: Templates rendered successfully"
        
        # List rendered files
        print_info "Rendered templates:"
        find "$template_dir" -name "*.yaml" | while read file; do
            echo "  - $(basename $file)"
        done
        
        rm -rf "$template_dir"
    fi
}

test_kubernetes_deployment() {
    print_header "Testing Kubernetes Deployment"
    
    if [ "$SKIP_DEPLOY" = "true" ]; then
        print_skip "Kubernetes deployment (SKIP_DEPLOY=true)"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Check if deployment already exists
    if kubectl get deployment "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_warning "Deployment already exists, will upgrade"
        
        if [ "$DRY_RUN" != "true" ]; then
            run_test "Helm: Upgrade deployment" \
                "helm upgrade $RELEASE_NAME $HELM_CHART_PATH \
                 --namespace $NAMESPACE \
                 --wait \
                 --timeout 5m"
        fi
    else
        if [ "$DRY_RUN" != "true" ]; then
            run_test "Helm: Install deployment" \
                "helm install $RELEASE_NAME $HELM_CHART_PATH \
                 --namespace $NAMESPACE \
                 --wait \
                 --timeout 5m"
        else
            print_info "DRY RUN: Would install Helm chart"
        fi
    fi
    
    # Wait for deployment to be ready
    if [ "$DRY_RUN" != "true" ] && [ "$SKIP_DEPLOY" != "true" ]; then
        print_info "Waiting for deployment to be ready..."
        
        if kubectl wait --for=condition=available --timeout=300s \
           deployment/$RELEASE_NAME -n $NAMESPACE 2>&1; then
            print_success "Kubernetes: Deployment is ready"
        else
            print_error "Kubernetes: Deployment failed to become ready"
            
            # Show pod status
            print_info "Pod status:"
            kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=$RELEASE_NAME
            
            # Show recent events
            print_info "Recent events:"
            kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
            
            return 1
        fi
    fi
}

test_service_availability() {
    print_header "Testing Service Availability"
    
    # Check if service exists
    if kubectl get service "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_success "Kubernetes: Service exists"
        
        # Get service details
        local cluster_ip=$(kubectl get service "$RELEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
        local port=$(kubectl get service "$RELEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
        
        print_info "Service ClusterIP: $cluster_ip"
        print_info "Service Port: $port"
    else
        print_error "Kubernetes: Service not found"
        return 1
    fi
    
    # Check endpoints
    if kubectl get endpoints "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
        local endpoints=$(kubectl get endpoints "$RELEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.subsets[0].addresses}' | grep -o 'ip' | wc -l)
        
        if [ "$endpoints" -gt 0 ]; then
            print_success "Kubernetes: Service has $endpoints endpoint(s)"
        else
            print_error "Kubernetes: Service has no endpoints"
            return 1
        fi
    fi
}

# =============================================================================
# Port Forwarding & API Tests
# =============================================================================

test_port_forwarding() {
    print_header "Testing Port Forwarding"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "DRY RUN: Would start port forwarding"
        return 0
    fi
    
    # Check if port is already in use
    if lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t &> /dev/null; then
        print_warning "Port $LOCAL_PORT is already in use"
        print_info "Attempting to kill existing process..."
        lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Start port forwarding in background
    print_info "Starting port forwarding: localhost:$LOCAL_PORT -> $DEPLOYMENT_NAME:$REMOTE_PORT"
    
    kubectl port-forward -n "$NAMESPACE" \
        deployment/"$DEPLOYMENT_NAME" \
        "$LOCAL_PORT:$REMOTE_PORT" > /tmp/pf-output-$$.log 2>&1 &
    
    local PF_PID=$!
    
    # Wait for port forwarding to establish
    sleep 5
    
    # Check if port forwarding is working
    if ps -p $PF_PID > /dev/null; then
        print_success "Port forwarding started (PID: $PF_PID)"
        
        # Store PID for cleanup
        echo $PF_PID > /tmp/dam-demo-pf-$$.pid
    else
        print_error "Port forwarding failed to start"
        cat /tmp/pf-output-$$.log
        return 1
    fi
}

test_api_endpoints() {
    print_header "Testing API Endpoints"
    
    if [ "$DRY_RUN" = "true" ]; then
        print_info "DRY RUN: Would test API endpoints"
        return 0
    fi
    
    local base_url="http://localhost:$LOCAL_PORT"
    
    # Wait for service to be ready
    print_info "Waiting for service to be ready..."
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$base_url/health" > /dev/null 2>&1; then
            break
        fi
        ((attempt++))
        sleep 2
    done
    
    # Test health endpoint
    print_info "Testing: GET $base_url/health"
    if response=$(curl -s -w "\n%{http_code}" "$base_url/health" 2>&1); then
        local body=$(echo "$response" | head -n -1)
        local status=$(echo "$response" | tail -n 1)
        
        if [ "$status" = "200" ]; then
            print_success "API: Health endpoint returned 200"
            print_info "Response: $body"
        else
            print_error "API: Health endpoint returned $status"
        fi
    else
        print_error "API: Health endpoint failed to respond"
    fi
    
    # Test OpenAPI endpoint
    print_info "Testing: GET $base_url/openapi.json"
    if response=$(curl -s -w "\n%{http_code}" "$base_url/openapi.json" 2>&1); then
        local status=$(echo "$response" | tail -n 1)
        
        if [ "$status" = "200" ]; then
            print_success "API: OpenAPI spec endpoint returned 200"
        else
            print_warning "API: OpenAPI spec endpoint returned $status"
        fi
    else
        print_warning "API: OpenAPI spec endpoint not available"
    fi
    
    # Test plugin endpoint (may require authentication)
    print_info "Testing: GET $base_url/dx/api/dam-plugin/v1"
    if response=$(curl -s -w "\n%{http_code}" "$base_url/dx/api/dam-plugin/v1" 2>&1); then
        local status=$(echo "$response" | tail -n 1)
        
        if [ "$status" = "200" ]; then
            print_success "API: Plugin endpoint returned 200"
        else
            print_warning "API: Plugin endpoint returned $status (may require authentication)"
        fi
    fi
}

# =============================================================================
# Integration Tests
# =============================================================================

test_dam_integration() {
    print_header "Testing DAM Integration"
    
    # Check if DAM ConfigMap exists
    local configmap_name="${NAMESPACE}-${DAM_CONFIGMAP_SUFFIX}"
    
    if kubectl get configmap "$configmap_name" -n "$NAMESPACE" &> /dev/null; then
        print_success "DAM: ConfigMap exists"
        
        # Check if plugin is registered
        local config_data=$(kubectl get configmap "$configmap_name" -n "$NAMESPACE" -o jsonpath='{.data.config\.json}' 2>/dev/null || echo "")
        
        if echo "$config_data" | grep -q "$RELEASE_NAME"; then
            print_success "DAM: Plugin appears to be registered"
        else
            print_warning "DAM: Plugin may not be registered yet"
            print_info "Run: ./scripts/register-plugin-with-dam.sh"
        fi
    else
        print_warning "DAM: ConfigMap not found (DAM may not be installed)"
    fi
}

test_ingress_configuration() {
    print_header "Testing Ingress Configuration"
    
    # Check if ingress exists
    if kubectl get ingress "$RELEASE_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_success "Kubernetes: Ingress exists"
        
        # Get ingress details
        local host=$(kubectl get ingress "$RELEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
        local path=$(kubectl get ingress "$RELEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].http.paths[0].path}')
        
        print_info "Ingress Host: $host"
        print_info "Ingress Path: $path"
        
        # Check for HAProxy labels
        local haproxy_label=$(kubectl get ingress "$RELEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.custom-haproxy}')
        
        if [ "$haproxy_label" = "enabled" ]; then
            print_success "Ingress: HAProxy label present"
            print_warning "HAProxy dynamic configuration testing not yet implemented"
        fi
    else
        print_info "Kubernetes: No ingress configured (ClusterIP only)"
    fi
}

# =============================================================================
# Cleanup
# =============================================================================

cleanup() {
    print_header "Cleanup"
    
    # Stop port forwarding
    for pidfile in /tmp/dam-demo-pf-*.pid; do
        if [ -f "$pidfile" ]; then
            local PF_PID=$(cat "$pidfile")
            if ps -p $PF_PID > /dev/null 2>&1; then
                print_info "Stopping port forwarding (PID: $PF_PID)"
                kill $PF_PID 2>/dev/null || true
            fi
            rm "$pidfile"
        fi
    done
    
    # Clean up temp files
    rm -f /tmp/pf-output-*.log
}

# =============================================================================
# Test Execution
# =============================================================================

run_all_tests() {
    print_header "DAM-Demo Template End-to-End Testing"
    print_info "Test Mode: $TEST_MODE"
    print_info "Dry Run: $DRY_RUN"
    print_info "Skip Push: $SKIP_PUSH"
    print_info "Skip Deploy: $SKIP_DEPLOY"
    
    # Run pre-flight checks
    if ! preflight_checks; then
        print_error "Pre-flight checks failed"
        return 1
    fi
    
    # Build tests
    if [[ "$TEST_MODE" == "full" ]] || [[ "$TEST_MODE" == "build-only" ]] || [[ "$TEST_MODE" == "backend-only" ]]; then
        test_backend_build || true
        test_docker_build || true
        
        if [[ "$TEST_MODE" == "full" ]]; then
            test_docker_push || true
        fi
    fi
    
    # Deployment tests
    if [[ "$TEST_MODE" == "full" ]] || [[ "$TEST_MODE" == "deploy-only" ]] || [[ "$TEST_MODE" == "backend-only" ]]; then
        test_helm_chart_validation || true
        test_kubernetes_deployment || true
        test_service_availability || true
    fi
    
    # Integration tests
    if [[ "$TEST_MODE" == "full" ]] || [[ "$TEST_MODE" == "deploy-only" ]]; then
        test_port_forwarding || true
        sleep 3
        test_api_endpoints || true
        test_dam_integration || true
        test_ingress_configuration || true
    fi
    
    # Summary
    print_header "Test Summary"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "Some tests failed"
        return 1
    fi
}

# Trap cleanup
trap cleanup EXIT

# Run tests
run_all_tests
exit_code=$?

exit $exit_code
