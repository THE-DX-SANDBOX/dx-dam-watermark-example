#!/bin/bash
# Validate template structure and configuration

cd "$(dirname "$0")/../.."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Template Validation Checklist"
echo "=========================================="
echo ""

total_checks=0
passed_checks=0
warning_checks=0

check_item() {
    local description=$1
    local status=$2
    
    ((total_checks++))
    
    if [ "$status" = "pass" ]; then
        echo -e "${GREEN}✅${NC} $description"
        ((passed_checks++))
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠️${NC}  $description"
        ((warning_checks++))
    else
        echo -e "${RED}❌${NC} $description"
    fi
}

# Project structure checks
echo "Project Structure:"
echo "-------------------"

[ -d "packages/server-v1" ] && check_item "Backend package exists" "pass" || check_item "Backend package missing" "fail"
[ -d "helm/dam-plugin" ] && check_item "Helm chart exists" "pass" || check_item "Helm chart missing" "fail"
[ -d "scripts" ] && check_item "Scripts directory exists" "pass" || check_item "Scripts directory missing" "fail"
[ -d ".ai" ] && check_item "AI context directory exists" "pass" || check_item "AI context directory missing" "fail"

echo ""
echo "Configuration Files:"
echo "-------------------"

[ -f ".env.example" ] && check_item ".env.example exists" "pass" || check_item ".env.example missing" "fail"
[ -f ".env" ] && check_item ".env exists (user configured)" "pass" || check_item ".env not configured" "warn"
[ -f "plugin-config.json" ] && check_item "plugin-config.json exists" "pass" || check_item "plugin-config.json missing" "fail"
[ -f ".gitignore" ] && check_item ".gitignore exists" "pass" || check_item ".gitignore missing" "fail"
[ -f "package.json" ] && check_item "Root package.json exists" "pass" || check_item "Root package.json missing" "fail"

echo ""
echo "Scripts:"
echo "-------------------"

[ -x "scripts/build.sh" ] && check_item "build.sh is executable" "pass" || check_item "build.sh not executable" "fail"
[ -x "scripts/deploy.sh" ] && check_item "deploy.sh is executable" "pass" || check_item "deploy.sh not executable" "fail"
[ -x "scripts/load-env.sh" ] && check_item "load-env.sh is executable" "pass" || check_item "load-env.sh not executable" "fail"
[ -f "scripts/port-forward.sh" ] && check_item "port-forward.sh exists" "pass" || check_item "port-forward.sh missing" "warn"

echo ""
echo "Backend Package:"
echo "-------------------"

[ -f "packages/server-v1/package.json" ] && check_item "Backend package.json exists" "pass" || check_item "Backend package.json missing" "fail"
[ -f "packages/server-v1/tsconfig.json" ] && check_item "TypeScript config exists" "pass" || check_item "TypeScript config missing" "fail"
[ -d "packages/server-v1/src" ] && check_item "Backend src/ directory exists" "pass" || check_item "Backend src/ missing" "fail"
[ -f "packages/server-v1/src/application.ts" ] && check_item "LoopBack application exists" "pass" || check_item "LoopBack application missing" "fail"

echo ""
echo "Dependencies:"
echo "-------------------"

[ -d "packages/server-v1/node_modules" ] && check_item "Backend dependencies installed" "pass" || check_item "Backend dependencies not installed (run: npm install)" "warn"

echo ""
echo "Build Artifacts:"
echo "-------------------"

[ -d "packages/server-v1/dist" ] && check_item "Backend built (dist/ exists)" "pass" || check_item "Backend not built (run: npm run build)" "warn"

echo ""
echo "Documentation:"
echo "-------------------"

[ -f "README.md" ] && check_item "README.md exists" "pass" || check_item "README.md missing" "fail"
[ -f "docs/ENVIRONMENT_SETUP.md" ] && check_item "Environment setup guide exists" "pass" || check_item "Environment setup guide missing" "warn"
[ -d ".ai" ] && [ "$(ls -A .ai)" ] && check_item "AI context files exist" "pass" || check_item "AI context incomplete" "warn"

echo ""
echo "Helm Chart:"
echo "-------------------"

[ -f "helm/dam-plugin/Chart.yaml" ] && check_item "Chart.yaml exists" "pass" || check_item "Chart.yaml missing" "fail"
[ -f "helm/dam-plugin/values.yaml" ] && check_item "values.yaml exists" "pass" || check_item "values.yaml missing" "fail"
[ -d "helm/dam-plugin/templates" ] && check_item "Templates directory exists" "pass" || check_item "Templates directory missing" "fail"

echo ""
echo "=========================================="
echo "Summary:"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $passed_checks / $total_checks"
echo -e "${YELLOW}Warnings:${NC} $warning_checks"
echo -e "${RED}Failed:${NC} $((total_checks - passed_checks - warning_checks))"
echo ""

if [ $((total_checks - passed_checks - warning_checks)) -eq 0 ]; then
    echo -e "${GREEN}✅ Template structure is valid!${NC}"
    
    if [ $warning_checks -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some optional items have warnings${NC}"
    fi
    
    exit 0
else
    echo -e "${RED}❌ Template has validation errors${NC}"
    exit 1
fi
