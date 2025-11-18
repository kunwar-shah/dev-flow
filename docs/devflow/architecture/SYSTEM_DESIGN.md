# System Design
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft

---

## 1. Overview

### 1.1 System Purpose
DevFlow is a CLI-based development environment manager that automates the setup and management of LAMP stack sites on WSL and Linux systems.

### 1.2 Design Principles
- **Simplicity**: One command for common tasks
- **Performance**: Native filesystem operations, no Docker overhead
- **Reliability**: Validate before execute, atomic operations
- **Modularity**: Independent, reusable components
- **Maintainability**: Clear code structure, comprehensive tests

### 1.3 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User (CLI)                            │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                  DevFlow CLI (bin/devflow)                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │          Command Router & Argument Parser              │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Core Libraries                            │
│  ┌──────────┐  ┌────────┐  ┌──────────┐  ┌──────────────┐  │
│  │  Config  │  │ Logger │  │ Validator│  │    Utils     │  │
│  └──────────┘  └────────┘  └──────────┘  └──────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Command Modules                            │
│  ┌─────────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌────────────┐     │
│  │  Site   │ │ PHP  │ │ SSL  │ │  DB  │ │  Service   │     │
│  └─────────┘ └──────┘ └──────┘ └──────┘ └────────────┘     │
│  ┌─────────┐ ┌──────┐ ┌──────┐ ┌──────┐                    │
│  │ Migrate │ │ Logs │ │Backup│ │Hosts │ ...                │
│  └─────────┘ └──────┘ └──────┘ └──────┘                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   System Services                            │
│  ┌────────────┐  ┌───────────┐  ┌─────────────────┐        │
│  │   Apache   │  │  PHP-FPM  │  │  MySQL/MariaDB  │        │
│  └────────────┘  └───────────┘  └─────────────────┘        │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                  Configuration & Data                        │
│  ┌───────────────┐  ┌──────────────┐  ┌────────────────┐   │
│  │ sites.json    │  │ devflow.conf │  │ SSL certs      │   │
│  └───────────────┘  └──────────────┘  └────────────────┘   │
│  ┌───────────────┐  ┌──────────────┐  ┌────────────────┐   │
│  │ Apache vhosts │  │ PHP-FPM pools│  │ Site files     │   │
│  └───────────────┘  └──────────────┘  └────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Component Architecture

### 2.1 Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer (CLI Interface)                      │
│  - Command parsing                                       │
│  - User interaction (prompts, output)                    │
│  - Help system                                           │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│  Business Logic Layer (Command Modules)                  │
│  - Site management logic                                 │
│  - Service orchestration                                 │
│  - Validation rules                                      │
│  - Error handling                                        │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│  Data Access Layer (Config & State Management)           │
│  - JSON file operations                                  │
│  - Configuration read/write                              │
│  - State persistence                                     │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│  Infrastructure Layer (System Integration)               │
│  - Apache configuration                                  │
│  - systemd service control                               │
│  - Filesystem operations                                 │
│  - Package management                                    │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Core Components

#### 2.2.1 CLI Router (`bin/devflow`)
**Responsibility**: Entry point, command routing, global options

```bash
devflow <command> <subcommand> [options] [arguments]
```

**Functions**:
- Parse command-line arguments
- Route to appropriate command module
- Handle global flags (--help, --version, --verbose)
- Display usage information

#### 2.2.2 Core Libraries (`lib/core/`)

**config.sh**
- Load configuration from `~/.devflow/config.json`
- Save configuration changes
- Provide default values
- Validate configuration

**utils.sh**
- Common utility functions
- String manipulation
- Array operations
- Color output helpers
- Timestamp formatting

**logger.sh**
- Log to file and console
- Log levels: DEBUG, INFO, WARN, ERROR
- Structured logging
- Log rotation support

**validator.sh**
- Input validation
- Site name validation (DNS format)
- Path validation
- Version validation
- Dependency checking

#### 2.2.3 Command Modules (`lib/commands/`)

Each module handles a specific domain:

**site.sh**
- create_site()
- delete_site()
- list_sites()
- info_site()
- open_site()

**php.sh**
- install_php()
- list_php()
- switch_php()
- extension_install()

**ssl.sh**
- install_ca()
- create_certificate()
- renew_certificate()

**db.sh**
- create_database()
- import_database()
- export_database()
- list_databases()

**service.sh**
- start_service()
- stop_service()
- restart_service()
- status_services()

**migrate.sh**
- migrate_project()
- preview_migration()
- fix_permissions()

---

## 3. Data Flow

### 3.1 Site Creation Flow

```
User Command
    │
    ▼
┌────────────────────┐
│ Parse Arguments    │
│ - Validate inputs  │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Check Preconditions│
│ - Site name unique │
│ - PHP version ok   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Create Directory   │
│ ~/websites/name/   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Generate Vhost     │
│ From template      │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Enable Site        │
│ a2ensite           │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Test Config        │
│ apachectl test     │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Reload Apache      │
│ systemctl reload   │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Update Registry    │
│ sites.json         │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ Display Success    │
│ Show URL & steps   │
└────────────────────┘
```

