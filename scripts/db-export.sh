#!/bin/bash
set -e

# ===========================================
# Export Docker MySQL database to SQL file
# ===========================================
# Usage: ./scripts/db-export.sh [output-filename]
# Example: ./scripts/db-export.sh backup_2024_01_29.sql

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

DB_NAME="${DB_DATABASE:-haubaboss_app}"
DB_ROOT_PASS="${DB_ROOT_PASSWORD:-secretroot}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${1:-$PROJECT_DIR/db-backups/backup_${TIMESTAMP}.sql}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== HaubaBoss Database Export ===${NC}"

# Check if container is running
if ! docker compose ps db | grep -q "running"; then
    echo -e "${RED}Error: Database container is not running${NC}"
    echo "Start it with: docker compose up -d db"
    exit 1
fi

# Create backup directory if needed
mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "Database: $DB_NAME"
echo "Output: $OUTPUT_FILE"
echo ""

# Export the database
docker compose exec -T db mysqldump -u root -p"$DB_ROOT_PASS" --single-transaction --routines --triggers "$DB_NAME" > "$OUTPUT_FILE"

# Get file size
FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

echo ""
echo -e "${GREEN}✅ Database exported successfully!${NC}"
echo "File: $OUTPUT_FILE ($FILE_SIZE)"
