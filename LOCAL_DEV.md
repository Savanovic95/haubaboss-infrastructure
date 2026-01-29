# HaubaBoss - Local Development Guide

This guide covers everything you need to develop HaubaBoss locally. Follow it step by step.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Development Modes](#development-modes)
4. [Frontend Development](#frontend-development)
5. [Backend Development](#backend-development)
6. [Database](#database)
7. [Queue Workers](#queue-workers)
8. [Testing](#testing)
9. [Debugging](#debugging)
10. [Common Issues](#common-issues)

---

## Prerequisites

### Required Software

| Software | Version | Check Command |
|----------|---------|---------------|
| Node.js | 20+ | `node --version` |
| npm | 10+ | `npm --version` |
| PHP | 8.2+ | `php --version` |
| Composer | 2+ | `composer --version` |
| Docker | 24+ | `docker --version` |
| Docker Compose | 2+ | `docker compose version` |
| MySQL | 8.0 | `mysql --version` (optional if using Docker) |

### Install on macOS

```bash
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install node@20 php@8.2 composer mysql docker

# Start Docker Desktop
open -a Docker
```

---

## Quick Start

### Option 1: Full Docker (Recommended for first-time setup)

```bash
# Clone and enter project
cd ~/haubaboss

# Copy environment file
cp .env.example .env

# Start everything
./scripts/dev.sh docker
```

Access at: **http://localhost**

### Option 2: Hybrid Mode (Recommended for daily development)

```bash
# Start only database in Docker
./scripts/dev.sh hybrid

# In Terminal 1: Backend
cd haubaboss-backend
cp .env.example .env  # First time only
php artisan serve --port=8000

# In Terminal 2: Frontend
cd haubaboss-frontend
cp .env.local.example .env.local  # First time only
npm install  # First time only
npm run dev

# In Terminal 3: Queue Worker (optional)
cd haubaboss-backend
php artisan queue:work
```

Access at: **http://localhost:3000**

---

## Development Modes

### Full Docker Mode

**Best for:** Initial setup, testing production-like environment, CI/CD

```bash
./scripts/dev.sh docker
```

| Service | URL | Notes |
|---------|-----|-------|
| Frontend | http://localhost | Via nginx |
| Backend API | http://localhost/api/v1 | Via nginx |
| Database | localhost:3306 | Direct access |

**Pros:**
- Matches production environment
- No local PHP/Node installation needed
- Isolated from system

**Cons:**
- Slower hot reload
- More resource intensive

### Hybrid Mode

**Best for:** Daily development, fast iteration

```bash
./scripts/dev.sh hybrid
```

| Service | URL | Notes |
|---------|-----|-------|
| Frontend | http://localhost:3000 | Next.js dev server |
| Backend API | http://localhost:8000/api/v1 | PHP artisan serve |
| Database | localhost:3306 | Docker MySQL |

**Pros:**
- Instant hot reload
- Native debugging tools
- Less resource usage

**Cons:**
- Requires local PHP/Node
- Slightly different from production

---

## Frontend Development

### Directory Structure

```
haubaboss-frontend/
├── app/                    # Next.js App Router
│   ├── (auth)/            # Auth pages (login, signup)
│   ├── (root)/            # Protected pages (dashboard, etc.)
│   ├── actions/           # Server Actions
│   ├── api/               # API routes
│   └── types/             # TypeScript types
├── components/            # React components
├── lib/                   # Utilities
│   ├── api.ts            # API base URL helper
│   ├── api-client.ts     # Centralized API client
│   ├── logger.ts         # Logging utility
│   └── env.ts            # Environment validation
└── public/               # Static assets
```

### Environment Variables

Create `haubaboss-frontend/.env.local`:

```bash
# For hybrid mode (native frontend + backend)
NEXT_PUBLIC_API_URL=http://localhost:8000
API_URL=http://localhost:8000

# For Docker mode
# NEXT_PUBLIC_API_URL=http://localhost
# API_URL=http://nginx
```

### Common Commands

```bash
cd haubaboss-frontend

# Install dependencies
npm install

# Start dev server (port 3000)
npm run dev

# Build for production
npm run build

# Run production build locally
npm start

# Lint code
npm run lint

# Type check
npx tsc --noEmit
```

### Adding a New Page

1. Create file in `app/(root)/your-page/page.tsx`
2. Add server action in `app/actions/yourAction.ts`
3. Use the API client:

```typescript
import { apiGet, apiPost } from "@/lib/api-client";

// In your server action
export async function getItems() {
  const result = await apiGet<Item[]>("/api/v1/items");
  if (!result.success) {
    throw new Error(result.error || "Failed to fetch items");
  }
  return result.data;
}
```

---

## Backend Development

### Directory Structure

```
haubaboss-backend/
├── app/
│   ├── Http/
│   │   ├── Controllers/Api/   # API controllers
│   │   └── Middleware/        # Custom middleware
│   └── Models/                # Eloquent models
├── database/
│   ├── migrations/            # Database migrations
│   └── seeders/               # Database seeders
├── routes/
│   └── api.php               # API routes
└── storage/
    └── logs/                 # Laravel logs
```

### Environment Variables

Create `haubaboss-backend/.env`:

```bash
APP_NAME=HaubaBoss
APP_ENV=local
APP_KEY=base64:YOUR_KEY_HERE
APP_DEBUG=true
APP_URL=http://localhost:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=haubaboss_app
DB_USERNAME=root
DB_PASSWORD=

# For Docker, use:
# DB_HOST=db
# DB_PASSWORD=your_docker_password
```

### Common Commands

```bash
cd haubaboss-backend

# Install dependencies
composer install

# Generate app key (first time)
php artisan key:generate

# Run migrations
php artisan migrate

# Run seeders
php artisan db:seed

# DONT RUN THIS ON PRODUCTION! To delete all data in db and reapply migrations + seed
php artisan migrate:fresh --seed

# Start dev server
php artisan serve --port=8000

# Clear all caches
php artisan optimize:clear

# List all routes
php artisan route:list --path=api

# Create new controller
php artisan make:controller Api/YourController

# Create new model with migration
php artisan make:model YourModel -m
```

### Adding a New API Endpoint

1. Create controller:
```bash
php artisan make:controller Api/ItemController
```

2. Add routes in `routes/api.php`:
```php
Route::middleware('auth:sanctum')->group(function () {
    Route::apiResource('items', ItemController::class);
});
```

3. Implement controller methods

---

## Database

### Using Docker MySQL

```bash
# Start database only
docker compose up -d db

# Connect via CLI
docker compose exec db mysql -u root -p haubaboss_app

# View logs
docker compose logs db
```

### Using Local MySQL

```bash
# Start MySQL
brew services start mysql

# Create database
mysql -u root -e "CREATE DATABASE haubaboss_app;"

# Import backup
mysql -u root haubaboss_app < backup.sql
```

### Database Management

```bash
cd haubaboss-backend

# Run pending migrations
php artisan migrate

# Rollback last migration
php artisan migrate:rollback

# Fresh start (drops all tables)
php artisan migrate:fresh --seed

# Create new migration
php artisan make:migration create_items_table

# Create seeder
php artisan make:seeder ItemSeeder
```

### Backup & Restore

```bash
# Export from Docker
./scripts/db-export.sh

# Import to Docker
./scripts/db-import.sh backup.sql
```

---

## Queue Workers

HaubaBoss uses Laravel queues for background jobs.

### Local Development

```bash
cd haubaboss-backend

# Process jobs (stops after queue is empty)
php artisan queue:work --once

# Process jobs continuously
php artisan queue:work

# Process with verbose output
php artisan queue:work --verbose

# Failed jobs
php artisan queue:failed
php artisan queue:retry all
```

### Docker Development

Queue worker runs automatically via Supervisor in the backend container.

```bash
# View queue worker logs
docker compose exec backend tail -f /var/log/supervisor/queue-worker.log

# Restart queue worker
docker compose exec backend supervisorctl restart queue-worker
```

---

## Testing

### API Smoke Test

```bash
# Test local
./scripts/test-api.sh http://localhost:8000

# Test Docker
./scripts/test-api.sh http://localhost

# Test production
./scripts/test-api.sh http://89.167.24.255
```

### Health Check

```bash
# Check system health
curl http://localhost:3000/api/health | jq
```

### Backend Tests

```bash
cd haubaboss-backend

# Run all tests
php artisan test

# Run specific test
php artisan test --filter=LoginTest

# With coverage
php artisan test --coverage
```

### Frontend Tests

```bash
cd haubaboss-frontend

# Run tests (if configured)
npm test
```

---

## Debugging

### Frontend Debugging

1. **Browser DevTools**: F12 → Console/Network tabs
2. **Server logs**: Check terminal running `npm run dev`
3. **React DevTools**: Install browser extension

### Backend Debugging

1. **Laravel logs**:
```bash
tail -f haubaboss-backend/storage/logs/laravel.log
```

2. **Add debug output**:
```php
\Log::debug('Message', ['data' => $variable]);
dd($variable);  // Dump and die
```

3. **Tinker (REPL)**:
```bash
php artisan tinker
>>> User::first()
```

### Docker Debugging

```bash
# View all logs
./scripts/logs.sh

# View specific service
./scripts/logs.sh frontend
./scripts/logs.sh backend

# Shell into container
docker compose exec frontend sh
docker compose exec backend bash

# Check container status
docker compose ps
```

### Network Debugging

```bash
# Test API from frontend container
docker compose exec frontend wget -qO- http://nginx/api/health

# Test backend directly
curl -v http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}'
```

---

## Common Issues

### "Failed to find Server Action"

**Cause:** Browser cached old Next.js build

**Fix:**
1. Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
2. Clear browser cache
3. Use incognito window
4. Rebuild: `npm run build`

### "ECONNREFUSED" or "fetch failed"

**Cause:** Backend not running or wrong URL

**Fix:**
1. Check backend is running: `curl http://localhost:8000/api/v1/auth/login`
2. Check `.env.local` has correct `API_URL`
3. In Docker, ensure nginx is running: `docker compose ps`

### "Missing auth token"

**Cause:** Not logged in or cookies not set

**Fix:**
1. Clear cookies and login again
2. Check cookie domain matches request domain
3. Ensure `httpOnly` cookies are being set

### Database connection refused

**Cause:** MySQL not running or wrong credentials

**Fix:**
```bash
# Check if MySQL is running
docker compose ps db

# Or for local MySQL
brew services list | grep mysql

# Test connection
mysql -h 127.0.0.1 -u root -p
```

### Port already in use

**Cause:** Another process using the port

**Fix:**
```bash
# Find process on port 3000
lsof -i :3000

# Kill it
kill -9 <PID>

# Or use different port
npm run dev -- -p 3001
php artisan serve --port=8001
```

### Docker build fails

**Cause:** Cache issues or missing files

**Fix:**
```bash
# Clean rebuild
docker compose build --no-cache

# Remove all containers and volumes
docker compose down -v
docker system prune -f
```

---

## Quick Reference

### URLs

| Environment | Frontend | Backend API | Database |
|-------------|----------|-------------|----------|
| Hybrid | http://localhost:3000 | http://localhost:8000/api/v1 | localhost:3306 |
| Docker | http://localhost | http://localhost/api/v1 | localhost:3306 |
| Production | http://89.167.24.255 | http://89.167.24.255/api/v1 | (internal) |

### Test Accounts

| Role | Email | Password |
|------|-------|----------|
| Zeus | zeus@haubaboss.com | zeus123456 |
| Admin | admin@testcompany.com | admin123456 |
| Manager | manager@testcompany.com | manager123456 |
| Worker | worker@testcompany.com | worker123456 |

### Useful Commands

```bash
# Start development
./scripts/dev.sh hybrid

# Stop everything
./scripts/dev.sh stop

# Test API
./scripts/test-api.sh

# View logs
./scripts/logs.sh

# Deploy to production
./scripts/deploy.sh
```

---

## Need Help?

1. Check the logs first: `./scripts/logs.sh`
2. Run the API test: `./scripts/test-api.sh`
3. Check the health endpoint: `curl localhost:3000/api/health`
4. Review this guide's [Common Issues](#common-issues) section
