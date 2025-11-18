# Components
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft

---

## 1. Component Overview

DevFlow is organized into modular, reusable components. Each component has a specific responsibility and well-defined interfaces.

```
devflow/
├── bin/devflow                 # CLI Entry Point
├── lib/
│   ├── core/                  # Core Libraries
│   │   ├── config.sh
│   │   ├── logger.sh
│   │   ├── utils.sh
│   │   └── validator.sh
│   ├── commands/              # Command Modules
│   │   ├── site.sh
│   │   ├── php.sh
│   │   ├── ssl.sh
│   │   ├── db.sh
│   │   ├── service.sh
│   │   ├── migrate.sh
│   │   ├── logs.sh
│   │   ├── backup.sh
│   │   ├── hosts.sh
│   │   └── env.sh
│   ├── templates/             # Configuration Templates
│   │   ├── apache-vhost.conf
│   │   ├── apache-vhost-ssl.conf
│   │   ├── php-fpm-pool.conf
│   │   └── xdebug.ini
│   └── installers/            # Installation Scripts
│       ├── php-installer.sh
│       ├── node-installer.sh
│       ├── db-installer.sh
│       └── service-installer.sh
├── share/
│   ├── site-templates/        # Project Templates
│   └── ssl/                   # SSL Certificates
├── scripts/
│   ├── install.sh            # Installation
│   ├── uninstall.sh
│   └── setup-systemd.sh
└── tests/                     # Test Suites
    ├── unit/
    └── integration/
```

---

## 2. Core Components

### 2.1 CLI Entry Point (`bin/devflow`)

**Purpose**: Main executable, command routing, argument parsing

**Responsibilities**:
- Parse command-line arguments
- Route to appropriate command handler
- Handle global options (--help, --version, --verbose)
- Load core libraries
- Handle errors gracefully

**Interface**:
```bash
devflow <command> <subcommand> [options] [arguments]

Global Options:
  --help, -h        Show help
  --version, -v     Show version
  --verbose         Enable verbose output
  --quiet           Suppress non-error output
```

**Implementation Outline**:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Load core libraries
source "${DEVFLOW_LIB}/core/config.sh"
source "${DEVFLOW_LIB}/core/logger.sh"
source "${DEVFLOW_LIB}/core/utils.sh"
source "${DEVFLOW_LIB}/core/validator.sh"

# Parse global options
parse_global_options "$@"

# Get command
COMMAND="${1:-help}"
shift || true

# Route to command handler
case "$COMMAND" in
    site)     source "${DEVFLOW_LIB}/commands/site.sh"; site_command "$@" ;;
    php)      source "${DEVFLOW_LIB}/commands/php.sh"; php_command "$@" ;;
    ssl)      source "${DEVFLOW_LIB}/commands/ssl.sh"; ssl_command "$@" ;;
    db)       source "${DEVFLOW_LIB}/commands/db.sh"; db_command "$@" ;;
    service)  source "${DEVFLOW_LIB}/commands/service.sh"; service_command "$@" ;;
    *)        show_help; exit 1 ;;
esac
```

---

### 2.2 Core Libraries (`lib/core/`)

#### 2.2.1 Configuration Manager (`config.sh`)

**Purpose**: Manage user configuration and site registry

**Key Functions**:

```bash
# Load configuration
config_load()
# Returns: 0 on success, 1 on error
# Sets: Global config variables

# Save configuration
config_save()
# Parameters: config_json
# Returns: 0 on success, 1 on error

# Get configuration value
config_get(key, default)
# Parameters: key, optional default
# Returns: value or default

# Set configuration value
config_set(key, value)
# Parameters: key, value
# Returns: 0 on success

# Site registry operations
site_add(site_json)
site_get(site_name)
site_update(site_name, updates)
site_delete(site_name)
site_list(filter)
site_exists(site_name)
```

**Data Storage**:
- `~/.devflow/config.json` - User preferences
- `~/.devflow/sites.json` - Site registry

**Dependencies**:
- `jq` for JSON parsing
- File system access

#### 2.2.2 Logger (`logger.sh`)

**Purpose**: Structured logging with levels

**Key Functions**:

```bash
# Log functions
log_debug(message)
log_info(message)
log_warn(message)
log_error(message)

# Log with context
log(level, message, context_json)

