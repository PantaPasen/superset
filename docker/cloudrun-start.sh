#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -eo pipefail

echo "Starting Superset for Cloud Run with PostgreSQL and Redis..."

# Ensure the superset_home directory exists
mkdir -p "${SUPERSET_HOME}"

# Start PostgreSQL service
echo "Starting PostgreSQL service..."
service postgresql start

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -U postgres; do
    echo "PostgreSQL is not ready yet, waiting..."
    sleep 2
done

# Start Redis service
echo "Starting Redis service..."
redis-server --daemonize yes --port 6379

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
until redis-cli ping; do
    echo "Redis is not ready yet, waiting..."
    sleep 1
done

echo "✅ PostgreSQL and Redis services are running!"

# Switch to superset user for database operations
echo "Switching to superset user for application setup..."

# Check if we need to initialize the database (PostgreSQL based check)
echo "Checking if Superset database needs initialization..."
DB_INITIALIZED=$(sudo -u postgres psql -d superset -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | xargs || echo "0")

if [ "$DB_INITIALIZED" = "0" ]; then
    echo "Initializing Superset database..."
    
    # Grant proper permissions to superset user on public schema
    echo "Granting database permissions..."
    sudo -u postgres psql -d superset -c "GRANT ALL PRIVILEGES ON SCHEMA public TO superset;"
    sudo -u postgres psql -d superset -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO superset;"
    sudo -u postgres psql -d superset -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO superset;"
    sudo -u postgres psql -d superset -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO superset;"
    sudo -u postgres psql -d superset -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO superset;"
    
    # Set database URI for Superset to use PostgreSQL
    export DATABASE_URL="postgresql://superset:superset@localhost/superset"
    export SUPERSET_CONFIG_PATH="/app/pythonpath/superset_config.py"
    
    sudo -u superset -E superset db upgrade
    
    # Create admin user if not exists
    echo "Creating admin user..."
    sudo -u superset -E superset fab create-admin \
        --username admin \
        --firstname Admin \
        --lastname User \
        --email admin@superset.com \
        --password admin || echo "Admin user might already exist"
    
    # Initialize Superset
    echo "Initializing Superset..."
    sudo -u superset -E superset init
    
    # Skip loading examples during startup to avoid timeout
    echo "Skipping example data loading during startup for faster boot..."
else
    echo "Database already initialized, skipping initialization..."
    
    # Ensure permissions are still correct for existing database
    echo "Ensuring database permissions are correct..."
    sudo -u postgres psql -d superset -c "GRANT ALL PRIVILEGES ON SCHEMA public TO superset;" || true
    sudo -u postgres psql -d superset -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO superset;" || true
    sudo -u postgres psql -d superset -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO superset;" || true
fi

# Quick database upgrade check (for updates)
echo "Ensuring database is up to date..."
export DATABASE_URL="postgresql://superset:superset@localhost/superset"
export SUPERSET_CONFIG_PATH="/app/pythonpath/superset_config.py"
sudo -u superset -E superset db upgrade || echo "Database upgrade failed or not needed"

# Use Cloud Run's PORT environment variable, fallback to SUPERSET_PORT
export PORT=${PORT:-${SUPERSET_PORT:-8088}}

# Start Superset web server with Gunicorn for production as superset user
echo "Starting Superset web server with Gunicorn on port ${PORT}..."
exec sudo -u superset -E gunicorn \
    --bind "0.0.0.0:${PORT}" \
    --access-logfile - \
    --error-logfile - \
    --workers 1 \
    --worker-class gthread \
    --threads 2 \
    --timeout 300 \
    --keep-alive 2 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    "superset.app:create_app()" 