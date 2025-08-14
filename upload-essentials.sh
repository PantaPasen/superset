#!/bin/bash

# Upload essential files to VM
set -e

VM_NAME="bower-superset-test"
ZONE="europe-north1-a"
VM_USER="lucasnilsson"
VM_PROJECT_DIR="/home/${VM_USER}/superset"

echo "🚀 Uploading essential files to VM..."

# Upload Docker files
echo "📦 Uploading Docker configuration files..."
gcloud compute scp docker-compose-final.yml ${VM_NAME}:${VM_PROJECT_DIR}/ --zone=${ZONE}
gcloud compute scp docker-compose-local-build.yml ${VM_NAME}:${VM_PROJECT_DIR}/ --zone=${ZONE}
gcloud compute scp Dockerfile ${VM_NAME}:${VM_PROJECT_DIR}/ --zone=${ZONE}

# Upload configuration files
echo "⚙️  Uploading configuration files..."
gcloud compute scp superset_config_local.py ${VM_NAME}:${VM_PROJECT_DIR}/ --zone=${ZONE} || echo "superset_config_local.py not found, skipping..."
gcloud compute scp requirements/base.txt ${VM_NAME}:${VM_PROJECT_DIR}/requirements/ --zone=${ZONE} || echo "requirements/base.txt not found, skipping..."

# Upload modified superset files
echo "🔧 Uploading modified Superset files..."
gcloud compute scp superset/charts/schemas.py ${VM_NAME}:${VM_PROJECT_DIR}/superset/charts/ --zone=${ZONE} || echo "superset/charts/schemas.py not found, skipping..."
gcloud compute scp superset/constants.py ${VM_NAME}:${VM_PROJECT_DIR}/superset/ --zone=${ZONE} || echo "superset/constants.py not found, skipping..."

# Upload example chart definitions
echo "📊 Uploading example chart definitions..."
gcloud compute scp --recurse superset/examples/ ${VM_NAME}:${VM_PROJECT_DIR}/superset/ --zone=${ZONE} || echo "superset/examples/ not found, skipping..."

# Upload frontend files (CRITICAL for new charts)
echo "🎨 Uploading frontend files with new chart plugins..."
gcloud compute scp --recurse superset-frontend/plugins/ ${VM_NAME}:${VM_PROJECT_DIR}/superset-frontend/ --zone=${ZONE} || echo "superset-frontend/plugins/ not found, skipping..."
gcloud compute scp superset-frontend/package.json ${VM_NAME}:${VM_PROJECT_DIR}/superset-frontend/ --zone=${ZONE} || echo "superset-frontend/package.json not found, skipping..."
gcloud compute scp superset-frontend/package-lock.json ${VM_NAME}:${VM_PROJECT_DIR}/superset-frontend/ --zone=${ZONE} || echo "superset-frontend/package-lock.json not found, skipping..."

# Upload frontend source files that register plugins
echo "🔗 Uploading frontend source files..."
gcloud compute scp --recurse superset-frontend/src/ ${VM_NAME}:${VM_PROJECT_DIR}/superset-frontend/ --zone=${ZONE} || echo "superset-frontend/src/ not found, skipping..."

# Upload build script
echo "📝 Uploading build script..."
gcloud compute scp build-and-deploy-vm.sh ${VM_NAME}:${VM_PROJECT_DIR}/ --zone=${ZONE} || echo "build-and-deploy-vm.sh not found, skipping..."

echo "✅ Essential files uploaded successfully!"
echo ""
echo "⚠️  IMPORTANT: Your new charts require frontend compilation!"
echo ""
echo "Next steps:"
echo "1. SSH into your VM: gcloud compute ssh ${VM_NAME} --zone=${ZONE}"
echo "2. Navigate to project: cd ${VM_PROJECT_DIR}"
echo "3. Build with local frontend changes: docker-compose -f docker-compose-local-build.yml up --build -d"
echo ""
echo "❌ DO NOT use docker-compose-final.yml - it uses pre-built Apache image without your changes!"
echo "✅ USE docker-compose-local-build.yml - it builds your custom frontend"

