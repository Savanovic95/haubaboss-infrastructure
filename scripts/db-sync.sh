#!/bin/bash
#
# Database Sync Script
# Syncs data between local Mac MySQL and production Docker MySQL
#
# Usage:
#   ./scripts/db-sync.sh export              # Export local DB to file
#   ./scripts/db-sync.sh import <file>       # Import file to local DB
#   ./scripts/db-sync.sh push                # Push local DB to production
#   ./scripts/db-sync.sh pull                # Pull production DB to local
#   ./scripts/db-sync.sh validate            # Validate table structures match
#   ./scripts/db-sync.sh compare             # Compare row counts
#

set -e

# Configuration
LOCAL_DB_USER="root"
LOCAL_DB_PASS=""
LOCAL_DB_NAME="haubaboss_app"

REMOTE_HOST="89.167.24.255"
REMOTE_SSH_KEY="~/.ssh/id_ed25519"
REMOTE_DB_USER="haubaboss"
REMOTE_DB_PASS="your_secure_db_password"
REMOTE_DB_NAME="haubaboss_app"

BACKUP_DIR="$(cd "$(dirname "$0")/.." && pwd)/db-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$BACKUP_DIR"

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

local_mysql() {
    if [ -n "$LOCAL_DB_PASS" ]; then
        mysql -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" "$LOCAL_DB_NAME" "$@"
    else
        mysql -u "$LOCAL_DB_USER" "$LOCAL_DB_NAME" "$@"
    fi
}

local_mysqldump() {
    if [ -n "$LOCAL_DB_PASS" ]; then
        mysqldump -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" "$LOCAL_DB_NAME" "$@"
    else
        mysqldump -u "$LOCAL_DB_USER" "$LOCAL_DB_NAME" "$@"
    fi
}

remote_mysql() {
    ssh -i "$REMOTE_SSH_KEY" root@"$REMOTE_HOST" \
        "cd /var/www/haubaboss && docker compose exec -T db mysql -u $REMOTE_DB_USER -p$REMOTE_DB_PASS $REMOTE_DB_NAME" "$@"
}

remote_mysqldump() {
    ssh -i "$REMOTE_SSH_KEY" root@"$REMOTE_HOST" \
        "cd /var/www/haubaboss && docker compose exec -T db mysqldump -u $REMOTE_DB_USER -p$REMOTE_DB_PASS $REMOTE_DB_NAME" "$@"
}

# Export local database
export_local() {
    local OUTPUT_FILE="$BACKUP_DIR/local_${TIMESTAMP}.sql"
    log_info "Exporting local database to $OUTPUT_FILE..."
    
    local_mysqldump --single-transaction --routines --triggers > "$OUTPUT_FILE"
    
    local SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    log_success "Export complete: $OUTPUT_FILE ($SIZE)"
}

# Import to local database
import_local() {
    local INPUT_FILE="$1"
    
    if [ -z "$INPUT_FILE" ]; then
        log_error "Usage: $0 import <file.sql>"
        exit 1
    fi
    
    if [ ! -f "$INPUT_FILE" ]; then
        log_error "File not found: $INPUT_FILE"
        exit 1
    fi
    
    log_warn "This will REPLACE all data in local database!"
    read -p "Are you sure? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Aborted."
        exit 0
    fi
    
    log_info "Importing $INPUT_FILE to local database..."
    local_mysql < "$INPUT_FILE"
    log_success "Import complete!"
}

# Push local to production
push_to_prod() {
    log_warn "This will REPLACE all data in PRODUCTION database!"
    log_warn "This is a DESTRUCTIVE operation!"
    read -p "Type 'PUSH TO PRODUCTION' to confirm: " CONFIRM
    
    if [ "$CONFIRM" != "PUSH TO PRODUCTION" ]; then
        log_info "Aborted."
        exit 0
    fi
    
    # First backup production
    log_info "Backing up production database first..."
    local PROD_BACKUP="$BACKUP_DIR/prod_backup_before_push_${TIMESTAMP}.sql"
    remote_mysqldump --single-transaction > "$PROD_BACKUP"
    log_success "Production backup saved: $PROD_BACKUP"
    
    # Export local
    local LOCAL_EXPORT="$BACKUP_DIR/local_for_push_${TIMESTAMP}.sql"
    log_info "Exporting local database..."
    local_mysqldump --single-transaction > "$LOCAL_EXPORT"
    
    # Push to production
    log_info "Pushing to production..."
    cat "$LOCAL_EXPORT" | ssh -i "$REMOTE_SSH_KEY" root@"$REMOTE_HOST" \
        "cd /var/www/haubaboss && docker compose exec -T db mysql -u $REMOTE_DB_USER -p$REMOTE_DB_PASS $REMOTE_DB_NAME"
    
    log_success "Push complete! Production database updated."
}

