#!/bin/bash
#
# Sync Database from Local Mac to Target
# ======================================
# Syncs your local Mac MySQL database to either:
# - Local Docker containers (for development)
# - Production server
#
# Usage:
#   ./scripts/db-sync-from-local.sh local       # Sync to local Docker
#   ./scripts/db-sync-from-local.sh production  # Sync to production server
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
LOCAL_DB_USER="root"
LOCAL_DB_PASS=""
LOCAL_DB_NAME="haubaboss_app"

REMOTE_HOST="89.167.24.255"
REMOTE_USER="root"
SSH_KEY="~/.ssh/id_ed25519"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

TARGET="${1:-}"
BACKUP_DIR="$PROJECT_DIR/db-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

if [ -z "$TARGET" ]; then
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           Database Sync from Local Mac                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "Usage: $0 <target>"
    echo ""
    echo "Targets:"
    echo "  local       - Sync to local Docker containers"
    echo "  production  - Sync to production server"
    echo ""
    exit 1
fi

# Check if local MySQL is accessible
echo -e "${BLUE}Checking local MySQL...${NC}"
if ! mysql -u "$LOCAL_DB_USER" -e "SELECT 1" &>/dev/null; then
    echo -e "${RED}Cannot connect to local MySQL${NC}"
    echo "Make sure MySQL is running on your Mac"
    exit 1
fi

# Check if database exists
if ! mysql -u "$LOCAL_DB_USER" -e "USE $LOCAL_DB_NAME" &>/dev/null; then
    echo -e "${RED}Database '$LOCAL_DB_NAME' not found on local MySQL${NC}"
    exit 1
fi

# Get row counts
echo -e "${BLUE}Local database stats:${NC}"
mysql -u "$LOCAL_DB_USER" "$LOCAL_DB_NAME" -e "
SELECT 
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM companies) as companies,
    (SELECT COUNT(*) FROM vehicles) as vehicles,
    (SELECT COUNT(*) FROM parts) as parts,
    (SELECT COUNT(*) FROM manufacturers) as manufacturers,
    (SELECT COUNT(*) FROM variants) as variants
\G" 2>/dev/null | grep -v "^\*"

echo ""

case "$TARGET" in
    local)
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  Syncing Local Mac DB → Local Docker                       ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        echo -e "${YELLOW}⚠ This will REPLACE all data in your local Docker database!${NC}"
        read -p "Continue? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            echo "Aborted."
            exit 0
        fi
        
        # Export from local Mac MySQL
        echo -e "${BLUE}[1/3]${NC} Exporting local database..."
        DUMP_FILE="$BACKUP_DIR/local_mac_${TIMESTAMP}.sql"
        mysqldump -u "$LOCAL_DB_USER" "$LOCAL_DB_NAME" \
            --single-transaction \
            --routines \
            --triggers \
            --skip-lock-tables \
            > "$DUMP_FILE"
        echo -e "${GREEN}✓ Exported to $DUMP_FILE${NC}"
        
        # Import to Docker
        echo -e "${BLUE}[2/3]${NC} Importing to Docker..."
        cd "$PROJECT_DIR"
        source .env 2>/dev/null || true
        DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-rootpassword}"
        
        docker compose exec -T db mysql -u root -p${DB_ROOT_PASSWORD} -e "DROP DATABASE IF EXISTS haubaboss_app; CREATE DATABASE haubaboss_app;"
        docker compose exec -T db mysql -u root -p${DB_ROOT_PASSWORD} haubaboss_app < "$DUMP_FILE"
        echo -e "${GREEN}✓ Imported to Docker${NC}"
        
        # Verify
        echo -e "${BLUE}[3/3]${NC} Verifying..."
        docker compose exec -T db mysql -u root -p${DB_ROOT_PASSWORD} haubaboss_app -e "SELECT COUNT(*) as users FROM users;"
        
        echo -e "${GREEN}✓ Sync complete!${NC}"
        ;;
        
    production)
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  Syncing Local Mac DB → Production Server                  ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        
        echo -e "${RED}⚠ WARNING: This will REPLACE all data in PRODUCTION!${NC}"
        echo -e "${RED}⚠ This is a DESTRUCTIVE operation!${NC}"
        read -p "Type 'SYNC TO PRODUCTION' to confirm: " CONFIRM
        if [ "$CONFIRM" != "SYNC TO PRODUCTION" ]; then
            echo "Aborted."
            exit 0
        fi
        
        # Backup production first
        echo -e "${BLUE}[1/5]${NC} Backing up production database first..."
        PROD_BACKUP="$BACKUP_DIR/prod_backup_before_sync_${TIMESTAMP}.sql"
        ssh -i $SSH_KEY ${REMOTE_USER}@${REMOTE_HOST} "cd /var/www/haubaboss && source .env && docker compose exec -T db mysqldump -u root -p\${DB_ROOT_PASSWORD} haubaboss_app --single-transaction" > "$PROD_BACKUP"
        echo -e "${GREEN}✓ Production backup saved to $PROD_BACKUP${NC}"
        
        # Export from local Mac MySQL
        echo -e "${BLUE}[2/5]${NC} Exporting local database..."
        DUMP_FILE="$BACKUP_DIR/local_mac_for_prod_${TIMESTAMP}.sql"
        mysqldump -u "$LOCAL_DB_USER" "$LOCAL_DB_NAME" \
            --single-transaction \
            --routines \
            --triggers \
            --skip-lock-tables \
            > "$DUMP_FILE"
        echo -e "${GREEN}✓ Exported${NC}"
        
        # Transfer to server
        echo -e "${BLUE}[3/5]${NC} Transferring to server..."
        scp -i $SSH_KEY "$DUMP_FILE" ${REMOTE_USER}@${REMOTE_HOST}:/tmp/sync_dump.sql
        echo -e "${GREEN}✓ Transferred${NC}"
        
        # Import on server
        echo -e "${BLUE}[4/5]${NC} Importing on production..."
        ssh -i $SSH_KEY ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
cd /var/www/haubaboss
source .env
docker compose exec -T db mysql -u root -p${DB_ROOT_PASSWORD} -e "DROP DATABASE IF EXISTS haubaboss_app; CREATE DATABASE haubaboss_app;"
docker compose exec -T db mysql -u root -p${DB_ROOT_PASSWORD} haubaboss_app < /tmp/sync_dump.sql
rm /tmp/sync_dump.sql
ENDSSH
        echo -e "${GREEN}✓ Imported${NC}"
        
        # Verify
        echo -e "${BLUE}[5/5]${NC} Verifying..."
        ssh -i $SSH_KEY ${REMOTE_USER}@${REMOTE_HOST} "cd /var/www/haubaboss && source .env && docker compose exec -T db mysql -u root -p\${DB_ROOT_PASSWORD} haubaboss_app -e 'SELECT COUNT(*) as users FROM users;'"
        
        echo -e "${GREEN}✓ Production sync complete!${NC}"
        ;;
        
    *)
        echo -e "${RED}Unknown target: $TARGET${NC}"
        echo "Use 'local' or 'production'"
        exit 1
        ;;
esac
