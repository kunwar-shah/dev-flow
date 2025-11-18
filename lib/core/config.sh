#!/usr/bin/env bash

#######################################
# Configuration Management
# Handles user configuration and site registry
#
# This module provides functions for:
# - Loading and saving user configuration
# - Managing site registry (sites.json)
# - Configuration validation
# - Default configuration creation
#######################################

# Configuration directories
DEVFLOW_CONFIG_DIR="${DEVFLOW_CONFIG_DIR:-$HOME/.devflow}"
DEVFLOW_SITES_FILE="$DEVFLOW_CONFIG_DIR/sites.json"
DEVFLOW_CONFIG_FILE="$DEVFLOW_CONFIG_DIR/config.json"
DEVFLOW_DB_CREDS_FILE="$DEVFLOW_CONFIG_DIR/db-credentials.json"

# Configuration template path
DEVFLOW_CONFIG_TEMPLATE="${DEVFLOW_LIB_DIR}/../config/devflow.conf.json"

# Default configuration values (fallback if template not found)
DEFAULT_WEBSITES_ROOT="$HOME/websites"
DEFAULT_PHP_VERSION="8.2"
DEFAULT_DOCROOT="public"

# Cache for loaded configuration
_CONFIG_CACHE=""
_SITES_CACHE=""

#######################################
# Initialize configuration system
# Creates config directory and default files if needed
# Globals:
#   DEVFLOW_CONFIG_DIR
#   DEVFLOW_CONFIG_FILE
#   DEVFLOW_SITES_FILE
# Returns:
#   0 on success, 1 on error
#######################################
config_init() {
    # Create config directory if it doesn't exist
    if [ ! -d "$DEVFLOW_CONFIG_DIR" ]; then
        mkdir -p "$DEVFLOW_CONFIG_DIR" || return 1
        chmod 700 "$DEVFLOW_CONFIG_DIR"
    fi

    # Create subdirectories
    mkdir -p "$DEVFLOW_CONFIG_DIR"/{ssl/ca,ssl/certs,logs,backup,tmp} 2>/dev/null || true

    # Create default config if it doesn't exist
    if [ ! -f "$DEVFLOW_CONFIG_FILE" ]; then
        config_create_default || return 1
    fi

    # Create empty sites registry if it doesn't exist
    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        echo '{"version":"1.0","sites":[]}' > "$DEVFLOW_SITES_FILE"
    fi

    # Create empty credentials file if it doesn't exist
    if [ ! -f "$DEVFLOW_DB_CREDS_FILE" ]; then
        echo '{"version":"1.0","credentials":[]}' > "$DEVFLOW_DB_CREDS_FILE"
        chmod 600 "$DEVFLOW_DB_CREDS_FILE"
    fi

    return 0
}

#######################################
# Create default configuration file from template
# Reads config/devflow.conf.json and expands variables
# Globals:
#   DEVFLOW_CONFIG_FILE
#   DEVFLOW_CONFIG_TEMPLATE
#   DEVFLOW_CONFIG_DIR
#   DEVFLOW_LIB_DIR
#   HOME
#   USER
# Returns:
#   0 on success, 1 on error
#######################################
config_create_default() {
    local config

    # Check if template exists
    if [ -f "$DEVFLOW_CONFIG_TEMPLATE" ]; then
        # Read template and expand variables
        config=$(cat "$DEVFLOW_CONFIG_TEMPLATE")

        # Expand common variables
        config="${config//\$HOME/$HOME}"
        config="${config//\$USER/$USER}"
        config="${config//\$DEVFLOW_CONFIG_DIR/$DEVFLOW_CONFIG_DIR}"
        config="${config//\$DEVFLOW_LIB_DIR/$DEVFLOW_LIB_DIR}"

        # Add runtime fields
        config=$(echo "$config" | jq --arg date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '. + {updated_at: $date}')
        config=$(echo "$config" | jq '.php.installed_versions = []')

    else
        # Fallback to hardcoded config if template not found
        config=$(cat <<EOF
{
  "version": "1.0",
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "settings": {
    "websites_root": "$DEFAULT_WEBSITES_ROOT",
    "default_php": "$DEFAULT_PHP_VERSION",
    "default_docroot": "$DEFAULT_DOCROOT",
    "auto_ssl": false,
    "auto_hosts": false,
    "auto_db": false,
    "editor": "code"
  },
  "services": {
    "apache": {
      "enabled": true,
      "auto_start": true,
      "port": 80,
      "ssl_port": 443
    },
    "mysql": {
      "enabled": true,
      "auto_start": true,
      "port": 3306,
      "host": "127.0.0.1"
    },
    "redis": {
      "enabled": false,
      "auto_start": false,
      "port": 6379
    }
  },
  "php": {
    "installed_versions": [],
    "default_version": "$DEFAULT_PHP_VERSION"
  },
  "backup": {
    "enabled": true,
    "location": "$DEVFLOW_CONFIG_DIR/backup",
    "retention_days": 30,
    "compress": true,
    "auto_backup": false
  },
  "logging": {
    "level": "INFO",
    "file": "$DEVFLOW_CONFIG_DIR/logs/devflow.log",
    "max_size_mb": 100,
    "rotate": true
  },
  "display": {
    "color": true,
    "emoji": true,
    "verbose": false,
    "quiet": false
  }
}
EOF
)
    fi

    # Write config file
    echo "$config" > "$DEVFLOW_CONFIG_FILE" || return 1
    return 0
}