### 3.2 Error Handling Flow

```
Operation Starts
    │
    ▼
┌────────────────────┐
│ Validate Inputs    │──────► Error ──► Display Help
└────────┬───────────┘                  Exit 1
         │ Valid
         ▼
┌────────────────────┐
│ Check Preconditions│──────► Error ──► Explain Issue
└────────┬───────────┘                  Suggest Fix
         │ OK                           Exit 1
         ▼
┌────────────────────┐
│ Execute Operation  │──────► Error ──► Rollback Changes
└────────┬───────────┘                  Show Error Detail
         │ Success                      Exit 1
         ▼
┌────────────────────┐
│ Verify Result      │──────► Warning ─► Continue
└────────┬───────────┘                   Log Warning
         │ OK
         ▼
┌────────────────────┐
│ Display Success    │
└────────────────────┘
```

---

## 4. File System Structure

### 4.1 Installation Locations

```
/opt/devflow/               # System installation (optional)
├── bin/devflow            # Main executable
├── lib/                   # Libraries
└── share/                 # Templates and resources

~/.devflow/                # User configuration
├── config.json           # User preferences
├── sites.json            # Site registry
├── ssl/                  # SSL certificates
│   ├── ca/              # Root CA
│   └── certs/           # Site certificates
├── logs/                # DevFlow logs
├── backup/              # Site backups
└── tmp/                 # Temporary files

~/websites/               # Development sites
├── site1.test/
│   └── public/
├── site2.test/
│   └── public/
└── ...

/etc/apache2/
├── sites-available/
│   ├── site1.test.conf
│   ├── site1.test-ssl.conf
│   └── ...
└── sites-enabled/
    ├── site1.test.conf -> ../sites-available/
    └── ...

/run/php/
├── php7.4-fpm.sock
├── php8.2-fpm.sock
└── ...
```

### 4.2 Configuration File Locations

```
~/.devflow/config.json              # Main configuration
~/.devflow/sites.json               # Site registry
/etc/devflow/defaults.conf          # System defaults
/etc/apache2/sites-available/*.conf # Apache vhosts
/etc/php/*/fpm/pool.d/*.conf       # PHP-FPM pools
```

---

## 5. State Management

### 5.1 Site Registry (`sites.json`)

**Purpose**: Central database of all managed sites

**Structure**:
```json
{
  "version": "1.0",
  "sites": [
    {
      "name": "myapp.test",
      "path": "/home/user/websites/myapp.test",
      "docroot": "public",
      "php_version": "8.2",
      "ssl_enabled": true,
      "created_at": "2025-11-13T14:30:00Z",
      "updated_at": "2025-11-13T15:00:00Z",
      "status": "active",
      "database": {
        "name": "myapp_db",
        "user": "myapp_user",
        "host": "127.0.0.1",
        "port": 3306
      },
      "apache_config": "/etc/apache2/sites-available/myapp.test.conf",
      "ssl_config": "/etc/apache2/sites-available/myapp.test-ssl.conf",
      "certificate": "/home/user/.devflow/ssl/certs/myapp.test/"
    }
  ]
}
```

**Operations**:
- Add site
- Update site
- Remove site
- Query sites (by name, PHP version, status)
- Validate integrity

### 5.2 Configuration (`config.json`)

**Purpose**: User preferences and defaults

**Structure**:
```json
{
  "version": "1.0",
  "websites_root": "/home/user/websites",
  "default_php": "8.2",
  "default_docroot": "public",
  "auto_ssl": false,
  "auto_hosts": false,
  "backup_retention_days": 30,
  "log_level": "INFO",
  "services": {
    "apache": true,
    "mysql": true,
    "redis": false
  },
  "php_versions": ["7.4", "8.2", "8.3"],
  "editor": "code"
}
```

---

## 6. Service Integration

### 6.1 Apache Integration

**Configuration Management**:
- Generate vhost from template
- Enable/disable sites
- Test configuration validity
- Reload without downtime

**Vhost Template**:
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

### 6.2 PHP-FPM Integration

**Multi-Version Support**:
- Each version runs separate FPM service
- Unix socket communication
- Per-version configuration
- Independent service control

**Socket Mapping**:
```
PHP 7.4 → /run/php/php7.4-fpm.sock
PHP 8.0 → /run/php/php8.0-fpm.sock
PHP 8.1 → /run/php/php8.1-fpm.sock
PHP 8.2 → /run/php/php8.2-fpm.sock
PHP 8.3 → /run/php/php8.3-fpm.sock
```

### 6.3 systemd Integration

**Service Control**:
```bash
# Start service
systemctl start php8.2-fpm

# Stop service
systemctl stop php8.2-fpm

# Restart service
systemctl restart apache2

# Check status
systemctl status mariadb

# Enable auto-start
systemctl enable php8.2-fpm
```

**Service Dependencies**:
- Apache depends on PHP-FPM (at least one version)
- Sites may depend on MySQL/MariaDB

---

## 7. Security Architecture

### 7.1 Permission Model