# Set log level
log_set_level(level)
# Levels: DEBUG, INFO, WARN, ERROR

# Log to file
log_to_file(message)

# Rotate logs
log_rotate()
```

**Output Formats**:
```bash
# Console
[2025-11-13 14:30:45] INFO: Site created: myapp.test

# File (JSON)
{"timestamp":"2025-11-13T14:30:45Z","level":"INFO","message":"Site created","context":{"site":"myapp.test"}}
```

**Log Files**:
- `~/.devflow/logs/devflow.log` - All logs
- `~/.devflow/logs/error.log` - Errors only

#### 2.2.3 Utilities (`utils.sh`)

**Purpose**: Common helper functions

**Key Functions**:

```bash
# String utilities
str_trim(string)
str_lower(string)
str_upper(string)
str_contains(haystack, needle)

# Array utilities
array_contains(array, element)
array_join(array, delimiter)

# Output utilities
print_success(message)
print_error(message)
print_warning(message)
print_info(message)

# Progress indicators
show_progress(current, total)
show_spinner(pid, message)

# Confirmation prompts
confirm(prompt, default)
# Returns: 0 for yes, 1 for no

# File utilities
ensure_dir(path)
backup_file(file)
is_writable(path)

# System utilities
get_os_info()
is_wsl()
is_systemd_running()
get_available_space(path)

# Time utilities
timestamp()
format_date(timestamp)
```

#### 2.2.4 Validator (`validator.sh`)

**Purpose**: Input validation and sanity checks

**Key Functions**:

```bash
# Site name validation
validate_site_name(name)
# Rules: DNS-safe, lowercase, alphanumeric + hyphen + dot

# PHP version validation
validate_php_version(version)
# Valid: 7.4, 8.0, 8.1, 8.2, 8.3

# Path validation
validate_path(path)
validate_absolute_path(path)
path_exists(path)

# Database name validation
validate_db_name(name)
# Rules: alphanumeric + underscore, no spaces

# Dependency checking
check_command(command)
check_package(package)
check_service(service)

# System validation
validate_system_requirements()
# Checks: OS, systemd, disk space, permissions

# Apache configuration validation
validate_apache_config()
# Runs: apachectl configtest
```

---

## 3. Command Modules (`lib/commands/`)

### 3.1 Site Module (`site.sh`)

**Purpose**: Site creation, management, and deletion

**Public Functions**:

```bash
site_command(subcommand, args...)
# Entry point for site commands

site_create(name, php_version, docroot)
# Creates new development site
# Returns: 0 on success, 1 on error

site_delete(name, confirm)
# Deletes site
# Returns: 0 on success, 1 on error

site_list(filter, format)
# Lists all sites
# Formats: table, json, simple

site_info(name)
# Shows detailed site information

site_open(name)
# Opens site in default browser
```

**Internal Functions**:

```bash
_site_create_directory(site_path)
_site_generate_vhost(name, php_version, docroot)
_site_enable_vhost(name)
_site_test_apache_config()
_site_reload_apache()
_site_set_permissions(path)
_site_add_to_registry(site_data)
```

**Dependencies**:
- Core libraries (config, logger, utils, validator)
- Apache (a2ensite, a2dissite, apachectl)
- systemd (systemctl)

### 3.2 PHP Module (`php.sh`)

**Purpose**: PHP version installation and management

**Public Functions**:

```bash
php_command(subcommand, args...)

php_install(version, extensions)
# Installs PHP version with common extensions
# Returns: 0 on success

php_list(format)
# Lists installed PHP versions

php_switch(version)
# Switches default CLI PHP version

php_extension_install(version, extension)
# Installs PHP extension

php_extension_list(version)
# Lists installed extensions for version
```

**Internal Functions**:

```bash
_php_add_repository()
_php_install_packages(version, packages)
_php_configure_fpm(version)
_php_start_service(version)
_php_update_alternatives(version)
_php_get_installed_versions()
```

**Dependencies**:
- apt package manager
- Ondřej Surý PPA
- systemd

### 3.3 SSL Module (`ssl.sh`)

**Purpose**: SSL certificate generation and management

**Public Functions**:

```bash
ssl_command(subcommand, args...)

ssl_install_ca()
# Creates root Certificate Authority

ssl_create(site_name)
# Creates SSL certificate for site

