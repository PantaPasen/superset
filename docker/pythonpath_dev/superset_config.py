# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# This file is included in the final Docker image and SHOULD be overridden when
# deploying the image to prod. Settings configured here are intended for use in local
# development environments. Also note that superset_config_docker.py is imported
# as a final step as a means to override "defaults" configured here
#
import datetime
import logging
import os
import random
import sys
import uuid

from celery.schedules import crontab
from flask_caching.backends.filesystemcache import FileSystemCache

logger = logging.getLogger()

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================
# Get SECRET_KEY from environment variable - REQUIRED for Superset to work
SECRET_KEY = os.getenv("SUPERSET__SECRET_KEY")
if not SECRET_KEY or SECRET_KEY in [
    "CHANGE_ME_TO_A_COMPLEX_RANDOM_SECRET_KEY_GENERATED_WITH_OPENSSL",
    "CHANGE-ME-IN-PRODUCTION-USE-OPENSSL-RAND-BASE64-42",
    "CHANGE_ME"
]:
    logger.error("❌ SECRET_KEY is not properly configured!")
    logger.error("Set SUPERSET__SECRET_KEY environment variable with a secure random key")
    logger.error("Generate one with: openssl rand -base64 42")
    raise RuntimeError("SECRET_KEY must be configured before starting Superset")

logger.info("✅ SECRET_KEY configured from environment variable")

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
DATABASE_DIALECT = os.getenv("DATABASE_DIALECT")
DATABASE_USER = os.getenv("DATABASE_USER")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD")
DATABASE_HOST = os.getenv("DATABASE_HOST")
DATABASE_PORT = os.getenv("DATABASE_PORT")
DATABASE_DB = os.getenv("DATABASE_DB")

EXAMPLES_USER = os.getenv("EXAMPLES_USER")
EXAMPLES_PASSWORD = os.getenv("EXAMPLES_PASSWORD")
EXAMPLES_HOST = os.getenv("EXAMPLES_HOST")
EXAMPLES_PORT = os.getenv("EXAMPLES_PORT")
EXAMPLES_DB = os.getenv("EXAMPLES_DB")

# The SQLAlchemy connection string.
SQLALCHEMY_DATABASE_URI = (
    f"{DATABASE_DIALECT}://"
    f"{DATABASE_USER}:{DATABASE_PASSWORD}@"
    f"{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
)

SQLALCHEMY_EXAMPLES_URI = (
    f"{DATABASE_DIALECT}://"
    f"{EXAMPLES_USER}:{EXAMPLES_PASSWORD}@"
    f"{EXAMPLES_HOST}:{EXAMPLES_PORT}/{EXAMPLES_DB}"
)

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = os.getenv("REDIS_PORT", "6379")
REDIS_CELERY_DB = os.getenv("REDIS_CELERY_DB", "0")
REDIS_RESULTS_DB = os.getenv("REDIS_RESULTS_DB", "1")

# Results backend for SQL Lab
RESULTS_BACKEND = FileSystemCache("/app/superset_home/sqllab")

# =============================================================================
# THUMBNAIL AND SCREENSHOT CACHE CONFIGURATION
# =============================================================================
# CRITICAL: Thumbnail cache is required for PDF/screenshot functionality
THUMBNAIL_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,  # 24 hours
    "CACHE_KEY_PREFIX": "thumbnail_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": REDIS_RESULTS_DB,
}

# =============================================================================
# THUMBNAIL EXECUTORS CONFIGURATION
# =============================================================================
# CRITICAL: This defines who can generate thumbnails and how
# Import the new executor types
from superset.tasks.types import ExecutorType, FixedExecutor

THUMBNAIL_EXECUTORS = [
    ExecutorType.CURRENT_USER,      # Use current user for thumbnails
    FixedExecutor("admin"),         # Fallback to admin user
]

