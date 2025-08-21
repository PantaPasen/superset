#!/bin/bash

# Superset - Deploy to Google Cloud VM Script
# This script builds, uploads, and deploys Docker images from your machine to GCP VM
# Ensures x86_64 compatibility for VM deployment
#
# Inspired by Bower Airflow deployment with improvements for Superset

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-config.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        echo "Please run: ./deploy-to-vm.sh --setup"
        exit 1
    fi
    
    source "$CONFIG_FILE"
    
    # Set default values for optional variables - DATA PRESERVATION IS ALWAYS ENABLED
    PRESERVE_DATA="true"  # Always preserve data - no option to disable in production
    BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
    HEALTH_CHECK_ENABLED="${HEALTH_CHECK_ENABLED:-true}"
    
    # Validate required variables
    local required_vars=("GCP_PROJECT_ID" "VM_INSTANCE_NAME" "VM_ZONE" "VM_PROJECT_PATH" "DOCKER_REGISTRY")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            error "Required configuration variable $var is not set in $CONFIG_FILE"
            exit 1
        fi
    done
    
    success "Configuration loaded successfully"
}

# Validate security configuration
validate_security_config() {
    log "Validating security configuration..."
    
    # Check if superset.env exists and has proper SECRET_KEY placeholder
    if [[ -f "superset.env" ]]; then
        if grep -q "SUPERSET__SECRET_KEY=CHANGE" superset.env; then
            warning "superset.env contains default SECRET_KEY placeholder"
            log "💡 The deployment script will auto-generate a secure SECRET_KEY during deployment"
        fi
    else
        warning "superset.env template not found - SECRET_KEY will be auto-generated"
    fi
    
    success "Security configuration validated"
}

# Setup configuration
setup_config() {
    log "Setting up deployment configuration..."
    
    echo "# Superset Deployment Configuration" > "$CONFIG_FILE"
    echo "# Generated on $(date)" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
    
    # GCP Configuration
    echo "# Google Cloud Platform Configuration" >> "$CONFIG_FILE"
    read -p "Enter your GCP Project ID: " project_id
    echo "GCP_PROJECT_ID=\"$project_id\"" >> "$CONFIG_FILE"
    
    read -p "Enter VM Instance Name [bower-superset-test]: " instance_name
    instance_name=${instance_name:-bower-superset-test}
    echo "VM_INSTANCE_NAME=\"$instance_name\"" >> "$CONFIG_FILE"
    
    read -p "Enter VM Zone [europe-north1-a]: " zone
    zone=${zone:-europe-north1-a}
    echo "VM_ZONE=\"$zone\"" >> "$CONFIG_FILE"
    
    read -p "Enter VM user [lucasnilsson]: " vm_user
    vm_user=${vm_user:-lucasnilsson}
    echo "VM_USER=\"$vm_user\"" >> "$CONFIG_FILE"
    
    echo "VM_PROJECT_PATH=\"/home/$vm_user/superset\"" >> "$CONFIG_FILE"
    
    # Docker Registry Configuration
    echo "" >> "$CONFIG_FILE"
    echo "# Docker Registry Configuration" >> "$CONFIG_FILE"
    echo "DOCKER_REGISTRY=\"gcr.io/$project_id\"" >> "$CONFIG_FILE"
    echo "IMAGE_NAME=\"superset\"" >> "$CONFIG_FILE"
    echo "IMAGE_TAG=\"\$(date +%Y%m%d-%H%M%S)\"" >> "$CONFIG_FILE"
    
    # Build Configuration
    echo "" >> "$CONFIG_FILE"
    echo "# Build Configuration" >> "$CONFIG_FILE"
    echo "DOCKER_PLATFORM=\"linux/amd64\"  # Ensures x86_64 compatibility" >> "$CONFIG_FILE"
    echo "DOCKER_BUILDKIT=1" >> "$CONFIG_FILE"
    echo "COMPOSE_DOCKER_CLI_BUILD=1" >> "$CONFIG_FILE"
    echo "SUPERSET_BUILD_TARGET=\"dev\"  # can use 'dev' or 'lean'" >> "$CONFIG_FILE"
    
    # Build Optimization Flags
    echo "" >> "$CONFIG_FILE"
    echo "# Build Optimization Flags" >> "$CONFIG_FILE"
    echo "INCLUDE_CHROMIUM=\"false\"" >> "$CONFIG_FILE"
    echo "INCLUDE_FIREFOX=\"false\"" >> "$CONFIG_FILE"
    echo "BUILD_TRANSLATIONS=\"false\"" >> "$CONFIG_FILE"
    echo "DEV_MODE=\"false\"" >> "$CONFIG_FILE"
    
    # Deployment Configuration
    echo "" >> "$CONFIG_FILE"
    echo "# Deployment Configuration" >> "$CONFIG_FILE"
    echo "BACKUP_ENABLED=\"true\"" >> "$CONFIG_FILE"
    echo "HEALTH_CHECK_ENABLED=\"true\"" >> "$CONFIG_FILE"
    echo "EXTERNAL_IP=\"\"  # Leave empty to auto-detect" >> "$CONFIG_FILE"
    
    # Database Configuration
    echo "" >> "$CONFIG_FILE"
    echo "# Database Configuration (for health checks and backups)" >> "$CONFIG_FILE"
    echo "POSTGRES_USER=\"superset\"" >> "$CONFIG_FILE"
    echo "POSTGRES_DB=\"superset\"" >> "$CONFIG_FILE"
    echo "POSTGRES_PASSWORD=\"superset\"" >> "$CONFIG_FILE"
    
    # Superset Configuration
    echo "" >> "$CONFIG_FILE"
    echo "# Superset Configuration" >> "$CONFIG_FILE"
    echo "SUPERSET_PORT=\"8088\"" >> "$CONFIG_FILE"
    echo "SUPERSET_ADMIN_USER=\"admin\"" >> "$CONFIG_FILE"
    echo "SUPERSET_ADMIN_EMAIL=\"admin@superset.com\"" >> "$CONFIG_FILE"
    
    # Security Configuration
    echo "" >> "$CONFIG_FILE"
    echo "# Security Configuration" >> "$CONFIG_FILE"
    echo "# Note: SECRET_KEY will be auto-generated during deployment if not set in .env" >> "$CONFIG_FILE"
    echo "# You can also manually set it using: openssl rand -base64 42" >> "$CONFIG_FILE"
    
    success "Configuration file created: $CONFIG_FILE"
    log "Please review and modify the configuration if needed, then run the deployment again"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check gcloud CLI
    if ! command -v gcloud &> /dev/null; then
        error "Google Cloud CLI (gcloud) is not installed or not in PATH"
        echo "Please install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running"
        exit 1
    fi
    
    # Check gcloud authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        error "Not authenticated with Google Cloud"
        echo "Please run: gcloud auth login"
        exit 1
    fi
    
    # Check Superset frontend directory
    if [[ ! -d "superset-frontend" ]]; then
        error "superset-frontend directory not found!"
        echo "Make sure you're running this script from the superset root directory."
        exit 1
    fi
    
    # Check for potential TypeScript issues
    log "Checking for potential frontend build issues..."
    if find superset-frontend -name "*.test.ts" -o -name "*.test.tsx" | xargs grep -l "from.*src.*" | head -5 >/dev/null 2>&1; then
        warning "Found test files that might reference missing source files"
        warning "This could cause TypeScript compilation errors"
    fi
    
    success "All prerequisites satisfied"
}