ssl_renew(site_name)
# Renews SSL certificate

ssl_list()
# Lists all SSL certificates

ssl_trust_instructions()
# Shows browser trust instructions
```

**Internal Functions**:

```bash
_ssl_generate_ca()
_ssl_generate_private_key(name)
_ssl_generate_csr(name)
_ssl_sign_certificate(name)
_ssl_create_ssl_vhost(name)
_ssl_enable_ssl_vhost(name)
```

**Dependencies**:
- openssl
- Apache SSL module

### 3.4 Database Module (`db.sh`)

**Purpose**: Database creation, import, export

**Public Functions**:

```bash
db_command(subcommand, args...)

db_create(name, user, password)
# Creates database and user

db_delete(name, confirm)
# Deletes database

db_list(format)
# Lists all databases

db_import(db_name, sql_file)
# Imports SQL dump

db_export(db_name, output_file, compress)
# Exports database to SQL file

db_user_create(username, password, db_name)
# Creates database user
```

**Internal Functions**:

```bash
_db_connect()
_db_execute(query)
_db_generate_password()
_db_test_connection(user, pass)
```

**Dependencies**:
- mysql/mariadb client
- gzip (for compression)

### 3.5 Service Module (`service.sh`)

**Purpose**: System service management

**Public Functions**:

```bash
service_command(subcommand, args...)

service_status(service_name)
# Shows service status

service_start(service_name)
# Starts service

service_stop(service_name)
# Stops service

service_restart(service_name)
# Restarts service

service_reload(service_name)
# Reloads service configuration

service_enable(service_name)
# Enables service auto-start

service_disable(service_name)
# Disables service auto-start

service_list()
# Lists all managed services
```

**Internal Functions**:

```bash
_service_get_status(service)
_service_get_uptime(service)
_service_get_memory(service)
_service_is_running(service)
_service_get_port(service)
```

**Dependencies**:
- systemd (systemctl)

### 3.6 Migration Module (`migrate.sh`)

**Purpose**: Project migration from Windows to WSL

**Public Functions**:

```bash
migrate_command(args...)

migrate_project(source, target_site, confirm)
# Migrates project from /mnt to WSL

migrate_preview(source, target)
# Shows dry-run of migration
```

**Internal Functions**:

```bash
_migrate_calculate_size(source)
_migrate_check_space(target, size)
_migrate_rsync(source, target, dry_run)
_migrate_fix_permissions(target)
_migrate_detect_project_type(target)
_migrate_offer_setup(site, project_type)
```

**Dependencies**:
- rsync
- Site module (for vhost creation)
- DB module (for database creation)

### 3.7 Logs Module (`logs.sh`)

**Purpose**: Log viewing and monitoring

**Public Functions**:

```bash
logs_command(args...)

logs_view(site, lines, follow, filter)
# Views site logs

logs_tail(site, filter)
# Real-time log tailing

logs_error(site, lines)
# Shows only errors
```

**Internal Functions**:

```bash
_logs_get_paths(site)
_logs_aggregate(log_files)
_logs_colorize(line, level)
_logs_filter(lines, pattern)
```

**Dependencies**:
- tail, grep, sed

### 3.8 Backup Module (`backup.sh`)

**Purpose**: Site backup and restore

**Public Functions**:

```bash
backup_command(subcommand, args...)

backup_create(site_name, compress)
# Creates backup of site

backup_restore(backup_id, target_site)
# Restores from backup

backup_list(site_filter)
# Lists available backups

backup_delete(backup_id, confirm)
# Deletes backup
```

**Internal Functions**:

```bash
_backup_create_archive(site_path)
_backup_dump_database(db_name)
_backup_save_metadata(backup_path, site_data)
_backup_verify_integrity(backup_path)
_backup_extract(backup_path, target)
```

**Dependencies**:
- tar, gzip
- DB module

### 3.9 Hosts Module (`hosts.sh`)

**Purpose**: Windows hosts file management

**Public Functions**:

```bash
hosts_command(subcommand, args...)

hosts_add(site_name)
# Adds entry to Windows hosts file

hosts_remove(site_name)
# Removes entry from Windows hosts file

hosts_list()
# Lists all hosts entries

