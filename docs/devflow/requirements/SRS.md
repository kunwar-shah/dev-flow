# Software Requirements Specification (SRS)
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft
**Author**: DevFlow Team

---

## 1. Introduction

### 1.1 Purpose
This Software Requirements Specification (SRS) document describes the functional and non-functional requirements for DevFlow, a command-line tool designed to provide a Laragon-style development environment for WSL and Linux systems.

### 1.2 Scope
DevFlow will provide:
- Multi-site LAMP stack management
- Multiple PHP version support per site
- Automated service configuration and management
- Project migration from Windows filesystem to WSL
- SSL certificate generation and management
- Database management tools
- Node.js project support
- Development environment automation

### 1.3 Intended Audience
- Web developers using WSL for development
- Teams migrating from Laragon to WSL
- Linux developers seeking simplified local development
- DevOps engineers managing development environments
- Open source contributors

### 1.4 Definitions and Acronyms

| Term | Definition |
|------|------------|
| LAMP | Linux, Apache, MySQL/MariaDB, PHP |
| WSL | Windows Subsystem for Linux |
| CLI | Command Line Interface |
| SSL | Secure Sockets Layer / TLS |
| CA | Certificate Authority |
| FPM | FastCGI Process Manager (PHP-FPM) |
| NVM | Node Version Manager |
| vhost | Apache Virtual Host |
| SRS | Software Requirements Specification |

### 1.5 References
- [PRD](PRD.md) - Product Requirements Document
- [System Design](../architecture/SYSTEM_DESIGN.md) - Architecture documentation
- [CLI Reference](../api/CLI_REFERENCE.md) - Command reference

---

## 2. Overall Description

### 2.1 Product Perspective
DevFlow is a standalone CLI tool that operates within WSL/Linux environments. It manages:
- Apache web server configuration
- PHP-FPM services across multiple versions
- MySQL/MariaDB databases
- SSL certificates
- Project directory structures
- Service lifecycle management

### 2.2 Product Functions
- **Site Management**: Create, configure, delete, and list web projects
- **PHP Management**: Install, switch, and manage multiple PHP versions
- **Service Control**: Start, stop, restart, and monitor system services
- **SSL Management**: Generate and manage self-signed certificates
- **Database Operations**: Create, import, export databases
- **Project Migration**: Move projects from /mnt to native WSL filesystem
- **Log Management**: View and monitor application logs
- **Backup/Restore**: Backup sites and databases

### 2.3 User Classes and Characteristics

#### Primary Users: Web Developers
- **Experience Level**: Intermediate to Advanced
- **Technical Skills**: Familiar with CLI, LAMP stack, git
- **Usage Frequency**: Daily
- **Primary Goals**: Fast site creation, easy PHP switching, minimal configuration

#### Secondary Users: DevOps Engineers
- **Experience Level**: Advanced
- **Technical Skills**: System administration, automation
- **Usage Frequency**: Weekly (setup and maintenance)
- **Primary Goals**: Automation, consistency, reproducibility

#### Tertiary Users: New Developers
- **Experience Level**: Beginner to Intermediate
- **Technical Skills**: Basic CLI knowledge
- **Usage Frequency**: During initial setup
- **Primary Goals**: Simple installation, clear documentation

### 2.4 Operating Environment
- **OS**: Ubuntu 22.04+, Debian 11+, WSL2 (Ubuntu 24.04 recommended)
- **Shell**: Bash 4.4+
- **Required Services**: Apache 2.4+, systemd
- **Dependencies**: jq, curl, git, openssl
- **Filesystem**: ext4 (native Linux filesystem required)

### 2.5 Design and Implementation Constraints
- Must run on WSL2 and native Linux
- Must use native services (no Docker for main stack)
- Must support systemd for service management
- Configuration must be version-controllable (text-based)
- Must be compatible with existing Apache/PHP installations
- Must not require root access for normal operations (only for service config)

### 2.6 Assumptions and Dependencies

#### Assumptions
- User has sudo access on the system
- systemd is enabled in WSL (for WSL users)
- Internet connection available for package installation
- Sufficient disk space (minimum 10GB free recommended)

#### Dependencies
- Ondřej Surý's PHP PPA (for multiple PHP versions)
- Apache with mod_proxy_fcgi
- systemd for service management
- jq for JSON parsing
- OpenSSL for certificate generation

---

## 3. Functional Requirements

### 3.1 Site Management

#### FR-1.1: Create Site
**Priority**: Critical
**Description**: Users must be able to create a new development site with a single command.

