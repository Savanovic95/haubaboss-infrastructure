# CI/CD Setup Guide

This guide explains how to set up GitHub Actions for automatic deployment.

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflows                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  haubaboss-frontend (push to main)                              │
│  ├── Lint & Type Check                                          │
│  ├── Build                                                       │
│  └── Deploy → SSH to server → Pull & Rebuild frontend           │
│                                                                  │
│  haubaboss-backend (push to main)                               │
│  ├── Run Tests (with MySQL)                                     │
│  ├── Security Audit                                              │
│  └── Deploy → SSH to server → Pull & Rebuild backend            │
│                                                                  │
│  haubaboss-infrastructure (push to main)                        │
│  └── Deploy Full Stack → Sync files → Pull all repos → Rebuild  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Required GitHub Secrets

You need to add these secrets to **each repository** on GitHub.

### How to Add Secrets

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret below

### Secrets to Add

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `SSH_PRIVATE_KEY` | Contents of `~/.ssh/id_ed25519` | Your SSH private key |
| `SERVER_IP` | `89.167.24.255` | Production server IP |
| `SERVER_USER` | `root` | SSH username |
| `NEXT_PUBLIC_API_URL` | `http://89.167.24.255` | Public API URL |

### Getting Your SSH Private Key

```bash
# On your Mac, copy the private key content
cat ~/.ssh/id_ed25519

# Copy the ENTIRE output including:
# -----BEGIN OPENSSH PRIVATE KEY-----
# ... key content ...
# -----END OPENSSH PRIVATE KEY-----
```

## Setup Steps

### 1. Add Secrets to Frontend Repo

Go to: https://github.com/Savanovic95/haubaboss-frontend/settings/secrets/actions

Add:
- `SSH_PRIVATE_KEY`
- `SERVER_IP`
- `SERVER_USER`
- `NEXT_PUBLIC_API_URL`

### 2. Add Secrets to Backend Repo

Go to: https://github.com/Savanovic95/haubaboss-backend/settings/secrets/actions

Add:
- `SSH_PRIVATE_KEY`
- `SERVER_IP`
- `SERVER_USER`

### 3. Add Secrets to Infrastructure Repo

Go to: https://github.com/Savanovic95/haubaboss-infrastructure/settings/secrets/actions

Add:
- `SSH_PRIVATE_KEY`
- `SERVER_IP`
- `SERVER_USER`

### 4. Create Production Environment (Optional but Recommended)

For each repo:
1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name it `production`
4. Enable **Required reviewers** if you want manual approval before deploy

## How Deployments Work

### Automatic Deployment

When you push to `main` branch:

```bash
# Push frontend changes
cd haubaboss-frontend
git add -A && git commit -m "Fix bug"
git push origin main
# → GitHub Actions automatically deploys frontend

# Push backend changes
cd haubaboss-backend
git add -A && git commit -m "Add feature"
git push origin main
# → GitHub Actions automatically deploys backend

# Push infrastructure changes
cd haubaboss (infrastructure)
git add -A && git commit -m "Update nginx config"
git push origin main
# → GitHub Actions deploys full stack
```

### Manual Deployment

You can also trigger deployments manually:

1. Go to repository → **Actions** tab
2. Select the workflow (e.g., "Deploy Frontend")
3. Click **Run workflow**
4. Select branch and options
5. Click **Run workflow**

## Workflow Details

### Frontend Workflow

```yaml
Triggers: Push to main, Manual
Jobs:
  1. Lint & Type Check
  2. Build (with NEXT_PUBLIC_API_URL)
  3. Deploy to server
     - SSH to server
     - Pull latest code
     - Rebuild Docker container
     - Health check
```

### Backend Workflow

```yaml
Triggers: Push to main, Manual
Jobs:
  1. Run Tests (with MySQL service)
  2. Security Audit (composer audit)
  3. Deploy to server
     - SSH to server
     - Pull latest code
     - Rebuild Docker container
     - Run migrations
     - Cache config
     - Health check
```

### Infrastructure Workflow

```yaml
Triggers: Push to main, Manual
Jobs:
  1. Deploy Full Stack
     - Sync infrastructure files
     - Pull frontend repo
     - Pull backend repo
     - Build all containers
     - Run migrations
     - Validate database
     - Health check
```

## Monitoring Deployments

### View Deployment Status

1. Go to repository → **Actions** tab
2. Click on the latest workflow run
3. View logs for each step

### Common Issues

#### SSH Connection Failed

```
Error: ssh: connect to host 89.167.24.255 port 22: Connection refused
```

**Fix:** Check that:
- Server is running
- SSH key is correct
- Server IP is correct
- Firewall allows SSH (port 22)

#### Permission Denied

```
Error: Permission denied (publickey)
```

**Fix:** 
- Verify SSH_PRIVATE_KEY secret is correct
- Ensure the public key is in server's `~/.ssh/authorized_keys`

#### Docker Build Failed

```
Error: failed to solve: failed to read dockerfile
```

**Fix:**
- Check Dockerfile exists in the repo
- Verify docker-compose.yml paths are correct

## Rollback

If a deployment fails, you can rollback:

```bash
# SSH to server
ssh root@89.167.24.255

# Go to the repo
cd /var/www/haubaboss/haubaboss-frontend

# Checkout previous commit
git checkout HEAD~1

# Rebuild
cd /var/www/haubaboss
docker compose build frontend
docker compose up -d frontend
```

## Adding Notifications (Optional)

### Slack Notifications

Add to workflow:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    fields: repo,message,commit,author,action,eventName,ref,workflow
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Discord Notifications

Add to workflow:

```yaml
- name: Notify Discord
  if: always()
  uses: sarisia/actions-status-discord@v1
  with:
    webhook: ${{ secrets.DISCORD_WEBHOOK }}
    status: ${{ job.status }}
```

## Security Best Practices

1. **Never commit secrets** - Always use GitHub Secrets
2. **Use environment protection** - Require approval for production
3. **Rotate SSH keys** - Change keys periodically
4. **Limit SSH access** - Use a deploy-only user if possible
5. **Monitor Actions** - Check logs regularly for anomalies