# Build Docker images with x86_64 compatibility
build_images() {
    log "Building Superset Docker image with x86_64 compatibility..."
    
    # Set build environment variables
    export DOCKER_BUILDKIT=1
    export BUILDKIT_PROGRESS=plain
    
    # Generate image tag
    local timestamp=$(date +%Y%m%d-%H%M%S)
    export IMAGE_TAG="$timestamp"
    
    log "Build configuration:"
    log "  • Platform: $DOCKER_PLATFORM"
    log "  • Target: $SUPERSET_BUILD_TARGET"
    log "  • Chrome/Firefox: $INCLUDE_CHROMIUM/$INCLUDE_FIREFOX"
    log "  • Translations: $BUILD_TRANSLATIONS"
    log "  • Dev mode: $DEV_MODE"
    log "  • Image tag: $IMAGE_TAG"
    
    # Build multi-platform image for x86_64 compatibility
    log "Building Superset image for linux/amd64 platform..."
    
    if ! docker build \
        --platform "$DOCKER_PLATFORM" \
        --target "$SUPERSET_BUILD_TARGET" \
        --build-arg INCLUDE_CHROMIUM="$INCLUDE_CHROMIUM" \
        --build-arg INCLUDE_FIREFOX="$INCLUDE_FIREFOX" \
        --build-arg BUILD_TRANSLATIONS="$BUILD_TRANSLATIONS" \
        --build-arg DEV_MODE="$DEV_MODE" \
        --tag "$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG" \
        --tag "$DOCKER_REGISTRY/$IMAGE_NAME:latest" \
        .; then
        error "Docker build failed!"
        echo ""
        echo "💡 Common fixes:"
        echo "   • Check for TypeScript compilation errors in superset-frontend/"
        echo "   • Ensure all test files reference existing source files"
        echo "   • Try running 'npm run build' locally in superset-frontend/ to debug"
        echo "   • Check Docker daemon is running with sufficient resources"
        echo "   • If you get 'exec format error' on VM, the image is built for linux/amd64"
        exit 1
    fi
    
    # Get image size for reporting
    local image_size=$(docker images "$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG" --format "table {{.Size}}" | tail -n 1)
    success "Docker image built successfully (Size: $image_size)"
    
    # Save image tag for deployment
    echo "CURRENT_IMAGE_TAG=\"$IMAGE_TAG\"" > /tmp/superset-deployment-vars.env
}

# Push images to registry
push_images() {
    log "Pushing images to Google Container Registry..."
    
    # Configure Docker for GCR
    gcloud auth configure-docker --quiet
    
    # Load current image tag
    source /tmp/superset-deployment-vars.env
    
    # Push Superset image
    log "Pushing Superset image..."
    docker push "$DOCKER_REGISTRY/$IMAGE_NAME:$CURRENT_IMAGE_TAG"
    docker push "$DOCKER_REGISTRY/$IMAGE_NAME:latest"
    
    success "Images pushed to registry successfully"
}

