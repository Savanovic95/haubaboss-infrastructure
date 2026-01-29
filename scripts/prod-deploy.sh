#!/bin/bash
#
# HaubaBoss Production Deployment - Single Command Setup
# ======================================================
# Run this on a fresh server to deploy the entire stack.
# Just clone the infrastructure repo and run this script.
#
# Usage (on server):
#   git clone git@github.com:Savanovic95/haubaboss-infrastructure.git /var/www/haubaboss
#   cd /var/www/haubaboss
#   ./scripts/prod-deploy.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "$PROJECT_DIR"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           HaubaBoss Production Deployment                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ===========================================
# Step 1: Check Prerequisites
# ===========================================
echo -e "${BLUE}[1/8]${NC} Checking prerequisites..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        echo "Installing $1..."
        case $1 in
            docker)
                curl -fsSL https://get.docker.com | sh
                systemctl enable docker
                systemctl start docker
                ;;
            git)
                apt-get update && apt-get install -y git
                ;;
            *)
                echo "Please install $1 manually"
                exit 1
                ;;
        esac
    fi
}

check_command docker
check_command git

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${YELLOW}Starting Docker...${NC}"
    systemctl start docker || service docker start
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"

# ===========================================
# Step 2: Clone repositories
# ===========================================
echo -e "${BLUE}[2/8]${NC} Setting up repositories..."

if [ ! -d "haubaboss-frontend/.git" ]; then
    echo -e "${YELLOW}Cloning frontend repository...${NC}"
    rm -rf haubaboss-frontend
    git clone git@github.com:Savanovic95/haubaboss-frontend.git haubaboss-frontend
else
    echo -e "${YELLOW}Updating frontend repository...${NC}"
    cd haubaboss-frontend
    git fetch origin
    git reset --hard origin/main
    cd ..
fi

if [ ! -d "haubaboss-backend/.git" ]; then
    echo -e "${YELLOW}Cloning backend repository...${NC}"
    rm -rf haubaboss-backend
    git clone git@github.com:Savanovic95/haubaboss-backend.git haubaboss-backend
else
    echo -e "${YELLOW}Updating backend repository...${NC}"
    cd haubaboss-backend
    git fetch origin
    git reset --hard origin/main
    cd ..
fi

echo -e "${GREEN}✓ Repositories OK${NC}"

# ===========================================
# Step 3: Setup environment
# ===========================================
echo -e "${BLUE}[3/8]${NC} Setting up environment..."

if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating production .env...${NC}"
    
    # Generate secure passwords
    DB_ROOT_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    DB_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    cat > .env << EOF
# Database (auto-generated secure passwords)
DB_ROOT_PASSWORD=${DB_ROOT_PASS}
DB_DATABASE=haubaboss_app
DB_USERNAME=haubaboss
DB_PASSWORD=${DB_PASS}
DB_PORT=3306

# App
APP_ENV=production
APP_DEBUG=false

# API URLs
NEXT_PUBLIC_API_URL=http://${SERVER_IP}
API_URL=http://nginx
EOF

    echo -e "${GREEN}✓ Created .env with secure passwords${NC}"
    echo -e "${YELLOW}⚠ Save these credentials:${NC}"
    echo -e "  DB Root Password: ${DB_ROOT_PASS}"
    echo -e "  DB User Password: ${DB_PASS}"
fi

# Backend .env
if [ ! -f "haubaboss-backend/.env" ]; then
    echo -e "${YELLOW}Creating backend .env...${NC}"
    source .env
    
    if [ -f "haubaboss-backend/.env.example" ]; then
        cp haubaboss-backend/.env.example haubaboss-backend/.env
    fi
    
    # Generate app key
    APP_KEY=$(openssl rand -base64 32)
    
    # Update settings
    sed -i "s|APP_KEY=.*|APP_KEY=base64:${APP_KEY}|" haubaboss-backend/.env
    sed -i "s|APP_ENV=.*|APP_ENV=production|" haubaboss-backend/.env
    sed -i "s|APP_DEBUG=.*|APP_DEBUG=false|" haubaboss-backend/.env
    sed -i "s|DB_HOST=.*|DB_HOST=db|" haubaboss-backend/.env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_DATABASE}|" haubaboss-backend/.env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USERNAME}|" haubaboss-backend/.env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" haubaboss-backend/.env
fi

# Frontend .env.local
if [ ! -f "haubaboss-frontend/.env.local" ]; then
    source .env
    cat > haubaboss-frontend/.env.local << EOF
NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}
API_URL=http://nginx
EOF
fi

echo -e "${GREEN}✓ Environment configured${NC}"

# ===========================================
# Step 4: Build containers
# ===========================================
echo -e "${BLUE}[4/8]${NC} Building Docker containers..."

source .env

docker compose build \
    --build-arg NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL} \
    --build-arg API_URL=http://nginx

echo -e "${GREEN}✓ Containers built${NC}"

# ===========================================
# Step 5: Start containers
# ===========================================
echo -e "${BLUE}[5/8]${NC} Starting containers..."

docker compose up -d

echo -e "${GREEN}✓ Containers started${NC}"

# ===========================================
# Step 6: Wait for database
# ===========================================
echo -e "${BLUE}[6/8]${NC} Waiting for database..."

source .env
MAX_TRIES=60
TRIES=0
until docker compose exec -T db mysqladmin ping -h localhost -u root -p${DB_ROOT_PASSWORD} --silent 2>/dev/null; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo -e "${RED}Database failed to start${NC}"
        docker compose logs db
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""

echo -e "${GREEN}✓ Database ready${NC}"

# ===========================================
# Step 7: Run migrations and seed
# ===========================================
echo -e "${BLUE}[7/8]${NC} Running migrations..."

sleep 5
docker compose exec -T backend php artisan migrate --force

# Check if seeding needed
USER_COUNT=$(docker compose exec -T db mysql -u root -p${DB_ROOT_PASSWORD} haubaboss_app -N -e "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")

if [ "$USER_COUNT" = "0" ]; then
    echo -e "${YELLOW}Seeding database...${NC}"
    docker compose exec -T backend php artisan db:seed --force
fi

echo -e "${GREEN}✓ Database ready${NC}"

# ===========================================
# Step 8: Cache and optimize
# ===========================================
echo -e "${BLUE}[8/8]${NC} Optimizing for production..."

docker compose exec -T backend php artisan config:cache
docker compose exec -T backend php artisan route:cache
docker compose exec -T backend php artisan view:cache
docker compose exec -T backend php artisan storage:link 2>/dev/null || true

echo -e "${GREEN}✓ Optimization complete${NC}"

# ===========================================
# Done!
# ===========================================
source .env
SERVER_IP=$(echo $NEXT_PUBLIC_API_URL | sed 's|http://||' | sed 's|https://||')

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Production Deployment Complete!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Website:${NC}   http://${SERVER_IP}"
echo -e "  ${CYAN}API:${NC}       http://${SERVER_IP}/api"
echo ""
echo -e "  ${YELLOW}Test accounts:${NC}"
echo -e "    Zeus:    zeus@haubaboss.com / zeus123456"
echo -e "    Admin:   admin@testcompany.com / admin123456"
echo ""
echo -e "  ${YELLOW}Management commands:${NC}"
echo -e "    docker compose logs -f     # View logs"
echo -e "    docker compose restart     # Restart all"
echo -e "    docker compose down        # Stop all"
echo ""
