# Building Superset Locally on VM - Step by Step

## 🚀 Quick Automated Method

Run this single command from your local machine:
```bash
./build-and-deploy-vm.sh
```

## 🔧 Manual Step-by-Step Method

### Step 1: Copy Files to VM
```bash
# From your local machine
gcloud compute scp --recurse . bower-superset-test:/home/lucasnilsson/superset/ --zone=europe-north1-a
```

### Step 2: SSH into VM
```bash
gcloud compute ssh bower-superset-test --zone=europe-north1-a
```

### Step 3: On the VM - Build and Run

```bash
# Navigate to project directory
cd /home/lucasnilsson/superset

# Stop any existing containers
docker-compose -f docker-compose-final.yml down || true
docker-compose -f docker-compose-local-build.yml down || true

# Build the Docker image locally
docker build -t local-superset:latest .

# Option A: Use the local build docker-compose (Recommended)
docker-compose -f docker-compose-local-build.yml up -d

# Option B: Or modify existing docker-compose to use local image
# sed -i 's|image: apache/superset:latest|image: local-superset:latest|g' docker-compose-final.yml
# docker-compose -f docker-compose-final.yml up -d

# Check status
docker-compose -f docker-compose-local-build.yml ps

# View logs
docker-compose -f docker-compose-local-build.yml logs -f superset
```

### Step 4: Access Your Application

Get your VM's external IP:
```bash
curl ifconfig.me
```

Then access Superset at: `http://[VM_IP]:8088`
- Username: `admin`
- Password: `admin`

## 🔍 Troubleshooting Commands

```bash
# Check Docker images
docker images

# Check running containers
docker ps

# View all logs
docker-compose -f docker-compose-local-build.yml logs

# Restart just Superset container
docker-compose -f docker-compose-local-build.yml restart superset

# Rebuild image if needed
docker build --no-cache -t local-superset:latest .
```

## 📝 What Each File Does

- `Dockerfile`: Defines how to build your custom Superset image
- `docker-compose-local-build.yml`: Uses the locally built image with health checks
- `build-and-deploy-vm.sh`: Automates the entire process
- `superset_config_local.py`: Your custom Superset configuration
