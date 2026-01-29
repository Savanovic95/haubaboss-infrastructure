#!/bin/bash
set -e

# ===========================================
# HaubaBoss Server Setup Script
# ===========================================
# Run this on a fresh Ubuntu 22.04 server
# Usage: curl -sSL <url> | bash
# Or: bash server-setup.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   HaubaBoss Server Setup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo bash server-setup.sh)${NC}"
    exit 1
fi

# Update system
echo -e "${YELLOW}[1/7] Updating system packages...${NC}"
apt-get update && apt-get upgrade -y

# Install required packages
echo -e "${YELLOW}[2/7] Installing required packages...${NC}"
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    ufw \
    fail2ban \
    htop \
    unzip

# Install Docker
echo -e "${YELLOW}[3/7] Installing Docker...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "Docker already installed"
fi

# Install Docker Compose
echo -e "${YELLOW}[4/7] Installing Docker Compose...${NC}"
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "Docker Compose already installed"
fi

# Configure firewall
echo -e "${YELLOW}[5/7] Configuring firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# Configure fail2ban
echo -e "${YELLOW}[6/7] Configuring fail2ban...${NC}"
systemctl enable fail2ban
systemctl start fail2ban

# Create app directory
echo -e "${YELLOW}[7/7] Creating application directory...${NC}"
mkdir -p /var/www/haubaboss
chown -R $SUDO_USER:$SUDO_USER /var/www/haubaboss 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Server setup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Clone your repo:"
echo "   cd /var/www/haubaboss"
echo "   git clone <your-repo-url> ."
echo ""
echo "2. Configure environment:"
echo "   cp .env.example .env"
echo "   nano .env  # Set your passwords"
echo ""
echo "3. Start the application:"
echo "   ./scripts/start.sh prod"
echo ""
echo "4. Import your database:"
echo "   ./scripts/db-import.sh /path/to/backup.sql"
echo ""
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"
