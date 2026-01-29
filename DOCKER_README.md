# Haubaboss Docker Setup

Complete Docker setup for the Haubaboss application with multi-tenant subdomain support.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         NGINX                                │
│              (Reverse Proxy + Subdomain Routing)            │
│                    Port 80 / 443                            │
└─────────────────┬───────────────────────┬───────────────────┘
                  │                       │
                  ▼                       ▼
┌─────────────────────────┐   ┌─────────────────────────────┐
│    Next.js Frontend     │   │      Laravel Backend        │
│       Port 3000         │   │     PHP-FPM Port 9000       │
│                         │   │     + Queue Workers         │
└─────────────────────────┘   └──────────────┬──────────────┘
                                             │
                                             ▼
                              ┌─────────────────────────────┐
                              │         MySQL 8.0           │
                              │        Port 3306            │
                              └─────────────────────────────┘
```

## Quick Start

### 1. Prepare Environment

```bash
# Copy environment file
cp .env.example .env

# Edit with your values
nano .env
```

### 2. Export Existing Database (if you have local data)

```bash
# Export your local MySQL database
chmod +x scripts/export-local-db.sh
./scripts/export-local-db.sh
```

### 3. Start Everything

```bash
# Make init script executable and run
chmod +x scripts/docker-init.sh
./scripts/docker-init.sh
```

Or manually:

```bash
docker compose build
docker compose up -d
```

### 4. Import Existing Database (alternative method)

```bash
chmod +x scripts/import-db.sh
./scripts/import-db.sh haubaboss-backend/haubaboss_app.sql
```

## Multi-Tenant Subdomain Setup

The nginx configuration supports wildcard subdomains for multi-tenancy:

- `tenant1.haubaboss.com` → Tenant ID: `tenant1`
- `tenant2.haubaboss.com` → Tenant ID: `tenant2`
- `haubaboss.com` → Tenant ID: `default`

The tenant ID is passed to:
- **Backend**: Via `X-Tenant` header (accessible in Laravel as `request()->header('X-Tenant')`)
- **Frontend**: Via `X-Tenant` header

### Laravel Multi-Tenant Implementation

Add this middleware to handle tenant identification:

```php
// app/Http/Middleware/IdentifyTenant.php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class IdentifyTenant
{
    public function handle(Request $request, Closure $next)
    {
        $tenantId = $request->header('X-Tenant', 'default');
        
        // Store tenant in config or container
        config(['app.tenant_id' => $tenantId]);
        
        // Or use a tenant service
        // app(TenantService::class)->setCurrentTenant($tenantId);
        
        return $next($request);
    }
}
```

## Permissions Handling

Docker handles permissions through:

1. **Backend container**: Runs as `www-data` user (UID 33)
2. **Frontend container**: Runs as `nextjs` user (UID 1001)
3. **Volume mounts**: Storage directories are writable

### If you encounter permission issues:

```bash
# Fix Laravel storage permissions
docker compose exec backend chown -R www-data:www-data /var/www/html/storage
docker compose exec backend chmod -R 775 /var/www/html/storage

# Or from host (Linux/Mac)
sudo chown -R 33:33 haubaboss-backend/storage
sudo chmod -R 775 haubaboss-backend/storage
```

## Useful Commands

```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f nginx

# Shell into containers
docker compose exec backend sh
docker compose exec frontend sh
docker compose exec db mysql -u root -p

# Run Laravel artisan commands
docker compose exec backend php artisan migrate
docker compose exec backend php artisan tinker
docker compose exec backend php artisan queue:work

# Restart services
docker compose restart backend
docker compose restart frontend

# Rebuild after code changes
docker compose up -d --build

# Stop everything
docker compose down

# Stop and remove volumes (WARNING: deletes database!)
docker compose down -v
```

## Production Deployment

### 1. SSL/HTTPS Setup

Place your SSL certificates in `nginx/ssl/`:
- `fullchain.pem` - Full certificate chain
- `privkey.pem` - Private key

Then uncomment the HTTPS server block in `nginx/conf.d/default.conf`.

### 2. DNS Configuration

For multi-tenant subdomains, configure a wildcard DNS record:
```
*.haubaboss.com  →  YOUR_SERVER_IP
haubaboss.com    →  YOUR_SERVER_IP
```

### 3. Environment Variables

Update `.env` for production:
```env
APP_ENV=production
APP_DEBUG=false
DB_PASSWORD=very_secure_password_here
```

## Troubleshooting

### Database connection refused
```bash
# Check if MySQL is running
docker compose ps
docker compose logs db

# Wait for MySQL to be fully ready
docker compose exec db mysqladmin ping -h localhost -u root -p
```

### Laravel storage permission denied
```bash
docker compose exec backend chmod -R 775 storage bootstrap/cache
docker compose exec backend chown -R www-data:www-data storage bootstrap/cache
```

### Frontend build fails
```bash
# Check Node.js build logs
docker compose logs frontend

# Rebuild frontend
docker compose build --no-cache frontend
```

### Nginx 502 Bad Gateway
```bash
# Check if backend is running
docker compose ps
docker compose logs backend

# Restart backend
docker compose restart backend
```
