# Technical Specification
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft

---

## 1. Overview

This document provides detailed technical specifications for implementing DevFlow. It serves as a reference for developers building the system.

---

## 2. Technology Stack

### Core
- **Language**: Bash 4.4+
- **Shell**: `/usr/bin/env bash`
- **JSON Parser**: jq 1.6+
- **Testing**: BATS (Bash Automated Testing System)

### System Dependencies
- **OS**: Ubuntu 22.04+, Debian 11+, WSL2
- **Init System**: systemd
- **Web Server**: Apache 2.4+
- **PHP**: 7.4, 8.0, 8.1, 8.2, 8.3 (via Ondřej Surý PPA)
- **Database**: MySQL 8.0+ or MariaDB 10.6+
- **SSL**: OpenSSL 1.1.1+

---

## 3. File Structure Specification

```
/opt/devflow/               # Optional system installation
~/.devflow/                 # User data directory
  ├── config.json          # User configuration
  ├── sites.json           # Site registry
  ├── db-credentials.json  # Database passwords (600)
  ├── ssl/                 # SSL certificates
  │   ├── ca/             # Root CA (600 on ca.key)
  │   └── certs/          # Site certificates
  ├── logs/               # DevFlow logs
  ├── backup/             # Site backups
  └── tmp/                # Temporary files

~/websites/                # Development sites
  └── [sitename]/
      └── [docroot]/

/etc/apache2/sites-available/  # Apache vhosts
/run/php/                     # PHP-FPM sockets
```

---

## 4. Core Library Specifications

### 4.1 config.sh

**Purpose**: Configuration and state management

**Functions**:
```bash
config_load()               # Load ~/.devflow/config.json
config_save(json)          # Save configuration
config_get(key, default)   # Get config value
config_set(key, value)     # Set config value

site_add(site_json)        # Add site to registry
site_get(name)             # Get site by name
site_update(name, json)    # Update site
site_delete(name)          # Remove site
site_list(filter)          # List sites (jq filter)
site_exists(name)          # Check if site exists
```

**Data Format**: See DATA_MODEL.md for JSON schemas

### 4.2 logger.sh

**Purpose**: Structured logging

**Functions**:
```bash
log_debug(message)         # Debug level
log_info(message)          # Info level
log_warn(message)          # Warning level
log_error(message)         # Error level
log(level, message, context)  # Generic log with context
```

**Log Format**:
```
Console: [2025-11-13 14:30:45] INFO: Message
File: {"timestamp":"2025-11-13T14:30:45Z","level":"INFO","message":"Message","context":{}}
```

### 4.3 utils.sh

**Purpose**: Common utility functions

**Functions**:
```bash
# Output
print_success(msg)         # Green checkmark + message
print_error(msg)           # Red X + message
print_warning(msg)         # Yellow warning + message
print_info(msg)            # Blue info + message

# Progress
show_progress(current, total)  # Progress bar
show_spinner(pid, msg)     # Spinner for long operations

# Prompts
confirm(prompt, default)   # Yes/no confirmation (returns 0/1)

# Files
ensure_dir(path)           # Create directory if not exists
backup_file(file)          # Backup file with timestamp
is_writable(path)          # Check write permission

# System
get_os_info()              # Get OS name and version
is_wsl()                   # Check if running in WSL
is_systemd_running()       # Check if systemd available
get_available_space(path)  # Get free disk space in bytes

# Strings
str_trim(string)           # Remove leading/trailing whitespace
str_lower(string)          # Convert to lowercase
str_contains(hay, needle)  # Check if string contains substring
```

### 4.4 validator.sh

**Purpose**: Input validation

**Functions**:
```bash
validate_site_name(name)   # DNS-safe name validation
validate_php_version(ver)  # Check valid PHP version
validate_db_name(name)     # Database name validation
validate_path(path)        # Path safety checks
validate_absolute_path(p)  # Must be absolute path

check_command(cmd)         # Check if command exists
check_package(pkg)         # Check if package installed
check_service(svc)         # Check if service exists

validate_system_requirements()  # Full system check
validate_apache_config()   # apachectl configtest
```

---

## 5. Command Module Specifications

### 5.1 Site Module (site.sh)

**Entry Point**: `site_command(subcommand, args...)`

**Commands**:
- `create <name> <php-version> [docroot]`
- `delete <name>`
- `list [--filter <filter>]`
- `info <name>`
- `open <name>`

**Implementation**:
```bash
site_create() {
    local name="$1"
    local php_version="$2"
    local docroot="${3:-public}"

    # Validate inputs
    validate_site_name "$name" || return 1
    validate_php_version "$php_version" || return 1
    site_exists "$name" && { log_error "Site exists"; return 1; }

    # Create directory
    local site_path="$WEBSITES_ROOT/$name"
    mkdir -p "$site_path/$docroot" || return 1

    # Generate vhost
    generate_vhost "$name" "$php_version" "$docroot" || return 1

    # Enable site
    sudo a2ensite "$name.conf" || return 1

    # Test and reload
    sudo apachectl configtest || { log_error "Config test failed"; return 1; }
    sudo systemctl reload apache2 || return 1

    # Set permissions
    sudo chown -R "$USER:www-data" "$site_path"
    sudo chmod -R 775 "$site_path"

    # Add to registry
    site_add "$site_json" || return 1

    print_success "Site created: $name"
    echo "URL: http://$name"
}
```