#######################################
# Load configuration into cache
# Globals:
#   DEVFLOW_CONFIG_FILE
#   _CONFIG_CACHE
# Returns:
#   0 on success, 1 on error
#######################################
config_load() {
    if [ ! -f "$DEVFLOW_CONFIG_FILE" ]; then
        return 1
    fi

    # Validate JSON
    if ! jq empty "$DEVFLOW_CONFIG_FILE" 2>/dev/null; then
        return 1
    fi

    # Load into cache
    _CONFIG_CACHE=$(cat "$DEVFLOW_CONFIG_FILE")
    return 0
}

#######################################
# Get configuration value
# Arguments:
#   $1 - Configuration key (jq path, e.g., "settings.default_php")
#   $2 - Default value if key not found (optional)
# Outputs:
#   Configuration value or default
# Returns:
#   0 on success
#######################################
config_get() {
    local key="$1"
    local default="${2:-}"

    # Load config if not cached
    if [ -z "$_CONFIG_CACHE" ]; then
        config_load || {
            echo "$default"
            return 0
        }
    fi

    # Query value
    local value
    value=$(echo "$_CONFIG_CACHE" | jq -r ".$key // empty")

    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

#######################################
# Set configuration value
# Arguments:
#   $1 - Configuration key (jq path)
#   $2 - Value to set
# Globals:
#   DEVFLOW_CONFIG_FILE
#   _CONFIG_CACHE
# Returns:
#   0 on success, 1 on error
#######################################
config_set() {
    local key="$1"
    local value="$2"

    # Load current config
    config_load || return 1

    # Update value
    local updated
    updated=$(echo "$_CONFIG_CACHE" | jq ".$key = \"$value\"")

    # Update timestamp
    updated=$(echo "$updated" | jq ".updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

    # Write to temp file
    echo "$updated" > "${DEVFLOW_CONFIG_FILE}.tmp" || return 1

    # Validate
    if ! jq empty "${DEVFLOW_CONFIG_FILE}.tmp" 2>/dev/null; then
        rm -f "${DEVFLOW_CONFIG_FILE}.tmp"
        return 1
    fi

    # Atomic move
    mv "${DEVFLOW_CONFIG_FILE}.tmp" "$DEVFLOW_CONFIG_FILE" || return 1

    # Update cache
    _CONFIG_CACHE="$updated"

    return 0
}

#######################################
# Save configuration
# Arguments:
#   $1 - Configuration JSON string
# Globals:
#   DEVFLOW_CONFIG_FILE
# Returns:
#   0 on success, 1 on error
#######################################
config_save() {
    local config_json="$1"

    # Write to temp file
    echo "$config_json" > "${DEVFLOW_CONFIG_FILE}.tmp" || return 1

    # Validate
    if ! jq empty "${DEVFLOW_CONFIG_FILE}.tmp" 2>/dev/null; then
        rm -f "${DEVFLOW_CONFIG_FILE}.tmp"
        return 1
    fi

    # Atomic move
    mv "${DEVFLOW_CONFIG_FILE}.tmp" "$DEVFLOW_CONFIG_FILE" || return 1

    # Clear cache
    _CONFIG_CACHE=""

    return 0
}

#######################################
# Add site to registry
# Arguments:
#   $1 - Site JSON object
# Globals:
#   DEVFLOW_SITES_FILE
# Returns:
#   0 on success, 1 on error
#######################################
site_add() {
    local site_json="$1"

    # Load current sites
    local sites
    sites=$(cat "$DEVFLOW_SITES_FILE")

    # Add new site
    sites=$(echo "$sites" | jq ".sites += [$site_json]")

    # Update timestamp
    sites=$(echo "$sites" | jq ".updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

    # Save
    echo "$sites" > "${DEVFLOW_SITES_FILE}.tmp" || return 1

    # Validate
    if ! jq empty "${DEVFLOW_SITES_FILE}.tmp" 2>/dev/null; then
        rm -f "${DEVFLOW_SITES_FILE}.tmp"
        return 1
    fi

    # Atomic move
    mv "${DEVFLOW_SITES_FILE}.tmp" "$DEVFLOW_SITES_FILE" || return 1

    return 0
}

#######################################
# Get site from registry
# Arguments:
#   $1 - Site name
# Outputs:
#   Site JSON object or empty string
# Returns:
#   0 if found, 1 if not found
#######################################
site_get() {
    local name="$1"

    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        return 1
    fi

    local site
    site=$(jq -r ".sites[] | select(.name == \"$name\")" "$DEVFLOW_SITES_FILE")

    if [ -z "$site" ] || [ "$site" = "null" ]; then
        return 1
    fi

    echo "$site"
    return 0
}

#######################################
# Check if site exists in registry
# Arguments:
#   $1 - Site name
# Returns:
#   0 if exists, 1 if not
#######################################
site_exists() {
    local name="$1"

    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        return 1
    fi

    local count
    count=$(jq -r "[.sites[] | select(.name == \"$name\")] | length" "$DEVFLOW_SITES_FILE")

    [ "$count" -gt 0 ]
}

#######################################
# Update site in registry
# Arguments:
#   $1 - Site name
#   $2 - jq update expression (e.g., ".ssl_enabled = true")
# Globals:
#   DEVFLOW_SITES_FILE
# Returns:
#   0 on success, 1 on error
#######################################
site_update() {
    local name="$1"
    local update_expr="$2"

    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        return 1
    fi

    # Update site
    local sites
    sites=$(jq "(.sites[] | select(.name == \"$name\")) |= ($update_expr)" "$DEVFLOW_SITES_FILE")

    # Update timestamp
    sites=$(echo "$sites" | jq "(.sites[] | select(.name == \"$name\")).updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

    # Save
    echo "$sites" > "${DEVFLOW_SITES_FILE}.tmp" || return 1

    # Validate
    if ! jq empty "${DEVFLOW_SITES_FILE}.tmp" 2>/dev/null; then
        rm -f "${DEVFLOW_SITES_FILE}.tmp"
        return 1
    fi

    # Atomic move
    mv "${DEVFLOW_SITES_FILE}.tmp" "$DEVFLOW_SITES_FILE" || return 1

    return 0
}

#######################################
# Delete site from registry
# Arguments:
#   $1 - Site name
# Globals:
#   DEVFLOW_SITES_FILE
# Returns:
#   0 on success, 1 on error
#######################################
site_delete() {
    local name="$1"

    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        return 1
    fi

    # Remove site
    local sites
    sites=$(jq ".sites |= map(select(.name != \"$name\"))" "$DEVFLOW_SITES_FILE")

    # Update timestamp
    sites=$(echo "$sites" | jq ".updated_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

    # Save
    echo "$sites" > "${DEVFLOW_SITES_FILE}.tmp" || return 1

    # Validate
    if ! jq empty "${DEVFLOW_SITES_FILE}.tmp" 2>/dev/null; then
        rm -f "${DEVFLOW_SITES_FILE}.tmp"
        return 1
    fi

    # Atomic move
    mv "${DEVFLOW_SITES_FILE}.tmp" "$DEVFLOW_SITES_FILE" || return 1

    return 0
}

#######################################
# List all sites
# Arguments:
#   $1 - Optional jq filter (default: all sites)
# Outputs:
#   Array of site objects as JSON
# Returns:
#   0 on success
#######################################
site_list() {
    local filter="${1:-.sites[]}"

    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        echo "[]"
        return 0
    fi

    jq -c "$filter" "$DEVFLOW_SITES_FILE"
}

#######################################
# Get websites root directory
# Outputs:
#   Path to websites directory
# Returns:
#   0 on success
#######################################
config_get_websites_root() {
    config_get "settings.websites_root" "$DEFAULT_WEBSITES_ROOT"
}

#######################################
# Get default PHP version
# Outputs:
#   PHP version string
# Returns:
#   0 on success
#######################################
config_get_default_php() {
    config_get "settings.default_php" "$DEFAULT_PHP_VERSION"
}

#######################################
# Get default document root
# Outputs:
#   Document root subdirectory
# Returns:
#   0 on success
#######################################
config_get_default_docroot() {
    config_get "settings.default_docroot" "$DEFAULT_DOCROOT"
}
