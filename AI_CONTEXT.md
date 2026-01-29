# HaubaBoss - AI Agent Context

This document provides context for AI coding assistants working on this project.

---

## Project Overview

**HaubaBoss** is a SaaS application for auto parts inventory management, targeting scrapyards and auto parts businesses in the Balkans region.

### Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Frontend | Next.js (App Router) | 16.x |
| Frontend Framework | React | 19.x |
| Styling | TailwindCSS | 4.x |
| Backend | Laravel | 12.x |
| Backend Language | PHP | 8.2+ |
| Database | MySQL | 8.0 |
| Auth | Laravel Sanctum | Token-based |
| Containerization | Docker Compose | 2.x |
| Reverse Proxy | Nginx | Alpine |
| CI/CD | GitHub Actions | - |

---

## Repository Structure

```
haubaboss/                          # Infrastructure repo (this one)
├── docker-compose.yml              # Main Docker orchestration
├── docker-compose.dev.yml          # Development overrides
├── docker-compose.prod.yml         # Production overrides
├── nginx/
│   └── conf.d/default.conf         # Nginx routing config
├── scripts/
│   ├── dev-start.sh                # Single command local dev setup
│   ├── prod-deploy.sh              # Single command production deploy
│   ├── db-sync-from-local.sh       # Sync DB from Mac to Docker/prod
│   ├── db-backup-prod.sh           # Backup production DB
│   └── ...
├── haubaboss-frontend/             # Next.js app (separate git repo)
│   ├── app/                        # App Router pages and layouts
│   │   ├── (root)/                 # Main app routes (dashboard, etc.)
│   │   ├── (auth)/                 # Auth routes (login, register)
│   │   ├── actions/                # Server Actions
│   │   └── api/                    # API routes (health check)
│   ├── components/                 # React components
│   ├── lib/                        # Utilities (api-client, logger, env)
│   └── .env.local                  # Frontend environment variables
└── haubaboss-backend/              # Laravel app (separate git repo)
    ├── app/
    │   ├── Http/Controllers/Api/   # API controllers
    │   ├── Models/                 # Eloquent models
    │   └── Console/Commands/       # Artisan commands
    ├── database/
    │   ├── migrations/             # Database schema
    │   └── seeders/                # Test data seeders
    ├── routes/api.php              # API routes
    └── .env                        # Backend environment variables
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Browser                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ HTTP :80/:443
┌─────────────────────────────────────────────────────────────────┐
│                         Nginx                                    │
│                   (Reverse Proxy)                                │
│                                                                  │
│   Routes:                                                        │
│   - /api/*  → Laravel backend (PHP-FPM :9000)                   │
│   - /*      → Next.js frontend (:3000)                          │
└─────────────────────────────────────────────────────────────────┘
           │                                    │
           ▼                                    ▼
┌─────────────────────┐              ┌─────────────────────┐
│   Laravel Backend   │              │   Next.js Frontend  │
│   (PHP-FPM)         │◄─────────────│   (Node.js)         │
│                     │ Server       │                     │
│   - REST API        │ Actions      │   - SSR Pages       │
│   - Auth (Sanctum)  │              │   - Server Actions  │
│   - Queue Workers   │              │   - React Components│
└─────────────────────┘              └─────────────────────┘
           │
           ▼
┌─────────────────────┐
│       MySQL         │
│     Database        │
│                     │
│   - haubaboss_app   │
└─────────────────────┘
```

---

## Key Concepts

### Authentication Flow

1. User submits login form (frontend)
2. Server Action calls Laravel `/api/v1/login`
3. Laravel validates credentials, returns Sanctum token
4. Token stored in HTTP-only cookie
5. Subsequent requests include token in Authorization header

### API Communication

- **Client-side:** Uses `NEXT_PUBLIC_API_URL` (public URL)
- **Server-side (SSR/Server Actions):** Uses `API_URL` (internal Docker network: `http://nginx`)

### Multi-tenancy (Planned)

- Users belong to Companies
- Data is scoped by `company_id`
- Roles: `zeus` (super admin), `admin`, `manager`, `worker`

---

## Database Schema (Key Tables)

| Table | Purpose |
|-------|---------|
| `users` | User accounts with roles |
| `companies` | Tenant companies |
| `vehicles` | Vehicles in inventory (by VIN) |
| `parts` | Auto parts inventory |
| `manufacturers` | Vehicle manufacturers (BMW, Audi, etc.) |
| `vehicle_models` | Vehicle models |
| `variants` | Vehicle variants (engine, year, etc.) |
| `main_categories` | Parts categories |
| `subcategories` | Parts subcategories |
| `seven_zap_*` | External data source tables |

---

## Environment Variables

### Frontend (.env.local)

```bash
# Public (exposed to browser)
NEXT_PUBLIC_API_URL=http://localhost      # Production: http://YOUR_IP

# Private (server-side only)
API_URL=http://nginx                       # Internal Docker network
```

### Backend (.env)

```bash
APP_KEY=base64:xxx
APP_ENV=local                              # Production: production
APP_DEBUG=true                             # Production: false

DB_HOST=db                                 # Docker service name
DB_DATABASE=haubaboss_app
DB_USERNAME=haubaboss
DB_PASSWORD=xxx
```

