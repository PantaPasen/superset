# BigQuery Setup Guide for Apache Superset

## Overview
BigQuery support has been enabled in your Superset production environment. This guide will help you configure BigQuery connections and optimize performance.

## Prerequisites

### 1. BigQuery Dependencies
The following packages are now included in your production environment:
- `pandas-gbq>=0.19.1` - For data uploads and enhanced BigQuery integration
- `sqlalchemy-bigquery>=1.6.1` - SQLAlchemy dialect for BigQuery
- `google-cloud-bigquery>=3.10.0` - Google Cloud BigQuery client library

### 2. Google Cloud Setup
1. **Create a Google Cloud Project** (if you don't have one)
2. **Enable the BigQuery API** in your project
3. **Create a Service Account** with the following permissions:
   - BigQuery Data Viewer
   - BigQuery Metadata Viewer
   - BigQuery Job User
   - BigQuery Read Session User (for optimal performance)

## Configuration Steps

### Step 1: Create Service Account Credentials

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to "IAM & Admin" > "Service Accounts"
3. Click "Create Service Account"
4. Fill in the details and click "Create and Continue"
5. Assign the required roles (listed above)
6. Click "Create Key" and download the JSON file
7. Keep this JSON file secure - you'll need its contents

### Step 2: Configure BigQuery Connection in Superset

1. **Access Superset Admin Panel**
   - Go to "Settings" > "Database Connections"
   - Click "Add Database"

2. **Basic Connection Settings**
   - **Database Type**: Select "Google BigQuery"
   - **Database Name**: Choose a descriptive name (e.g., "Production BigQuery")
   - **SQLAlchemy URI**: `bigquery://{your-project-id}`
   - Replace `{your-project-id}` with your actual Google Cloud project ID

3. **Advanced Configuration**
   - Click on the "Advanced" tab
   - In the "Secure Extra" field, add the following JSON structure:

```json
{
  "credentials_info": {
    "type": "service_account",
    "project_id": "your-project-id",
    "private_key_id": "key-id-from-json-file",
    "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
    "client_email": "service-account-email@your-project.iam.gserviceaccount.com",
    "client_id": "client-id-from-json-file",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs/service-account-email%40your-project.iam.gserviceaccount.com"
  }
}
```

4. **Test the Connection**
   - Click "Test Connection" to verify the setup
   - You should see a success message

### Step 3: Performance Optimization

Your production configuration includes the following BigQuery optimizations:

```python
# BigQuery-specific performance settings
BIGQUERY_RESULTS_BACKEND_TIMEOUT = 300  # 5 minutes timeout for BigQuery queries
BIGQUERY_QUERY_COST_ESTIMATION_ENABLED = True  # Enable cost estimation
```

## Security Best Practices

### 1. Service Account Security
- **Principle of Least Privilege**: Only grant necessary permissions
- **Regular Rotation**: Rotate service account keys periodically
- **Secure Storage**: Store credentials securely in your production environment

### 2. Data Access Control
- Use BigQuery's built-in row-level security features
- Implement dataset-level permissions in Google Cloud
- Consider using authorized views for sensitive data

### 3. Cost Management
- **Query Cost Estimation**: Enabled by default in your configuration
- **Set up billing alerts** in Google Cloud Console
- **Use partitioned tables** for better performance and cost control
- **Monitor query costs** regularly through BigQuery console

## Common Connection Patterns

### 1. Multiple Projects
To connect to multiple BigQuery projects, create separate database connections:

```
Database 1: bigquery://project-analytics
Database 2: bigquery://project-marketing
Database 3: bigquery://project-operations
```

### 2. Cross-Project Queries
BigQuery supports cross-project queries. You can reference tables from other projects:

```sql
SELECT * FROM `other-project.dataset.table`
WHERE date >= '2024-01-01'
```

### 3. Using BigQuery with Superset Features

#### SQL Lab
- Write and test queries in SQL Lab
- Use BigQuery's standard SQL syntax
- Leverage BigQuery functions like `APPROX_COUNT_DISTINCT()`, `ARRAY_AGG()`, etc.

#### Chart Creation
- Create charts directly from BigQuery datasets
- Use BigQuery's analytical functions for complex visualizations
- Take advantage of BigQuery's fast aggregation capabilities

#### Dashboard Building
- Build real-time dashboards with BigQuery data
- Use native filters for interactive dashboards
- Implement cross-filtering across multiple BigQuery datasets

## Performance Tips

### 1. Query Optimization
- Use `LIMIT` clauses for exploratory queries
- Leverage BigQuery's partitioned tables
- Use clustering for frequently filtered columns
- Consider materialized views for complex aggregations

### 2. Caching Strategy
Your production configuration includes optimized caching:
- Query results cached for 24 hours by default
- Dashboard cache enabled
- Filter state cached for faster interactions

### 3. Async Query Processing
- Large queries run asynchronously
- Users can continue working while queries execute
- Results are cached for future use

## Troubleshooting

### Common Issues and Solutions

1. **Authentication Errors**
   - Verify service account permissions
   - Check that the JSON credentials are correctly formatted
   - Ensure the service account has access to the specific datasets

2. **Query Timeouts**
   - Increase `BIGQUERY_RESULTS_BACKEND_TIMEOUT` if needed
   - Optimize queries for better performance
   - Consider breaking large queries into smaller parts

3. **Cost Concerns**
   - Monitor query costs in Google Cloud Console
   - Use the cost estimation feature before running expensive queries
   - Implement query limits and approval workflows

4. **Performance Issues**
   - Check if tables are partitioned and clustered
   - Review query execution plans in BigQuery console
   - Consider using BigQuery's BI Engine for faster dashboard queries

### Getting Help

- **BigQuery Documentation**: https://cloud.google.com/bigquery/docs
- **Superset Documentation**: https://superset.apache.org/docs/databases/bigquery
- **Google Cloud Support**: Available through Google Cloud Console

## Migration Notes

If you're migrating from a previous Superset installation:

1. **Export existing database connections** before upgrading
2. **Test BigQuery connections** in a staging environment first
3. **Update any custom SQL** to use BigQuery's standard SQL syntax
4. **Verify dashboard functionality** after migration

## Environment Variables

You can also configure BigQuery connections using environment variables:

```bash
# BigQuery specific environment variables
export BIGQUERY_PROJECT_ID="your-project-id"
export BIGQUERY_CREDENTIALS_PATH="/path/to/service-account.json"
export BIGQUERY_TIMEOUT="300"
```

This guide should help you successfully integrate BigQuery with your Superset production environment. Remember to test thoroughly in a staging environment before deploying to production. 