### 5.2 PHP Module (php.sh)

**Entry Point**: `php_command(subcommand, args...)`

**Commands**:
- `install <version>`
- `list`
- `switch <version>`
- `extension install <version> <extension>`

**Implementation**:
```bash
php_install() {
    local version="$1"
    validate_php_version "$version" || return 1

    # Add PPA
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update

    # Install packages
    local packages=(
        "php${version}-fpm"
        "php${version}-cli"
        "php${version}-mbstring"
        "php${version}-xml"
        "php${version}-mysql"
        "php${version}-curl"
        "php${version}-zip"
        "php${version}-gd"
    )

    sudo apt install -y "${packages[@]}" || return 1

    # Start FPM
    sudo systemctl enable "php${version}-fpm"
    sudo systemctl start "php${version}-fpm"

    print_success "PHP $version installed"
}
```

---

## 6. Template Specifications

### 6.1 Apache Vhost Template

**File**: `lib/templates/apache-vhost.conf`

**Template Variables**:
- `${SITENAME}` - Site domain name
- `${DOCROOT}` - Full path to document root
- `${PHPVER}` - PHP version (e.g., php8.2)

**Template Content**:
```apache
<VirtualHost *:80>
    ServerName ${SITENAME}
    ServerAlias www.${SITENAME}
    DocumentRoot ${DOCROOT}

    <Directory ${DOCROOT}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/${PHPVER}-fpm.sock|fcgi://localhost/"
    </FilesMatch>

    ErrorLog ${APACHE_LOG_DIR}/${SITENAME}_error.log
    CustomLog ${APACHE_LOG_DIR}/${SITENAME}_access.log combined
</VirtualHost>
```

---

## 7. Error Handling Specifications

### 7.1 Error Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Permission denied |
| 4 | Resource not found |
| 5 | Resource already exists |
| 10 | System requirement not met |
| 11 | Service not running |
| 12 | Configuration error |

### 7.2 Error Message Format

```
✗ Error: [What went wrong]

[Why it happened]

[How to fix]:
  - Option 1: command
  - Option 2: command

Run 'devflow help [command]' for more information.
```

---

## 8. Performance Specifications

### 8.1 Targets

- Site creation: < 30 seconds
- PHP installation: < 3 minutes
- File migration (1GB): < 10 seconds
- Database import (100MB): < 30 seconds
- CLI response time: < 100ms
- Memory usage: < 50 MB

### 8.2 Optimization Strategies

- Use native WSL filesystem (no /mnt)
- Cache parsed JSON in memory
- Batch operations where possible
- Parallel operations where safe
- Lazy load modules

---

## 9. Security Specifications

### 9.1 File Permissions

| Path | Owner | Group | Permissions |
|------|-------|-------|-------------|
| ~/.devflow/ | user | user | 700 |
| ~/.devflow/config.json | user | user | 644 |
| ~/.devflow/db-credentials.json | user | user | 600 |
| ~/.devflow/ssl/ca/ca.key | user | user | 600 |
| ~/websites/[site]/ | user | www-data | 775 |
| ~/websites/[site]/file | user | www-data | 664 |

### 9.2 Input Sanitization

- All user input validated before use
- No eval or command substitution on user input
- Path traversal checks (no `..`)
- SQL injection prevention (parameterized queries)

---

## 10. Testing Specifications

### 10.1 Unit Tests

**Framework**: BATS
**Coverage Target**: >80%
**Location**: `tests/unit/`

**Example**:
```bash
#!/usr/bin/env bats

@test "validate_site_name accepts valid names" {
    source lib/core/validator.sh
    run validate_site_name "myapp.test"
    [ "$status" -eq 0 ]
}

@test "validate_site_name rejects invalid names" {
    source lib/core/validator.sh
    run validate_site_name "Invalid Name"
    [ "$status" -eq 1 ]
}
```

### 10.2 Integration Tests

**Coverage Target**: Main workflows
**Location**: `tests/integration/`

**Example**:
```bash
@test "create and access site" {
    # Create site
    run devflow site create test.local php8.2
    [ "$status" -eq 0 ]

    # Check site exists
    [ -d "$HOME/websites/test.local" ]

    # Check vhost
    [ -f "/etc/apache2/sites-available/test.local.conf" ]

    # Cleanup
    devflow site delete test.local --yes
}
```

---

## 11. CI/CD Specifications

### 11.1 GitHub Actions

**Workflow**: `.github/workflows/tests.yml`

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ubuntu-version: ['22.04', '24.04']
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: sudo apt install -y jq shellcheck bats
      - name: Lint
        run: shellcheck lib/**/*.sh
      - name: Unit tests
        run: bats tests/unit/
      - name: Integration tests
        run: sudo bats tests/integration/
```

---

## 12. Documentation Specifications

### 12.1 Code Documentation

**Function Header Format**:
```bash
# Description of what the function does
#
# Arguments:
#   $1 - First argument description
#   $2 - Second argument description
#
# Returns:
#   0 - Success
#   1 - Error
#
# Example:
#   my_function "arg1" "arg2"
#
my_function() {
    # Implementation
}
```

---

## Document History

| Version | Date       | Author        | Changes                    |
|---------|------------|---------------|----------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial technical spec     |