**Requirements**:
- Accept site name (DNS-format: example.test)
- Accept PHP version (e.g., php8.2)
- Accept document root subdirectory (default: "public")
- Create directory structure at `~/websites/[sitename]/`
- Generate Apache vhost configuration
- Configure PHP-FPM socket for specified version
- Enable site in Apache
- Set correct permissions (user:www-data, 775/664)
- Add entry to site registry (sites.json)
- Validate site name is unique
- Test Apache configuration before reload
- Display success message with URL and next steps

**Input**:
```bash
devflow site create myapp.test php8.2 public
```

**Output**:
```
✓ Created directory: /home/user/websites/myapp.test/public
✓ Generated Apache vhost: /etc/apache2/sites-available/myapp.test.conf
✓ Enabled site: myapp.test
✓ Apache configuration test passed
✓ Reloaded Apache
✓ Added to site registry

Site created successfully!
URL: http://myapp.test
Path: /home/user/websites/myapp.test
PHP: 8.2
Document Root: public/

Next steps:
1. Add to Windows hosts file: 127.0.0.1 myapp.test
   (or run: devflow hosts add myapp.test)
2. Place your code in: /home/user/websites/myapp.test/public/
```

**Error Conditions**:
- Site name already exists → Display error, suggest alternative name
- PHP version not installed → Offer to install, show command
- Invalid site name format → Display format requirements
- Insufficient permissions → Check sudo access
- Apache configuration test fails → Show error details

#### FR-1.2: Delete Site
**Priority**: High
**Description**: Users must be able to remove a site and optionally its files.

**Requirements**:
- Accept site name
- Show site details before deletion
- Prompt for confirmation (safety check)
- Disable site in Apache
- Remove Apache vhost configuration
- Optionally delete site directory
- Remove from site registry
- Reload Apache
- Display summary of actions taken

**Input**:
```bash
devflow site delete myapp.test
```

**Output**:
```
Site: myapp.test
Path: /home/user/websites/myapp.test
PHP: 8.2
Created: 2025-11-10

Delete site configuration and files? [y/N]: y

✓ Disabled site in Apache
✓ Removed vhost configuration
✓ Deleted site directory
✓ Removed from registry
✓ Reloaded Apache

Site 'myapp.test' has been deleted.
```

**Error Conditions**:
- Site not found → Display error, list available sites
- Apache reload fails → Show error, site partially removed
- Permission denied for file deletion → Suggest sudo

#### FR-1.3: List Sites
**Priority**: High
**Description**: Users must be able to view all managed sites.

**Requirements**:
- Display table of all sites
- Show: name, PHP version, status, path
- Support filtering (by PHP version, status)
- Support sorting (by name, date created)
- Show summary count
- Indicate which sites have SSL enabled

**Input**:
```bash
devflow site list
```

**Output**:
```
DevFlow Sites (5 total)

NAME                 PHP    STATUS   SSL   PATH
myapp.test          8.2    active   ✓     ~/websites/myapp.test
oldproject.test     7.4    active   ✗     ~/websites/oldproject.test
laravel-demo.test   8.3    active   ✓     ~/websites/laravel-demo.test
wordpress.test      8.1    inactive ✗     ~/websites/wordpress.test
api.test            8.2    active   ✓     ~/websites/api.test
```

#### FR-1.4: Site Info
**Priority**: Medium
**Description**: Users must be able to view detailed information about a specific site.

**Requirements**:
- Display all site configuration
- Show: name, path, PHP version, document root, SSL status, database info
- Show vhost configuration file path
- Show recent log entries (last 10 errors)
- Show disk usage
- Display creation date

**Input**:
```bash
devflow site info myapp.test
```

**Output**:
```
Site Information: myapp.test

General
  URL:            http://myapp.test (https://myapp.test)
  Path:           /home/user/websites/myapp.test
  Document Root:  public/
  Created:        2025-11-10 14:30:00

Configuration
  PHP Version:    8.2
  PHP-FPM Socket: /run/php/php8.2-fpm.sock
  SSL Enabled:    Yes
  Apache Config:  /etc/apache2/sites-available/myapp.test.conf

Database
  Type:           mysql
  Name:           myapp_db
  Host:           127.0.0.1
  Port:           3306

Resources
  Disk Usage:     245 MB
  Files:          1,234

Recent Errors (last 10)
  2025-11-13 10:15:23 - PHP Fatal error: Uncaught Error in index.php:42
  (no other errors)

Commands
  Open in browser:  devflow site open myapp.test
  View logs:        devflow logs myapp.test
  Backup:           devflow backup create myapp.test
```

