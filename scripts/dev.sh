#!/bin/bash
#
# Start local development environment
#
# This script provides options for different development setups:
# 1. Full Docker stack (frontend + backend + db + nginx)
# 2. Hybrid mode (only db in Docker, frontend/backend native)
#
# Usage:
#   ./scripts/dev.sh              # Full Docker development
#   ./scripts/dev.sh hybrid       # Hybrid mode (recommended for fast iteration)
#   ./scripts/dev.sh stop         # Stop all services
#

set -e

MODE=${1:-docker}
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  HaubaBoss Development Environment${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

case $MODE in
    "docker")
        echo -e "${GREEN}Starting full Docker development stack...${NC}"
        echo ""
        
        # Stop any existing containers
        docker compose down 2>/dev/null || true
        
        # Start with dev overrides
        docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
        ;;
        
    "hybrid")
        echo -e "${GREEN}Starting hybrid development mode...${NC}"
        echo -e "${YELLOW}Database: Docker | Backend: Native | Frontend: Native${NC}"
        echo ""
        
        # Start only the database
        docker compose up -d db
        
        echo ""
        echo -e "${GREEN}Database started on localhost:3306${NC}"
        echo ""
        echo "Now run in separate terminals:"
        echo ""
        echo -e "  ${BLUE}Backend:${NC}"
        echo "    cd $PROJECT_ROOT/haubaboss-backend"
        echo "    php artisan serve --port=8000"
        echo ""
        echo -e "  ${BLUE}Frontend:${NC}"
        echo "    cd $PROJECT_ROOT/haubaboss-frontend"
        echo "    npm run dev"
        echo ""
        echo -e "  ${BLUE}Queue Worker (optional):${NC}"
        echo "    cd $PROJECT_ROOT/haubaboss-backend"
        echo "    php artisan queue:work"
        echo ""
        echo "Access the app at: http://localhost:3000"
        echo "API available at: http://localhost:8000/api/v1"
        ;;
        
    "stop")
        echo -e "${YELLOW}Stopping all services...${NC}"
        docker compose down
        
        # Kill any running PHP/Node processes (optional)
        pkill -f "php artisan serve" 2>/dev/null || true
        pkill -f "next dev" 2>/dev/null || true
        
        echo -e "${GREEN}All services stopped.${NC}"
        ;;
        
    *)
        echo "Usage: $0 [docker|hybrid|stop]"
        echo ""
        echo "Modes:"
        echo "  docker  - Full Docker stack with hot reload"
        echo "  hybrid  - Only DB in Docker, run frontend/backend natively"
        echo "  stop    - Stop all services"
        exit 1
        ;;
esac
