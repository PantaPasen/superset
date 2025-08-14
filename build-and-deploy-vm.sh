#!/bin/bash

# Build and Deploy Superset to VM Script
# This script copies files to VM, builds Docker image locally, and runs it

set -e  # Exit on any error

VM_NAME="bower-superset-test"
ZONE="europe-north1-a"
VM_USER="lucasnilsson"
VM_PROJECT_DIR="/home/${VM_USER}/superset"

echo "🚀 Starting Superset build and deployment to VM..."

# Step 1: Copy all files to VM
echo "📁 Step 1: Copying files to VM..."
gcloud compute scp --recurse . ${VM_NAME}:${VM_PROJECT_DIR}/ --zone=${ZONE}

# Step 2: SSH into VM and build + run
echo "🔧 Step 2: Building and running on VM..."
gcloud compute ssh ${VM_NAME} --zone=${ZONE} --command="
    set -e
    cd ${VM_PROJECT_DIR}
    
    echo '🛑 Stopping existing containers...'
    docker-compose -f docker-compose-final.yml down || true
    
    echo '🏗️  Building Superset Docker image locally...'
    docker build -t local-superset:latest .
    
    echo '📝 Updating docker-compose to use local image...'
    sed -i 's|image: apache/superset:latest|image: local-superset:latest|g' docker-compose-final.yml
    
    echo '🚀 Starting containers with local image...'
    docker-compose -f docker-compose-final.yml up -d
    
    echo '📊 Checking container status...'
    docker-compose -f docker-compose-final.yml ps
    
    echo '✅ Deployment complete! Superset should be available at: http://$(curl -s ifconfig.me):8088'
    echo '👤 Login: admin / admin'
"

echo "🎉 Build and deployment script completed!"
