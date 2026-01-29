# HaubaBoss Database Workflow Guide

## How the Dockerized Database Works

```
┌─────────────────────────────────────────────────────────────────┐
│                     YOUR MACHINE (Local/Server)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │              Docker Container: haubaboss-db              │   │
│   │                                                          │   │
│   │   MySQL 8.0 Server                                       │   │
│   │   - Database: haubaboss_app                              │   │
│   │   - Port: 3306 (exposed to host)                         │   │
│   │                                                          │   │
│   │   Data stored in Docker Volume: mysql_data               │   │
│   │   (persists even if container is removed)                │   │
│   └─────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │              Docker Volume: mysql_data                   │   │
│   │              /var/lib/docker/volumes/...                 │   │
│   │                                                          │   │
│   │   ✅ Survives: docker compose down                       │   │
│   │   ✅ Survives: docker compose restart                    │   │
│   │   ✅ Survives: container rebuild                         │   │
│   │   ❌ Deleted:  docker compose down -v (with -v flag!)    │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## LOCAL Development Workflow

### First Time Setup

```bash
# 1. Navigate to project root
cd /Users/mopmop/haubaboss

# 2. Create your .env file
cp .env.example .env
# Edit .env with your passwords

# 3. Start everything
chmod +x scripts/*.sh
./scripts/start.sh

# 4. Import your existing database
./scripts/db-import.sh ./haubaboss-backend/haubaboss_app.sql
```

### Daily Development

```bash
# Start the stack (if not running)
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f backend

# Stop when done (data is preserved!)
docker compose down
```

### Connect with DB Tools (TablePlus, DBeaver, etc.)

```
Host: localhost (or 127.0.0.1)
Port: 3306
Database: haubaboss_app
Username: root
Password: [your DB_ROOT_PASSWORD from .env]
```

---

## SERVER Deployment Workflow

### First Time Server Setup

```bash
# 1. Clone your repo on server
git clone <your-repo> /var/www/haubaboss
cd /var/www/haubaboss

# 2. Create production .env
cp .env.example .env
nano .env  # Set strong passwords!

# 3. Start in production mode
./scripts/start.sh prod

# 4. Import database backup
./scripts/db-import.sh /path/to/your/backup.sql
```

### Server Updates

```bash
cd /var/www/haubaboss

# Pull latest code
git pull

# Rebuild containers if Dockerfile changed
docker compose up -d --build

# Run any new migrations
./scripts/migrate.sh
```

---

## Importing Data

### Method 1: Using the import script (Recommended)

```bash
# Import any SQL file
./scripts/db-import.sh /path/to/your/dump.sql

# Or use the default location
./scripts/db-import.sh ./haubaboss-backend/haubaboss_app.sql
```

### Method 2: Auto-import on first start

Place your SQL file in `db-init/` folder **before** first `docker compose up`:

```bash
cp your-backup.sql db-init/01-data.sql
docker compose up -d
# MySQL automatically imports files from db-init/ on first start
```

**Note**: Files in `db-init/` only run when the volume is empty (first time).

### Method 3: Direct MySQL CLI

```bash
# Get into MySQL CLI
docker compose exec db mysql -u root -p

# Then in MySQL:
USE haubaboss_app;
SOURCE /backups/your-file.sql;
```

---

## Exporting/Backing Up Data

```bash
# Create a backup (saved to db-backups/ folder)
./scripts/db-export.sh

# Or specify filename
./scripts/db-export.sh my-backup-2024.sql

# Backups are saved to: ./db-backups/
```

---

## Laravel Migrations Workflow

### How Migrations Work with Docker

When you modify or add migrations in Laravel, here's the workflow:

```
┌─────────────────────────────────────────────────────────────────┐
│  1. You create/edit migration file locally                       │
│     haubaboss-backend/database/migrations/xxxx_create_xxx.php   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Run migration command                                        │
│     ./scripts/migrate.sh                                         │
│                                                                  │
│     This executes inside the Docker container:                   │
│     docker compose exec backend php artisan migrate              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Laravel connects to Docker MySQL (db container)              │
│     - Checks 'migrations' table for what's already run           │
│     - Runs only NEW migrations                                   │
│     - Records them in 'migrations' table                         │
└─────────────────────────────────────────────────────────────────┘
```

### Common Migration Commands

```bash
# Run pending migrations
./scripts/migrate.sh

# Run migrations + seeders
./scripts/migrate.sh --seed

# Check migration status
./scripts/migrate.sh status

# Rollback last migration
./scripts/migrate.sh rollback

# Rollback all and re-run (DESTRUCTIVE - dev only!)
./scripts/migrate.sh fresh --seed

# Create a new migration
docker compose exec backend php artisan make:migration create_tenants_table
```

### Adding a New Migration

```bash
# 1. Create the migration
docker compose exec backend php artisan make:migration add_tenant_id_to_users_table

# 2. Edit the file in your IDE
#    haubaboss-backend/database/migrations/2024_xx_xx_xxxxxx_add_tenant_id_to_users_table.php

# 3. Run it
./scripts/migrate.sh

# 4. Commit to git
git add -A
git commit -m "Add tenant_id to users table"
```

### On Server After Code Update

```bash
# Pull latest code (includes new migration files)
git pull

# Run migrations - Laravel only runs NEW ones
./scripts/migrate.sh

# That's it! Existing data is preserved, new columns/tables are added
```

---

## Local vs Server: Key Differences

| Aspect | Local (Dev) | Server (Prod) |
|--------|-------------|---------------|
| Start command | `./scripts/start.sh` | `./scripts/start.sh prod` |
| APP_DEBUG | true | false |
| Config caching | No | Yes (faster) |
| DB Port exposed | Yes (3306) | Optional |
| Hot reload | Yes | No |

---

## Troubleshooting

### "Connection refused" to database

```bash
# Check if DB container is running
docker compose ps

# Check DB logs
docker compose logs db

# Restart DB
docker compose restart db
```

### "Access denied" for MySQL

```bash
# Verify your .env passwords match
cat .env | grep DB_

# Try connecting as root
docker compose exec db mysql -u root -p
```

### Migration fails

```bash
# Check migration status
./scripts/migrate.sh status

# Check Laravel logs
docker compose exec backend cat storage/logs/laravel.log | tail -50
```

### Reset everything (NUCLEAR OPTION - deletes all data!)

```bash
# Stop and remove everything including volumes
docker compose down -v

# Start fresh
./scripts/start.sh
```

---

## Database Sync Between Local and Server

### Overview

Your local Mac has a MySQL database with real data. The production server has a Docker MySQL. Here's how to keep them in sync.

### Sync Commands

```bash
# Compare row counts between local and production
./scripts/db-sync.sh compare

# Validate table structures match
./scripts/db-sync.sh validate

# Export local database to backup file
./scripts/db-sync.sh export

# Push local database to production (DESTRUCTIVE)
./scripts/db-sync.sh push

# Pull production database to local (DESTRUCTIVE)
./scripts/db-sync.sh pull
```

### Validation

```bash
# Validate local database integrity
cd haubaboss-backend
php artisan db:validate

# On production (via Docker)
docker compose exec backend php artisan db:validate
```

### Recommended Workflow

1. **Before deploying new features:**
   ```bash
   ./scripts/db-sync.sh compare    # Check differences
   ./scripts/db-sync.sh validate   # Ensure structures match
   ```

2. **After adding migrations locally:**
   ```bash
   # Run migrations locally first
   php artisan migrate
   
   # Then on production
   docker compose exec backend php artisan migrate
   ```

3. **To sync data from local to production:**
   ```bash
   ./scripts/db-sync.sh push       # Requires confirmation
   ```

4. **To sync data from production to local:**
   ```bash
   ./scripts/db-sync.sh pull       # Requires confirmation
   ```

### Seeders

For fresh database setup, use seeders instead of SQL dumps:

```bash
# Run all seeders
php artisan db:seed

# Run specific seeder
php artisan db:seed --class=ManufacturerSeeder
php artisan db:seed --class=MainCategorySeeder
php artisan db:seed --class=SubcategorySeeder

# Fresh migration + seed (DESTRUCTIVE)
php artisan migrate:fresh --seed
```

Available seeders:
- `CompanySeeder` - Creates test companies
- `ZeusUserSeeder` - Creates admin users
- `ManufacturerSeeder` - Creates vehicle manufacturers (BMW, Audi, etc.)
- `MainCategorySeeder` - Creates parts categories
- `SubcategorySeeder` - Creates subcategories

---

## Quick Reference

```bash
# Start
./scripts/start.sh

# Stop (keeps data)
docker compose down

# Import DB
./scripts/db-import.sh backup.sql

# Export DB
./scripts/db-export.sh

# Run migrations
./scripts/migrate.sh

# Validate database
php artisan db:validate

# Sync databases
./scripts/db-sync.sh compare
./scripts/db-sync.sh push
./scripts/db-sync.sh pull

# Shell into backend
docker compose exec backend sh

# MySQL CLI
docker compose exec db mysql -u root -p

# View logs
docker compose logs -f
```
