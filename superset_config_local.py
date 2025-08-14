"""
Modern Apache Superset Local Development Configuration
Updated with latest best practices for local development
"""
import os
import logging
from datetime import timedelta
from flask_caching.backends.filesystemcache import FileSystemCache

# =============================================================================
# LOCAL DEVELOPMENT SETUP
# =============================================================================

# Local Superset home directory
SUPERSET_HOME = os.path.expanduser("~/superset_local")
SQLALCHEMY_DATABASE_URI = f"sqlite:///{SUPERSET_HOME}/superset.db"

# Create directories if they don't exist
os.makedirs(SUPERSET_HOME, exist_ok=True)
os.makedirs(f"{SUPERSET_HOME}/cache", exist_ok=True)
os.makedirs(f"{SUPERSET_HOME}/uploads", exist_ok=True)
os.makedirs(f"{SUPERSET_HOME}/logs", exist_ok=True)

# =============================================================================
# SECURITY CONFIGURATION - LOCAL DEVELOPMENT
# =============================================================================

# Secret key for local development (generate a strong one for production)
SECRET_KEY = os.getenv("SUPERSET__SECRET_KEY", "dev-secret-key-change-in-production-use-openssl-rand-base64-42")

# Enhanced CSRF protection (disabled for easier local development)
WTF_CSRF_ENABLED = False  # Easier for local dev
WTF_CSRF_TIME_LIMIT = int(timedelta(hours=1).total_seconds())

# Session security configuration
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = False  # Allow HTTP for local development
SESSION_COOKIE_SAMESITE = "Lax"
PERMANENT_SESSION_LIFETIME = timedelta(hours=24)

# CORS configuration for local development
ENABLE_CORS = True
CORS_OPTIONS = {
    "supports_credentials": True,
    "allow_headers": [
        "Accept",
        "Accept-Language",
        "Content-Language",
        "Content-Type",
        "Authorization",
        "X-Requested-With",
    ],
    "resources": {
        "/api/*": {"origins": "*"},
        "/superset/csrf_token/": {"origins": "*"},
    },
    "origins": [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:8088",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:8088",
    ],
}

# Rate limiting (disabled for local development)
RATELIMIT_ENABLED = False
AUTH_RATE_LIMITED = False

# =============================================================================
# CACHING CONFIGURATION - ENHANCED FOR LOCAL DEV
# =============================================================================

# Enhanced cache configuration with multiple cache types
CACHE_CONFIG = {
    "CACHE_TYPE": "FileSystemCache",
    "CACHE_DIR": f"{SUPERSET_HOME}/cache",
    "CACHE_DEFAULT_TIMEOUT": 3600,  # 1 hour
    "CACHE_THRESHOLD": 1000,
}

# Data cache configuration for query results
DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "FileSystemCache",
    "CACHE_DIR": f"{SUPERSET_HOME}/cache/data",
    "CACHE_DEFAULT_TIMEOUT": 86400,  # 24 hours for data cache
}

# Explore form data cache
EXPLORE_FORM_DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "FileSystemCache",
    "CACHE_DIR": f"{SUPERSET_HOME}/cache/explore",
    "CACHE_DEFAULT_TIMEOUT": 7200,  # 2 hours
}

# Filter state cache
FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "FileSystemCache",
    "CACHE_DIR": f"{SUPERSET_HOME}/cache/filters",
    "CACHE_DEFAULT_TIMEOUT": 86400,  # 24 hours
}

# Results backend for SQL Lab
RESULTS_BACKEND = FileSystemCache(
    f"{SUPERSET_HOME}/cache/results",
    default_timeout=3600,
    threshold=500,
)

# =============================================================================
# MODERN FEATURE FLAGS - ALL LATEST FEATURES ENABLED
# =============================================================================