hosts_verify(site_name)
# Verifies hosts entry exists
```

**Internal Functions**:

```bash
_hosts_get_windows_path()
_hosts_generate_powershell_command(action, site)
_hosts_execute_powershell(command)
```

**Dependencies**:
- PowerShell (via WSL integration)

---

## 4. Installation Components (`lib/installers/`)

### 4.1 PHP Installer (`php-installer.sh`)

**Purpose**: Automated PHP installation

**Functions**:
```bash
install_php_version(version)
install_php_extensions(version, extensions)
configure_php_fpm(version)
```

### 4.2 Database Installer (`db-installer.sh`)

**Purpose**: MySQL/MariaDB installation

**Functions**:
```bash
install_mysql()
install_mariadb()
secure_installation()
```

### 4.3 Service Installer (`service-installer.sh`)

**Purpose**: Install and configure system services

**Functions**:
```bash
install_apache()
install_redis()
install_postgresql()
```

---

## 5. Template Components (`lib/templates/`)

### 5.1 Apache Vhost Template

**File**: `apache-vhost.conf`

**Variables**:
- `${SITENAME}` - Site domain name
- `${DOCROOT}` - Document root path
- `${PHPVER}` - PHP version (e.g., php8.2)
- `${USERNAME}` - Current user

### 5.2 Apache SSL Vhost Template

**File**: `apache-vhost-ssl.conf`

**Additional Variables**:
- `${CERT_PATH}` - SSL certificate path
- `${KEY_PATH}` - SSL private key path

### 5.3 PHP-FPM Pool Template

**File**: `php-fpm-pool.conf`

**Variables**:
- `${POOL_NAME}` - Pool name
- `${USER}` - Run as user
- `${GROUP}` - Run as group

---

## 6. Component Communication

### 6.1 Inter-Component Dependencies

```
┌─────────────────────────────────────────────┐
│         Command Modules                      │
│  ┌─────┐  ┌────┐  ┌────┐  ┌────┐           │
│  │Site │  │PHP │  │SSL │  │ DB │  ...      │
│  └──┬──┘  └─┬──┘  └─┬──┘  └─┬──┘           │
└─────┼───────┼───────┼───────┼──────────────┘
      │       │       │       │
      └───────┴───────┴───────┴────────────┐
                                            │
┌───────────────────────────────────────────▼─┐
│         Core Libraries                      │
│  ┌────────┐  ┌────────┐  ┌─────────────┐  │
│  │Config  │  │Logger  │  │  Validator  │  │
│  └────────┘  └────────┘  └─────────────┘  │
│  ┌────────┐                                 │
│  │Utils   │                                 │
│  └────────┘                                 │
└─────────────────────────────────────────────┘
```

### 6.2 Data Flow Between Components

**Example: Site Creation with SSL**

```
User → CLI → site.sh
              ├─> config.sh (check site exists)
              ├─> validator.sh (validate name)
              ├─> utils.sh (create directory)
              ├─> template (generate vhost)
              ├─> service.sh (reload apache)
              ├─> ssl.sh (create certificate)
              │    ├─> openssl (generate cert)
              │    └─> service.sh (reload apache)
              ├─> config.sh (save site registry)
              └─> logger.sh (log success)
```

---

## 7. Component Testing

### 7.1 Unit Testing

Each component should have unit tests:

```
tests/unit/
├── core/
│   ├── test_config.bats
│   ├── test_logger.bats
│   ├── test_utils.bats
│   └── test_validator.bats
└── commands/
    ├── test_site.bats
    ├── test_php.bats
    └── ...
```

### 7.2 Integration Testing

Test component interactions:

```
tests/integration/
├── test_site_creation.bats
├── test_site_with_ssl.bats
├── test_migration.bats
└── ...
```

---

## 8. Component Extension

### 8.1 Adding New Commands

1. Create `lib/commands/newcmd.sh`
2. Implement `newcmd_command()` function
3. Add route in `bin/devflow`
4. Add tests in `tests/unit/commands/test_newcmd.bats`
5. Document in CLI reference

### 8.2 Adding New Core Functions

1. Add function to appropriate core module
2. Document function header
3. Add unit tests
4. Update component documentation

---

## Document History

| Version | Date       | Author        | Changes                    |
|---------|------------|---------------|----------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial components doc     |

---

**Document Status**: Draft
**Next Review Date**: Before implementation
**Approval**: Pending