# =============================================================================
# THUMBNAIL GENERATION SETTINGS
# =============================================================================
# Enable automatic thumbnail generation
THUMBNAIL_SELENIUM_USER = "admin"           # Default user for selenium thumbnails
THUMBNAIL_EXECUTE_AS = [                    # Users who can execute thumbnails
    "Admin",
    "Alpha", 
    "Gamma"
]

# Thumbnail sizes - optimized for list views
THUMBNAIL_DEFAULT_SIZE = (400, 300)         # Default thumbnail size
CHART_THUMBNAIL_SIZE = (400, 300)           # Chart thumbnail size  
DASHBOARD_THUMBNAIL_SIZE = (400, 300)       # Dashboard thumbnail size

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": REDIS_RESULTS_DB,
}
DATA_CACHE_CONFIG = CACHE_CONFIG


class CeleryConfig:
    broker_url = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}"
    imports = (
        "superset.sql_lab",
        "superset.tasks.scheduler",
        "superset.tasks.thumbnails",  # CRITICAL: Required for screenshot tasks
        "superset.tasks.cache",
        "superset.tasks.celery_app",
    )
    result_backend = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_RESULTS_DB}"
    worker_prefetch_multiplier = 1
    task_acks_late = False
    task_always_eager = False                   # IMPORTANT: Must be False for async tasks
    task_eager_propagates = True
    task_serializer = 'json'
    result_serializer = 'json'
    accept_content = ['json']
    timezone = 'UTC'
    enable_utc = True
    
    # Task routing for screenshot tasks - disabled to use default queue
    # task_routes = {
    #     'cache_dashboard_screenshot': {'queue': 'thumbnails'},
    #     'cache_dashboard_thumbnail': {'queue': 'thumbnails'},
    #     'cache_chart_thumbnail': {'queue': 'thumbnails'},
    # }
    
    beat_schedule = {
        "reports.scheduler": {
            "task": "reports.scheduler",
            "schedule": crontab(minute="*", hour="*"),
        },
        "reports.prune_log": {
            "task": "reports.prune_log",
            "schedule": crontab(minute=10, hour=0),
        },
    }


CELERY_CONFIG = CeleryConfig

# =============================================================================
# FILE UPLOAD CONFIGURATION
# =============================================================================
# Enable file upload functionality
UPLOAD_FOLDER = "/app/superset_home/uploads/"
IMG_UPLOAD_FOLDER = "/app/superset_home/uploads/"
IMG_UPLOAD_URL = "/static/uploads/"

# File size limits (100MB default)
MAX_CONTENT_LENGTH = 100 * 1024 * 1024

# Allowed file extensions for uploads
EXCEL_EXTENSIONS = {"xlsx", "xls"}
CSV_EXTENSIONS = {"csv", "tsv", "txt"}
COLUMNAR_EXTENSIONS = {"parquet", "zip"}
ALLOWED_EXTENSIONS = {*EXCEL_EXTENSIONS, *CSV_EXTENSIONS, *COLUMNAR_EXTENSIONS}

# CSV export options
CSV_EXPORT = {
    "encoding": "utf-8",
    "index": False,
    "date_format": "%Y-%m-%d %H:%M:%S",
}

# Schema configuration for CSV uploads
# You can specify which schemas are allowed for file uploads
ALLOWED_USER_CSV_SCHEMA_FUNC = lambda database, user: []  # Allow all schemas by default

# =============================================================================
# ADDITIONAL NOTES FOR ENABLING CSV UPLOADS
# =============================================================================
# After restarting Superset with this configuration:
# 1. Go to Data → Databases in the Superset UI
# 2. Edit your database connection 
# 3. In the "Extra" tab, check "Allow file uploads to database"
# 4. Save the database configuration
# 
# This enables file uploads for that specific database connection.

# =============================================================================
# MODERN FEATURE FLAGS - COMPREHENSIVE BEST PRACTICES
# =============================================================================
# Organized by category for better maintainability and understanding