FEATURE_FLAGS = {
    # Performance & Analytics
    "DYNAMIC_PLUGINS": True,
    "ENABLE_TEMPLATE_PROCESSING": True,
    "SQLLAB_ASYNC": False,  # Keep simple for local dev
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "HORIZONTAL_FILTER_BAR": True,
    "DASHBOARD_VIRTUALIZATION": True,
    
    # Data Management
    "VERSIONED_EXPORT": True,
    "ENABLE_ADVANCED_DATA_TYPES": True,
    "ENABLE_EXPLORE_DRAG_AND_DROP": True,
    "ENABLE_DATASET_HEALTH_CHECK": True,
    
    # Security & Governance
    "ALERT_REPORTS": False,  # Disabled for local dev to avoid dependencies
    "ROW_LEVEL_SECURITY": True,
    "ENABLE_ROW_LEVEL_SECURITY": True,
    "DASHBOARD_RBAC": True,
    
    # Modern UI/UX
    "LISTVIEWS_DEFAULT_CARD_VIEW": True,
    "ENABLE_EXPLORE_JSON_CSRF_PROTECTION": False,  # Disabled for local dev
    "THUMBNAILS": True,
    "DASHBOARD_EDIT_CHART_IN_NEW_TAB": True,
    
    # API & Integration
    "EMBEDDED_SUPERSET": True,
    "GENERIC_CHART_AXES": True,
    "DASHBOARD_FILTERS_EXPERIMENTAL": True,
    
    # Performance Optimizations
    "GLOBAL_ASYNC_QUERIES": False,  # Disabled for simpler local development
    "DASHBOARD_CACHE": True,
    "PRESTO_EXPAND_DATA": True,
}

# =============================================================================
# PERFORMANCE CONFIGURATION
# =============================================================================

# Row limits for better performance
ROW_LIMIT = 50000
SAMPLES_ROW_LIMIT = 1000
NATIVE_FILTER_DEFAULT_ROW_LIMIT = 10000
FILTER_SELECT_ROW_LIMIT = 10000

# Query timeout settings
SUPERSET_WEBSERVER_TIMEOUT = int(timedelta(minutes=5).total_seconds())
SQLLAB_TIMEOUT = int(timedelta(minutes=10).total_seconds())  # Shorter for local dev
SQLLAB_ASYNC_TIME_LIMIT_SEC = int(timedelta(hours=1).total_seconds())

# Dashboard performance
SUPERSET_DASHBOARD_PERIODICAL_REFRESH_LIMIT = 30  # seconds
SUPERSET_DASHBOARD_POSITION_DATA_LIMIT = 65535

# =============================================================================
# LOCAL DEVELOPMENT SETTINGS
# =============================================================================

# Enable development mode
DEBUG = True
SUPERSET_WEBSERVER_PORT = int(os.getenv("SUPERSET_PORT", "8088"))
SUPERSET_WEBSERVER_ADDRESS = "0.0.0.0"

# Database engine optimization for local development
SQLALCHEMY_ENGINE_OPTIONS = {
    "pool_pre_ping": True,             # Validate connections before use
    "echo": False,                     # Set to True for SQL debugging
    # Note: SQLite doesn't support pool_size, max_overflow, pool_timeout, pool_recycle
    # These are only used with PostgreSQL/MySQL and other production databases
}

# =============================================================================
# FILE UPLOAD CONFIGURATION
# =============================================================================

# File upload settings
UPLOAD_FOLDER = f"{SUPERSET_HOME}/uploads/"
IMG_UPLOAD_FOLDER = f"{SUPERSET_HOME}/uploads/"
IMG_UPLOAD_URL = "/static/uploads/"

# File size limits
MAX_CONTENT_LENGTH = 100 * 1024 * 1024  # 100MB
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

# =============================================================================
# LOGGING CONFIGURATION - SIMPLIFIED FOR LOCAL DEV
# =============================================================================

# Standard logging configuration for local development
ENABLE_TIME_ROTATE = True
TIME_ROTATE_LOG_LEVEL = "DEBUG"
FILENAME = f"{SUPERSET_HOME}/logs/superset.log"

# Set log level
LOG_LEVEL = logging.DEBUG

