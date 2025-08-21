#!/bin/bash

# Simple Production Backup Script
# Works with existing production Superset containers

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-config-production.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Load config
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    error "Production config not found: $CONFIG_FILE"
    exit 1
fi

echo ""
echo "🛡️  Simple Production Backup"
echo "============================"
echo ""

log "Target: $VM_INSTANCE_NAME"
log "Creating backup of existing production data..."

# Create backup on VM
gcloud compute ssh "$VM_INSTANCE_NAME" \
    --zone="$VM_ZONE" \
    --project="$GCP_PROJECT_ID" \
    --command="
        set -e
        
        BACKUP_TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
        BACKUP_DIR=\"/tmp/superset-backup-\$BACKUP_TIMESTAMP\"
        
        echo \"📂 Creating backup directory: \$BACKUP_DIR\"
        mkdir -p \"\$BACKUP_DIR\"
        
        echo \"🗄️  Backing up database from superset_db container...\"
        if sudo docker ps --format '{{.Names}}' | grep -q '^superset_db\$'; then
            echo \"  📊 Database container found: superset_db\"
            
            # Create database dump
            sudo docker exec superset_db pg_dump -U superset -d superset > \"\$BACKUP_DIR/database.sql\"
            
            # Get data statistics
            DASHBOARDS=\$(sudo docker exec superset_db psql -U superset -d superset -t -c 'SELECT COUNT(*) FROM dashboards;' | tr -d ' ')
            CHARTS=\$(sudo docker exec superset_db psql -U superset -d superset -t -c 'SELECT COUNT(*) FROM slices;' | tr -d ' ')
            USERS=\$(sudo docker exec superset_db psql -U superset -d superset -t -c 'SELECT COUNT(*) FROM ab_user;' | tr -d ' ')
            
            echo \"  📊 Data backed up: \$DASHBOARDS dashboards, \$CHARTS charts, \$USERS users\"
            
            # Create metadata
            cat > \"\$BACKUP_DIR/metadata.json\" << EOF
{
  \"backup_timestamp\": \"\$BACKUP_TIMESTAMP\",
  \"backup_type\": \"production_simple\",
  \"data_counts\": {
    \"dashboards\": \$DASHBOARDS,
    \"charts\": \$CHARTS,
    \"users\": \$USERS
  },
  \"containers_backed_up\": [\"superset_db\"],
  \"backup_size\": \"\$(du -sh \$BACKUP_DIR | cut -f1)\"
}
EOF
            
            echo \"✅ Backup completed successfully!\"
            echo \"📍 Location: \$BACKUP_DIR\"
            echo \"📊 Size: \$(du -sh \$BACKUP_DIR | cut -f1)\"
            echo \"\"
            echo \"🛡️  Your production data is safely backed up:\"
            echo \"   📊 \$DASHBOARDS dashboards\"
            echo \"   📈 \$CHARTS charts\" 
            echo \"   👥 \$USERS users\"
            echo \"\"
            
        else
            echo \"❌ superset_db container not found\"
            exit 1
        fi
    "

if [ $? -eq 0 ]; then
    success "Production backup completed successfully!"
    echo ""
    echo "✅ Your production Superset data has been backed up"
    echo "✅ Ready for safe deployment"
else
    error "Backup failed"
    exit 1
fi