#### FR-1.5: Open Site
**Priority**: Low
**Description**: Users should be able to open a site in their default browser.

**Requirements**:
- Accept site name
- Detect if Windows (WSL) or Linux
- Open appropriate browser
- Use HTTPS if SSL enabled, otherwise HTTP

**Input**:
```bash
devflow site open myapp.test
```

**Output**:
```
Opening http://myapp.test in browser...
```

### 3.2 PHP Management

#### FR-2.1: Install PHP Version
**Priority**: Critical
**Description**: Users must be able to install additional PHP versions.

**Requirements**:
- Accept PHP version (7.4, 8.0, 8.1, 8.2, 8.3)
- Add Ondřej Surý PPA if not present
- Install PHP-FPM and CLI packages
- Install common extensions (mbstring, xml, mysql, curl, zip, gd, redis)
- Configure PHP-FPM pool
- Enable and start PHP-FPM service
- Update update-alternatives for CLI
- Display installation summary

**Input**:
```bash
devflow php install 8.2
```

**Output**:
```
Installing PHP 8.2...

✓ Added Ondřej Surý PPA
✓ Updated package lists
✓ Installing PHP 8.2 packages:
  - php8.2-fpm
  - php8.2-cli
  - php8.2-mbstring
  - php8.2-xml
  - php8.2-mysql
  - php8.2-curl
  - php8.2-zip
  - php8.2-gd
  - php8.2-redis
✓ Configured PHP-FPM pool
✓ Started php8.2-fpm service
✓ Configured CLI alternative

PHP 8.2 installed successfully!

PHP-FPM Socket: /run/php/php8.2-fpm.sock
Configuration:  /etc/php/8.2/

Set as default CLI: devflow php switch 8.2
```

#### FR-2.2: List PHP Versions
**Priority**: High
**Description**: Users must be able to see installed PHP versions.

**Requirements**:
- List all installed PHP versions
- Indicate default CLI version
- Show PHP-FPM service status
- Show number of sites using each version

**Input**:
```bash
devflow php list
```

**Output**:
```
Installed PHP Versions

VERSION  CLI DEFAULT  FPM STATUS  SITES
7.4                   running     2
8.1                   running     1
8.2      ✓            running     5
8.3                   stopped     0

Default CLI version: 8.2 (php8.2)
Change default: devflow php switch <version>
```

#### FR-2.3: Switch Default PHP CLI Version
**Priority**: Medium
**Description**: Users must be able to change the default PHP version used in the command line.

**Requirements**:
- Accept PHP version
- Verify version is installed
- Use update-alternatives to set default
- Update shell profile if needed
- Display confirmation

**Input**:
```bash
devflow php switch 8.2
```

**Output**:
```
Switching default PHP CLI to 8.2...

✓ Updated alternatives
✓ PHP 8.2 is now the default

Verify: php -v
PHP 8.2.15 (cli) (built: Jan 10 2025 10:15:23) (NTS)
```

#### FR-2.4: Install PHP Extensions
**Priority**: Medium
**Description**: Users should be able to install additional PHP extensions.

**Requirements**:
- Accept PHP version and extension name
- Install extension for specified version
- Reload PHP-FPM if needed
- Display confirmation

**Input**:
```bash
devflow php extension install 8.2 imagick
```

**Output**:
```
Installing php8.2-imagick...

✓ Installed php8.2-imagick
✓ Reloaded php8.2-fpm

Extension installed successfully!
```

### 3.3 Service Management

#### FR-3.1: Service Status
**Priority**: High
**Description**: Users must be able to view the status of all managed services.

**Requirements**:
- Display status of Apache, PHP-FPM (all versions), MySQL/MariaDB
- Show: service name, status (running/stopped), uptime, memory usage
- Color-coded output (green=running, red=stopped)
- Show ports in use
- Indicate if auto-start enabled

**Input**:
```bash
devflow service status
```

**Output**:
```
DevFlow Services Status

SERVICE         STATUS   UPTIME    MEMORY   AUTO-START
apache2         ● running  2d 5h    45 MB    enabled
php7.4-fpm      ● running  2d 5h    32 MB    enabled
php8.2-fpm      ● running  2d 5h    38 MB    enabled
php8.3-fpm      ○ stopped  -        -        disabled
mariadb         ● running  2d 5h    156 MB   enabled

Ports
  80, 443  - Apache2
  3306     - MariaDB

All critical services are running.
```

