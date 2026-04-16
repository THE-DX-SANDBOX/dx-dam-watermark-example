#!/bin/sh
#
# DAM Plugin Server Startup Script
#

# Load configuration from ConfigMap if mounted
if [ -d "/etc/config" ]; then
  for file in /etc/config/*; do
    if [ -f "$file" ]; then
      # Extract variable name from filename (e.g., api.key -> API_KEY)
      varname=$(basename "$file" | tr '[:lower:]' '[:upper:]' | tr '.' '_')
      varvalue=$(cat "$file")
      export "$varname=$varvalue"
      echo "Loaded config: $varname"
    fi
  done
fi

# Load secrets from mounted secret directory
if [ -d "/etc/secrets" ]; then
  for file in /etc/secrets/*; do
    if [ -f "$file" ]; then
      varname=$(basename "$file" | tr '[:lower:]' '[:upper:]' | tr '.' '_')
      varvalue=$(cat "$file")
      export "$varname=$varvalue"
      echo "Loaded secret: $varname"
    fi
  done
fi

# Set default values if not provided
export PORT=${PORT:-3000}
export HOST=${HOST:-0.0.0.0}
export NODE_ENV=${NODE_ENV:-production}
export LOG_LEVEL=${LOG_LEVEL:-info}

echo "=========================================="
echo "Starting DAM Plugin Server"
echo "=========================================="
echo "Environment: $NODE_ENV"
echo "Host: $HOST"
echo "Port: $PORT"
echo "Log Level: $LOG_LEVEL"
echo "=========================================="

# Start the server
cd /opt/app/server-v1
exec node dist/index.js
