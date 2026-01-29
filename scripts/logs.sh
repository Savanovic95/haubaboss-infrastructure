#!/bin/bash
#
# Tail logs from all Docker containers
#
# Usage:
#   ./scripts/logs.sh           # All containers
#   ./scripts/logs.sh frontend  # Just frontend
#   ./scripts/logs.sh backend   # Just backend
#

SERVICE=${1:-}

if [ -n "$SERVICE" ]; then
    docker compose logs -f "$SERVICE"
else
    docker compose logs -f
fi
