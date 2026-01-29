# HaubaBoss - Production Deployment Guide

Complete guide for deploying and managing HaubaBoss in production.

---

## Table of Contents

1. [Server Requirements](#server-requirements)
2. [Initial Server Setup](#initial-server-setup)
3. [Deployment](#deployment)
4. [Environment Configuration](#environment-configuration)
5. [SSL/HTTPS Setup](#sslhttps-setup)
6. [Database Management](#database-management)
7. [Monitoring & Logs](#monitoring--logs)
8. [Backup & Recovery](#backup--recovery)
9. [Scaling](#scaling)
10. [Troubleshooting](#troubleshooting)
11. [Security Checklist](#security-checklist)

---

## Server Requirements

### Minimum Specifications

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4 cores |
| RAM | 2 GB | 4 GB |
| Storage | 20 GB SSD | 50 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

### Required Software

- Docker 24+
- Docker Compose 2+
- Git
- (Optional) Certbot for SSL

---

## Initial Server Setup

### 1. Create Server

Create a VPS on your preferred provider (Hetzner, DigitalOcean, AWS, etc.)

Current production server: `89.167.24.255`

### 2. Run Setup Script

```bash
# SSH into server
ssh root@YOUR_SERVER_IP

# Download and run setup script
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/scripts/server-setup.sh | bash

# Or manually:
apt update && apt upgrade -y
apt install -y docker.io docker-compose-v2 git curl
systemctl enable docker
systemctl start docker
```

### 3. Clone Repository

```bash
cd /var/www
git clone YOUR_REPO_URL haubaboss
cd haubaboss
```

### 4. Configure Environment

```bash
cp .env.example .env
nano .env
```

Edit the following values:

```bash
# CRITICAL: Change these!
APP_KEY=base64:GENERATE_NEW_KEY
DB_ROOT_PASSWORD=STRONG_PASSWORD_HERE
DB_PASSWORD=ANOTHER_STRONG_PASSWORD

# Set your domain/IP
APP_URL=http://YOUR_DOMAIN_OR_IP
NEXT_PUBLIC_API_URL=http://YOUR_DOMAIN_OR_IP
```

### 5. Deploy

```bash
./scripts/deploy.sh
```

---

## Deployment

### Standard Deployment

From your local machine:

```bash
./scripts/deploy.sh
```

This script:
1. Syncs code to server
2. Builds Docker images
3. Runs migrations
4. Restarts containers

### Manual Deployment

SSH into server and run:

```bash
cd /var/www/haubaboss

# Pull latest code
git pull origin main

# Build and restart
docker compose -f docker-compose.yml -f docker-compose.prod.yml build
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Run migrations
docker compose exec backend php artisan migrate --force

# Clear caches
docker compose exec backend php artisan optimize:clear
docker compose exec backend php artisan config:cache
docker compose exec backend php artisan route:cache
```

### Zero-Downtime Deployment

```bash
# Build new images without stopping
docker compose build

# Recreate containers one by one
docker compose up -d --no-deps --build frontend
docker compose up -d --no-deps --build backend

# Reload nginx
docker compose exec nginx nginx -s reload
```

### Rollback

```bash
# View previous images
docker images | grep haubaboss

# Rollback to previous version
git checkout HEAD~1
docker compose up -d --build
```

---

## Environment Configuration

### Production .env File

```bash
# ===========================================
# PRODUCTION ENVIRONMENT
# ===========================================

# Application
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:YOUR_GENERATED_KEY
APP_URL=https://yourdomain.com

# Database
DB_ROOT_PASSWORD=super_secure_root_password_123
DB_DATABASE=haubaboss_app
DB_USERNAME=haubaboss
DB_PASSWORD=super_secure_app_password_456
DB_PORT=3306

# Frontend
NEXT_PUBLIC_API_URL=https://yourdomain.com

# Optional: External services
# MAIL_MAILER=smtp
# MAIL_HOST=smtp.mailgun.org
# MAIL_PORT=587
# MAIL_USERNAME=
# MAIL_PASSWORD=
```

### Generate App Key

```bash
# On server
docker compose exec backend php artisan key:generate --show

# Copy the output and add to .env
```

### Verify Configuration

```bash
# Check all env vars are set
docker compose exec backend php artisan config:show

# Test database connection
docker compose exec backend php artisan db:show
```

---

## SSL/HTTPS Setup

### Option 1: Certbot (Let's Encrypt)

```bash
# Install certbot
apt install -y certbot

# Get certificate
certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# Certificates will be in:
# /etc/letsencrypt/live/yourdomain.com/fullchain.pem
# /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

### Option 2: Copy Existing Certificates

```bash
# Copy to nginx ssl directory
cp /path/to/fullchain.pem /var/www/haubaboss/nginx/ssl/
cp /path/to/privkey.pem /var/www/haubaboss/nginx/ssl/
```

### Update Nginx Config

Edit `nginx/conf.d/default.conf`:

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # ... rest of config
}
```

### Auto-Renewal

```bash
# Add to crontab
crontab -e

# Add this line (renews at 3am daily)
0 3 * * * certbot renew --quiet && docker compose -f /var/www/haubaboss/docker-compose.yml exec nginx nginx -s reload
```

---

## Database Management

### Access Database

```bash
# Via Docker
docker compose exec db mysql -u root -p haubaboss_app

# Direct connection (if port exposed)
mysql -h YOUR_SERVER_IP -P 3306 -u haubaboss -p haubaboss_app
```

### Run Migrations

```bash
# Standard migration
docker compose exec backend php artisan migrate --force

# Fresh migration (DESTROYS DATA)
docker compose exec backend php artisan migrate:fresh --seed --force
```

### Backup Database

```bash
# Manual backup
docker compose exec db mysqldump -u root -p haubaboss_app > backup_$(date +%Y%m%d).sql

# Using script
./scripts/db-export.sh
```

### Restore Database

```bash
# From backup file
cat backup.sql | docker compose exec -T db mysql -u root -p haubaboss_app

# Using script
./scripts/db-import.sh backup.sql
```

### Automated Backups

Add to crontab:

```bash
# Daily backup at 2am
0 2 * * * cd /var/www/haubaboss && ./scripts/db-export.sh >> /var/log/haubaboss-backup.log 2>&1

# Weekly cleanup (keep last 7 days)
0 3 * * 0 find /var/www/haubaboss/db-backups -mtime +7 -delete
```

---

## Monitoring & Logs

### View Logs

```bash
# All containers
docker compose logs -f

# Specific service
docker compose logs -f frontend
docker compose logs -f backend
docker compose logs -f nginx

# Last 100 lines
docker compose logs --tail=100 backend
```

### Laravel Logs

```bash
# View Laravel log
docker compose exec backend tail -f storage/logs/laravel.log

# Search for errors
docker compose exec backend grep -i error storage/logs/laravel.log
```

### Nginx Access Logs

```bash
# Access log
tail -f nginx/logs/access.log

# Error log
tail -f nginx/logs/error.log
```

### Health Check

```bash
# Check system health
curl http://YOUR_SERVER_IP/api/health | jq

# Run API smoke test
./scripts/test-api.sh http://YOUR_SERVER_IP
```

### Container Status

```bash
# View running containers
docker compose ps

# Resource usage
docker stats

# Disk usage
docker system df
```

### Set Up Monitoring (Optional)

For production, consider:
- **Uptime monitoring**: UptimeRobot, Pingdom
- **Error tracking**: Sentry
- **Log aggregation**: Papertrail, Logtail
- **Metrics**: Prometheus + Grafana

---

## Backup & Recovery

### Full Backup Strategy

```bash
#!/bin/bash
# scripts/full-backup.sh

BACKUP_DIR="/var/www/haubaboss/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Database
docker compose exec -T db mysqldump -u root -p$DB_ROOT_PASSWORD haubaboss_app > $BACKUP_DIR/database.sql

# Uploaded files
cp -r haubaboss-backend/storage/app/public $BACKUP_DIR/uploads

# Environment
cp .env $BACKUP_DIR/env.backup

# Compress
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

echo "Backup created: $BACKUP_DIR.tar.gz"
```

### Disaster Recovery

```bash
# 1. Restore database
cat backup/database.sql | docker compose exec -T db mysql -u root -p haubaboss_app

# 2. Restore uploads
cp -r backup/uploads/* haubaboss-backend/storage/app/public/

# 3. Restore environment
cp backup/env.backup .env

# 4. Restart services
docker compose down
docker compose up -d
```

### Off-Site Backup

```bash
# Sync to remote storage (example: rsync to backup server)
rsync -avz /var/www/haubaboss/backups/ backup-server:/backups/haubaboss/

# Or use S3
aws s3 sync /var/www/haubaboss/backups/ s3://your-bucket/haubaboss-backups/
```

---

## Scaling

### Vertical Scaling

Upgrade server resources (CPU, RAM, Storage)

### Horizontal Scaling

For high traffic, consider:

1. **Load Balancer**: Put nginx on separate server
2. **Multiple App Servers**: Run multiple backend containers
3. **Database Replication**: MySQL read replicas
4. **CDN**: CloudFlare for static assets

### Docker Swarm / Kubernetes

For enterprise scale:

```yaml
# docker-compose.prod.yml with replicas
services:
  backend:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs backend

# Check container status
docker compose ps

# Inspect container
docker inspect haubaboss-backend
```

### 502 Bad Gateway

```bash
# Check if backend is running
docker compose ps backend

# Check nginx can reach backend
docker compose exec nginx ping backend

# Check PHP-FPM is listening
docker compose exec backend ps aux | grep php-fpm
```

### Database Connection Failed

```bash
# Check database is running
docker compose ps db

# Test connection from backend
docker compose exec backend php artisan db:show

# Check credentials
docker compose exec backend cat .env | grep DB_
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean Docker
docker system prune -a

# Remove old logs
truncate -s 0 nginx/logs/*.log
docker compose exec backend truncate -s 0 storage/logs/laravel.log
```

### High Memory Usage

```bash
# Check container memory
docker stats

# Restart specific service
docker compose restart backend

# Check for memory leaks in logs
docker compose logs backend | grep -i memory
```

### SSL Certificate Issues

```bash
# Check certificate expiry
openssl x509 -enddate -noout -in nginx/ssl/fullchain.pem

# Renew certificate
certbot renew

# Reload nginx
docker compose exec nginx nginx -s reload
```

---

## Security Checklist

### Before Going Live

- [ ] Change all default passwords in `.env`
- [ ] Generate new `APP_KEY`
- [ ] Set `APP_DEBUG=false`
- [ ] Set `APP_ENV=production`
- [ ] Enable HTTPS
- [ ] Configure firewall (only ports 80, 443, 22)
- [ ] Set up automated backups
- [ ] Remove test accounts or change passwords
- [ ] Review and restrict CORS settings
- [ ] Enable rate limiting

### Firewall Setup

```bash
# UFW (Ubuntu)
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw enable
```

### Regular Maintenance

- [ ] Weekly: Review logs for errors
- [ ] Weekly: Check disk space
- [ ] Monthly: Update system packages
- [ ] Monthly: Review and rotate backups
- [ ] Quarterly: Update Docker images
- [ ] Quarterly: Review security advisories

### Update System

```bash
# Update packages
apt update && apt upgrade -y

# Update Docker images
docker compose pull
docker compose up -d
```

---

## Quick Reference

### SSH Access

```bash
ssh root@89.167.24.255
```

### Common Commands

```bash
# Deploy
./scripts/deploy.sh

# View logs
docker compose logs -f

# Restart all
docker compose restart

# Run migrations
docker compose exec backend php artisan migrate --force

# Clear caches
docker compose exec backend php artisan optimize:clear

# Backup database
./scripts/db-export.sh

# Test API
./scripts/test-api.sh http://89.167.24.255
```

### Important Paths

| Path | Description |
|------|-------------|
| `/var/www/haubaboss` | Application root |
| `/var/www/haubaboss/.env` | Environment config |
| `/var/www/haubaboss/nginx/logs` | Nginx logs |
| `/var/www/haubaboss/db-backups` | Database backups |

### Ports

| Port | Service |
|------|---------|
| 80 | HTTP (nginx) |
| 443 | HTTPS (nginx) |
| 3306 | MySQL (internal only) |
| 3000 | Frontend (internal only) |
| 9000 | PHP-FPM (internal only) |

---

## Emergency Contacts

- **Server Provider**: Hetzner
- **Domain Registrar**: (your registrar)
- **SSL Provider**: Let's Encrypt

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-29 | Initial production deployment |
