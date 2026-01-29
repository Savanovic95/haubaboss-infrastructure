#!/bin/bash
set -e

# Script to import existing MySQL database into Docker container
# Usage: ./scripts/import-db.sh [path-to-sql-file]

SQL_FILE=${1:-"haubaboss-backend/haubaboss_app.sql"}

if [ ! -f "$SQL_FILE" ]; then
    echo "Error: SQL file not found: $SQL_FILE"
    echo "Usage: ./scripts/import-db.sh [path-to-sql-file]"
    exit 1
fi

# Load environment variables
source .env

echo "Importing database from: $SQL_FILE"
echo "This may take a while for large databases..."

# Import the SQL file
docker compose exec -T db mysql -u root -p"${DB_ROOT_PASSWORD}" "${DB_DATABASE}" < "$SQL_FILE"

echo "✅ Database import completed!"