#### FR-3.2: Start/Stop/Restart Services
**Priority**: Critical
**Description**: Users must be able to control services.

**Requirements**:
- Accept service name or "all"
- Support: start, stop, restart, reload
- Show progress indicator
- Display result
- Handle dependencies (e.g., Apache depends on PHP-FPM)

**Input**:
```bash
devflow service restart apache2
devflow service stop php7.4-fpm
devflow service start all
```

**Output**:
```
Restarting apache2...
✓ apache2 restarted successfully

Stopping php7.4-fpm...
✓ php7.4-fpm stopped

Starting all services...
✓ apache2 started
✓ php7.4-fpm started
✓ php8.2-fpm started
✓ mariadb started

All services started successfully.
```

### 3.4 SSL Management

#### FR-4.1: Install Root CA
**Priority**: High
**Description**: Users must be able to create a root Certificate Authority for self-signed certificates.

**Requirements**:
- Generate RSA private key
- Create self-signed root certificate
- Store in `~/.devflow/ssl/ca/`
- Display instructions for trusting CA in browsers
- Platform-specific instructions (Chrome, Firefox, Edge)
- For Windows (WSL): provide PowerShell command

**Input**:
```bash
devflow ssl install-ca
```

**Output**:
```
Creating DevFlow Root Certificate Authority...

✓ Generated private key
✓ Created root certificate
✓ Saved to: /home/user/.devflow/ssl/ca/

Root CA installed successfully!

To trust certificates in your browser:

Windows (PowerShell as Admin):
  Import-Certificate -FilePath "\\wsl$\Ubuntu\home\user\.devflow\ssl\ca\devflow-ca.crt" -CertStoreLocation Cert:\LocalMachine\Root

Chrome/Edge: Settings → Privacy → Security → Manage Certificates → Trusted Root → Import
Firefox: Settings → Privacy → Certificates → View Certificates → Import

Certificate location: /home/user/.devflow/ssl/ca/devflow-ca.crt

You only need to do this once. All site certificates will be trusted automatically.
```

#### FR-4.2: Create Site SSL Certificate
**Priority**: High
**Description**: Users must be able to enable SSL/HTTPS for a site.

**Requirements**:
- Accept site name
- Verify site exists
- Check if Root CA exists (create if not)
- Generate private key for site
- Create certificate signing request (CSR)
- Sign certificate with root CA
- Create/update Apache SSL vhost
- Enable SSL site in Apache
- Update site registry (ssl_enabled: true)
- Display confirmation with HTTPS URL

**Input**:
```bash
devflow ssl create myapp.test
```

**Output**:
```
Enabling SSL for myapp.test...

✓ Generated private key
✓ Created certificate signing request
✓ Signed certificate with Root CA
✓ Created SSL vhost configuration
✓ Enabled SSL site
✓ Reloaded Apache
✓ Updated site registry

SSL enabled successfully!

URLs:
  HTTP:  http://myapp.test
  HTTPS: https://myapp.test (✓ Trusted)

Certificate location: /home/user/.devflow/ssl/certs/myapp.test/

If certificate not trusted, ensure Root CA is installed:
  devflow ssl install-ca
```

### 3.5 Database Management

#### FR-5.1: Create Database
**Priority**: High
**Description**: Users must be able to create a new database.

**Requirements**:
- Accept database name
- Validate name (alphanumeric + underscore only)
- Create database with UTF-8 encoding
- Optionally create dedicated user
- Set permissions for user
- Update site registry if associated with a site
- Display connection details

**Input**:
```bash
devflow db create myapp_db
```

**Output**:
```
Creating database: myapp_db

✓ Database created
✓ User 'myapp_user' created
✓ Permissions granted

Database created successfully!

Connection Details:
  Database: myapp_db
  User:     myapp_user
  Password: [randomly generated]
  Host:     127.0.0.1
  Port:     3306

Add to your .env file:
  DB_CONNECTION=mysql
  DB_HOST=127.0.0.1
  DB_PORT=3306
  DB_DATABASE=myapp_db
  DB_USERNAME=myapp_user
  DB_PASSWORD=[password shown above]

Password saved to: /home/user/.devflow/db-credentials.txt
```

#### FR-5.2: List Databases
**Priority**: Medium
**Description**: Users must be able to list all databases.

**Requirements**:
- Show all databases
- Display size
- Show associated site (if registered)
- Exclude system databases (mysql, information_schema, etc.)

**Input**:
```bash
devflow db list
```

