#!/bin/bash
set -e

# ===========================================
# Import SQL dump into Docker MySQL container
# ===========================================
# Usage: ./scripts/db-import.sh [path-to-sql-file]
# Example: ./scripts/db-import.sh ./haubaboss-backend/haubaboss_app.sql

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

DB_NAME="${DB_DATABASE:-haubaboss_app}"
DB_ROOT_PASS="${DB_ROOT_PASSWORD:-secretroot}"
SQL_FILE="${1:-$PROJECT_DIR/haubaboss-backend/haubaboss_app.sql}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== HaubaBoss Database Import ===${NC}"

# Check if SQL file exists
if [ ! -f "$SQL_FILE" ]; then
    echo -e "${RED}Error: SQL file not found: $SQL_FILE${NC}"
    echo "Usage: ./scripts/db-import.sh [path-to-sql-file]"
    exit 1
fi

# Check if container is running
if ! docker compose ps db | grep -q "running"; then
    echo -e "${RED}Error: Database container is not running${NC}"
    echo "Start it with: docker compose up -d db"
    exit 1
fi

# Get file size for progress indication
FILE_SIZE=$(du -h "$SQL_FILE" | cut -f1)
echo -e "Importing: ${GREEN}$SQL_FILE${NC} ($FILE_SIZE)"
echo "Database: $DB_NAME"
echo ""
echo -e "${YELLOW}This may take several minutes for large databases...${NC}"

# Import the SQL file
docker compose exec -T db mysql -u root -p"$DB_ROOT_PASS" "$DB_NAME" < "$SQL_FILE"

echo ""
echo -e "${GREEN}✅ Database import completed successfully!${NC}"
echo ""
echo "Verify with: docker compose exec db mysql -u root -p'$DB_ROOT_PASS' -e 'SHOW TABLES;' $DB_NAME"
