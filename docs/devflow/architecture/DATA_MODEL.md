# Data Model
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft

---

## 1. Overview

DevFlow uses JSON-based configuration and state management. All data is stored in text files for version control compatibility and human readability.

**Storage Locations**:
- `~/.devflow/config.json` - User configuration
- `~/.devflow/sites.json` - Site registry
- `~/.devflow/db-credentials.json` - Database credentials (encrypted)
- `/etc/devflow/defaults.json` - System defaults

---

## 2. Configuration Schema

### 2.1 User Configuration (`config.json`)

**Location**: `~/.devflow/config.json`

**Schema**:
```json
{
  "$schema": "https://devflow.dev/schemas/config-v1.json",
  "version": "1.0",
  "updated_at": "2025-11-13T14:30:00Z",

  "settings": {
    "websites_root": "/home/user/websites",
    "default_php": "8.2",
    "default_docroot": "public",
    "auto_ssl": false,
    "auto_hosts": false,
    "auto_db": true,
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
    "installed_versions": ["7.4", "8.2", "8.3"],
    "default_version": "8.2",
    "extensions": {
      "common": ["mbstring", "xml", "mysql", "curl", "zip", "gd"],
      "optional": ["imagick", "redis", "xdebug"]
    }
  },

  "backup": {
    "enabled": true,
    "location": "/home/user/.devflow/backup",
    "retention_days": 30,
    "compress": true,
    "auto_backup": false
  },

  "logging": {
    "level": "INFO",
    "file": "/home/user/.devflow/logs/devflow.log",
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
```

**Field Descriptions**:

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| version | string | Yes | "1.0" | Config format version |
| settings.websites_root | string | Yes | "~/websites" | Root directory for sites |
| settings.default_php | string | Yes | "8.2" | Default PHP version |
| settings.default_docroot | string | Yes | "public" | Default document root subdirectory |
| settings.auto_ssl | boolean | No | false | Auto-enable SSL for new sites |
| settings.auto_hosts | boolean | No | false | Auto-update Windows hosts file |
| settings.auto_db | boolean | No | true | Auto-create database for sites |
| settings.editor | string | No | "code" | Default code editor |

---

## 3. Site Registry Schema

### 3.1 Sites Registry (`sites.json`)

**Location**: `~/.devflow/sites.json`

**Schema**:
```json
{
  "$schema": "https://devflow.dev/schemas/sites-v1.json",
  "version": "1.0",
  "updated_at": "2025-11-13T14:30:00Z",
  "sites": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "myapp.test",
      "status": "active",
      "created_at": "2025-11-10T10:30:00Z",
      "updated_at": "2025-11-13T14:30:00Z",

      "paths": {
        "root": "/home/user/websites/myapp.test",
        "docroot": "public",
        "absolute_docroot": "/home/user/websites/myapp.test/public"
      },

      "php": {
        "version": "8.2",
        "fpm_socket": "/run/php/php8.2-fpm.sock",
        "extensions": ["xdebug", "redis"]
      },

      "apache": {
        "vhost": "/etc/apache2/sites-available/myapp.test.conf",
        "enabled": true,
        "server_alias": ["www.myapp.test"]
      },

      "ssl": {
        "enabled": true,
        "vhost": "/etc/apache2/sites-available/myapp.test-ssl.conf",
        "cert": "/home/user/.devflow/ssl/certs/myapp.test/cert.pem",
        "key": "/home/user/.devflow/ssl/certs/myapp.test/key.pem",
        "expires_at": "2026-11-13T14:30:00Z"
      },

      "database": {
        "type": "mysql",
        "name": "myapp_db",
        "user": "myapp_user",
        "host": "127.0.0.1",
        "port": 3306,
        "created_at": "2025-11-10T10:35:00Z"
      },

      "project": {
        "type": "laravel",
        "version": "10.x",
        "env_file": "/home/user/websites/myapp.test/.env"
      },

      "stats": {
        "disk_usage_bytes": 257698037,
        "file_count": 1234,
        "last_accessed": "2025-11-13T14:25:00Z"
      },

      "metadata": {
        "tags": ["client-work", "php8"],
        "notes": "Client demo site",
        "migrated_from": "/mnt/c/Users/boss/Projects/myapp"
      }
    }
  ]
}
```

**Field Descriptions**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | uuid | Yes | Unique site identifier |
| name | string | Yes | Site domain name (DNS format) |
| status | enum | Yes | active, inactive, error |
| created_at | iso8601 | Yes | Creation timestamp |
| updated_at | iso8601 | Yes | Last update timestamp |
| paths.root | string | Yes | Site root directory |
| paths.docroot | string | Yes | Document root subdirectory |
| php.version | string | Yes | PHP version (e.g., "8.2") |
| apache.vhost | string | Yes | Path to Apache vhost config |
| apache.enabled | boolean | Yes | Site enabled in Apache |
| ssl.enabled | boolean | Yes | HTTPS enabled |
| database.name | string | No | Database name (if exists) |
| project.type | string | No | Detected project type |