FEATURE_FLAGS = {
    # =============================================================================
    # CORE PERFORMANCE & ANALYTICS
    # =============================================================================
    "DYNAMIC_PLUGINS": True,                    # Enable dynamic plugin loading
    "ENABLE_TEMPLATE_PROCESSING": True,         # Enable Jinja templating in SQL
    "DASHBOARD_VIRTUALIZATION": True,           # Improve dashboard performance
    "GLOBAL_ASYNC_QUERIES": False,              # Async queries (requires Celery setup)
    "DASHBOARD_CACHE": True,                    # Enable dashboard caching
    "PRESTO_EXPAND_DATA": True,                 # Expand nested Presto data types
    "OPTIMIZE_SQL": True,                       # SQL query optimization
    
    # =============================================================================
    # MODERN UI/UX FEATURES
    # =============================================================================
    "LISTVIEWS_DEFAULT_CARD_VIEW": True,        # Modern card view for lists
    "HORIZONTAL_FILTER_BAR": True,              # Horizontal filter layout
    "DATAPANEL_CLOSED_BY_DEFAULT": False,       # Keep data panel open
    "DASHBOARD_EDIT_CHART_IN_NEW_TAB": True,    # Edit charts in new tab
    "AVOID_COLORS_COLLISION": True,             # Better color management
    "USE_ANALOGOUS_COLORS": True,               # Improved color schemes
    
    # =============================================================================
    # THUMBNAIL UI FEATURES
    # =============================================================================
    "THUMBNAILS_SQLA_LISTENERS": True,          # Enable SQLAlchemy listeners for auto-thumbnails
    "THUMBNAILS_DASHBOARD_DIGEST": True,        # Enable dashboard digest for thumbnails
    "THUMBNAILS_CHART_DIGEST": True,            # Enable chart digest for thumbnails
    
    # =============================================================================
    # ADVANCED DATA FEATURES
    # =============================================================================
    "ENABLE_ADVANCED_DATA_TYPES": True,         # Support for advanced data types
    "ENABLE_EXPLORE_DRAG_AND_DROP": True,       # Drag & drop in explore view
    "ENABLE_DATASET_HEALTH_CHECK": True,        # Dataset health monitoring
    "VERSIONED_EXPORT": True,                   # Version control for exports
    "DRILL_BY": True,                           # Drill-by functionality
    "EMBEDDABLE_CHARTS": True,                  # Chart embedding capability
    "GENERIC_CHART_AXES": True,                 # Generic chart axis support
    
    # =============================================================================
    # SECURITY & GOVERNANCE
    # =============================================================================
    "DASHBOARD_RBAC": True,                     # Role-based access control
    "ROW_LEVEL_SECURITY": True,                 # Row-level security
    "ENABLE_ROW_LEVEL_SECURITY": True,          # Enable RLS features
    "RLS_IN_SQLLAB": False,                     # RLS in SQL Lab (careful - can break queries)
    "CACHE_QUERY_BY_USER": True,                # Per-user query caching
    "CACHE_IMPERSONATION": True,                # Cache per impersonation key
    "ESCAPE_MARKDOWN_HTML": True,               # Security: escape HTML in markdown
    
    # =============================================================================
    # EXPORT & REPORTING
    # =============================================================================
    "ALERT_REPORTS": True,                      # Enable alerts and reports
    "THUMBNAILS": True,                         # Dashboard thumbnails
    "ENABLE_DASHBOARD_SCREENSHOT_ENDPOINTS": True,  # Screenshot endpoints (fixed typo)
    "ENABLE_DASHBOARD_DOWNLOAD_WEBDRIVER_SCREENSHOT": True,  # PDF/image export
    "ALLOW_FULL_CSV_EXPORT": True,              # Full CSV export capability
    "ALERTS_ATTACH_REPORTS": True,              # Attach screenshots to alerts
    "PLAYWRIGHT_REPORTS_AND_THUMBNAILS": False, # Use Playwright instead of Selenium
    "DATE_FORMAT_IN_EMAIL_SUBJECT": True,       # Custom date formats in emails
    
    # =============================================================================
    # INTEGRATION & EMBEDDING
    # =============================================================================
    "EMBEDDED_SUPERSET": True,                  # Enable embedding capabilities
    "SHARE_QUERIES_VIA_KV_STORE": True,         # Share queries via key-value store
    "SQLLAB_BACKEND_PERSISTENCE": True,         # Persist SQL Lab state
    "SSH_TUNNELING": True,                      # SSH tunnel support
    
    # =============================================================================
    # EXPERIMENTAL FEATURES (Use with caution)
    # =============================================================================
    "TAGGING_SYSTEM": True,                     # Content tagging system
    "CHART_PLUGINS_EXPERIMENTAL": False,        # Experimental chart plugins
    "ENABLE_SUPERSET_META_DB": False,           # Cross-database queries (security risk)
    "ESTIMATE_QUERY_COST": True,                # Query cost estimation
    
    # =============================================================================
    # DEVELOPMENT & DEBUGGING
    # =============================================================================
    "CONFIRM_DASHBOARD_DIFF": True,             # Confirm dashboard changes
    "MENU_HIDE_USER_INFO": False,               # Show user info in menu
    "SLACK_ENABLE_AVATARS": False,              # Slack avatar integration
}

