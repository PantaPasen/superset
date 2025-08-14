#!/bin/bash
set -e

# Modern Apache Superset - Simplified Container Initialization Script
echo "🚀 Starting Modern Apache Superset (Simplified Single Container)"

# Create log directory
mkdir -p /var/log/supervisor

# =============================================================================
# POSTGRESQL SETUP
# =============================================================================
echo "📊 Setting up PostgreSQL..."

# Start PostgreSQL temporarily for setup
sudo -u postgres /usr/local/bin/pg_ctl -D /var/lib/postgresql/data -l /var/log/postgresql.log start

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until sudo -u postgres psql -c '\q' 2>/dev/null; do
    sleep 1
done
echo "✅ PostgreSQL is ready"

# Get database credentials from environment
DB_USER=${DATABASE_USER:-superset}
DB_PASSWORD=${DATABASE_PASSWORD:-superset}
DB_NAME=${DATABASE_DB:-superset}
EXAMPLES_DB=${EXAMPLES_DB:-examples}

# Create database user and databases
echo "🔧 Creating databases and user..."
sudo -u postgres psql <<EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
    END IF;
END
\$\$;

-- Create main database
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Create examples database
DROP DATABASE IF EXISTS $EXAMPLES_DB;
CREATE DATABASE $EXAMPLES_DB OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $EXAMPLES_DB TO $DB_USER;

-- Grant superuser privileges for database operations
ALTER USER $DB_USER CREATEDB;
EOF

echo "✅ PostgreSQL databases created successfully"

# Stop PostgreSQL (supervisor will manage it)
sudo -u postgres /usr/local/bin/pg_ctl -D /var/lib/postgresql/data stop

# =============================================================================
# REDIS SETUP
# =============================================================================
echo "🔴 Setting up Redis..."

# Create Redis directories
mkdir -p /var/lib/redis
chown redis:redis /var/lib/redis

echo "✅ Redis configuration ready"

# =============================================================================
# SUPERSET SETUP
# =============================================================================
echo "⚡ Setting up Superset..."

# Set environment variables
export PYTHONPATH="/app/pythonpath"
export SUPERSET_CONFIG_PATH="/app/pythonpath/superset_config.py"
export DATABASE_DIALECT="postgresql"
export DATABASE_HOST="localhost"
export DATABASE_USER="$DB_USER"
export DATABASE_PASSWORD="$DB_PASSWORD"
export DATABASE_DB="$DB_NAME"
export REDIS_HOST="localhost"

# Generate secret key if not provided
if [ -z "$SUPERSET__SECRET_KEY" ]; then
    echo "🔑 Generating secret key..."
    export SUPERSET__SECRET_KEY=$(openssl rand -base64 42)
    echo "Generated SECRET_KEY: $SUPERSET__SECRET_KEY"
    echo "⚠️  IMPORTANT: Save this secret key for future deployments!"
fi

# Start supervisor to manage all services
echo "🎯 Starting all services with supervisor..."
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 15

# Wait for PostgreSQL to be available through supervisor
until pg_isready -h localhost -p 5432 -U $DB_USER; do
    echo "Waiting for PostgreSQL..."
    sleep 2
done

# Wait for Redis to be available
until redis-cli -h localhost ping; do
    echo "Waiting for Redis..."
    sleep 2
done

echo "✅ Services are ready"

# =============================================================================
# SUPERSET INITIALIZATION
# =============================================================================
echo "🔧 Initializing Superset..."

# Switch to superset user for initialization
sudo -u superset bash <<EOF
export PYTHONPATH="/app/pythonpath"
export SUPERSET_CONFIG_PATH="/app/pythonpath/superset_config.py"
export DATABASE_DIALECT="postgresql"
export DATABASE_HOST="localhost"
export DATABASE_USER="$DB_USER"
export DATABASE_PASSWORD="$DB_PASSWORD"
export DATABASE_DB="$DB_NAME"
export REDIS_HOST="localhost"
export SUPERSET__SECRET_KEY="$SUPERSET__SECRET_KEY"

cd /app

# Initialize the database
echo "📊 Upgrading database schema..."
superset db upgrade

# Create admin user if it doesn't exist
echo "👤 Creating admin user..."
superset fab create-admin \
    --username admin \
    --firstname Superset \
    --lastname Admin \
    --email admin@superset.local \
    --password admin || echo "Admin user already exists"

# Initialize Superset
echo "⚡ Initializing Superset..."
superset init

# Load example data if requested
if [ "\$LOAD_EXAMPLES" = "true" ]; then
    echo "📈 Loading example data..."
    superset load-examples
fi
EOF

echo "✅ Superset initialization completed"

# =============================================================================
# FINAL SETUP
# =============================================================================
echo "🎉 Modern Apache Superset is ready!"
echo ""
echo "🌐 Access Superset at: http://localhost:8088"
echo "👤 Default credentials: admin/admin"
echo "📊 Database: PostgreSQL (localhost:5432)"
echo "🔴 Cache: Redis (localhost:6379)"
echo ""
echo "🚨 IMPORTANT NOTES:"
echo "   - Change the default admin password"
echo "   - Save the generated SECRET_KEY for production"
echo "   - Configure proper authentication for production use"
echo ""

# Keep supervisor running in foreground
wait 