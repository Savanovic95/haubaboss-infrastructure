#!/bin/bash
set -e

echo "🚀 Initializing Haubaboss Docker Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    cp .env.example .env
    echo -e "${RED}Please edit .env with your actual values before continuing!${NC}"
    exit 1
fi

# Create necessary directories
echo "Creating required directories..."
mkdir -p nginx/ssl nginx/logs db-init
mkdir -p haubaboss-backend/storage/logs
mkdir -p haubaboss-backend/storage/framework/{cache,sessions,views}
mkdir -p haubaboss-backend/bootstrap/cache

# Fix permissions for Laravel
echo "Setting permissions for Laravel storage..."
chmod -R 775 haubaboss-backend/storage
chmod -R 775 haubaboss-backend/bootstrap/cache

# Build and start containers
echo -e "${GREEN}Building Docker images...${NC}"
docker compose build

echo -e "${GREEN}Starting containers...${NC}"
docker compose up -d

# Wait for database to be ready
echo "Waiting for database to be ready..."
sleep 10

# Run Laravel migrations
echo -e "${GREEN}Running Laravel migrations...${NC}"
docker compose exec backend php artisan migrate --force

# Generate app key if needed
echo "Checking Laravel app key..."
docker compose exec backend php artisan key:generate --force

# Clear and cache Laravel config
echo "Optimizing Laravel..."
docker compose exec backend php artisan config:cache
docker compose exec backend php artisan route:cache
docker compose exec backend php artisan view:cache

# Create storage link
docker compose exec backend php artisan storage:link || true

echo -e "${GREEN}✅ Haubaboss is now running!${NC}"
echo ""
echo "Access the application at:"
echo "  - Frontend: http://localhost"
echo "  - API: http://localhost/api"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f          # View logs"
echo "  docker compose exec backend sh  # Shell into backend"
echo "  docker compose down             # Stop all containers"