**Output**:
```
Databases

NAME                SIZE      SITE
myapp_db           12.5 MB    myapp.test
oldproject_db      245 MB     oldproject.test
laravel_test       5.2 MB     laravel-demo.test

Total: 3 databases (262.7 MB)
```

#### FR-5.3: Import Database
**Priority**: High
**Description**: Users must be able to import SQL dumps.

**Requirements**:
- Accept database name and SQL file path
- Verify file exists
- Show file size and estimated import time
- Display progress for large files
- Handle compressed files (.sql.gz)
- Display import summary

**Input**:
```bash
devflow db import myapp_db backup.sql
```

**Output**:
```
Importing backup.sql into myapp_db...

File size: 125 MB
Estimated time: ~30 seconds

Importing... ████████████████████ 100%

✓ Import completed in 28 seconds
✓ 1,234 tables created
✓ 45,678 rows inserted

Database import successful!
```

#### FR-5.4: Export Database
**Priority**: High
**Description**: Users must be able to export databases.

**Requirements**:
- Accept database name and optional output file
- Default filename: [dbname]_YYYY-MM-DD_HHMMSS.sql
- Optionally compress output (.sql.gz)
- Display progress
- Show output file location

**Input**:
```bash
devflow db export myapp_db
```

**Output**:
```
Exporting myapp_db...

Exporting... ████████████████████ 100%

✓ Export completed in 12 seconds
✓ File size: 125 MB

Database exported successfully!
Location: /home/user/myapp_db_2025-11-13_145623.sql

Compress: gzip /home/user/myapp_db_2025-11-13_145623.sql
```

### 3.6 Project Migration

#### FR-6.1: Migrate Project from /mnt
**Priority**: Critical
**Description**: Users must be able to move projects from Windows filesystem (/mnt) to WSL.

**Requirements**:
- Accept source path (/mnt/c/...) and site name
- Validate source path exists
- Estimate size and check available disk space
- Show rsync dry-run preview
- Prompt for confirmation
- Exclude common directories (node_modules, vendor, storage/logs)
- Show real-time progress
- Fix permissions after transfer
- Detect project type (Laravel, WordPress, etc.)
- Offer to create site vhost
- Offer to create database
- Display next steps

**Input**:
```bash
devflow migrate /mnt/c/Users/ajay/Projects/myapp myapp.test
```

**Output**:
```
Migrating project to WSL...

Source: /mnt/c/Users/ajay/Projects/myapp
Target: /home/user/websites/myapp.test
Size:   245 MB (estimated)
Available disk space: 45 GB

Dry-run preview:
  ./
  ./public/
  ./public/index.php
  ./composer.json
  ... (156 more files)

Excluded directories: node_modules/, vendor/, storage/logs/

Proceed with migration? [y/N]: y

Migrating files... ████████████████████ 100% (245 MB in 8s)

✓ Files transferred: 1,234 files
✓ Permissions fixed
✓ Git repository preserved

Project type detected: Laravel 10

Create site vhost? [Y/n]: y
✓ Site vhost created

Create database? [Y/n]: y
Database name [myapp_db]:
✓ Database created: myapp_db

Migration completed successfully!

Next steps:
1. cd ~/websites/myapp.test
2. Copy .env.example to .env
3. Update .env with database credentials
4. Run: composer install
5. Run: php artisan key:generate
6. Run: php artisan migrate
7. Add to Windows hosts: 127.0.0.1 myapp.test
8. Open: http://myapp.test
```

### 3.7 Log Management

#### FR-7.1: View Logs
**Priority**: High
**Description**: Users must be able to view site logs.

**Requirements**:
- Accept site name
- Aggregate logs from: Apache access, Apache error, PHP-FPM, application logs
- Color-code by severity (error=red, warning=yellow, info=white)
- Show last N lines (default: 50)
- Support filtering by log type
- Support real-time tailing

**Input**:
```bash
devflow logs myapp.test
devflow logs myapp.test --error
devflow logs myapp.test --tail
```

**Output**:
```
Logs for myapp.test (last 50 lines)

[2025-11-13 14:56:23] [ACCESS] 127.0.0.1 GET /index.php 200
[2025-11-13 14:56:24] [ERROR] PHP Fatal error: Uncaught Error in index.php:42
[2025-11-13 14:56:25] [ACCESS] 127.0.0.1 GET /app.css 200
...

View specific log:
  Apache access: tail -f /var/log/apache2/myapp.test_access.log
  Apache error:  tail -f /var/log/apache2/myapp.test_error.log
  PHP-FPM:       tail -f /var/log/php8.2-fpm.log
```