# =============================================================================
# WEBDRIVER CONFIGURATION FOR PDF/SCREENSHOT GENERATION
# =============================================================================
# WebDriver type - Chrome is recommended for production
WEBDRIVER_TYPE = "chrome"

# Chrome/Chromium options for headless operation
WEBDRIVER_OPTION_ARGS = [
    "--headless",                           # Run in headless mode
    "--no-sandbox",                         # Required for Docker environments
    "--disable-dev-shm-usage",              # Overcome limited resource problems
    "--disable-gpu",                        # Disable GPU acceleration
    "--disable-setuid-sandbox",             # Required for some environments
    "--disable-extensions",                 # Disable browser extensions
    "--disable-web-security",               # Allow cross-origin requests
    "--disable-features=VizDisplayCompositor",  # Disable compositor
    "--force-device-scale-factor=2.0",      # High DPI for better quality
    "--high-dpi-support=2.0",               # Enable high DPI support
    "--window-size=1920,1080",              # Set default window size
    "--disable-background-timer-throttling", # Prevent throttling
    "--disable-backgrounding-occluded-windows",
    "--disable-renderer-backgrounding",
    "--disable-ipc-flooding-protection",
    "--enable-logging",                     # Enable logging for debugging
    "--log-level=0",                        # Set log level
    "--v=1",                                # Verbose logging
]

# Window sizes for different content types
WEBDRIVER_WINDOW = {
    "dashboard": (1920, 1080),              # Standard dashboard size
    "slice": (1600, 1200),                  # Chart/slice size
    "pixel_density": 2,                     # Retina display quality
}

# Advanced WebDriver configuration
WEBDRIVER_CONFIGURATION = {
    "service_args": [
        "--verbose",                        # Verbose ChromeDriver logging
        "--log-path=/tmp/chromedriver.log", # Log file location
    ],
}

# Base URL for screenshot generation - CRITICAL for production
WEBDRIVER_BASEURL = "http://superset:8088/"  # Internal Docker service URL
WEBDRIVER_BASEURL_USER_FRIENDLY = "https://superset.getbower.com/"  # External URL for links
# =============================================================================
# PERFORMANCE OPTIMIZATION SETTINGS
# =============================================================================
# Row limits for better performance and user experience
ROW_LIMIT = 50000                           # Default row limit for charts
VIZ_ROW_LIMIT = 10000                       # Row limit for visualizations
SAMPLES_ROW_LIMIT = 1000                    # Row limit for data samples
NATIVE_FILTER_DEFAULT_ROW_LIMIT = 10000     # Native filter row limit
FILTER_SELECT_ROW_LIMIT = 10000             # Filter dropdown row limit

# Query timeout settings (in seconds)
SUPERSET_WEBSERVER_TIMEOUT = 300           # 5 minutes for web requests
SQLLAB_TIMEOUT = 600                        # 10 minutes for SQL Lab queries
SQLLAB_ASYNC_TIME_LIMIT_SEC = 1800          # 30 minutes for async queries

