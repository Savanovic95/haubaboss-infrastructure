#!/bin/bash
#
# Database Validation Script
# Validates data integrity and checks for common issues
#
# Usage:
#   ./scripts/db-validate.sh              # Validate local database
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DB_NAME="haubaboss_app"

echo "============================================"
echo "  Database Validation - LOCAL"
echo "============================================"
echo ""

PASSED=0
FAILED=0
WARNINGS=0

# Helper function
run_check() {
    local NAME="$1"
    local QUERY="$2"
    local EXPECTED="$3"
    
    RESULT=$(mysql -u root "$DB_NAME" -s -e "$QUERY" 2>/dev/null | tail -1)
    
    if [ "$RESULT" == "$EXPECTED" ]; then
        echo -e "${GREEN}[PASS]${NC} $NAME"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $NAME (expected: $EXPECTED, got: $RESULT)"
        ((FAILED++))
    fi
}

run_check_gt_zero() {
    local NAME="$1"
    local QUERY="$2"
    
    RESULT=$(mysql -u root "$DB_NAME" -s -e "$QUERY" 2>/dev/null | tail -1)
    
    if [ "$RESULT" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} $NAME ($RESULT records)"
        ((PASSED++))
    else
        echo -e "${RED}[FAIL]${NC} $NAME (no records)"
        ((FAILED++))
    fi
}

run_check_zero() {
    local NAME="$1"
    local QUERY="$2"
    
    RESULT=$(mysql -u root "$DB_NAME" -s -e "$QUERY" 2>/dev/null | tail -1)
    
    if [ "$RESULT" -eq 0 ] 2>/dev/null; then
        echo -e "${GREEN}[PASS]${NC} $NAME"
        ((PASSED++))
    else
        echo -e "${YELLOW}[WARN]${NC} $NAME ($RESULT issues)"
        ((WARNINGS++))
    fi
}

# 1. Check essential tables
echo -e "${BLUE}[INFO]${NC} Checking essential tables..."
run_check "users table" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='users';" "1"
run_check "companies table" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='companies';" "1"
run_check "vehicles table" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='vehicles';" "1"
run_check "parts table" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='parts';" "1"
run_check "manufacturers table" "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME' AND table_name='manufacturers';" "1"
echo ""

# 2. Check essential data
echo -e "${BLUE}[INFO]${NC} Checking essential data..."
run_check_gt_zero "Users exist" "SELECT COUNT(*) FROM users;"
run_check_gt_zero "Companies exist" "SELECT COUNT(*) FROM companies;"
run_check_gt_zero "Manufacturers exist" "SELECT COUNT(*) FROM manufacturers;"
echo ""

# 3. Check for orphaned records
echo -e "${BLUE}[INFO]${NC} Checking for orphaned records..."
run_check_zero "Parts without valid company" "SELECT COUNT(*) FROM parts WHERE company_id IS NOT NULL AND company_id NOT IN (SELECT id FROM companies);"
run_check_zero "Vehicles without valid company" "SELECT COUNT(*) FROM vehicles WHERE company_id IS NOT NULL AND company_id NOT IN (SELECT id FROM companies);"
echo ""

# 4. Check for duplicates
echo -e "${BLUE}[INFO]${NC} Checking for duplicates..."
run_check_zero "Duplicate user emails" "SELECT COUNT(*) FROM (SELECT email, COUNT(*) as cnt FROM users GROUP BY email HAVING cnt > 1) as dups;"
run_check_zero "Duplicate vehicle VINs" "SELECT COUNT(*) FROM (SELECT vin, COUNT(*) as cnt FROM vehicles GROUP BY vin HAVING cnt > 1) as dups;"
echo ""

# 5. Summary
echo "============================================"
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$WARNINGS warnings${NC}"
echo "============================================"

exit $FAILED
