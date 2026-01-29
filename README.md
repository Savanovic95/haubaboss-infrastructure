# HaubaBoss Infrastructure

Docker infrastructure, deployment scripts, and documentation for the HaubaBoss application.

## Quick Start Commands

### 1. Local Development (Single Command)

```bash
./scripts/dev-start.sh
```

This handles everything:
- Clones frontend/backend repos if missing
- Creates `.env` files if missing
- Starts all Docker containers
- Waits for database
- Runs migrations
- Seeds database if empty

**Result:** App running at http://localhost:3000

---

### 2. Production Deployment (Single Command)

On a fresh server:

```bash
# Clone infrastructure repo
git clone git@github.com:Savanovic95/haubaboss-infrastructure.git /var/www/haubaboss
cd /var/www/haubaboss

# Deploy everything
./scripts/prod-deploy.sh
```

This handles everything:
- Installs Docker if missing
- Clones frontend/backend repos
- Generates secure passwords
- Builds and starts containers
- Runs migrations and seeds
- Caches Laravel config

**Result:** App running at http://YOUR_SERVER_IP

---

### 3. Sync Database from Local Mac

```bash
# Sync to local Docker containers
./scripts/db-sync-from-local.sh local

# Sync to production server (DESTRUCTIVE!)
./scripts/db-sync-from-local.sh production
```

This syncs your local Mac MySQL database to the target.

---

### 4. Backup Production Database

```bash
# Backup to db-backups/ folder
./scripts/db-backup-prod.sh

# Backup to specific folder
./scripts/db-backup-prod.sh ~/Desktop
```

Downloads production database to your local machine.

---

## Repository Structure

```
haubaboss/                    # This repo (infrastructure)
├── docker-compose.yml        # Main Docker config
├── docker-compose.dev.yml    # Development overrides
├── docker-compose.prod.yml   # Production overrides
├── nginx/                    # Nginx configuration
├── scripts/                  # All utility scripts
│   ├── dev-start.sh         # Local development setup
│   ├── prod-deploy.sh       # Production deployment
│   ├── db-sync-from-local.sh # Sync DB from Mac
│   ├── db-backup-prod.sh    # Backup production DB
│   └── ...
├── haubaboss-frontend/       # Next.js frontend (separate repo)
└── haubaboss-backend/        # Laravel backend (separate repo)
```

## Test Accounts

| Role | Email | Password |
|------|-------|----------|
| Zeus | zeus@haubaboss.com | zeus123456 |
| Admin | admin@testcompany.com | admin123456 |
| Manager | manager@testcompany.com | manager123456 |
| Worker | worker@testcompany.com | worker123456 |

## CI/CD

GitHub Actions automatically deploys on push to `main`:

- **Frontend repo** → Deploys frontend container
- **Backend repo** → Runs tests, deploys backend container
- **Infrastructure repo** → Deploys full stack

See [CICD_SETUP.md](CICD_SETUP.md) for setup instructions.

## Documentation

- [LOCAL_DEV.md](LOCAL_DEV.md) - Detailed local development guide
- [PRODUCTION.md](PRODUCTION.md) - Production deployment guide
- [DB_WORKFLOW.md](DB_WORKFLOW.md) - Database management guide
- [CICD_SETUP.md](CICD_SETUP.md) - CI/CD setup guide

## Common Commands

```bash
# View logs
docker compose logs -f

# Restart all containers
docker compose restart

# Stop all containers
docker compose down

# Rebuild and restart
docker compose up -d --build

# Run migrations
docker compose exec backend php artisan migrate

# Run seeders
docker compose exec backend php artisan db:seed

# Validate database
docker compose exec backend php artisan db:validate

# Shell into backend
docker compose exec backend sh

# MySQL CLI
docker compose exec db mysql -u root -p
```