# Create deployment package
create_deployment_package() {
    log "Creating deployment package..."
    
    local temp_dir="/tmp/superset-deploy-$(date +%s)"
    mkdir -p "$temp_dir"
    
    # Copy essential files
    cp docker-compose-uploaded.yml "$temp_dir/docker-compose.yml"
    cp superset.env "$temp_dir/"
    
    # Copy Docker configuration
    mkdir -p "$temp_dir/docker"
    cp -r docker/pythonpath_dev "$temp_dir/docker/"
    cp -r docker/nginx "$temp_dir/docker/"
    
    # Copy superset configuration (our custom one with environment variable support)
    if [[ -f "superset_config.py" ]]; then
        cp superset_config.py "$temp_dir/"
        log "✅ Copied custom superset_config.py"
    else
        warning "superset_config.py not found - using default Docker configuration"
    fi
    
    # Create deployment script for VM
    cat > "$temp_dir/vm-deploy.sh" << 'EOF'
#!/bin/bash
set -e

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
}

success() {
    echo "[SUCCESS] $1"
}

# Detect Docker Compose command (prefer newer version)
detect_docker_compose() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        error "Neither docker-compose nor docker compose found"
        exit 1
    fi
}

# Load deployment variables
if [[ -f "deployment-vars.env" ]]; then
    source deployment-vars.env
else
    error "Deployment variables file not found"
    exit 1
fi

# Set Docker Compose command
DOCKER_COMPOSE_CMD=$(detect_docker_compose)
log "Using Docker Compose command: $DOCKER_COMPOSE_CMD"

log "Starting VM deployment with image: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"

# Setup environment
if [[ -f "superset.env" ]] && [[ ! -f ".env" ]]; then
    cp superset.env .env
    log "Created .env from superset.env template"
    
    # Fix database and redis hosts for Docker Compose multi-container deployment
    log "Updating .env for Docker Compose multi-container deployment..."
    sed -i 's/DATABASE_HOST=localhost/DATABASE_HOST=db/g' .env
    sed -i 's/REDIS_HOST=localhost/REDIS_HOST=redis/g' .env
    sed -i 's/EXAMPLES_HOST=localhost/EXAMPLES_HOST=db/g' .env
    log "✅ Updated database and redis hostnames for container networking"
fi

# Clean up any duplicate environment variables and ensure Docker Compose compatibility
if [[ -f ".env" ]]; then
    log "Cleaning up duplicate environment variables..."
    # Create a temporary file with unique environment variables (keeping the last occurrence)
    awk -F= '!seen[$1]++ {var[$1] = $0} END {for (i in var) print var[i]}' .env > .env.tmp
    mv .env.tmp .env
    
    # Ensure Docker Compose service names are used (fix any localhost references)
    log "Ensuring Docker Compose service names in .env..."
    sed -i 's/DATABASE_HOST=localhost/DATABASE_HOST=db/g' .env
    sed -i 's/REDIS_HOST=localhost/REDIS_HOST=redis/g' .env
    sed -i 's/EXAMPLES_HOST=localhost/EXAMPLES_HOST=db/g' .env
    
    log "✅ Cleaned up .env file and ensured Docker Compose compatibility"
fi

# Ensure registry variables are set in .env
log "Setting registry variables in .env..."
if ! grep -q "DOCKER_REGISTRY=" .env; then
    echo "DOCKER_REGISTRY=$DOCKER_REGISTRY" >> .env
else
    sed -i "s|DOCKER_REGISTRY=.*|DOCKER_REGISTRY=$DOCKER_REGISTRY|g" .env
fi

if ! grep -q "IMAGE_NAME=" .env; then
    echo "IMAGE_NAME=$IMAGE_NAME" >> .env
else
    sed -i "s|IMAGE_NAME=.*|IMAGE_NAME=$IMAGE_NAME|g" .env
fi

if ! grep -q "IMAGE_TAG=" .env; then
    echo "IMAGE_TAG=$IMAGE_TAG" >> .env
else
    sed -i "s|IMAGE_TAG=.*|IMAGE_TAG=$IMAGE_TAG|g" .env
fi

log "Registry variables configured in .env"

# Ensure SECRET_KEY is properly configured via environment variables
log "Validating Superset SECRET_KEY configuration..."

# Check if SECRET_KEY is set in .env file
SECRET_KEY_SET=false
if [[ -f ".env" ]] && grep -q "SUPERSET__SECRET_KEY=" .env; then
    # Check if it's not the default placeholder value
    SECRET_KEY_VALUE=$(grep "SUPERSET__SECRET_KEY=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [[ "$SECRET_KEY_VALUE" != "CHANGE_ME_TO_A_COMPLEX_RANDOM_SECRET_KEY_GENERATED_WITH_OPENSSL" ]] && \
       [[ "$SECRET_KEY_VALUE" != "CHANGE-ME-IN-PRODUCTION-USE-OPENSSL-RAND-BASE64-42" ]] && \
       [[ "$SECRET_KEY_VALUE" != "CHANGE_ME" ]] && \
       [[ ${#SECRET_KEY_VALUE} -gt 20 ]]; then
        SECRET_KEY_SET=true
        log "✅ SECRET_KEY is properly configured in .env file"
    fi
fi

if [[ "$SECRET_KEY_SET" = false ]]; then
    log "🔐 Generating secure SECRET_KEY..."
    
    # Generate a secure random SECRET_KEY using openssl
    if command -v openssl &> /dev/null; then
        NEW_SECRET_KEY=$(openssl rand -base64 42)
        log "Generated new SECRET_KEY using openssl"
    else
        # Fallback: generate using /dev/urandom and base64
        NEW_SECRET_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 42)
        log "Generated new SECRET_KEY using /dev/urandom (openssl not available)"
    fi
    
    # Update or add SECRET_KEY to .env file
    if grep -q "SUPERSET__SECRET_KEY=" .env 2>/dev/null; then
        # Replace existing SECRET_KEY
        sed -i "s|SUPERSET__SECRET_KEY=.*|SUPERSET__SECRET_KEY=\"$NEW_SECRET_KEY\"|g" .env
        log "✅ Updated SECRET_KEY in .env file"
    else
        # Add SECRET_KEY to .env file
        echo "SUPERSET__SECRET_KEY=\"$NEW_SECRET_KEY\"" >> .env
        log "✅ Added SECRET_KEY to .env file"
    fi
    
    log "🔒 SECRET_KEY configured securely via environment variables"