# =============================================================================
# CELERY CONFIGURATION - SIMPLIFIED FOR LOCAL DEV
# =============================================================================

class CeleryConfig:
    broker_url = f"sqla+{SQLALCHEMY_DATABASE_URI}"
    imports = ("superset.sql_lab",)
    result_backend = f"sqla+{SQLALCHEMY_DATABASE_URI}"
    worker_prefetch_multiplier = 1
    worker_max_tasks_per_child = 50
    task_acks_late = False
    
    # Simplified task routing for local development
    task_routes = {
        "sql_lab.get_sql_results": {"queue": "default"},
        "email_reports.send": {"queue": "default"},
    }

CELERY_CONFIG = CeleryConfig

# =============================================================================
# AUTHENTICATION & AUTHORIZATION
# =============================================================================

# Public role for demo purposes (local development only)
PUBLIC_ROLE_LIKE_GAMMA = True

# OAuth2 configuration template for local development
# Uncomment and configure if you want to test OAuth locally
# 
# from flask_appbuilder.security.manager import AUTH_OAUTH
# AUTH_TYPE = AUTH_OAUTH
# 
# OAUTH_PROVIDERS = [
#     {
#         "name": "google",
#         "icon": "fa-google",
#         "token_key": "access_token",
#         "remote_app": {
#             "client_id": os.environ.get("GOOGLE_KEY"),
#             "client_secret": os.environ.get("GOOGLE_SECRET"),
#             "api_base_url": "https://www.googleapis.com/oauth2/v2/",
#             "client_kwargs": {"scope": "email profile"},
#             "access_token_url": "https://accounts.google.com/o/oauth2/token",
#             "authorize_url": "https://accounts.google.com/o/oauth2/auth",
#         },
#     }
# ]

# =============================================================================
# ADDITIONAL MODERN BI FEATURES
# =============================================================================

# Thumbnail configuration (optional for local dev)
THUMBNAIL_SELENIUM_USER = "admin"
THUMBNAIL_CACHE_CONFIG = CACHE_CONFIG

# Custom CSS for branding (example)
CUSTOM_CSS = """
/* Modern local development styling */
.navbar-brand {
    color: #1890ff !important;
}
.navbar-nav .nav-link {
    color: #666 !important;
}
"""

# =============================================================================
# LOCAL DEVELOPMENT HELPERS
# =============================================================================

# Environment detection
ENVIRONMENT_TAG_CONFIG = {
    "variable": "SUPERSET_ENV",
    "values": {
        "development": {
            "color": "success.base",
            "text": "Local Dev",
        },
    },
}

# Welcome page configuration
WELCOME_PAGE_LAST_TAB = "all"

# =============================================================================
# STARTUP MESSAGES
# =============================================================================

print("🚀 Modern Apache Superset Local Configuration Loaded")
print("=" * 60)
print(f"📁 Data directory: {SUPERSET_HOME}")
print(f"🗄️ Database: {SQLALCHEMY_DATABASE_URI}")
print(f"💾 Cache directory: {SUPERSET_HOME}/cache")
print(f"📋 Logs directory: {SUPERSET_HOME}/logs")
print(f"📤 Upload directory: {SUPERSET_HOME}/uploads")
print(f"🌐 Server: http://localhost:{SUPERSET_WEBSERVER_PORT}")
print("=" * 60)
print("✅ Modern BI Features Enabled:")
print("   • Dashboard Native Filters")
print("   • Cross-Dashboard Filtering")
print("   • Advanced Data Types")
print("   • Row-Level Security")
print("   • Embedded Dashboards")
print("   • Modern UI Components")
print("   • Enhanced Caching")
print("   • Structured Logging")
print("=" * 60)
print("⚠️  Local Development Notes:")
print("   • CSRF protection disabled for easier development")
print("   • CORS enabled for frontend development")
print("   • Debug mode enabled")
print("   • Public role enabled for testing")
print("   • Async queries disabled for simpler setup")
print("   • Use strong SECRET_KEY for production!")
print("=" * 60) 