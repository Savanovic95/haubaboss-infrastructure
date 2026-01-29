#!/bin/bash
set -e

# ===========================================
# Run Laravel migrations in Docker container
# ===========================================
# Usage: ./scripts/migrate.sh [artisan-args]
# Examples:
#   ./scripts/migrate.sh                    # Run pending migrations
#   ./scripts/migrate.sh --seed             # Run migrations + seeders
#   ./scripts/migrate.sh:fresh --seed       # Fresh DB + seeders (DESTRUCTIVE!)
#   ./scripts/migrate.sh:rollback           # Rollback last migration
#   ./scripts/migrate.sh:status             # Show migration status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if container is running
if ! docker compose ps backend | grep -q "running"; then
    echo -e "${RED}Error: Backend container is not running${NC}"
    echo "Start it with: docker compose up -d"
    exit 1
fi

# Default to 'migrate' if no args
COMMAND="${1:-migrate}"

# Handle special commands
case "$COMMAND" in
    "fresh"|"migrate:fresh")
        echo -e "${RED}⚠️  WARNING: This will DROP ALL TABLES and recreate them!${NC}"
        read -p "Are you sure? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Aborted."
            exit 0
        fi
        shift
        docker compose exec backend php artisan migrate:fresh "$@"
        ;;
    "rollback"|"migrate:rollback")
        shift
        docker compose exec backend php artisan migrate:rollback "$@"
        ;;
    "status"|"migrate:status")
        docker compose exec backend php artisan migrate:status
        ;;
    "seed"|"db:seed")
        shift
        docker compose exec backend php artisan db:seed "$@"
        ;;
    *)
        docker compose exec backend php artisan migrate "$@"
        ;;
esac

echo ""
echo -e "${GREEN}✅ Done!${NC}"
