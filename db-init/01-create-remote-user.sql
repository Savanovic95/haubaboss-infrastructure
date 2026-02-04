-- This script runs ONLY on initial database creation (empty volume)
-- Passwords are set via environment variables in docker-compose.yml
-- This file is for LOCAL DEVELOPMENT only

-- Grant privileges to app user (password set by MYSQL_PASSWORD env var)
GRANT ALL PRIVILEGES ON haubaboss_app.* TO 'haubaboss'@'%';

FLUSH PRIVILEGES;