### 3.8 Backup and Restore

#### FR-8.1: Create Backup
**Priority**: Medium
**Description**: Users should be able to backup sites.

**Requirements**:
- Accept site name
- Create timestamped backup directory
- Backup site files (compressed tar.gz)
- Backup database (SQL dump, compressed)
- Backup .env file (encrypted or separate secure location)
- Create metadata.json with site configuration
- Display backup location and size

**Input**:
```bash
devflow backup create myapp.test
```

**Output**:
```
Creating backup for myapp.test...

✓ Backed up files (245 MB → 89 MB compressed)
✓ Backed up database (12.5 MB → 3.2 MB compressed)
✓ Saved configuration
✓ Saved environment file

Backup created successfully!

Backup ID:   myapp.test_2025-11-13_145623
Location:    /var/devflow/backup/myapp.test_2025-11-13_145623/
Total size:  92.2 MB (compressed)

Restore: devflow backup restore myapp.test_2025-11-13_145623 <target-site>
```

#### FR-8.2: Restore Backup
**Priority**: Medium
**Description**: Users should be able to restore from backups.

**Requirements**:
- Accept backup ID and target site name
- Show backup details
- Prompt for confirmation
- Restore files
- Restore database
- Restore configuration
- Update site registry
- Display success message

**Input**:
```bash
devflow backup restore myapp.test_2025-11-13_145623 myapp-restored.test
```

**Output**:
```
Restoring backup: myapp.test_2025-11-13_145623

Backup created: 2025-11-13 14:56:23
PHP version:    8.2
Database:       myapp_db
Size:           92.2 MB

Target site:    myapp-restored.test

This will:
  - Create new site: myapp-restored.test
  - Restore all files
  - Create and populate database: myapp_restored_db
  - Configure Apache vhost

Proceed? [y/N]: y

Restoring... ████████████████████ 100%

✓ Site created
✓ Files restored
✓ Database restored
✓ Configuration applied
✓ Apache reloaded

Restore completed successfully!

Site URL: http://myapp-restored.test
Update .env with new database name if needed: myapp_restored_db
```

### 3.9 Windows Integration

#### FR-9.1: Add Hosts Entry
**Priority**: Medium
**Description**: Users should be able to add Windows hosts file entries from WSL.

**Requirements**:
- Accept site name
- Generate PowerShell command
- Optionally execute automatically (if running as admin in Windows)
- Display manual instructions
- Verify entry was added

**Input**:
```bash
devflow hosts add myapp.test
```

**Output**:
```
Adding myapp.test to Windows hosts file...

Run this command in Windows PowerShell (as Administrator):

  Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "127.0.0.1 myapp.test"

Or manually edit: C:\Windows\System32\drivers\etc\hosts
Add this line: 127.0.0.1 myapp.test

After adding, verify: ping myapp.test
```

### 3.10 Xdebug Management

#### FR-10.1: Enable Xdebug
**Priority**: Medium
**Description**: Users should be able to enable Xdebug for a PHP version.

**Requirements**:
- Accept PHP version
- Install xdebug if not present
- Configure xdebug.ini
- Restart PHP-FPM
- Display IDE configuration instructions (VS Code, PhpStorm)

**Input**:
```bash
devflow xdebug enable 8.2
```

**Output**:
```
Enabling Xdebug for PHP 8.2...

✓ Installed php8.2-xdebug
✓ Configured /etc/php/8.2/fpm/conf.d/20-xdebug.ini
✓ Restarted php8.2-fpm

Xdebug enabled!

Configuration:
  xdebug.mode = develop,debug
  xdebug.start_with_request = yes
  xdebug.client_port = 9003

VS Code Configuration (.vscode/launch.json):
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Listen for Xdebug",
      "type": "php",
      "request": "launch",
      "port": 9003,
      "pathMappings": {
        "/home/user/websites/myapp.test": "${workspaceFolder}"
      }
    }
  ]
}

PhpStorm: Already configured to listen on port 9003 by default.
```

#### FR-10.2: Disable Xdebug
**Priority**: Medium
**Description**: Users should be able to disable Xdebug (for performance).

**Requirements**:
- Accept PHP version
- Disable xdebug extension
- Restart PHP-FPM
- Display confirmation

**Input**:
```bash
devflow xdebug disable 8.2
```

**Output**:
```
Disabling Xdebug for PHP 8.2...

✓ Disabled xdebug extension
✓ Restarted php8.2-fpm

Xdebug disabled. PHP-FPM will run faster now.
```

