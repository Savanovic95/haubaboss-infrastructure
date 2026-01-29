#!/bin/bash
set -e

# ===========================================
# Stop HaubaBoss Docker Stack
# ===========================================
# This script stops Docker containers and restarts local MySQL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Stopping HaubaBoss Docker Stack ===${NC}"
echo ""

# Stop Docker containers
echo -e "${YELLOW}Stopping Docker containers...${NC}"
docker compose down

echo -e "${GREEN}Docker containers stopped.${NC}"
echo ""

# Restart local MySQL
echo -e "${YELLOW}Restarting local MySQL...${NC}"

if command -v brew &> /dev/null; then
    brew services start mysql 2>/dev/null && echo -e "${GREEN}Local MySQL started via Homebrew.${NC}" || true
else
    # Try launchctl for system MySQL
    sudo launchctl load -w /Library/LaunchDaemons/com.mysql.mysql.plist 2>/dev/null && echo -e "${GREEN}Local MySQL started via launchctl.${NC}" || true
fi

# Verify MySQL is running
sleep 2
if lsof -i :3306 | grep -q mysqld 2>/dev/null; then
    echo -e "${GREEN}✅ Local MySQL is now running on port 3306${NC}"
else
    echo -e "${YELLOW}Note: Could not auto-start local MySQL. Start it manually if needed.${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ HaubaBoss stopped, local MySQL restored${NC}"
echo -e "${GREEN}========================================${NC}"
