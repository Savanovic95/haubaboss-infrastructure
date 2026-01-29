#!/bin/bash
set -e

# ===========================================
# Deploy HaubaBoss to Server
# ===========================================
# This script deploys the full stack:
# 1. Syncs infrastructure repo to server
# 2. Pulls latest frontend and backend from their repos
# 3. Builds and starts Docker containers
# 4. Runs migrations
#
# Usage: ./scripts/deploy.sh
#        ./scripts/deploy.sh --skip-sync   # Skip local sync, just pull on server

SERVER_IP="89.167.24.255"
SERVER_USER="root"
REMOTE_PATH="/var/www/haubaboss"
SSH_KEY="~/.ssh/id_ed25519"

# GitHub repos
FRONTEND_REPO="git@github.com:Savanovic95/haubaboss-frontend.git"
BACKEND_REPO="git@github.com:Savanovic95/haubaboss-backend.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SKIP_SYNC=false
if [ "$1" == "--skip-sync" ]; then
    SKIP_SYNC=true
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Deploying HaubaBoss to Server${NC}"
echo -e "${BLUE}   Server: ${SERVER_IP}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check SSH connection
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ! ssh -i $SSH_KEY -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_IP} "echo 'Connected'" 2>/dev/null; then
    echo -e "${RED}Cannot connect to server. Check:${NC}"
    echo "  - SSH key is set up"
    echo "  - Server IP is correct"
    echo "  - Server is running"
    exit 1
fi

echo -e "${GREEN}SSH connection OK${NC}"
echo ""

# Sync infrastructure files (if not skipped)
if [ "$SKIP_SYNC" = false ]; then
    echo -e "${YELLOW}Syncing infrastructure files to server...${NC}"
    rsync -avz --progress \
        -e "ssh -i $SSH_KEY" \
        --exclude 'haubaboss-frontend' \
        --exclude 'haubaboss-backend' \
        --exclude '.git' \
        --exclude '.env' \
        --exclude 'db-backups/*.sql' \
        --exclude '.DS_Store' \
        ./ ${SERVER_USER}@${SERVER_IP}:${REMOTE_PATH}/

    echo -e "${GREEN}Infrastructure files synced!${NC}"
    echo ""
fi

# Run deployment commands on server
echo -e "${YELLOW}Running deployment on server...${NC}"
ssh -i $SSH_KEY ${SERVER_USER}@${SERVER_IP} << ENDSSH
set -e
cd /var/www/haubaboss

# Make scripts executable
chmod +x scripts/*.sh

# Check if .env exists
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "⚠️  Please edit /var/www/haubaboss/.env with production values!"
fi

echo ""
echo "=========================================="
echo "  Pulling Frontend Repository"
echo "=========================================="
if [ -d "haubaboss-frontend/.git" ]; then
    cd haubaboss-frontend
    git fetch origin
    git reset --hard origin/main
    cd ..
else
    echo "Cloning frontend repository..."
    rm -rf haubaboss-frontend
    git clone ${FRONTEND_REPO} haubaboss-frontend
fi

echo ""
echo "=========================================="
echo "  Pulling Backend Repository"
echo "=========================================="
if [ -d "haubaboss-backend/.git" ]; then
    cd haubaboss-backend
    git fetch origin
    git reset --hard origin/main
    cd ..
else
    echo "Cloning backend repository..."
    rm -rf haubaboss-backend
    git clone ${BACKEND_REPO} haubaboss-backend
fi

echo ""
echo "=========================================="
echo "  Building and Starting Containers"
echo "=========================================="

# Get API URL from .env
source .env
API_URL=\${NEXT_PUBLIC_API_URL:-http://${SERVER_IP}}

# Build frontend with correct API URL
docker compose build frontend --build-arg NEXT_PUBLIC_API_URL=\$API_URL --build-arg API_URL=http://nginx

# Build backend
docker compose build backend

# Start all containers
docker compose up -d

# Wait for DB to be healthy
echo "Waiting for database..."
sleep 10

echo ""
echo "=========================================="
echo "  Running Migrations"
echo "=========================================="
docker compose exec -T backend php artisan migrate --force || true

echo ""
echo "=========================================="
echo "  Caching Laravel Config"
echo "=========================================="
docker compose exec -T backend php artisan config:cache || true
docker compose exec -T backend php artisan route:cache || true
docker compose exec -T backend php artisan view:cache || true
docker compose exec -T backend php artisan storage:link 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Running API Smoke Test"
echo "=========================================="
./scripts/test-api.sh http://localhost || echo "Some tests failed, check logs"

echo ""
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