# Database connection settings
SQLALCHEMY_ENGINE_OPTIONS = {
    "pool_pre_ping": True,                  # Validate connections before use
    "pool_recycle": 300,                    # Recycle connections every 5 minutes
    "pool_timeout": 20,                     # Connection timeout
    "max_overflow": 0,                      # No connection overflow
}

# =============================================================================
# ADVANCED SECURITY SETTINGS
# =============================================================================
# Content Security Policy for better security
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    "force_https": False,                   # Set to True in production with HTTPS
    "content_security_policy": {
        "default-src": ["'self'"],
        "img-src": ["'self'", "data:", "https:"],
        "script-src": ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        "style-src": ["'self'", "'unsafe-inline'"],
        "connect-src": ["'self'"],
        "frame-src": ["'self'"],
        "font-src": ["'self'", "data:"],
    },
}

# Session configuration
PERMANENT_SESSION_LIFETIME = 86400          # 24 hours session timeout
SESSION_COOKIE_SECURE = False              # Set to True in production with HTTPS
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"

# CSRF Configuration for login forms (using defaults)
# WTF_CSRF_ENABLED = True  # Use Flask-AppBuilder defaults
# WTF_CSRF_TIME_LIMIT = 3600
# WTF_CSRF_SSL_STRICT = False

# Flask-AppBuilder login configuration (using defaults)
# FAB_UPDATE_PERMS = True  # Use Flask-AppBuilder defaults

# =============================================================================
# PRODUCTION SECURITY SETTINGS
# =============================================================================
# CRITICAL: Disable debug mode in production for security
DEBUG = False
FLASK_USE_RELOAD = False

# Ensure production environment
import os
os.environ["FLASK_DEBUG"] = "false"
os.environ["SUPERSET_ENV"] = "production"

# Enable rate limiting in production
RATELIMIT_ENABLED = True

# Hide stacktraces in production for security
SHOW_STACKTRACE = False

# Enhanced security settings
ENABLE_PROXY_FIX = True  # Trust X-Forwarded headers from nginx
PROXY_FIX_CONFIG = {"x_for": 1, "x_proto": 1, "x_host": 1, "x_port": 1, "x_prefix": 1}

# Additional security headers and settings
TALISMAN_ENABLED = True
TALISMAN_CONFIG = {
    "force_https": False,  # nginx handles HTTPS termination
    "content_security_policy": {
        "default-src": "'self'",
        "script-src": "'self' 'unsafe-inline' 'unsafe-eval'",
        "style-src": "'self' 'unsafe-inline'",
        "img-src": "* data: blob:",  # Added blob: for thumbnails
        "connect-src": "'self'",
        "font-src": "'self'",
        "object-src": "'none'",
        "media-src": "'self'",
        "frame-src": "'none'",
    }
}

# =============================================================================
# MODERN UI/UX CONFIGURATIONS
# =============================================================================
# Default time zone
DEFAULT_TIME_ZONE = "UTC"

# Custom CSS and branding
APP_NAME = "Bower Analytics Platform"
APP_ICON = "/static/assets/branding/google-play-developer-header.png"

# Modern color palette
SUPERSET_WEBSERVER_DOMAINS = None          # Allow all domains for development

# Chart and dashboard defaults
DEFAULT_CHART_HEIGHT = 600
DEFAULT_DASHBOARD_GRID_UNIT = 40

# =============================================================================
# DATA SOURCE AND ANALYTICS SETTINGS
# =============================================================================
# Enable cross-filter interactions
DASHBOARD_CROSS_FILTERS = True

# Advanced analytics features
ENABLE_JAVASCRIPT_CONTROLS = False         # Disabled for security
ENABLE_CORS = True                          # Enable CORS for API access
CORS_OPTIONS = {
    "origins": ["http://localhost:3000", "http://127.0.0.1:3000"],
    "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    "allow_headers": ["Content-Type", "Authorization"],
}