**Status Values**:
- `active` - Site is working and accessible
- `inactive` - Site disabled or not running
- `error` - Site has configuration errors

**Project Types**:
- `laravel` - Laravel framework
- `wordpress` - WordPress CMS
- `symfony` - Symfony framework
- `static` - Static HTML site
- `custom` - Custom/unknown

---

## 4. Database Credentials Schema

### 4.1 Credentials Store (`db-credentials.json`)

**Location**: `~/.devflow/db-credentials.json` (permissions: 600)

**Schema**:
```json
{
  "version": "1.0",
  "encrypted": false,
  "credentials": [
    {
      "database": "myapp_db",
      "username": "myapp_user",
      "password": "generated_secure_password_here",
      "created_at": "2025-11-10T10:35:00Z",
      "site": "myapp.test"
    }
  ]
}
```

**Security**:
- File permissions: 600 (read/write owner only)
- Optional encryption with user password
- Never log passwords
- Never include in backups (separate secure storage)

---

## 5. Backup Metadata Schema

### 5.1 Backup Manifest (`backup-manifest.json`)

**Location**: `~/.devflow/backup/[backup-id]/metadata.json`

**Schema**:
```json
{
  "version": "1.0",
  "backup_id": "myapp.test_2025-11-13_145623",
  "created_at": "2025-11-13T14:56:23Z",

  "site": {
    "name": "myapp.test",
    "php_version": "8.2",
    "ssl_enabled": true,
    "database_included": true
  },

  "files": {
    "archive": "files.tar.gz",
    "size_bytes": 93274112,
    "compressed_size_bytes": 31457280,
    "file_count": 1234,
    "checksum_sha256": "abc123..."
  },

  "database": {
    "file": "database.sql.gz",
    "size_bytes": 13107200,
    "compressed_size_bytes": 3355443,
    "checksum_sha256": "def456..."
  },

  "config": {
    "site_config": {...},
    "apache_vhost": "...",
    "env_file": "..."
  }
}
```

---

## 6. SSL Certificate Metadata

### 6.1 Certificate Info (`cert-info.json`)

**Location**: `~/.devflow/ssl/certs/[site]/info.json`

**Schema**:
```json
{
  "site": "myapp.test",
  "created_at": "2025-11-13T14:30:00Z",
  "expires_at": "2026-11-13T14:30:00Z",
  "serial": "01",
  "issuer": "DevFlow Root CA",
  "subject": "myapp.test",
  "algorithm": "RSA 2048",
  "files": {
    "cert": "cert.pem",
    "key": "key.pem",
    "csr": "csr.pem"
  }
}
```

---

## 7. Log Entry Format

### 7.1 Structured Logs (JSON)

**Location**: `~/.devflow/logs/devflow.log`

**Format**:
```json
{
  "timestamp": "2025-11-13T14:30:45.123Z",
  "level": "INFO",
  "message": "Site created successfully",
  "context": {
    "command": "site create",
    "site": "myapp.test",
    "php_version": "8.2",
    "duration_ms": 28453,
    "user": "boss"
  },
  "trace_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

## 8. Template Variables

### 8.1 Vhost Template Variables

**Available in templates**:

```json
{
  "SITENAME": "myapp.test",
  "DOCROOT": "/home/user/websites/myapp.test/public",
  "PHPVER": "php8.2",
  "PHPVER_SOCK": "/run/php/php8.2-fpm.sock",
  "USERNAME": "user",
  "GROUPNAME": "www-data",
  "SSL_CERT": "/home/user/.devflow/ssl/certs/myapp.test/cert.pem",
  "SSL_KEY": "/home/user/.devflow/ssl/certs/myapp.test/key.pem",
  "LOG_DIR": "/var/log/apache2",
  "SERVER_ALIAS": "www.myapp.test"
}
```

---

## 9. Data Validation Rules

### 9.1 Site Name Validation

**Rules**:
- Lowercase only
- Alphanumeric, hyphen, dot allowed
- Must contain at least one dot (TLD)
- Length: 4-253 characters
- Must be DNS-safe
- Cannot start/end with hyphen

**Valid Examples**:
- `myapp.test`
- `my-app.local`
- `app123.dev`

**Invalid Examples**:
- `MyApp.test` (uppercase)
- `myapp` (no TLD)
- `-myapp.test` (starts with hyphen)
- `my app.test` (space)

**Regex**:
```regex
^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$
```

### 9.2 PHP Version Validation

**Allowed Versions**:
- `7.4`
- `8.0`
- `8.1`
- `8.2`
- `8.3`

**Format**: `X.Y` where X is major, Y is minor

### 9.3 Database Name Validation

**Rules**:
- Alphanumeric and underscore only
- Must start with letter or underscore
- Length: 1-64 characters
- No reserved words (mysql, information_schema, etc.)

**Regex**:
```regex
^[a-zA-Z_][a-zA-Z0-9_]{0,63}$
```

### 9.4 Path Validation

**Site Root Path**:
- Must be absolute path
- Must start with `/home/`
- Must be within `~/websites/` (configurable)
- Must not contain `..` (path traversal)
- Must not be system directory

---

## 10. Data Migration

### 10.1 Config Version Upgrades

**Version 1.0 → 1.1** (example):

```bash
migrate_config_v1_to_v1_1() {
    local config_file="$1"

    # Add new fields
    jq '.settings.new_field = "default_value"' "$config_file" > tmp
    mv tmp "$config_file"

    # Update version
    jq '.version = "1.1"' "$config_file" > tmp
    mv tmp "$config_file"
}
```

### 10.2 Site Registry Upgrades

**Adding New Fields**:
- Old sites get default values for new fields
- No data loss on upgrade
- Backward compatibility for 2 versions

---

## 11. Data Access Patterns

### 11.1 Configuration Access

```bash
# Read config value
config_get "settings.default_php"

