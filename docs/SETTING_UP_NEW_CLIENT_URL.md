# Setting Up New Client Custom Domain

This guide explains how to set up a custom domain (e.g., `clientcompany.com`) for a tenant instead of using a subdomain.

## Prerequisites

- Client must own the domain
- Client must have access to their DNS settings
- You need SSH access to the server

## Step 1: Client DNS Configuration

The client needs to add an A record pointing to our server:

| Type | Name | Value |
|------|------|-------|
| A | `@` | `89.167.24.255` |
| A | `www` | `89.167.24.255` |

**Note:** DNS propagation can take up to 24 hours, but usually completes within 1-2 hours.

## Step 2: Verify DNS Propagation

Before proceeding, verify the DNS is pointing to our server:

```bash
dig +short A clientcompany.com
# Should return: 89.167.24.255
```

## Step 3: Generate SSL Certificate

SSH into the server and generate SSL certificate:

```bash
ssh root@89.167.24.255

# Stop nginx temporarily
cd /var/www/haubaboss
docker compose stop nginx

# Generate certificate
certbot certonly --standalone -d clientcompany.com -d www.clientcompany.com --agree-tos --email admin@unyielded.one

# Start nginx
docker compose start nginx
```

## Step 4: Add Nginx Server Block

Edit `/var/www/haubaboss/nginx/conf.d/default.conf` and add:

```nginx
# HTTP to HTTPS redirect for clientcompany.com
server {
    listen 80;
    server_name clientcompany.com www.clientcompany.com;
    return 301 https://$host$request_uri;
}

# HTTPS server block for clientcompany.com
server {
    listen 443 ssl http2;
    server_name clientcompany.com www.clientcompany.com;

    ssl_certificate /etc/letsencrypt/live/clientcompany.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/clientcompany.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    root /var/www/html/public;
    index index.php index.html;
    client_max_body_size 100M;

    # Tenant will be resolved by TenantMiddleware from custom_domain

    location /api/health {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api {
        limit_req zone=api_limit burst=20 nodelay;
        fastcgi_pass backend;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME /var/www/html/public/index.php;
        fastcgi_param REQUEST_URI $request_uri;
        fastcgi_param QUERY_STRING $query_string;
        fastcgi_param REQUEST_METHOD $request_method;
        fastcgi_param CONTENT_TYPE $content_type;
        fastcgi_param CONTENT_LENGTH $content_length;
        include fastcgi_params;
        fastcgi_read_timeout 300;
        fastcgi_send_timeout 300;
    }

    location /storage {
        alias /var/www/html/public/storage;
        try_files $uri =404;
    }

    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }

    location /_next/static {
        proxy_pass http://frontend;
        proxy_cache_valid 60m;
        add_header Cache-Control "public, immutable, max-age=31536000";
    }

    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location ~ /\.(?!well-known) {
        deny all;
    }

    location ~ /\.env {
        deny all;
    }
}
```

## Step 5: Restart Nginx

```bash
cd /var/www/haubaboss
docker compose restart nginx
```

## Step 6: Update Company in Database

As Zeus user, update the company with the custom domain:

**Option A: Via API**
```bash
curl -X PUT https://unyielded.one/api/v1/companies/{company_id} \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"custom_domain": "clientcompany.com"}'
```

**Option B: Via Database**
```sql
UPDATE companies SET custom_domain = 'clientcompany.com' WHERE id = {company_id};
```

## Step 7: Verify Setup

1. Visit `https://clientcompany.com`
2. Should load the application
3. Login should work
4. API calls should return data scoped to that company

## Troubleshooting

### SSL Certificate Issues
```bash
# Check certificate status
certbot certificates

# Renew certificate manually
certbot renew --cert-name clientcompany.com
```

### Nginx Configuration Test
```bash
docker compose exec nginx nginx -t
```

### Check Tenant Resolution
```bash
curl https://clientcompany.com/api/v1/tenant
# Should return the company info
```

## Notes

- SSL certificates auto-renew via certbot cron job
- TenantMiddleware automatically resolves tenant from `custom_domain` field
- Each custom domain requires its own SSL certificate
- Subdomains (`*.unyielded.one`) use the wildcard certificate