# =============================================================================
# ALERT AND REPORTING CONFIGURATION
# =============================================================================
ALERT_REPORTS_NOTIFICATION_DRY_RUN = False  # Set to False to enable actual reports

# Email configuration for alerts (configure based on your SMTP settings)
EMAIL_NOTIFICATIONS = True
SMTP_HOST = "localhost"
SMTP_STARTTLS = True
SMTP_SSL = False
SMTP_USER = "superset"
SMTP_PORT = 587
SMTP_PASSWORD = "LAsxWOT8GHXbmQmDyBb9rWTIWpXDc3GAdVW6-euYBvY"
SMTP_MAIL_FROM = "lucas@getbower.com"

# =============================================================================
# SQL LAB ADVANCED SETTINGS
# =============================================================================
SQLLAB_CTAS_NO_LIMIT = True
SQLLAB_VALIDATION_TIMEOUT = 10              # SQL validation timeout
SQLLAB_DEFAULT_DBID = None                  # Default database for SQL Lab

# Query result storage
RESULTS_BACKEND_USE_MSGPACK = True          # Use MessagePack for better performance
RESULTS_BACKEND_USE_COMPRESSION = True      # Compress query results

# =============================================================================
# LOGGING CONFIGURATION
# =============================================================================
# Enhanced logging for better monitoring
ENABLE_TIME_ROTATE = True
LOG_FORMAT = "%(asctime)s:%(levelname)s:%(name)s:%(message)s"
LOG_LEVEL = "INFO"

# Audit logging
ENABLE_ACCESS_REQUEST = True                # Log access requests
FAB_ADD_SECURITY_VIEWS = True              # Add security views to menu

# =============================================================================
# INTERNATIONALIZATION & LOCALIZATION
# =============================================================================
# Language settings
LANGUAGES = {
    'en': {'flag': 'us', 'name': 'English'}
}
BABEL_DEFAULT_LOCALE = 'en'
BABEL_DEFAULT_FOLDER = 'superset/translations'

# =============================================================================
# ADVANCED CACHING STRATEGIES
# =============================================================================
# Metadata cache for better performance
CACHE_DEFAULT_TIMEOUT = 86400              # 24 hours default cache timeout
EXPLORE_FORM_DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "explore_form_data_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": REDIS_RESULTS_DB,
}

# Filter state cache
FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_KEY_PREFIX": "filter_state_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": REDIS_RESULTS_DB,
}

# =============================================================================
# ADDITIONAL THUMBNAIL CONFIGURATIONS
# =============================================================================
# Thumbnail generation intervals and settings
THUMBNAIL_CACHE_TIMEOUT = 86400 * 7          # 7 days cache timeout for thumbnails
THUMBNAIL_FORCE_REFRESH = False              # Don't force refresh by default
THUMBNAIL_COMPUTE_ASYNC = True               # Generate thumbnails asynchronously

# Enable thumbnail generation on save/update
ENABLE_THUMBNAILS_ON_SAVE = True             # Generate thumbnails when saving dashboards/charts

# =============================================================================
# MODERN DASHBOARD FEATURES
# =============================================================================
# Native filters configuration
DASHBOARD_NATIVE_FILTERS_SET = {
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "HORIZONTAL_FILTER_BAR": True,
}

# Dashboard auto-refresh settings
DASHBOARD_AUTO_REFRESH_MODE = "change"      # Options: "change", "force", "fetch"
DASHBOARD_AUTO_REFRESH_INTERVALS = [
    [0, "Don't refresh"],
    [10, "10 seconds"],
    [30, "30 seconds"],
    [60, "1 minute"],
    [300, "5 minutes"],
    [1800, "30 minutes"],
    [3600, "1 hour"],
]

# =============================================================================
# API AND INTEGRATION SETTINGS
# =============================================================================
# REST API configuration
ENABLE_PROXY_FIX = True                     # Enable proxy fix for reverse proxy setups
FAB_API_SWAGGER_UI = True                   # Enable Swagger UI for API documentation

