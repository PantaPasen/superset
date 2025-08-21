#!/bin/bash
# Default environment variables for Superset Docker Compose
# Source this file to set default values and prevent warnings

# Database Configuration
export POSTGRES_DB="${POSTGRES_DB:-superset}"
export POSTGRES_USER="${POSTGRES_USER:-superset}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-superset}"

# Superset Configuration
export SUPERSET_LOG_LEVEL="${SUPERSET_LOG_LEVEL:-info}"
export SUPERSET_LOAD_EXAMPLES="${SUPERSET_LOAD_EXAMPLES:-no}"

# Celery Configuration
export CELERYD_CONCURRENCY="${CELERYD_CONCURRENCY:-2}"

# Development/Testing Configuration
export CYPRESS_CONFIG="${CYPRESS_CONFIG:-}"

# Build Configuration
export SUPERSET_BUILD_TARGET="${SUPERSET_BUILD_TARGET:-dev}"
export DEV_MODE="${DEV_MODE:-false}"

# Docker Registry (if using uploaded compose)
export DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
export IMAGE_NAME="${IMAGE_NAME:-superset}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "✅ Default environment variables set for Superset Docker Compose"