---

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### NFR-1: Site Creation Speed
- **Requirement**: Site creation must complete in < 30 seconds
- **Rationale**: Fast iteration for developers
- **Measurement**: Time from command execution to Apache reload

#### NFR-2: File Operation Speed
- **Requirement**: All file operations must run on native WSL filesystem
- **Rationale**: Avoid /mnt performance bottlenecks
- **Measurement**: File I/O throughput > 500 MB/s

#### NFR-3: Memory Usage
- **Requirement**: DevFlow CLI should use < 50 MB memory
- **Rationale**: Lightweight, no resource bloat
- **Measurement**: Peak memory during operations

#### NFR-4: Service Startup
- **Requirement**: All services must start in < 10 seconds total
- **Rationale**: Fast system restart/reboot
- **Measurement**: Time from systemd start to all services running

### 4.2 Reliability Requirements

#### NFR-5: Configuration Validation
- **Requirement**: All Apache configurations must be tested before reload
- **Rationale**: Prevent service disruption
- **Implementation**: `apachectl configtest` before reload

#### NFR-6: Atomic Operations
- **Requirement**: Site creation/deletion must be atomic (all-or-nothing)
- **Rationale**: Prevent partial/corrupt states
- **Implementation**: Rollback on error

#### NFR-7: Data Integrity
- **Requirement**: Backups must be verified for integrity
- **Rationale**: Ensure restorability
- **Implementation**: Checksum verification

### 4.3 Usability Requirements

#### NFR-8: Clear Error Messages
- **Requirement**: All error messages must be actionable
- **Format**: `Error: [what happened]. [why it happened]. [how to fix].`
- **Example**: `Error: Site 'myapp.test' already exists. Choose a different name or delete existing site with: devflow site delete myapp.test`

#### NFR-9: Progress Indicators
- **Requirement**: Operations > 5 seconds must show progress
- **Implementation**: Progress bars, spinners, percentage

#### NFR-10: Help Documentation
- **Requirement**: Every command must have `--help` flag
- **Content**: Description, usage, examples, related commands

#### NFR-11: Installation Time
- **Requirement**: Complete installation must complete in < 5 minutes
- **Includes**: Dependencies, configuration, initial setup

### 4.4 Security Requirements

#### NFR-12: File Permissions
- **Requirement**: All site files must use secure permissions
- **Implementation**: user:www-data ownership, 775 directories, 664 files

#### NFR-13: Database Credentials
- **Requirement**: Database credentials must be stored securely
- **Implementation**: Encrypted storage, restricted file permissions (600)

#### NFR-14: SSL Certificates
- **Requirement**: Private keys must be stored with 600 permissions
- **Location**: User-specific directory (~/.devflow/ssl/)

#### NFR-15: No Hardcoded Secrets
- **Requirement**: No passwords, keys, or tokens in codebase
- **Implementation**: Generated at runtime, stored securely

### 4.5 Maintainability Requirements

#### NFR-16: Code Organization
- **Requirement**: Modular, single-responsibility functions
- **Standard**: Google Shell Style Guide
- **Enforcement**: shellcheck linting

#### NFR-17: Configuration Format
- **Requirement**: All configuration in JSON (parseable)
- **Benefits**: Version control, programmatic access

#### NFR-18: Test Coverage
- **Requirement**: > 80% test coverage for core functions
- **Framework**: BATS (Bash Automated Testing System)

#### NFR-19: Documentation
- **Requirement**: All functions must have header comments
- **Format**: Description, parameters, return values, examples

### 4.6 Portability Requirements

#### NFR-20: OS Compatibility
- **Supported**: Ubuntu 22.04+, Debian 11+, WSL2 (Ubuntu 24.04)
- **Shell**: Bash 4.4+ (no zsh-specific features)

#### NFR-21: Dependency Management
- **Requirement**: All dependencies must be auto-installable via apt
- **Check**: Installation script verifies and installs missing dependencies

### 4.7 Scalability Requirements

#### NFR-22: Site Limit
- **Requirement**: Support minimum 100 sites without performance degradation
- **Measurement**: Site listing time < 1 second for 100 sites

#### NFR-23: Log File Size
- **Requirement**: Automatic log rotation
- **Implementation**: Leverage logrotate, prevent disk fill

---

## 5. External Interface Requirements

### 5.1 User Interfaces

#### UI-1: Command Line Interface
- **Type**: Text-based CLI
- **Shell**: Bash
- **Output**: Plain text, table formatting, color-coded
- **Input**: POSIX-compliant command syntax