# Pull production to local
pull_from_prod() {
    log_warn "This will REPLACE all data in LOCAL database!"
    read -p "Are you sure? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Aborted."
        exit 0
    fi
    
    # Backup local first
    log_info "Backing up local database first..."
    local LOCAL_BACKUP="$BACKUP_DIR/local_backup_before_pull_${TIMESTAMP}.sql"
    local_mysqldump --single-transaction > "$LOCAL_BACKUP"
    log_success "Local backup saved: $LOCAL_BACKUP"
    
    # Pull from production
    local PROD_EXPORT="$BACKUP_DIR/prod_for_pull_${TIMESTAMP}.sql"
    log_info "Pulling from production..."
    remote_mysqldump --single-transaction > "$PROD_EXPORT"
    
    # Import to local
    log_info "Importing to local..."
    local_mysql < "$PROD_EXPORT"
    
    log_success "Pull complete! Local database updated."
}

# Validate table structures match
validate_structure() {
    log_info "Validating table structures..."
    
    # Get local tables
    local LOCAL_TABLES=$(local_mysql -N -e "SHOW TABLES;" | sort)
    
    # Get remote tables
    local REMOTE_TABLES=$(echo "SHOW TABLES;" | remote_mysql -N 2>/dev/null | sort)
    
    # Compare
    local LOCAL_COUNT=$(echo "$LOCAL_TABLES" | wc -l | tr -d ' ')
    local REMOTE_COUNT=$(echo "$REMOTE_TABLES" | wc -l | tr -d ' ')
    
    echo ""
    echo "Table count: Local=$LOCAL_COUNT, Production=$REMOTE_COUNT"
    echo ""
    
    # Find differences
    local ONLY_LOCAL=$(comm -23 <(echo "$LOCAL_TABLES") <(echo "$REMOTE_TABLES"))
    local ONLY_REMOTE=$(comm -13 <(echo "$LOCAL_TABLES") <(echo "$REMOTE_TABLES"))
    
    if [ -n "$ONLY_LOCAL" ]; then
        log_warn "Tables only in LOCAL:"
        echo "$ONLY_LOCAL" | sed 's/^/  - /'
    fi
    
    if [ -n "$ONLY_REMOTE" ]; then
        log_warn "Tables only in PRODUCTION:"
        echo "$ONLY_REMOTE" | sed 's/^/  - /'
    fi
    
    if [ -z "$ONLY_LOCAL" ] && [ -z "$ONLY_REMOTE" ]; then
        log_success "All tables match!"
    fi
}

# Compare row counts
compare_counts() {
    log_info "Comparing row counts..."
    echo ""
    
    printf "%-35s %12s %12s %12s\n" "TABLE" "LOCAL" "PRODUCTION" "DIFF"
    printf "%-35s %12s %12s %12s\n" "-----" "-----" "----------" "----"
    
    local TABLES=$(local_mysql -N -e "SHOW TABLES;")
    
    for TABLE in $TABLES; do
        # Skip system tables
        if [[ "$TABLE" == "migrations" ]] || [[ "$TABLE" == "cache"* ]] || [[ "$TABLE" == "sessions" ]] || [[ "$TABLE" == "jobs" ]] || [[ "$TABLE" == "failed_jobs" ]] || [[ "$TABLE" == "job_batches" ]] || [[ "$TABLE" == "personal_access_tokens" ]]; then
            continue
        fi
        
        local LOCAL_COUNT=$(local_mysql -N -e "SELECT COUNT(*) FROM $TABLE;" 2>/dev/null || echo "0")
        local REMOTE_COUNT=$(echo "SELECT COUNT(*) FROM $TABLE;" | remote_mysql -N 2>/dev/null || echo "0")
        
        local DIFF=$((LOCAL_COUNT - REMOTE_COUNT))
        
        if [ "$DIFF" -ne 0 ]; then
            printf "%-35s %12s %12s ${YELLOW}%12s${NC}\n" "$TABLE" "$LOCAL_COUNT" "$REMOTE_COUNT" "$DIFF"
        else
            printf "%-35s %12s %12s %12s\n" "$TABLE" "$LOCAL_COUNT" "$REMOTE_COUNT" "$DIFF"
        fi
    done
    
    echo ""
}

# Main
case "${1:-}" in
    export)
        export_local
        ;;
    import)
        import_local "$2"
        ;;
    push)
        push_to_prod
        ;;
    pull)
        pull_from_prod
        ;;
    validate)
        validate_structure
        ;;
    compare)
        compare_counts
        ;;
    *)
        echo "Database Sync Script"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  export     - Export local database to backup file"
        echo "  import     - Import SQL file to local database"
        echo "  push       - Push local database to production (DESTRUCTIVE)"
        echo "  pull       - Pull production database to local (DESTRUCTIVE)"
        echo "  validate   - Validate table structures match"
        echo "  compare    - Compare row counts between local and production"
        exit 1
        ;;
esac