**File Ownership**:
```
User directories: user:user
Site directories: user:www-data
Site files: 664 (rw-rw-r--)
Site directories: 775 (rwxrwxr-x)
Private keys: 600 (rw-------)
Config files: 644 (rw-r--r--)
```

**Access Control**:
- DevFlow runs as user
- Sudo required only for system operations
- Principle of least privilege
- No root installations

### 7.2 SSL Certificate Chain

```
┌──────────────────────────┐
│  DevFlow Root CA         │
│  (Self-signed)           │
│  ~/.devflow/ssl/ca/      │
└────────────┬─────────────┘
             │ Signs
             ▼
┌──────────────────────────┐
│  Site Certificate        │
│  myapp.test              │
│  ~/.devflow/ssl/certs/   │
└──────────────────────────┘
```

**Certificate Generation**:
1. Create Root CA (once)
2. Generate site private key
3. Create CSR (Certificate Signing Request)
4. Sign with Root CA
5. Configure Apache SSL vhost

---

## 8. Extension Points

### 8.1 Plugin Architecture (Future)

**Hook System**:
```bash
# Before site creation
devflow_before_site_create() {
    local site_name="$1"
    # Custom logic
}

# After site creation
devflow_after_site_create() {
    local site_name="$1"
    # Custom logic
}
```

**Plugin Location**: `~/.devflow/plugins/`

### 8.2 Template System

**Custom Templates**:
```
~/.devflow/templates/
├── vhost-custom.conf
├── ssl-custom.conf
└── php-pool-custom.conf
```

**Template Variables**:
- `${SITENAME}` - Site domain
- `${DOCROOT}` - Document root path
- `${PHPVER}` - PHP version
- `${USERNAME}` - Current user

---

## 9. Performance Considerations

### 9.1 Optimization Strategies

**File Operations**:
- All operations on native WSL filesystem
- Avoid /mnt paths except during migration
- Batch file operations where possible
- Use rsync for large transfers

**Service Management**:
- Reload instead of restart when possible
- Batch service operations
- Cache service status (5 second TTL)
- Parallel operations where safe

**Configuration**:
- Cache parsed JSON (in-memory)
- Lazy load modules
- Minimize disk writes

### 9.2 Scalability

**Site Limits**:
- Design supports 1000+ sites
- JSON parsing optimized for large files
- Efficient site lookup (indexed)

**Resource Management**:
- Each PHP-FPM uses ~30-50 MB
- Apache ~40-60 MB base
- MySQL/MariaDB ~150-200 MB
- Total for 10 sites: ~1 GB RAM

---

## 10. Error Recovery

### 10.1 Rollback Mechanisms

**Site Creation Rollback**:
```bash
create_site_with_rollback() {
    local site="$1"
    local rollback_actions=()

    # Create directory
    mkdir -p "~/websites/$site" || return 1
    rollback_actions+=("rm -rf ~/websites/$site")

    # Create vhost
    generate_vhost "$site" || {
        execute_rollback "${rollback_actions[@]}"
        return 1
    }
    rollback_actions+=("rm /etc/apache2/sites-available/$site.conf")

    # Enable site
    a2ensite "$site" || {
        execute_rollback "${rollback_actions[@]}"
        return 1
    }

    # Success - clear rollback
    return 0
}
```

### 10.2 Backup Before Operations

**Critical Operations**:
- Site deletion → backup prompt
- Configuration changes → backup config
- Database operations → dump before import

---

## 11. Monitoring & Observability

### 11.1 Logging

**Log Levels**:
- DEBUG: Detailed diagnostic info
- INFO: General informational messages
- WARN: Warning messages
- ERROR: Error messages

**Log Locations**:
```
~/.devflow/logs/devflow.log       # Main log
~/.devflow/logs/devflow-error.log # Errors only
/var/log/apache2/[site]_error.log # Apache errors
/var/log/php*-fpm.log             # PHP-FPM logs
```

### 11.2 Health Checks

**System Health**:
```bash
devflow doctor
```

Checks:
- ✓ Required services running
- ✓ Disk space available
- ✓ Permissions correct
- ✓ Configuration valid
- ✓ No orphaned configs

---

## 12. Development Architecture

### 12.1 Module Independence

Each command module:
- Independent of other modules
- Testable in isolation
- Single responsibility
- Clear interface

### 12.2 Code Organization

```bash
# Good: Single responsibility
create_site() {
    validate_site_name "$1" || return 1
    create_directory "$1" || return 1
    generate_vhost "$1" || return 1
    enable_site "$1" || return 1
}

# Bad: Monolithic function
create_site() {
    # 500 lines of code doing everything
}
```

### 12.3 Testing Strategy

**Unit Tests**:
- Test individual functions
- Mock external dependencies
- Fast execution

**Integration Tests**:
- Test full workflows
- Real system interaction
- Slower but comprehensive

---

## Document History

| Version | Date       | Author        | Changes                    |
|---------|------------|---------------|----------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial system design      |

---

**Document Status**: Draft
**Next Review Date**: Before implementation
**Approval**: Pending