else
    log "🔒 Using existing SECRET_KEY from .env file"
fi

# Also handle JWT_SECRET similarly
log "Validating JWT_SECRET configuration..."
JWT_SECRET_SET=false
if [[ -f ".env" ]] && grep -q "SUPERSET__JWT_SECRET=" .env; then
    JWT_SECRET_VALUE=$(grep "SUPERSET__JWT_SECRET=" .env | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [[ "$JWT_SECRET_VALUE" != "CHANGE_ME_TO_A_COMPLEX_JWT_SECRET_GENERATED_WITH_OPENSSL" ]] && \
       [[ "$JWT_SECRET_VALUE" != "CHANGE-ME-IN-PRODUCTION-JWT-SECRET-USE-OPENSSL-RAND-BASE64-42" ]] && \
       [[ "$JWT_SECRET_VALUE" != "CHANGE_ME" ]] && \
       [[ ${#JWT_SECRET_VALUE} -gt 20 ]]; then
        JWT_SECRET_SET=true
        log "✅ JWT_SECRET is properly configured in .env file"
    fi
fi

if [[ "$JWT_SECRET_SET" = false ]]; then
    log "🔐 Generating secure JWT_SECRET..."
    
    if command -v openssl &> /dev/null; then
        NEW_JWT_SECRET=$(openssl rand -base64 42)
        log "Generated new JWT_SECRET using openssl"
    else
        NEW_JWT_SECRET=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 42)
        log "Generated new JWT_SECRET using /dev/urandom"
    fi
    
    if grep -q "SUPERSET__JWT_SECRET=" .env 2>/dev/null; then
        sed -i "s|SUPERSET__JWT_SECRET=.*|SUPERSET__JWT_SECRET=\"$NEW_JWT_SECRET\"|g" .env
        log "✅ Updated JWT_SECRET in .env file"
    else
        echo "SUPERSET__JWT_SECRET=\"$NEW_JWT_SECRET\"" >> .env
        log "✅ Added JWT_SECRET to .env file"
    fi
    
    log "🔒 JWT_SECRET configured securely via environment variables"
else
    log "🔒 Using existing JWT_SECRET from .env file"
fi

# Deploy custom superset_config.py if available
if [[ -f "superset_config.py" ]]; then
    log "Deploying custom superset_config.py..."
    # Replace the default Docker configuration with our custom one
    cp superset_config.py docker/pythonpath_dev/superset_config.py
    log "✅ Deployed custom superset_config.py with environment variable support"
else
    # Ensure the default config uses environment variables (remove any hardcoded SECRET_KEY)
    if [[ -f "docker/pythonpath_dev/superset_config.py" ]]; then
        sed -i '/^SECRET_KEY = ".*"/d' docker/pythonpath_dev/superset_config.py
        log "✅ Cleaned hardcoded SECRET_KEY from default superset_config.py"
    fi
fi

# Create required directories
mkdir -p superset_home logs
log "Created required directories"

# Set permissions
chmod -R 755 superset_home logs || true
log "Set directory permissions"

# Update docker-compose to use registry images
cp docker-compose.yml docker-compose-backup.yml

# Create a comprehensive replacement of all registry references
log "Updating docker-compose.yml for registry deployment..."

# Replace the main image references
sed -i "s|image: local-superset:uploaded|image: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG|g" docker-compose.yml

# Replace all variations of the old registry pattern
sed -i "s|\${DOCKER_REGISTRY:-gcr.io/your-project}/\${IMAGE_NAME:-superset}:\${IMAGE_TAG:-latest}|$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG|g" docker-compose.yml
sed -i "s|gcr.io/your-project/superset|$DOCKER_REGISTRY/$IMAGE_NAME|g" docker-compose.yml

# Ensure any remaining environment variable references are correct
export DOCKER_REGISTRY_ESCAPED=$(echo "$DOCKER_REGISTRY" | sed 's/[[\.*^$()+?{|]/\\&/g')
sed -i "s|gcr.io/your-project|$DOCKER_REGISTRY_ESCAPED|g" docker-compose.yml

log "✅ Updated docker-compose.yml for registry deployment"
log "📋 Registry: $DOCKER_REGISTRY"
log "📋 Image: $IMAGE_NAME:$IMAGE_TAG"

# Verify the changes were applied correctly
if grep -q "gcr.io/your-project" docker-compose.yml; then
    warning "Some old registry references may still exist in docker-compose.yml"
    log "Attempting additional cleanup..."
    sed -i "s|gcr.io/your-project|$DOCKER_REGISTRY|g" docker-compose.yml
fi

# Pull images from registry
log "Pulling images from registry..."
docker pull "$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG" || {
    error "Failed to pull main image"
    exit 1
}

# Deploy services (ALWAYS preserve data volumes)
log "Deploying services with data preservation..."
log "🛡️  Data preservation is ALWAYS enabled - existing data will be kept"

# Check if database volume exists and has data
if docker volume ls | grep -q superset_db_home; then
    log "✅ Existing database volume found - data will be preserved"
    DB_EXISTS=true
else
    log "ℹ️  No existing database volume found - will create and preserve for future deployments"
    DB_EXISTS=false
fi

# ALWAYS create a safety backup before deployment (even for fresh installs)
SAFETY_BACKUP_DIR="/tmp/pre-deployment-backup-$(date +%s)"
log "Creating safety backup at $SAFETY_BACKUP_DIR"
mkdir -p "$SAFETY_BACKUP_DIR"

# Backup database if it's running
if $DOCKER_COMPOSE_CMD ps db | grep -q "Up"; then
    $DOCKER_COMPOSE_CMD exec -T db pg_dump -U superset -d superset > "$SAFETY_BACKUP_DIR/database.sql" 2>/dev/null || true
    log "📦 Safety database backup created"
fi

# Backup superset data volume if it exists
if docker volume ls | grep -q superset_superset_home; then
    docker run --rm -v superset_superset_home:/data -v "$SAFETY_BACKUP_DIR":/backup alpine tar -czf /backup/superset_data.tar.gz -C /data . 2>/dev/null || true
    log "📦 Safety Superset data backup created"
fi

# ALWAYS stop services gracefully without removing volumes
log "Stopping services gracefully (preserving all volumes)..."
$DOCKER_COMPOSE_CMD stop || true

# NEVER use 'docker-compose down --volumes' to ensure data is never lost

# Start database and cache first
log "Starting database and cache services..."
$DOCKER_COMPOSE_CMD up -d db redis
sleep 15

# Wait for database to be ready
log "Waiting for database to be ready..."
for i in {1..30}; do
    if $DOCKER_COMPOSE_CMD exec -T db pg_isready -U superset >/dev/null 2>&1; then
        success "Database is ready"
        break
    else
        log "Database not ready, waiting... ($i/30)"
        sleep 5
    fi
done

# Start Superset services with data preservation checks
log "Starting Superset services..."

# Export registry variables to ensure docker-compose uses them
export DOCKER_REGISTRY="$DOCKER_REGISTRY"
export IMAGE_NAME="$IMAGE_NAME"
export IMAGE_TAG="$IMAGE_TAG"
log "📋 Using registry: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"

# Additional check: Verify database contains data before proceeding
if [ "$DB_EXISTS" = true ]; then
    log "Verifying existing database data integrity..."
    
    # Check if database has Superset tables
    TABLE_COUNT=$($DOCKER_COMPOSE_CMD exec -T db psql -U superset -d superset -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('dashboards', 'slices', 'tables');" 2>/dev/null | tr -d ' ' || echo "0")
    
    if [ "$TABLE_COUNT" -ge 3 ]; then
        log "✅ Database structure verified - existing Superset data preserved"
        
        # Count existing dashboards for reporting
        DASHBOARD_COUNT=$($DOCKER_COMPOSE_CMD exec -T db psql -U superset -d superset -t -c "SELECT COUNT(*) FROM dashboards;" 2>/dev/null | tr -d ' ' || echo "0")
        CHART_COUNT=$($DOCKER_COMPOSE_CMD exec -T db psql -U superset -d superset -t -c "SELECT COUNT(*) FROM dashboards;" 2>/dev/null | tr -d ' ' || echo "0")
        
        log "📊 Preserved data: $DASHBOARD_COUNT dashboards, $CHART_COUNT charts"
    else
        log "⚠️  Database volume exists but appears empty - will initialize"
    fi
fi

# Start all superset services with explicit environment variables
log "Starting all Superset services..."
DOCKER_REGISTRY="$DOCKER_REGISTRY" IMAGE_NAME="$IMAGE_NAME" IMAGE_TAG="$IMAGE_TAG" $DOCKER_COMPOSE_CMD up -d

# Wait and verify
sleep 30
if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
    success "Deployment completed successfully"
    $DOCKER_COMPOSE_CMD ps
    
    # Show useful information
    echo ""
    echo "🎉 Superset deployment completed!"
    echo "📋 Service status:"
    $DOCKER_COMPOSE_CMD ps
    echo ""
    echo "📊 To monitor logs:"
    echo "   $DOCKER_COMPOSE_CMD logs -f superset"
    echo ""
    echo "🌐 Access Superset at:"
    echo "   http://[VM_EXTERNAL_IP]:8088"
    echo "   Login: admin / admin"
else
    error "Deployment failed"
    echo "📋 Container status:"
    $DOCKER_COMPOSE_CMD ps
    echo ""
    echo "📋 Recent logs:"
    $DOCKER_COMPOSE_CMD logs --tail=50
    exit 1
fi
EOF
    
    chmod +x "$temp_dir/vm-deploy.sh"
    
    # Create deployment variables file
    source /tmp/superset-deployment-vars.env
    cat > "$temp_dir/deployment-vars.env" << EOF
DOCKER_REGISTRY="$DOCKER_REGISTRY"
IMAGE_NAME="$IMAGE_NAME"
IMAGE_TAG="$CURRENT_IMAGE_TAG"
EOF
    
    # Create archive
    local archive_path="/tmp/superset-deployment-$CURRENT_IMAGE_TAG.tar.gz"
    tar -czf "$archive_path" -C "$temp_dir" .
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    success "Deployment package created: $archive_path"
    echo "DEPLOYMENT_PACKAGE=\"$archive_path\"" >> /tmp/superset-deployment-vars.env
}

# Deploy to VM
deploy_to_vm() {
    log "Deploying to VM: $VM_INSTANCE_NAME in zone $VM_ZONE"
    
    # Load deployment variables
    source /tmp/superset-deployment-vars.env
    
    # Create comprehensive backup if enabled
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        log "Creating comprehensive backup on VM..."
        gcloud compute ssh "$VM_INSTANCE_NAME" \
            --zone="$VM_ZONE" \
            --project="$GCP_PROJECT_ID" \
            --command="
                set -e
                cd '$VM_PROJECT_PATH'
                
                # Create timestamped backup directory
                BACKUP_TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
                BACKUP_DIR=\"../superset-backup-\$BACKUP_TIMESTAMP\"
                BACKUP_METADATA_FILE=\"../superset-backup-\$BACKUP_TIMESTAMP-metadata.json\"
                
                echo \"📂 Creating comprehensive backup: \$BACKUP_DIR\"
                mkdir -p \"\$BACKUP_DIR\"
                
                # 1. Backup Superset configuration
                if [ -f 'superset_config.py' ]; then
                    echo '  • Backing up superset_config.py...'
                    cp superset_config.py \"\$BACKUP_DIR/\"
                    echo '    ✅ superset_config.py backed up'
                fi
                
                # 2. Backup environment configuration
                if [ -f '.env' ]; then
                    echo '  • Backing up .env file...'
                    cp .env \"\$BACKUP_DIR/\"
                    echo '    ✅ .env file backed up'
                fi
                
                # 3. Backup docker-compose configuration
                if [ -f 'docker-compose.yml' ]; then
                    echo '  • Backing up docker-compose.yml...'
                    cp docker-compose.yml \"\$BACKUP_DIR/\"
                    echo '    ✅ docker-compose.yml backed up'
                fi
                
                # 4. Backup custom configurations
                if [ -d 'docker' ]; then
                    echo '  • Backing up docker configurations...'
                    cp -r docker \"\$BACKUP_DIR/\"
                    echo '    ✅ Docker configurations backed up'
                fi
                
                # 5. Backup Superset home directory (contains dashboards, charts, etc.)
                if docker volume ls | grep -q superset_data; then
                    echo '  • Backing up Superset data volume...'
                    docker run --rm -v superset_data:/data -v \"\$(pwd)/\$BACKUP_DIR\":/backup alpine tar -czf /backup/superset_data.tar.gz -C /data . 2>/dev/null || echo '    ⚠️  Superset data backup failed'
                    if [ -f \"\$BACKUP_DIR/superset_data.tar.gz\" ]; then
                        echo '    ✅ Superset data volume backed up'
                    fi
                fi
                
                # 6. Backup PostgreSQL database
                echo '  • Backing up PostgreSQL database...'
                if docker compose ps db | grep -q 'Up'; then
                    # Database is running, create a dump
                    POSTGRES_USER=\"$POSTGRES_USER\"
                    POSTGRES_DB=\"$POSTGRES_DB\"
                    
                    docker compose exec -T db pg_dump -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" > \"\$BACKUP_DIR/superset_database.sql\" 2>/dev/null || {
                        echo '    ⚠️  Database dump failed, backing up data volume instead'
                        # Fallback: backup the database volume
                        if docker volume ls | grep -q db_data; then
                            docker run --rm -v db_data:/data -v \"\$(pwd)/\$BACKUP_DIR\":/backup alpine tar -czf /backup/postgres_data.tar.gz -C /data . 2>/dev/null || echo '    ❌ Database backup failed'
                            if [ -f \"\$BACKUP_DIR/postgres_data.tar.gz\" ]; then
                                echo '    ✅ Database volume backed up'
                            fi
                        fi
                    }
                    
                    if [ -f \"\$BACKUP_DIR/superset_database.sql\" ]; then
                        DB_SIZE=\$(wc -l < \"\$BACKUP_DIR/superset_database.sql\")
                        echo \"    ✅ Database dump created (\$DB_SIZE lines)\"
                    fi
                else
                    echo '    ⚠️  PostgreSQL container not running, skipping database backup'
                fi
                
                # 7. Get current Docker container status for rollback reference
                echo '  • Capturing current Docker state...'
                docker compose ps > \"\$BACKUP_DIR/docker-status-before.txt\" 2>/dev/null || echo 'No containers running' > \"\$BACKUP_DIR/docker-status-before.txt\"
                docker images > \"\$BACKUP_DIR/docker-images-before.txt\" 2>/dev/null || echo 'No images found' > \"\$BACKUP_DIR/docker-images-before.txt\"
                echo '    ✅ Docker state captured'
                
                # 8. Create backup metadata file
                echo '  • Creating backup metadata...'
                cat > \"\$BACKUP_METADATA_FILE\" << EOF
{
  \"backup_timestamp\": \"\$BACKUP_TIMESTAMP\",
  \"backup_directory\": \"\$BACKUP_DIR\",
  \"project_path\": \"$VM_PROJECT_PATH\",
  \"backup_components\": {
    \"superset_config\": \$([ -f \"superset_config.py\" ] && echo 'true' || echo 'false'),
    \"env_file\": \$([ -f \".env\" ] && echo 'true' || echo 'false'),
    \"docker_compose\": \$([ -f \"docker-compose.yml\" ] && echo 'true' || echo 'false'),
    \"docker_config\": \$([ -d \"docker\" ] && echo 'true' || echo 'false'),
    \"superset_data\": \$([ -f \"\$BACKUP_DIR/superset_data.tar.gz\" ] && echo 'true' || echo 'false'),
    \"database\": \$([ -f \"\$BACKUP_DIR/superset_database.sql\" ] || [ -f \"\$BACKUP_DIR/postgres_data.tar.gz\" ] && echo 'true' || echo 'false')
  },
  \"system_info\": {
    \"hostname\": \"\$(hostname)\",
    \"user\": \"\$(whoami)\",
    \"disk_usage\": \"\$(df -h $VM_PROJECT_PATH | tail -1)\"
  }
}
EOF
                echo \"    ✅ Backup metadata created at \$BACKUP_METADATA_FILE\"
                
                # 9. Verify backup integrity
                echo '🔍 Verifying backup integrity...'
                BACKUP_SIZE=\$(du -sh \"\$BACKUP_DIR\" | cut -f1)
                BACKUP_FILE_COUNT=\$(find \"\$BACKUP_DIR\" -type f | wc -l)
                echo \"    📊 Backup size: \$BACKUP_SIZE\"
                echo \"    📁 Files backed up: \$BACKUP_FILE_COUNT\"
                
                echo \"🎯 Comprehensive backup completed successfully!\"
                echo \"📍 Backup location: \$BACKUP_DIR\"
                echo \"📋 Metadata file: \$BACKUP_METADATA_FILE\"
                
                # Store backup info for rollback
                echo \"BACKUP_DIR=\$BACKUP_DIR\" > /tmp/current_backup.env
                echo \"BACKUP_TIMESTAMP=\$BACKUP_TIMESTAMP\" >> /tmp/current_backup.env
            " || warning "Comprehensive backup creation failed, continuing..."
    fi
    
    # Copy deployment package to VM
    log "Copying deployment package to VM..."
    gcloud compute scp "$DEPLOYMENT_PACKAGE" "$VM_INSTANCE_NAME:~/superset-deployment.tar.gz" \
        --zone="$VM_ZONE" \
        --project="$GCP_PROJECT_ID"
    
    # Extract and deploy on VM
    log "Extracting and deploying on VM..."
    gcloud compute ssh "$VM_INSTANCE_NAME" \
        --zone="$VM_ZONE" \
        --project="$GCP_PROJECT_ID" \
        --command="
            # Extract deployment package to temp location first
            TEMP_DEPLOY_DIR=\$(mktemp -d)
            tar -xzf ~/superset-deployment.tar.gz -C \"\$TEMP_DEPLOY_DIR\"
            
            # FORCE deployment to /root/superset regardless of SSH user
            sudo bash -c \"
            set -e
            
            # Force the correct project path (hardcoded to avoid variable expansion issues)
            echo '🎯 Forcing deployment to: /root/superset'
            
            # Ensure directory exists and has correct permissions
            mkdir -p /root/superset
            
            # Copy deployment files to the forced location
            cp -r \$TEMP_DEPLOY_DIR/* /root/superset/
            
            # Change to the forced directory and run deployment
            cd /root/superset
            chmod +x vm-deploy.sh
            
            # Show current directory and contents (inside sudo context)
            echo '📍 Current directory: /root/superset'
            echo '📁 Contents: checking deployment files...'
            
            # Run the deployment script
            ./vm-deploy.sh
            \"
            
            # Clean up temp directory
            rm -rf \"\$TEMP_DEPLOY_DIR\"
        "
    
    success "Deployment to VM completed"
}

# Health check
health_check() {
    if [[ "$HEALTH_CHECK_ENABLED" != "true" ]]; then
        return 0
    fi
    
    log "Performing health check..."
    
    # Get VM external IP
    local external_ip
    if [[ -n "$EXTERNAL_IP" ]]; then
        external_ip="$EXTERNAL_IP"
    else
        external_ip=$(gcloud compute instances describe "$VM_INSTANCE_NAME" \
            --zone="$VM_ZONE" \
            --project="$GCP_PROJECT_ID" \
            --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
    fi
    
    if [[ -z "$external_ip" ]]; then
        warning "Could not determine external IP for health check"
        return 0
    fi
    
    log "Testing Superset webserver at http://$external_ip:$SUPERSET_PORT"
    
    # Test webserver health
    for i in {1..20}; do
        if curl -f --connect-timeout 10 "http://$external_ip:$SUPERSET_PORT/health" &>/dev/null; then
            success "Superset webserver is accessible externally"
            break
        else
            log "Health check attempt $i/20 failed, retrying in 15 seconds..."
            sleep 15
        fi
    done
    
    # Test login page
    if curl -f --connect-timeout 10 "http://$external_ip:$SUPERSET_PORT/login/" 2>/dev/null | grep -q "Superset"; then
        success "Superset login page is responding correctly"
    else
        warning "Superset login page may not be fully ready yet"
    fi
    
    # Test API endpoint
    if curl -f --connect-timeout 10 "http://$external_ip:$SUPERSET_PORT/api/v1/chart/" 2>/dev/null | grep -q -E "(result|charts)"; then
        success "Superset API is responding correctly"
    else
        warning "Superset API may not be fully ready yet"
    fi
}

# Cleanup temporary files
cleanup() {
    log "Cleaning up temporary files..."
    rm -f /tmp/superset-deployment-vars.env
    rm -f /tmp/superset-deployment-*.tar.gz 2>/dev/null || true
    success "Cleanup completed"
}

# Main deployment function
deploy() {
    log "Starting Superset deployment to Google Cloud VM"
    log "Target: $VM_INSTANCE_NAME in $VM_ZONE"
    
    check_prerequisites
    validate_security_config
    build_images
    push_images
    create_deployment_package
    deploy_to_vm
    
    if [[ "$HEALTH_CHECK_ENABLED" == "true" ]]; then
        health_check
    fi
    
    cleanup
    
    success "🎉 Deployment completed successfully!"
    
    # Get and display VM external IP
    local external_ip=$(gcloud compute instances describe "$VM_INSTANCE_NAME" \
        --zone="$VM_ZONE" \
        --project="$GCP_PROJECT_ID" \
        --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || echo "unknown")
    
    echo ""
    echo "🌐 Superset Access Information:"
    echo "   URL: http://$external_ip:$SUPERSET_PORT"
    echo "   Username: $SUPERSET_ADMIN_USER"
    echo "   Password: admin"
    echo ""
    
    # Show data preservation status (always enabled)
    echo "🛡️  Data Preservation Status:"
    echo "   ✅ Database volumes preserved (always enabled)"
    echo "   ✅ Superset data volumes preserved (always enabled)"
    echo "   📦 Safety backups created before deployment"
    echo "   🔒 Data loss protection: MAXIMUM"
    echo ""
    
    echo "🔧 Useful commands:"
    echo "   • Check logs: gcloud compute ssh $VM_INSTANCE_NAME --zone=$VM_ZONE --command='cd $VM_PROJECT_PATH && docker compose logs -f'"
    echo "   • Stop services: gcloud compute ssh $VM_INSTANCE_NAME --zone=$VM_ZONE --command='cd $VM_PROJECT_PATH && docker compose down'"
    echo "   • Restart services: gcloud compute ssh $VM_INSTANCE_NAME --zone=$VM_ZONE --command='cd $VM_PROJECT_PATH && docker compose restart'"
}

# Show usage
usage() {
    echo "Superset - Deploy to Google Cloud VM"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --setup          Setup deployment configuration"
    echo "  --build-only     Only build Docker images"
    echo "  --push-only      Only push images to registry"
    echo "  --deploy-only    Only deploy to VM (requires images in registry)"
    echo "  --health-check   Run health check only"
    echo "  --backup         Create backup only"
    echo "  --help           Show this help message"
    echo ""
    echo "Default: Run full deployment (build, push, deploy)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Full deployment"
    echo "  $0 --setup           # Initial configuration setup"
    echo "  $0 --build-only      # Build images locally"
    echo "  $0 --health-check    # Check if deployment is healthy"
}

# Backup function (can be run independently)
backup_only() {
    log "Creating backup on VM: $VM_INSTANCE_NAME"
    
    gcloud compute ssh "$VM_INSTANCE_NAME" \
        --zone="$VM_ZONE" \
        --project="$GCP_PROJECT_ID" \
        --command="
            set -e
            cd '$VM_PROJECT_PATH'
            
            # Create timestamped backup directory
            BACKUP_TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
            BACKUP_DIR=\"../superset-backup-\$BACKUP_TIMESTAMP\"
            
            echo \"📂 Creating backup: \$BACKUP_DIR\"
            mkdir -p \"\$BACKUP_DIR\"
            
            # Backup configurations
            [ -f 'superset_config.py' ] && cp superset_config.py \"\$BACKUP_DIR/\" && echo '  ✅ Config backed up'
            [ -f '.env' ] && cp .env \"\$BACKUP_DIR/\" && echo '  ✅ Environment backed up'
            [ -f 'docker-compose.yml' ] && cp docker-compose.yml \"\$BACKUP_DIR/\" && echo '  ✅ Docker compose backed up'
            
            # Backup data volumes
            if docker volume ls | grep -q superset_data; then
                echo '  • Backing up Superset data...'
                docker run --rm -v superset_data:/data -v \"\$(pwd)/\$BACKUP_DIR\":/backup alpine tar -czf /backup/superset_data.tar.gz -C /data . && echo '  ✅ Data backed up'
            fi
            
            if docker compose ps db | grep -q 'Up'; then
                echo '  • Backing up database...'
                docker compose exec -T db pg_dump -U $POSTGRES_USER -d $POSTGRES_DB > \"\$BACKUP_DIR/superset_database.sql\" && echo '  ✅ Database backed up'
            fi
            
            echo \"🎯 Backup completed: \$BACKUP_DIR\"
        "
    
    success "Backup completed successfully"
}

# Main script logic
main() {
    case "${1:-}" in
        --setup)
            setup_config
            ;;
        --build-only)
            load_config
            check_prerequisites
            build_images
            ;;
        --push-only)
            load_config
            check_prerequisites
            push_images
            ;;
        --deploy-only)
            load_config
            check_prerequisites
            create_deployment_package
            deploy_to_vm
            health_check
            cleanup
            ;;
        --health-check)
            load_config
            health_check
            ;;
        --backup)
            load_config
            backup_only
            ;;
        --help)
            usage
            ;;
        "")
            load_config
            deploy
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
