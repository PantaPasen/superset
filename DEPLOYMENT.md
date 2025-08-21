# Superset Deployment Guide

This guide covers the improved deployment system for Apache Superset, inspired by the Airflow deployment methodology with enhanced features for production use.

## 🚀 Quick Start

### 1. Initial Setup
```bash
# Setup deployment configuration (one-time)
./deploy-to-vm.sh --setup
```

### 2. Full Deployment
```bash
# Build, push, and deploy to VM
./deploy-to-vm.sh
```

### 3. Quick Management
```bash
# Check status
./quick-deploy.sh status

# View logs
./quick-deploy.sh logs

# Restart services
./quick-deploy.sh restart
```

## 📁 File Structure

### New Files
- `deploy-to-vm.sh` - Main deployment script (replaces `build-and-upload.sh`)
- `deploy-config.env` - Centralized configuration file
- `env.template` - Environment variables template
- `docker-compose-production.yml` - Production-optimized compose file
- `quick-deploy.sh` - Helper script for common operations
- `DEPLOYMENT.md` - This documentation

### Updated Files
- `docker-compose-uploaded.yml` - Updated to use registry images and environment variables

## 🔧 Configuration

### Deploy Configuration (`deploy-config.env`)
Central configuration file containing:
- GCP project settings (project ID, VM name, zone)
- Docker registry configuration
- Build optimization flags
- Deployment options (backup, health checks, **data preservation**)

### Environment Template (`env.template`)
Template for runtime environment variables:
- Database connection settings
- Redis configuration
- Superset security settings
- Optional integrations (OAuth, SMTP, etc.)

## 🛠️ Deployment Options

### Full Deployment
```bash
./deploy-to-vm.sh
```
Runs the complete pipeline: build → push → deploy → health check

### Partial Operations
```bash
# Setup configuration
./deploy-to-vm.sh --setup

# Build images only
./deploy-to-vm.sh --build-only

# Push to registry only
./deploy-to-vm.sh --push-only

# Deploy to VM only (requires images in registry)
./deploy-to-vm.sh --deploy-only

# Health check only
./deploy-to-vm.sh --health-check

# Backup only
./deploy-to-vm.sh --backup
```

## 🔍 Management Commands

### Status and Monitoring
```bash
# Check VM and service status
./quick-deploy.sh status

# View live logs
./quick-deploy.sh logs

# SSH into VM
./quick-deploy.sh ssh
```

### Service Management
```bash
# Start services
./quick-deploy.sh start

# Stop services
./quick-deploy.sh stop

# Restart services
./quick-deploy.sh restart
```

## 🛡️ Data Preservation

The deployment system now **automatically preserves your production data** during deployments:

### How It Works
1. **Volume Detection**: Checks for existing Docker volumes containing data
2. **Safety Backup**: Creates additional backup before deployment
3. **Graceful Stop**: Stops services without removing volumes
4. **Data Verification**: Verifies data integrity after restart
5. **Reporting**: Shows what data was preserved

### Configuration
```bash
# No configuration needed - data preservation is ALWAYS enabled
# It's impossible to accidentally destroy your data
```

### What Gets Preserved
- ✅ **Dashboards**: All your custom dashboards
- ✅ **Charts**: All visualization configurations  
- ✅ **Datasets**: Database connections and table configurations
- ✅ **Users & Permissions**: User accounts and access controls
- ✅ **Settings**: Superset configuration and customizations

### Safety Features
- **Pre-deployment backups**: Additional backup created before each deployment
- **Volume verification**: Checks data integrity before and after deployment
- **Rollback capability**: Easy rollback using comprehensive backups
- **Status reporting**: Clear indication of what data was preserved

## 🔄 Key Improvements

### 1. Configuration Management
- **Centralized Config**: All settings in `deploy-config.env`
- **Environment Templates**: Standardized `.env` file generation
- **Validation**: Automatic validation of required configuration

### 2. Enhanced Build Process
- **Registry Support**: Uses Google Container Registry instead of manual tar uploads
- **Multi-platform**: Ensures x86_64 compatibility for VM deployment
- **Build Optimization**: Configurable build flags for faster builds
- **Error Handling**: Better error messages and troubleshooting tips

### 3. Comprehensive Backup System
- **Automatic Backups**: Creates timestamped backups before deployments
- **Multiple Components**: Backs up configs, data volumes, and databases
- **Metadata Tracking**: JSON metadata for backup verification
- **Rollback Support**: Backup information stored for easy rollback