# Rate limiting (if needed)
RATELIMIT_ENABLED = False                   # Set to True to enable rate limiting
RATELIMIT_STORAGE_URL = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_CELERY_DB}"

# =============================================================================
# CUSTOM ROLES AND PERMISSIONS
# =============================================================================
# Custom role definitions for better access control
CUSTOM_SECURITY_MANAGER = None              # Use default security manager

# Public role permissions (for embedded use cases)
# SECURITY: Disabled for production - all users must authenticate
PUBLIC_ROLE_LIKE = None                     # No public access - force authentication

# =============================================================================
# PRODUCTION AUTHENTICATION SECURITY SETTINGS
# =============================================================================
# CRITICAL: These settings ensure production security

# Disable public role - no unauthenticated access
# AUTH_ROLE_PUBLIC = None  # Don't set this - causes NULL role creation

# Disable user self-registration - admin must create accounts
AUTH_USER_REGISTRATION = False              # Disable self-registration for security

# If registration were enabled (not recommended), default role would be:
# AUTH_USER_REGISTRATION_ROLE = "Gamma"    # Lowest privilege role

# =============================================================================
# ADVANCED QUERY SETTINGS
# =============================================================================
# SQL templating - Additional context for Jinja templates
JINJA_CONTEXT_ADDONS = {
    'datetime': datetime,
    'random': random,
    'uuid': uuid,
}

# Query validation
SQL_MAX_ROW = 100000                        # Maximum rows for SQL queries
QUERY_SEARCH_LIMIT = 1000                   # Limit for query search results

# =============================================================================
# MONITORING AND HEALTH CHECKS
# =============================================================================
# Health check endpoint
HEALTH_CHECK_ENDPOINT = "/health"

# Metrics and monitoring
ENABLE_CHUNK_ENCODING = True                # Enable chunked encoding for large responses

log_level_text = os.getenv("SUPERSET_LOG_LEVEL", "INFO")
LOG_LEVEL = getattr(logging, log_level_text.upper(), logging.INFO)

if os.getenv("CYPRESS_CONFIG") == "true":
    # When running the service as a cypress backend, we need to import the config
    # located @ tests/integration_tests/superset_test_config.py
    base_dir = os.path.dirname(__file__)
    module_folder = os.path.abspath(
        os.path.join(base_dir, "../../tests/integration_tests/")
    )
    sys.path.insert(0, module_folder)
    from superset_test_config import *  # noqa

    sys.path.pop(0)

#
# Optionally import superset_config_docker.py (which will have been included on
# the PYTHONPATH) in order to allow for local settings to be overridden
#
try:
    import superset_config_docker
    from superset_config_docker import *  # noqa

    logger.info(
        f"Loaded your Docker configuration at " f"[{superset_config_docker.__file__}]"
    )
except ImportError:
    logger.info("Using default Docker config...")

