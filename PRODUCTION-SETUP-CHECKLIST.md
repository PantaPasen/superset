# Superset Production Setup Checklist

## ✅ **Current Status (Fixed)**

### **Core Application:**
- ✅ Docker Compose configuration (`docker-compose-uploaded.yml`)
- ✅ Nginx reverse proxy with SSL support
- ✅ Database (PostgreSQL) with backup/restore capability
- ✅ Redis cache for performance
- ✅ Celery workers for async tasks
- ✅ Environment variables properly configured

### **Access Methods:**
- ✅ **IP Access**: http://34.88.142.154 (working)
- ✅ **Domain HTTP**: http://superset.getbower.com (working) 
- ⚠️ **Domain HTTPS**: https://superset.getbower.com (needs nginx restart)

### **Features Working:**
- ✅ Static assets (CSS, JS, images)
- ✅ Charts and dashboards loading
- ✅ API endpoints responding
- ✅ Database connections (except BigQuery auth)

## 🔧 **Issues Fixed:**

1. **Nginx Static Assets**: Fixed 502 errors for static files
2. **Chart Loading**: Fixed 500 errors caused by encryption key mismatch
3. **Environment Variables**: Added defaults to prevent warnings
4. **Storage Space**: Cleaned up 15GB of old backup files
5. **Backup File Discovery**: Enhanced script to find files in `/tmp/production-restore-*`

## ⚠️ **Remaining Tasks:**

### **1. BigQuery Authentication (High Priority)**
- **Issue**: `403 ACCESS_TOKEN_SCOPE_INSUFFICIENT` when querying BigQuery
- **Cause**: Cleared encrypted credentials during decryption fix
- **Solution**: Reconfigure BigQuery connections in Superset UI:
  1. Login to http://superset.getbower.com
  2. Go to Settings → Database Connections
  3. Edit BigQuery connections
  4. Add service account credentials or use VM service account

### **2. HTTPS Domain Access (Medium Priority)**
- **Issue**: https://superset.getbower.com not accessible
- **Cause**: Nginx configuration needs restart with new SSL config
- **Solution**: Restart nginx on VM with updated configuration

### **3. Environment Variables Warnings (Low Priority)**
- **Issue**: Docker Compose warnings about missing variables
- **Solution**: Update VM `.env` file with production template

## 🚀 **Deployment Commands:**

### **Deploy New Version:**
```bash
./restore-and-deploy-production.sh production-backup-20250820-145211/
```

### **Validate Deployment:**
```bash
./validate-production-deployment.sh
```

### **Check Status:**
```bash
# Via IP
curl http://34.88.142.154/health

# Via domain
curl http://superset.getbower.com/health
curl https://superset.getbower.com/health
```

### **View Logs:**
```bash
gcloud compute ssh bower-superset --zone=europe-north1-a --command="cd /root/superset && docker compose logs -f superset"
```

## 📊 **Production Access:**

- **Primary URL**: http://superset.getbower.com
- **Backup URL**: http://34.88.142.154
- **Username**: admin
- **Password**: admin

## 🛡️ **Security Notes:**

1. **SSL Certificates**: Let's Encrypt certificates configured (expires 2025-11-18)
2. **Service Account**: VM uses `bower-analytics-superset@bower-eu-data-warehouse.iam.gserviceaccount.com`
3. **Secrets**: Managed via `.env` file on VM (not in repository)
4. **Backups**: Automatic cleanup keeps only recent backups

## 🔄 **Maintenance:**

1. **SSL Renewal**: Automatic via certbot
2. **Backup Cleanup**: Automatic via deployment scripts  
3. **Health Monitoring**: Built into deployment scripts
4. **Log Rotation**: Configured for 14-day retention