# Write config value
config_set "settings.default_php" "8.3"

# Check if config exists
config_has "services.redis.enabled"
```

### 11.2 Site Registry Access

```bash
# Get site by name
site=$(site_get "myapp.test")

# Update site field
site_update "myapp.test" ".ssl.enabled" true

# List sites by filter
sites=$(site_list ".php.version == \"8.2\"")

# Check if site exists
site_exists "myapp.test" && echo "exists"
```

### 11.3 Query Examples (jq)

```bash
# Get all sites using PHP 8.2
jq '.sites[] | select(.php.version == "8.2") | .name' sites.json

# Get total disk usage
jq '[.sites[].stats.disk_usage_bytes] | add' sites.json

# Get sites with SSL enabled
jq '.sites[] | select(.ssl.enabled == true) | .name' sites.json

# Count sites by status
jq '.sites | group_by(.status) | map({status: .[0].status, count: length})' sites.json
```

---

## 12. Data Integrity

### 12.1 Validation on Load

```bash
validate_config() {
    local config_file="$1"

    # Check JSON validity
    jq empty "$config_file" || return 1

    # Check required fields
    jq -e '.version' "$config_file" >/dev/null || return 1
    jq -e '.settings.websites_root' "$config_file" >/dev/null || return 1

    # Validate values
    local php_ver=$(jq -r '.settings.default_php' "$config_file")
    validate_php_version "$php_ver" || return 1

    return 0
}
```

### 12.2 Atomic Writes

```bash
config_save() {
    local config_data="$1"
    local config_file="~/.devflow/config.json"

    # Write to temp file
    echo "$config_data" > "${config_file}.tmp"

    # Validate
    validate_config "${config_file}.tmp" || {
        rm "${config_file}.tmp"
        return 1
    }

    # Atomic move
    mv "${config_file}.tmp" "$config_file"
}
```

### 12.3 Backup Before Modify

```bash
# Backup config before changes
cp ~/.devflow/config.json ~/.devflow/config.json.backup

# Backup sites registry
cp ~/.devflow/sites.json ~/.devflow/sites.json.backup
```

---

## 13. Performance Considerations

### 13.1 Caching

```bash
# Cache config in memory (5 minute TTL)
CACHE_CONFIG=""
CACHE_TIME=0
CACHE_TTL=300

config_load() {
    local now=$(date +%s)

    if [ -z "$CACHE_CONFIG" ] || [ $((now - CACHE_TIME)) -gt $CACHE_TTL ]; then
        CACHE_CONFIG=$(cat ~/.devflow/config.json)
        CACHE_TIME=$now
    fi

    echo "$CACHE_CONFIG"
}
```

### 13.2 Efficient Queries

```bash
# Bad: Load entire registry for single site
sites=$(cat ~/.devflow/sites.json)
site=$(echo "$sites" | jq ".sites[] | select(.name == \"$name\")")

# Good: Direct query
site=$(jq ".sites[] | select(.name == \"$name\")" ~/.devflow/sites.json)
```

### 13.3 Large Registry Handling

For 100+ sites:
- Index site names for fast lookup
- Paginate site list output
- Use streaming jq for large files

---

## Document History

| Version | Date       | Author        | Changes                |
|---------|------------|---------------|------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial data model     |

---

**Document Status**: Draft
**Next Review Date**: Before implementation
**Approval**: Pending
