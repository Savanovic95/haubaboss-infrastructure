#!/bin/bash
#
# API Smoke Test Script
# Tests all critical API endpoints to verify the system is working.
#
# Usage:
#   ./scripts/test-api.sh                    # Test localhost
#   ./scripts/test-api.sh http://89.167.24.255  # Test production
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_URL=${1:-http://localhost}
PASSED=0
FAILED=0

echo "============================================"
echo "  HaubaBoss API Smoke Test"
echo "  Target: $BASE_URL"
echo "============================================"
echo ""

# Helper function to test an endpoint
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_status="$4"
    local auth_header="$5"
    local body="$6"
    
    printf "%-30s" "$name..."
    
    local curl_args=(-s -w "%{http_code}" -o /tmp/api_response.txt)
    curl_args+=(-X "$method")
    curl_args+=(-H "Accept: application/json")
    
    if [ -n "$auth_header" ]; then
        curl_args+=(-H "$auth_header")
    fi
    
    if [ -n "$body" ]; then
        curl_args+=(-H "Content-Type: application/json")
        curl_args+=(-d "$body")
    fi
    
    local status=$(curl "${curl_args[@]}" "$BASE_URL$endpoint")
    
    if [ "$status" = "$expected_status" ]; then
        echo -e "${GREEN}PASS${NC} (HTTP $status)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC} (Expected $expected_status, got $status)"
        ((FAILED++))
        return 1
    fi
}

# 1. Health Check
echo "--- Frontend Health ---"
test_endpoint "Health endpoint" "GET" "/api/health" "200" "" "" || true

# 2. Backend connectivity
echo ""
echo "--- Backend API ---"

# Login with invalid credentials (should return 422 or 401)
test_endpoint "Login validation" "POST" "/api/v1/auth/login" "422" "" '{"email":"","password":""}' || true

# Login with valid credentials
echo ""
echo "--- Authentication ---"
printf "%-30s" "Login (zeus)..."

LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{"email":"zeus@haubaboss.com","password":"zeus123456"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo -e "${GREEN}PASS${NC} (Token received)"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (No token in response)"
    echo "Response: $LOGIN_RESPONSE"
    ((FAILED++))
    echo ""
    echo "============================================"
    echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
    echo "============================================"
    exit 1
fi

# 3. Authenticated endpoints
echo ""
echo "--- Protected Endpoints ---"
AUTH_HEADER="Authorization: Bearer $TOKEN"

test_endpoint "Get vehicles" "GET" "/api/v1/vehicles" "200" "$AUTH_HEADER" "" || true
test_endpoint "Get parts" "GET" "/api/v1/parts?company_id=1" "200" "$AUTH_HEADER" "" || true

# 4. Summary
echo ""
echo "============================================"
if [ $FAILED -eq 0 ]; then
    echo -e "  ${GREEN}All tests passed!${NC} ($PASSED/$PASSED)"
else
    echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
fi
echo "============================================"

exit $FAILED