#### UI-2: Output Formatting
- **Success**: Green checkmarks (✓)
- **Errors**: Red X marks (✗)
- **Warnings**: Yellow exclamation (⚠)
- **Info**: Blue info icon (ℹ)
- **Progress**: ASCII progress bars

### 5.2 Hardware Interfaces
- **Disk**: Minimum 10GB free space
- **Memory**: Minimum 2GB RAM (4GB recommended)
- **Network**: Internet connection for package installation

### 5.3 Software Interfaces

#### SI-1: Apache Web Server
- **Version**: 2.4+
- **Interface**: Configuration files, systemctl commands
- **Config Location**: /etc/apache2/

#### SI-2: PHP-FPM
- **Version**: 7.4, 8.0, 8.1, 8.2, 8.3
- **Interface**: Unix sockets, systemctl commands
- **Config Location**: /etc/php/*/fpm/

#### SI-3: MySQL/MariaDB
- **Version**: MySQL 8.0+ or MariaDB 10.6+
- **Interface**: mysql CLI, TCP socket (127.0.0.1:3306)

#### SI-4: systemd
- **Interface**: systemctl commands for service management
- **Required**: WSL must have systemd enabled

#### SI-5: OpenSSL
- **Version**: 1.1.1+
- **Interface**: Command-line for certificate generation

### 5.4 Communication Interfaces
- **HTTP**: Port 80 (Apache)
- **HTTPS**: Port 443 (Apache SSL)
- **MySQL**: Port 3306 (MariaDB)
- **Xdebug**: Port 9003 (Debug protocol)

---

## 6. System Features Priority

### Critical (Must Have for MVP)
- Site creation and deletion
- PHP version management
- Apache vhost generation
- Service management
- Project migration from /mnt
- Site listing

### High (Should Have for MVP)
- SSL certificate generation
- Database management (create, list, import, export)
- Log viewing
- Installation script

### Medium (Nice to Have)
- Xdebug management
- Windows hosts file integration
- Backup/restore
- Site templates

### Low (Future Enhancements)
- Node.js integration
- Redis/PostgreSQL support
- Monitoring and alerts
- Plugin system

---

## 7. Other Requirements

### 7.1 Licensing
- **License**: MIT License
- **Open Source**: GitHub public repository
- **Contributions**: Community contributions welcome

### 7.2 Documentation
- **User Guide**: Complete installation and usage documentation
- **API Reference**: All commands documented with examples
- **Troubleshooting**: Common issues and solutions
- **Architecture**: System design documentation
- **Contributing**: Guidelines for contributors

### 7.3 Testing
- **Unit Tests**: BATS framework for function testing
- **Integration Tests**: End-to-end workflow testing
- **CI/CD**: GitHub Actions for automated testing
- **Coverage**: Minimum 80% code coverage

---

## 8. Appendices

### 8.1 Glossary
See section 1.4 for definitions and acronyms.

### 8.2 Use Case Diagram
```
┌─────────────────────────────────────────────────────────┐
│                       DevFlow System                     │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Developer                                                │
│     │                                                     │
│     ├─→ Manage Sites (Create, Delete, List, Info)       │
│     ├─→ Manage PHP (Install, Switch, Configure)         │
│     ├─→ Manage SSL (Create Certs, Enable HTTPS)         │
│     ├─→ Manage Database (Create, Import, Export)        │
│     ├─→ View Logs (Access, Error, Application)          │
│     ├─→ Migrate Projects (From Windows to WSL)          │
│     ├─→ Backup/Restore Sites                            │
│     └─→ Control Services (Start, Stop, Restart)         │
│                                                           │
│  DevOps Engineer                                          │
│     │                                                     │
│     ├─→ Configure Services                               │
│     ├─→ Monitor System Health                            │
│     └─→ Automate Deployments                             │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### 8.3 Command Syntax Reference
```bash
devflow <command> <subcommand> [options] [arguments]

Examples:
  devflow site create myapp.test php8.2 public
  devflow site list
  devflow site delete myapp.test
  devflow php install 8.2
  devflow ssl create myapp.test
  devflow db create myapp_db
  devflow migrate /mnt/c/Projects/myapp myapp.test
  devflow backup create myapp.test
  devflow service status
  devflow logs myapp.test --tail
```

---

## Document History

| Version | Date       | Author        | Changes                |
|---------|------------|---------------|------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial SRS document   |

---

**Document Status**: Draft
**Next Review Date**: After PRD completion
**Approval**: Pending
