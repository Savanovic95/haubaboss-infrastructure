#!/bin/bash
set -e

# ===========================================
# Deploy HaubaBoss to Server
# ===========================================
# Run this from your LOCAL machine to deploy to server
# Usage: ./scripts/deploy.sh

SERVER_IP="89.167.24.255"
SERVER_USER="root"  # Change if you use a different user
REMOTE_PATH="/var/www/haubaboss"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Deploying HaubaBoss to Server${NC}"
echo -e "${BLUE}   Server: ${SERVER_IP}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ! ssh -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_IP} "echo 'Connected'" 2>/dev/null; then
    echo -e "${RED}Cannot connect to server. Check:${NC}"
    echo "  - SSH key is set up"
    echo "  - Server IP is correct"
    echo "  - Server is running"
    exit 1
fi

echo -e "${GREEN}SSH connection OK${NC}"
echo ""

# Sync files (excluding node_modules, vendor, etc.)
echo -e "${YELLOW}Syncing files to server...${NC}"
rsync -avz --progress \
    --exclude 'node_modules' \
    --exclude 'vendor' \
    --exclude '.git' \
    --exclude '.env' \
    --exclude 'storage/logs/*' \
    --exclude 'storage/framework/cache/*' \
    --exclude 'storage/framework/sessions/*' \
    --exclude 'storage/framework/views/*' \
    --exclude 'bootstrap/cache/*' \
    --exclude '.next' \
    --exclude 'db-backups/*' \
    --exclude '*.sql' \
    ./ ${SERVER_USER}@${SERVER_IP}:${REMOTE_PATH}/

echo -e "${GREEN}Files synced!${NC}"
echo ""

# Run deployment commands on server
echo -e "${YELLOW}Running deployment on server...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
cd /var/www/haubaboss

# Make scripts executable
chmod +x scripts/*.sh

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "⚠️  Please edit /var/www/haubaboss/.env with production values!"
fi

# Start/restart in production mode
echo "Starting Docker containers..."
docker compose -f docker-compose.yml up -d --build

# Wait for DB
echo "Waiting for database..."
sleep 10

# Run migrations
echo "Running migrations..."
docker compose exec -T backend php artisan migrate --force || true

# Cache config
echo "Caching Laravel config..."
docker compose exec -T backend php artisan config:cache || true
docker compose exec -T backend php artisan route:cache || true
docker compose exec -T backend php artisan view:cache || true

# Storage link
docker compose exec -T backend php artisan storage:link 2>/dev/null || true

echo "Deployment complete!"
ENDSSH

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your app is now running at:"
echo "  - http://${SERVER_IP}"
echo "  - API: http://${SERVER_IP}/api"
echo ""
echo "To import database:"
echo "  scp backup.sql ${SERVER_USER}@${SERVER_IP}:${REMOTE_PATH}/db-backups/"
echo "  ssh ${SERVER_USER}@${SERVER_IP} 'cd ${REMOTE_PATH} && ./scripts/db-import.sh db-backups/backup.sql'"
