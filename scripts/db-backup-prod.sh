#!/bin/bash
#
# Backup Production Database to Local Mac
# =======================================
# Downloads a backup of the production database to your local machine.
#
# Usage:
#   ./scripts/db-backup-prod.sh              # Backup to db-backups/
#   ./scripts/db-backup-prod.sh ~/Desktop    # Backup to specific folder
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
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

BACKUP_DIR="${1:-$PROJECT_DIR/db-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/production_backup_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Backup Production Database                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check SSH connection
echo -e "${BLUE}[1/4]${NC} Checking server connection..."
if ! ssh -i $SSH_KEY -o ConnectTimeout=5 ${REMOTE_USER}@${REMOTE_HOST} "echo 'Connected'" 2>/dev/null; then
    echo -e "${RED}Cannot connect to server${NC}"
    echo "Check SSH key and server availability"
    exit 1
fi
echo -e "${GREEN}✓ Connected${NC}"

# Get database stats
echo -e "${BLUE}[2/4]${NC} Getting database info..."
ssh -i $SSH_KEY ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
cd /var/www/haubaboss
source .env
echo "Database stats:"
docker compose exec -T db mysql -u root -p${DB_ROOT_PASSWORD} haubaboss_app -e "
SELECT 
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM companies) as companies,
    (SELECT COUNT(*) FROM vehicles) as vehicles,
    (SELECT COUNT(*) FROM parts) as parts,
    (SELECT COUNT(*) FROM manufacturers) as manufacturers
\G" 2>/dev/null | grep -v "^\*"
ENDSSH

# Create backup on server
echo -e "${BLUE}[3/4]${NC} Creating backup on server..."
ssh -i $SSH_KEY ${REMOTE_USER}@${REMOTE_HOST} << 'ENDSSH'
cd /var/www/haubaboss
source .env
docker compose exec -T db mysqldump -u root -p${DB_ROOT_PASSWORD} haubaboss_app \
    --single-transaction \
    --routines \
    --triggers \
    --skip-lock-tables \
    > /tmp/prod_backup.sql
echo "Backup size: $(du -h /tmp/prod_backup.sql | cut -f1)"
ENDSSH

# Download backup
echo -e "${BLUE}[4/4]${NC} Downloading backup..."
scp -i $SSH_KEY ${REMOTE_USER}@${REMOTE_HOST}:/tmp/prod_backup.sql "$BACKUP_FILE"

# Cleanup server
ssh -i $SSH_KEY ${REMOTE_USER}@${REMOTE_HOST} "rm /tmp/prod_backup.sql"

# Show result
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Backup Complete!                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}File:${NC}  $BACKUP_FILE"
echo -e "  ${CYAN}Size:${NC}  $BACKUP_SIZE"
echo ""
echo -e "  ${YELLOW}To restore to local Docker:${NC}"
echo -e "    ./scripts/db-sync-from-local.sh local"
echo -e "    # (after importing the backup to your Mac MySQL)"
echo ""
echo -e "  ${YELLOW}To import directly to Mac MySQL:${NC}"
echo -e "    mysql -u root haubaboss_app < $BACKUP_FILE"
echo ""