# =============================================================================
# PDF/SCREENSHOT TROUBLESHOOTING GUIDE
# =============================================================================
"""
🔧 THUMBNAIL & PDF TROUBLESHOOTING GUIDE

If thumbnails aren't showing in dashboard/chart lists or PDF downloads are failing:

THUMBNAIL ISSUES:
=================
1. GENERATE THUMBNAILS:
   Run the thumbnail generation script:
   ```
   ./generate-thumbnails.sh
   ```

2. MANUAL THUMBNAIL GENERATION:
   For all dashboards and charts:
   ```
   docker compose exec superset superset compute-thumbnails --asynchronous
   ```
   
   For specific dashboard:
   ```
   docker compose exec superset superset compute-thumbnails --dashboards_only --model_id DASHBOARD_ID
   ```

3. CHECK THUMBNAIL CACHE:
   Verify thumbnails are in Redis:
   ```
   docker compose exec redis redis-cli --scan --pattern "thumbnail_*"
   ```

4. VERIFY FEATURE FLAGS:
   Ensure THUMBNAILS feature flag is enabled in your config

5. CHECK CELERY WORKERS:
   Monitor thumbnail task processing:
   ```
   docker compose logs -f superset-worker | grep thumbnail
   ```

PDF DOWNLOAD ISSUES:
===================
If PDF downloads are failing with 404 errors, follow these steps:

1. DOCKER BUILD REQUIREMENTS:
   Set INCLUDE_CHROMIUM=true when building:
   ```
   export INCLUDE_CHROMIUM=true
   docker compose build superset
   ```

2. CELERY WORKER REQUIREMENTS:
   Ensure Celery workers are running and can process thumbnail tasks:
   ```
   docker compose logs superset-worker
   ```
   Look for: "cache_dashboard_screenshot", "cache_dashboard_thumbnail"

3. REDIS CONNECTIVITY:
   Verify Redis is accessible from all containers:
   ```
   docker compose exec superset redis-cli -h redis ping
   ```

4. CHROMIUM INSTALLATION:
   In production, ensure Chromium/Chrome is installed in the container:
   ```
   apt-get update && apt-get install -y chromium-browser
   ```

5. MEMORY REQUIREMENTS:
   Screenshot generation requires sufficient memory:
   - Increase worker memory: mem_limit: 2048m in docker-compose.yml
   - Set CELERYD_CONCURRENCY: 1 for memory-constrained environments

6. DEBUGGING STEPS:
   a) Check if screenshot endpoint is available:
      GET /api/v1/dashboard/{id}/cache_dashboard_screenshot/
   
   b) Monitor Celery logs for errors:
      docker compose logs -f superset-worker
   
   c) Verify WebDriver logs:
      Check /tmp/chromedriver.log in the container

🚀 PRODUCTION DEPLOYMENT CHECKLIST:
   ✅ Set INCLUDE_CHROMIUM=true in build
   ✅ Ensure Celery workers are running
   ✅ Configure sufficient memory for workers
   ✅ Set WEBDRIVER_BASEURL to internal service URL
   ✅ Set ALERT_REPORTS_NOTIFICATION_DRY_RUN=False
   ✅ Configure SMTP settings for reports
"""

# =============================================================================
# MODERN SUPERSET CONFIGURATION SUMMARY
# =============================================================================
"""
🚀 MODERN SUPERSET CONFIGURATION SUMMARY

This configuration includes:

✅ PERFORMANCE OPTIMIZATIONS:
   - Optimized row limits and query timeouts
   - Advanced caching strategies (Redis-based)
   - Database connection pooling
   - Query result compression

✅ SECURITY ENHANCEMENTS:
   - Content Security Policy (CSP)
   - Session security settings
   - Row-level security (RLS) support
   - Audit logging enabled

✅ MODERN UI/UX FEATURES:
   - Horizontal filter bar
   - Dashboard virtualization
   - Cross-filtering capabilities
   - Modern card view layouts
   - Improved color management

✅ ADVANCED ANALYTICS:
   - Dynamic plugins support
   - Jinja templating in SQL
   - Advanced data types
   - Drill-by functionality
   - Chart embedding

✅ INTEGRATION CAPABILITIES:
   - REST API with Swagger docs
   - CORS configuration
   - SSH tunneling support
   - Embedded Superset ready

✅ MONITORING & OBSERVABILITY:
   - Enhanced logging
   - Health check endpoints
   - Query cost estimation
   - Performance monitoring

📋 NEXT STEPS FOR PRODUCTION:
   1. Set TALISMAN_CONFIG force_https to True
   2. Configure proper SMTP settings for alerts
   3. Set SESSION_COOKIE_SECURE to True with HTTPS
   4. Review and adjust row limits based on your data volume
   5. Configure proper backup strategies
   6. Set up monitoring and alerting
   7. Review security settings for your environment

🔧 OPTIONAL OPTIMIZATIONS:
   - Enable GLOBAL_ASYNC_QUERIES for better performance (requires Celery)
   - Set up PLAYWRIGHT_REPORTS_AND_THUMBNAILS for better PDF generation
   - Configure custom security manager if needed
   - Set up rate limiting if required

For more information, visit: https://superset.apache.org/docs/
"""