### 4. Production Features
- **Health Checks**: Automated verification of deployment success
- **Service Dependencies**: Proper startup order with health check dependencies
- **Resource Limits**: Memory and CPU limits for production stability
- **Restart Policies**: Automatic restart on failure
- **🛡️ Data Preservation**: ALWAYS enabled - automatic preservation of database and Superset data during ALL deployments

### 5. Deployment Pipeline
- **Atomic Operations**: Each step can be run independently
- **Progress Tracking**: Clear logging and status reporting
- **Cleanup**: Automatic cleanup of temporary files
- **Parallel Processing**: Optimized for faster deployments

## 🏗️ Architecture

### Services
1. **PostgreSQL** (`db`) - Database with health checks and persistence
2. **Redis** (`redis`) - Cache and message broker with memory limits
3. **Superset Init** (`superset-init`) - Database initialization and migrations
4. **Superset App** (`superset`) - Main web application
5. **Superset Worker** (`superset-worker`) - Celery worker for async tasks
6. **Superset Beat** (`superset-worker-beat`) - Celery scheduler

### Volumes
- `superset_home` - Superset configuration and data
- `db_home` - PostgreSQL data persistence
- `redis` - Redis data persistence

## 🔐 Security Considerations

### Production Checklist
- [ ] Update default passwords in `deploy-config.env`
- [ ] Generate strong secret keys using `openssl rand -base64 42`
- [ ] Configure OAuth or LDAP authentication
- [ ] Set up SSL/TLS certificates
- [ ] Configure firewall rules
- [ ] Enable audit logging
- [ ] Set up monitoring and alerting

### Environment Variables
```bash
# Generate secure secret key
openssl rand -base64 42

# Generate JWT secret
openssl rand -base64 42
```

## 🚨 Troubleshooting

### Common Issues

#### Build Failures
```bash
# Check TypeScript issues
npm run build
# in superset-frontend/

# Check Docker resources
docker system df
docker system prune
```

#### Deployment Failures
```bash
# Check VM connectivity
gcloud compute ssh $VM_INSTANCE_NAME --zone=$VM_ZONE

# Check service logs
./quick-deploy.sh logs

# Check service status
./quick-deploy.sh status
```

#### Health Check Failures
```bash
# Manual health check
curl -f http://VM_EXTERNAL_IP:8088/health

# Check container status
./quick-deploy.sh ssh
docker-compose ps
docker-compose logs superset
```

## 📊 Monitoring

### Key Metrics to Monitor
- Container health status
- Database connection pool
- Redis memory usage
- Application response times
- Error rates in logs

### Log Locations
- Application logs: `docker-compose logs superset`
- Worker logs: `docker-compose logs superset-worker`
- Database logs: `docker-compose logs db`
- System logs: VM system logs

## 🔄 Rollback Procedure

If a deployment fails, you can rollback using the automatic backups:

1. **Identify Backup**: Check backup metadata files
2. **Stop Services**: `./quick-deploy.sh stop`
3. **Restore Configuration**: Copy backed up files
4. **Restore Data**: Restore database and volumes from backup
5. **Start Services**: `./quick-deploy.sh start`

## 💡 Best Practices

### Development Workflow
1. Test changes locally using `docker-compose.yml`
2. Use `--build-only` to test build process
3. Use `--deploy-only` for faster iteration (after initial build)
4. Monitor logs during deployment
5. Run health checks after deployment

### Production Deployment
1. Always backup before deployment (`--backup`)
2. Use tagged images instead of `latest`
3. Monitor resource usage and adjust limits
4. Set up external monitoring and alerting
5. Regular backup schedule

## 🆚 Comparison with Previous Method

| Feature | Old Method | New Method |
|---------|------------|------------|
| **Image Transfer** | Manual tar upload | Container registry |
| **Configuration** | Hardcoded values | Centralized config file |
| **Backup** | Manual/none | Automatic comprehensive backup |
| **Health Checks** | Manual verification | Automated health checks |
| **Error Handling** | Basic | Comprehensive with troubleshooting |
| **Service Management** | Manual docker commands | Helper scripts |
| **Rollback** | Manual | Automated backup system |
| **Monitoring** | Basic logging | Structured logging + health checks |

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs using `./quick-deploy.sh logs`
3. Check service status with `./quick-deploy.sh status`
4. Verify configuration in `deploy-config.env`
