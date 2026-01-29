#!/bin/bash
set -e

# ===========================================
# Start HaubaBoss Docker Stack
# ===========================================
# Usage: ./scripts/start.sh [environment]
# Examples:
#   ./scripts/start.sh          # Start in development mode
#   ./scripts/start.sh prod     # Start in production mode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENV="${1:-dev}"

echo -e "${BLUE}=== HaubaBoss Docker Stack ===${NC}"
echo ""

# Stop local MySQL if running (to free port 3306)
if lsof -i :3306 | grep -q mysqld 2>/dev/null; then
    echo -e "${YELLOW}Stopping local MySQL to free port 3306...${NC}"
    if command -v brew &> /dev/null; then
        brew services stop mysql 2>/dev/null || true
    fi
    # Also try launchctl for system MySQL
    sudo launchctl unload -w /Library/LaunchDaemons/com.mysql.mysql.plist 2>/dev/null || true
    # Give it a moment to stop
    sleep 2
    
    # If still running, try direct kill
    if lsof -i :3306 | grep -q mysqld 2>/dev/null; then
        echo -e "${YELLOW}Force stopping MySQL...${NC}"
        pkill -f mysqld 2>/dev/null || true
        sleep 2
    fi
    
    echo -e "${GREEN}Local MySQL stopped.${NC}"
fi

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    cp .env.example .env
    echo -e "${RED}Please edit .env with your actual values, then run this script again.${NC}"
    exit 1
fi

# Create required directories
mkdir -p db-backups db-init nginx/ssl nginx/logs
mkdir -p haubaboss-backend/storage/logs
mkdir -p haubaboss-backend/storage/framework/{cache,sessions,views}
mkdir -p haubaboss-backend/bootstrap/cache

# Set permissions for Laravel
chmod -R 775 haubaboss-backend/storage 2>/dev/null || true
chmod -R 775 haubaboss-backend/bootstrap/cache 2>/dev/null || true

if [ "$ENV" = "prod" ] || [ "$ENV" = "production" ]; then
    echo -e "${GREEN}Starting in PRODUCTION mode...${NC}"
    # In production, don't use override file
    docker compose -f docker-compose.yml up -d --build
else
    echo -e "${GREEN}Starting in DEVELOPMENT mode...${NC}"
    # In dev, docker-compose.override.yml is automatically loaded
    docker compose up -d --build
fi

# Wait for database
echo ""
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
sleep 5

# Check if DB is healthy
RETRIES=30
until docker compose exec -T db mysqladmin ping -h localhost -u root -p"${DB_ROOT_PASSWORD:-secretroot}" --silent 2>/dev/null; do
    RETRIES=$((RETRIES-1))
    if [ $RETRIES -le 0 ]; then
        echo -e "${RED}Database failed to start. Check logs with: docker compose logs db${NC}"
        exit 1
    fi
    echo "Waiting for database... ($RETRIES attempts left)"
    sleep 2
done

echo -e "${GREEN}Database is ready!${NC}"
echo ""

# Run migrations
echo -e "${YELLOW}Running Laravel migrations...${NC}"
docker compose exec -T backend php artisan migrate --force || true

# Cache config for production
if [ "$ENV" = "prod" ] || [ "$ENV" = "production" ]; then
    echo -e "${YELLOW}Caching Laravel config...${NC}"
    docker compose exec -T backend php artisan config:cache
    docker compose exec -T backend php artisan route:cache
    docker compose exec -T backend php artisan view:cache
fi

# Create storage link
docker compose exec -T backend php artisan storage:link 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ HaubaBoss is now running!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Access the application:"
echo "  - Frontend: http://localhost"
echo "  - API:      http://localhost/api"
echo "  - Database: localhost:3306"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f              # View all logs"
echo "  docker compose logs -f backend      # View backend logs"
echo "  docker compose exec backend sh      # Shell into backend"
echo "  docker compose exec db mysql -u root -p  # MySQL CLI"
echo "  ./scripts/migrate.sh                # Run migrations"
echo "  ./scripts/db-export.sh              # Backup database"
echo "  ./scripts/db-import.sh <file.sql>   # Import database"
echo ""
