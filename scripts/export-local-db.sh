#!/bin/bash
set -e

# Script to export your local MySQL database for Docker import
# Run this BEFORE dockerizing to capture your existing data

DB_NAME="haubaboss_app"
OUTPUT_FILE="db-init/01-init-data.sql"

echo "Exporting local MySQL database: $DB_NAME"

# Export the database (adjust credentials as needed)
mysqldump -u root "$DB_NAME" > "$OUTPUT_FILE"

echo "✅ Database exported to: $OUTPUT_FILE"
echo "This file will be automatically imported when Docker starts fresh."