---

## Common Development Tasks

### Start Development Environment
```bash
./scripts/dev-start.sh
```

### Run Migrations
```bash
docker compose exec backend php artisan migrate
```

### Run Seeders
```bash
docker compose exec backend php artisan db:seed
```

### Create New Migration
```bash
docker compose exec backend php artisan make:migration create_xxx_table
```

### Create New Controller
```bash
docker compose exec backend php artisan make:controller Api/XxxController
```

### View Logs
```bash
docker compose logs -f backend
docker compose logs -f frontend
```

### Validate Database
```bash
docker compose exec backend php artisan db:validate
```

---

## API Endpoints

Base URL: `/api/v1`

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/login` | No | User login |
| POST | `/logout` | Yes | User logout |
| GET | `/user` | Yes | Get current user |
| GET | `/parts` | Yes | List parts |
| GET | `/vehicles` | Yes | List vehicles |
| GET | `/manufacturers` | Yes | List manufacturers |

---

## Test Accounts

| Role | Email | Password |
|------|-------|----------|
| Zeus | zeus@haubaboss.com | zeus123456 |
| Admin | admin@testcompany.com | admin123456 |
| Manager | manager@testcompany.com | manager123456 |
| Worker | worker@testcompany.com | worker123456 |

---

## Deploying to a Different Server

### What to Change

#### 1. Server IP Address

Update in these files:

```bash
# scripts/deploy.sh
SERVER_IP="NEW_IP_ADDRESS"

# scripts/db-sync-from-local.sh
REMOTE_HOST="NEW_IP_ADDRESS"

# scripts/db-backup-prod.sh
REMOTE_HOST="NEW_IP_ADDRESS"
```

#### 2. GitHub Actions Secrets

Go to each repo's Settings → Secrets → Actions and update:

| Secret | New Value |
|--------|-----------|
| `SERVER_IP` | Your new server IP |
| `SSH_PRIVATE_KEY` | SSH key for new server |
| `NEXT_PUBLIC_API_URL` | `http://NEW_IP_ADDRESS` |

#### 3. SSH Key Setup

```bash
# On your local machine
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@NEW_IP_ADDRESS

# Or manually add to server's ~/.ssh/authorized_keys
```

#### 4. Domain Name (Optional)

If using a domain instead of IP:

```bash
# .env on server
NEXT_PUBLIC_API_URL=https://yourdomain.com

# Add SSL
apt install certbot python3-certbot-nginx
certbot --nginx -d yourdomain.com
```

### Deployment Steps for New Server

```bash
# 1. SSH to new server
ssh root@NEW_IP_ADDRESS

# 2. Install Docker
curl -fsSL https://get.docker.com | sh

# 3. Setup SSH key for GitHub
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
# Add this to GitHub → Settings → SSH Keys

# 4. Clone and deploy
git clone git@github.com:Savanovic95/haubaboss-infrastructure.git /var/www/haubaboss
cd /var/www/haubaboss
./scripts/prod-deploy.sh

# 5. (Optional) Import database
./scripts/db-import.sh /path/to/backup.sql
```

---

## Troubleshooting

### "Connection refused" to API
- Check nginx is running: `docker compose ps`
- Check backend logs: `docker compose logs backend`
- Verify API_URL in frontend .env.local

### "Unauthorized" errors
- Token may be expired
- Check cookie is being set
- Verify Sanctum configuration

### Database connection issues
- Check DB container is healthy: `docker compose ps`
- Verify credentials in backend .env
- Check DB_HOST is `db` (not localhost)

### Frontend not updating
- Clear Next.js cache: `docker compose exec frontend rm -rf .next`
- Rebuild: `docker compose up -d --build frontend`

---

## Git Repositories

| Repo | URL | Purpose |
|------|-----|---------|
| Infrastructure | github.com/Savanovic95/haubaboss-infrastructure | Docker, scripts, docs |
| Frontend | github.com/Savanovic95/haubaboss-frontend | Next.js app |
| Backend | github.com/Savanovic95/haubaboss-backend | Laravel API |

---

## CI/CD Pipeline

Push to `main` branch triggers automatic deployment:

1. **Frontend repo** → Lint → Build → Deploy frontend container
2. **Backend repo** → Test → Security audit → Deploy backend container
3. **Infrastructure repo** → Deploy full stack

---

## File Naming Conventions

- **Migrations:** `YYYY_MM_DD_HHMMSS_description.php`
- **Controllers:** `PascalCase` + `Controller.php`
- **Models:** `PascalCase.php` (singular)
- **React Components:** `PascalCase.tsx`
- **Server Actions:** `camelCase.ts`

---

## Important Notes for AI Agents

1. **Always use Docker commands** - Don't suggest `php artisan serve` or `npm run dev` directly
2. **API calls from frontend** - Use Server Actions, not direct client-side fetch
3. **Database changes** - Always create migrations, never modify DB directly
4. **Environment variables** - Never put secrets in `NEXT_PUBLIC_*` variables
5. **Testing changes** - Use `docker compose logs -f` to debug issues
6. **File paths** - Frontend uses App Router (`app/` directory), not Pages Router
