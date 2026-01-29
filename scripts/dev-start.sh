#!/bin/bash
#
# HaubaBoss Local Development - Single Command Setup
# ==================================================
# This script handles ALL edge cases for local development:
# - First time setup (clones repos, creates .env, seeds DB)
# - Subsequent runs (just starts containers)
# - New migrations (runs them automatically)
# - New seeders (runs them if DB is empty)
#
# Usage: ./scripts/dev-start.sh
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
echo "║           HaubaBoss Local Development Setup                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ===========================================
# Step 1: Check Prerequisites
# ===========================================
echo -e "${BLUE}[1/7]${NC} Checking prerequisites..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        echo "Please install $1 and try again"
        exit 1
    fi
}

check_command docker
check_command git

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"

# ===========================================
# Step 2: Clone repos if missing
# ===========================================
echo -e "${BLUE}[2/7]${NC} Checking repositories..."

FIRST_TIME=false

if [ ! -d "haubaboss-frontend" ]; then
    echo -e "${YELLOW}Cloning frontend repository...${NC}"
    git clone git@github.com:Savanovic95/haubaboss-frontend.git haubaboss-frontend
    FIRST_TIME=true
fi

if [ ! -d "haubaboss-backend" ]; then
    echo -e "${YELLOW}Cloning backend repository...${NC}"
    git clone git@github.com:Savanovic95/haubaboss-backend.git haubaboss-backend
    FIRST_TIME=true
fi

echo -e "${GREEN}✓ Repositories OK${NC}"

# ===========================================
# Step 3: Setup environment files
# ===========================================
echo -e "${BLUE}[3/7]${NC} Checking environment files..."

# Main .env
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${YELLOW}⚠ Please review .env and update passwords if needed${NC}"
    else
        cat > .env << 'EOF'
# Database
DB_ROOT_PASSWORD=rootpassword
DB_DATABASE=haubaboss_app
DB_USERNAME=haubaboss
DB_PASSWORD=haubaboss123
DB_PORT=3306

# App
APP_ENV=local
APP_DEBUG=true

# API URLs
NEXT_PUBLIC_API_URL=http://localhost
API_URL=http://nginx
EOF
    fi
    FIRST_TIME=true
fi

# Backend .env
if [ ! -f "haubaboss-backend/.env" ]; then
    echo -e "${YELLOW}Creating backend .env...${NC}"
    if [ -f "haubaboss-backend/.env.example" ]; then
        cp haubaboss-backend/.env.example haubaboss-backend/.env
    fi
    # Update DB settings for Docker
    if [ -f "haubaboss-backend/.env" ]; then
        sed -i.bak 's/DB_HOST=.*/DB_HOST=db/' haubaboss-backend/.env 2>/dev/null || \
        sed -i '' 's/DB_HOST=.*/DB_HOST=db/' haubaboss-backend/.env
        sed -i.bak 's/DB_DATABASE=.*/DB_DATABASE=haubaboss_app/' haubaboss-backend/.env 2>/dev/null || \
        sed -i '' 's/DB_DATABASE=.*/DB_DATABASE=haubaboss_app/' haubaboss-backend/.env
        sed -i.bak 's/DB_USERNAME=.*/DB_USERNAME=haubaboss/' haubaboss-backend/.env 2>/dev/null || \
        sed -i '' 's/DB_USERNAME=.*/DB_USERNAME=haubaboss/' haubaboss-backend/.env
        sed -i.bak 's/DB_PASSWORD=.*/DB_PASSWORD=haubaboss123/' haubaboss-backend/.env 2>/dev/null || \
        sed -i '' 's/DB_PASSWORD=.*/DB_PASSWORD=haubaboss123/' haubaboss-backend/.env
        rm -f haubaboss-backend/.env.bak
    fi
    FIRST_TIME=true
fi

# Frontend .env.local
if [ ! -f "haubaboss-frontend/.env.local" ]; then
    echo -e "${YELLOW}Creating frontend .env.local...${NC}"
    cat > haubaboss-frontend/.env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost
API_URL=http://nginx
EOF
    FIRST_TIME=true
fi

echo -e "${GREEN}✓ Environment files OK${NC}"

# ===========================================
# Step 4: Start Docker containers
# ===========================================
echo -e "${BLUE}[4/7]${NC} Starting Docker containers..."

# Use dev compose file if exists
if [ -f "docker-compose.dev.yml" ]; then
    docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
else
    docker compose up -d --build
fi

echo -e "${GREEN}✓ Containers started${NC}"

# ===========================================
# Step 5: Wait for database
# ===========================================
echo -e "${BLUE}[5/7]${NC} Waiting for database to be ready..."

MAX_TRIES=30
TRIES=0
until docker compose exec -T db mysqladmin ping -h localhost -u root -prootpassword --silent 2>/dev/null; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -ge $MAX_TRIES ]; then
        echo -e "${RED}Database failed to start after ${MAX_TRIES} attempts${NC}"
        echo "Check logs with: docker compose logs db"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""

echo -e "${GREEN}✓ Database ready${NC}"

# ===========================================
# Step 6: Run migrations
# ===========================================
echo -e "${BLUE}[6/7]${NC} Running database migrations..."

docker compose exec -T backend php artisan migrate --force 2>/dev/null || {
    echo -e "${YELLOW}Waiting for backend to be ready...${NC}"
    sleep 5
    docker compose exec -T backend php artisan migrate --force
}

echo -e "${GREEN}✓ Migrations complete${NC}"

# ===========================================
# Step 7: Seed database if needed
# ===========================================
echo -e "${BLUE}[7/7]${NC} Checking if database needs seeding..."

# Check if users table is empty
USER_COUNT=$(docker compose exec -T db mysql -u root -prootpassword haubaboss_app -N -e "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "0")

if [ "$USER_COUNT" = "0" ] || [ "$FIRST_TIME" = true ]; then
    echo -e "${YELLOW}Seeding database...${NC}"
    docker compose exec -T backend php artisan db:seed --force || true
    echo -e "${GREEN}✓ Database seeded${NC}"
else
    echo -e "${GREEN}✓ Database already has data (${USER_COUNT} users)${NC}"
fi

# ===========================================
# Done!
# ===========================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Development Environment Ready!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Frontend:${NC}  http://localhost:3000"
echo -e "  ${CYAN}Backend:${NC}   http://localhost/api"
echo -e "  ${CYAN}Database:${NC}  localhost:3306 (user: haubaboss, pass: haubaboss123)"
echo ""
echo -e "  ${YELLOW}Useful commands:${NC}"
echo -e "    docker compose logs -f          # View all logs"
echo -e "    docker compose logs -f frontend # View frontend logs"
echo -e "    docker compose logs -f backend  # View backend logs"
echo -e "    docker compose down             # Stop all containers"
echo ""
echo -e "  ${YELLOW}Test accounts:${NC}"
echo -e "    Zeus:    zeus@haubaboss.com / zeus123456"
echo -e "    Admin:   admin@testcompany.com / admin123456"
echo ""
