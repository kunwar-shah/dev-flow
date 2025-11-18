# User Stories
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft

---

## 1. Introduction

This document contains user stories for DevFlow, organized by feature area and priority. Each story follows the format:

**As a** [user type], **I want** [goal], **so that** [benefit].

Stories are tagged with:
- **Priority**: Critical, High, Medium, Low
- **Phase**: MVP (1), Phase 2, Phase 3
- **Story Points**: Effort estimate (1-13)

---

## 2. Site Management

### US-001: Create New Site
**Priority**: Critical | **Phase**: MVP | **Points**: 5

**As a** web developer,
**I want** to create a new development site with a single command,
**so that** I can start coding immediately without manual Apache configuration.

**Acceptance Criteria**:
- Given I run `devflow site create myapp.test php8.2`
- When the command completes
- Then a directory is created at `~/websites/myapp.test/public`
- And an Apache vhost is configured and enabled
- And the site is accessible at `http://myapp.test`
- And I see a success message with the URL and next steps

### US-002: List All Sites
**Priority**: High | **Phase**: MVP | **Points**: 3

**As a** web developer,
**I want** to see a list of all my development sites,
**so that** I can quickly remember what sites I have and their configurations.

**Acceptance Criteria**:
- Given I have created multiple sites
- When I run `devflow site list`
- Then I see a table showing: site name, PHP version, status, SSL status, path
- And the list is sorted alphabetically by site name
- And I see a count of total sites

### US-003: Delete Site
**Priority**: High | **Phase**: MVP | **Points**: 3

**As a** web developer,
**I want** to safely delete a development site,
**so that** I can clean up old projects without leaving configuration remnants.

**Acceptance Criteria**:
- Given I run `devflow site delete myapp.test`
- When I see the confirmation prompt
- And I confirm the deletion
- Then the Apache vhost is disabled and removed
- And the site directory is deleted
- And the site is removed from the registry
- And I see a summary of what was deleted

### US-004: View Site Details
**Priority**: Medium | **Phase**: MVP | **Points**: 2

**As a** web developer,
**I want** to view detailed information about a specific site,
**so that** I can check its configuration and troubleshoot issues.

**Acceptance Criteria**:
- Given I run `devflow site info myapp.test`
- When the command completes
- Then I see: URL, path, PHP version, SSL status, database info, disk usage
- And I see the location of the Apache config file
- And I see recent error log entries (if any)

### US-005: Open Site in Browser
**Priority**: Low | **Phase**: 2 | **Points**: 2

**As a** web developer,
**I want** to open a site in my browser from the command line,
**so that** I can quickly preview my work without typing the URL.

**Acceptance Criteria**:
- Given I run `devflow site open myapp.test`
- When the command completes
- Then my default browser opens
- And navigates to `http://myapp.test` (or `https://` if SSL enabled)

---

## 3. PHP Management

### US-006: Install PHP Version
**Priority**: Critical | **Phase**: MVP | **Points**: 8

**As a** web developer,
**I want** to install additional PHP versions easily,
**so that** I can support projects with different PHP requirements.

**Acceptance Criteria**:
- Given I run `devflow php install 8.2`
- When the installation completes
- Then PHP 8.2 FPM and CLI are installed
- And common extensions are installed (mbstring, xml, mysql, curl, zip, gd)
- And the PHP-FPM service is running
- And I can create sites using PHP 8.2

### US-007: List Installed PHP Versions
**Priority**: High | **Phase**: MVP | **Points**: 2

**As a** web developer,
**I want** to see which PHP versions are installed,
**so that** I know what versions are available for my sites.

**Acceptance Criteria**:
- Given I run `devflow php list`
- When the command completes
- Then I see a table of installed PHP versions
- And I see which version is the CLI default
- And I see the FPM service status for each version
- And I see how many sites are using each version

### US-008: Switch CLI PHP Version
**Priority**: Medium | **Phase**: MVP | **Points**: 3

**As a** web developer,
**I want** to change the default PHP version used in my terminal,
**so that** commands like `php` and `composer` use the version I need.

**Acceptance Criteria**:
- Given I run `devflow php switch 8.2`
- When the command completes
- Then running `php -v` shows PHP 8.2
- And I see a confirmation message
- And the change persists in new terminal sessions

### US-009: Install PHP Extension
**Priority**: Medium | **Phase**: 2 | **Points**: 3

**As a** web developer,
**I want** to install additional PHP extensions for a specific version,
**so that** I can add functionality needed by my applications.

**Acceptance Criteria**:
- Given I run `devflow php extension install 8.2 imagick`
- When the installation completes
- Then php8.2-imagick is installed
- And PHP-FPM is reloaded
- And I see a confirmation message

---

## 4. Service Management

### US-010: View Service Status
**Priority**: High | **Phase**: MVP | **Points**: 3

**As a** web developer,
**I want** to see the status of all development services,
**so that** I can quickly diagnose if something is not running.

**Acceptance Criteria**:
- Given I run `devflow service status`
- When the command completes
- Then I see a list of services (Apache, PHP-FPM versions, MariaDB)
- And I see each service's status (running/stopped)
- And I see uptime and memory usage
- And I see which ports are in use

### US-011: Restart Services
**Priority**: Critical | **Phase**: MVP | **Points**: 2

**As a** web developer,
**I want** to restart services easily,
**so that** I can apply configuration changes or recover from errors.

**Acceptance Criteria**:
- Given I run `devflow service restart apache2`
- When the command completes
- Then Apache is restarted
- And I see a success message
- And my sites continue to work

### US-012: Start All Services
**Priority**: High | **Phase**: MVP | **Points**: 2

**As a** web developer,
**I want** to start all development services at once,
**so that** I can quickly get my environment running after a reboot.

**Acceptance Criteria**:
- Given I run `devflow service start all`
- When the command completes
- Then all configured services start
- And I see the status of each service
- And I see a summary of what was started

---

## 5. SSL Management

### US-013: Create Root CA
**Priority**: High | **Phase**: 2 | **Points**: 5

**As a** web developer,
**I want** to create a trusted root certificate authority,
**so that** all my local development sites have trusted HTTPS certificates.

**Acceptance Criteria**:
- Given I run `devflow ssl install-ca`
- When the command completes
- Then a root CA is created
- And I see instructions for trusting it in my browser
- And I see platform-specific instructions (Windows, Chrome, Firefox)

### US-014: Enable SSL for Site
**Priority**: High | **Phase**: 2 | **Points**: 5

**As a** web developer,
**I want** to enable HTTPS for a development site,
**so that** I can test SSL features and avoid mixed-content warnings.

**Acceptance Criteria**:
- Given I run `devflow ssl create myapp.test`
- When the command completes
- Then a certificate is generated and signed by the root CA
- And an Apache SSL vhost is created
- And the site is accessible at `https://myapp.test`
- And the certificate is trusted (if root CA is installed in browser)

---

## 6. Database Management

### US-015: Create Database
**Priority**: High | **Phase**: 2 | **Points**: 3

**As a** web developer,
**I want** to create a new MySQL database easily,
**so that** I don't have to remember MySQL syntax.

**Acceptance Criteria**:
- Given I run `devflow db create myapp_db`
- When the command completes
- Then a database named `myapp_db` is created
- And a dedicated user is created with a secure password
- And I see the connection details
- And the password is saved securely

### US-016: Import Database Dump
**Priority**: High | **Phase**: 2 | **Points**: 3

**As a** web developer,
**I want** to import SQL dumps easily,
**so that** I can restore data from backups or staging environments.

**Acceptance Criteria**:
- Given I have a SQL dump file
- When I run `devflow db import myapp_db backup.sql`
- Then the SQL file is imported into the database
- And I see a progress indicator for large files
- And I see a summary of what was imported
- And compressed files (.sql.gz) are supported

### US-017: Export Database
**Priority**: Medium | **Phase**: 2 | **Points**: 2

**As a** web developer,
**I want** to export databases to SQL files,
**so that** I can back up or share data.

**Acceptance Criteria**:
- Given I run `devflow db export myapp_db`
- When the command completes
- Then an SQL dump is created
- And the filename includes a timestamp
- And I see the file location and size
- And I can optionally specify compression

### US-018: List Databases
**Priority**: Medium | **Phase**: 2 | **Points**: 2

**As a** web developer,
**I want** to see all my databases,
**so that** I can manage them and check their sizes.

**Acceptance Criteria**:
- Given I run `devflow db list`
- When the command completes
- Then I see a list of all databases (excluding system DBs)
- And I see each database's size
- And I see which site each database is associated with (if any)

---

## 7. Project Migration

### US-019: Migrate Project from Windows
**Priority**: Critical | **Phase**: MVP | **Points**: 8

**As a** web developer,
**I want** to safely move my project from Windows (/mnt) to WSL,
**so that** I get native Linux performance and avoid AI tool slowdowns.

**Acceptance Criteria**:
- Given I run `devflow migrate /mnt/c/Projects/myapp myapp.test`
- When the migration completes
- Then all files are copied to `~/websites/myapp.test`
- And git history is preserved
- And unnecessary files (node_modules, vendor) are excluded
- And permissions are set correctly
- And I'm offered to create a vhost and database
- And I see next steps (composer install, etc.)

### US-020: Dry-Run Migration
**Priority**: Medium | **Phase**: MVP | **Points**: 2

**As a** web developer,
**I want** to preview what will be migrated before actually doing it,
**so that** I can verify the migration will work correctly.

**Acceptance Criteria**:
- Given the migration command shows a dry-run by default
- When I see the preview
- Then I see a list of files that will be copied
- And I see files that will be excluded
- And I see the estimated size
- And I must confirm before the actual migration starts

---

## 8. Log Management

### US-021: View Site Logs
**Priority**: High | **Phase**: 2 | **Points**: 3

**As a** web developer,
**I want** to view logs for a specific site,
**so that** I can debug errors and monitor activity.

**Acceptance Criteria**:
- Given I run `devflow logs myapp.test`
- When the command completes
- Then I see aggregated logs from Apache and PHP-FPM
- And errors are highlighted in red
- And I see the last 50 lines by default
- And I can filter by log type (--error, --access)

### US-022: Tail Logs in Real-Time
**Priority**: Medium | **Phase**: 2 | **Points**: 2

**As a** web developer,
**I want** to watch logs in real-time,
**so that** I can see errors as they happen while testing.

**Acceptance Criteria**:
- Given I run `devflow logs myapp.test --tail`
- When the command runs
- Then I see new log entries as they occur
- And I can press Ctrl+C to stop
- And different log types are color-coded

---

## 9. Backup and Restore

### US-023: Create Site Backup
**Priority**: Medium | **Phase**: 2 | **Points**: 5

**As a** web developer,
**I want** to create backups of my sites,
**so that** I can restore them if something goes wrong.

**Acceptance Criteria**:
- Given I run `devflow backup create myapp.test`
- When the backup completes
- Then all site files are backed up (compressed)
- And the database is backed up (compressed)
- And configuration is saved
- And I see the backup location and ID
- And I see the total backup size

### US-024: Restore from Backup
**Priority**: Medium | **Phase**: 2 | **Points**: 5

**As a** web developer,
**I want** to restore a site from a backup,
**so that** I can recover from mistakes or create a copy.

**Acceptance Criteria**:
- Given I have a backup ID
- When I run `devflow backup restore [backup-id] newsite.test`
- Then a new site is created with the backed-up files
- And the database is restored
- And configuration is applied
- And I see a success message with the new site URL

### US-025: List Backups
**Priority**: Low | **Phase**: 2 | **Points**: 2

**As a** web developer,
**I want** to see all available backups,
**so that** I can choose which one to restore.

**Acceptance Criteria**:
- Given I run `devflow backup list`
- When the command completes
- Then I see all backups with: site name, date, size, backup ID
- And backups are sorted by date (newest first)

---

## 10. Windows Integration

### US-026: Add Hosts Entry
**Priority**: Medium | **Phase**: 2 | **Points**: 3

**As a** web developer using WSL,
**I want** to automatically add entries to my Windows hosts file,
**so that** I don't have to manually edit it each time.

**Acceptance Criteria**:
- Given I run `devflow hosts add myapp.test`
- When the command completes
- Then I see a PowerShell command to run in Windows
- Or the entry is added automatically if possible
- And I see instructions for manual editing if needed
- And I can verify the entry was added

### US-027: Remove Hosts Entry
**Priority**: Low | **Phase**: 2 | **Points**: 2

**As a** web developer,
**I want** to remove hosts file entries,
**so that** I can clean up when I delete sites.

**Acceptance Criteria**:
- Given I run `devflow hosts remove myapp.test`
- When the command completes
- Then I see instructions or a command to remove the entry
- And I see confirmation when it's removed

---

## 11. Xdebug Management

### US-028: Enable Xdebug
**Priority**: Medium | **Phase**: 2 | **Points**: 5

**As a** web developer,
**I want** to enable Xdebug for debugging,
**so that** I can step through my code and find bugs faster.

**Acceptance Criteria**:
- Given I run `devflow xdebug enable 8.2`
- When the command completes
- Then Xdebug is installed and enabled for PHP 8.2
- And PHP-FPM is restarted
- And I see IDE configuration instructions (VS Code, PhpStorm)
- And I can set breakpoints and debug

### US-029: Disable Xdebug
**Priority**: Medium | **Phase**: 2 | **Points**: 2

**As a** web developer,
**I want** to disable Xdebug when not debugging,
**so that** my site runs faster during normal development.

**Acceptance Criteria**:
- Given I run `devflow xdebug disable 8.2`
- When the command completes
- Then Xdebug is disabled for PHP 8.2
- And PHP-FPM is restarted
- And I see a confirmation message

---

## 12. Installation and Setup

### US-030: Easy Installation
**Priority**: Critical | **Phase**: MVP | **Points**: 13

**As a** new user,
**I want** to install DevFlow with a single command,
**so that** I can start using it quickly without manual setup.

**Acceptance Criteria**:
- Given I run the installation command
- When the installation completes
- Then all dependencies are installed
- And the `devflow` command is available
- And I see a success message with next steps
- And the installation takes less than 5 minutes

### US-031: Configuration Wizard
**Priority**: High | **Phase**: MVP | **Points**: 5

**As a** new user,
**I want** a guided setup wizard,
**so that** I can configure DevFlow correctly for my system.

**Acceptance Criteria**:
- Given I run the installation
- When prompted by the wizard
- Then I'm asked which PHP versions to install
- And I'm asked if I want to install MariaDB
- And defaults are provided for all questions
- And I can skip the wizard and use defaults

---

## 13. Environment Management

### US-032: Create Environment File
**Priority**: Low | **Phase**: 3 | **Points**: 3

**As a** web developer,
**I want** to create .env files from templates,
**so that** I don't have to manually copy and edit them.

**Acceptance Criteria**:
- Given I run `devflow env create myapp.test`
- When the command completes
- Then a .env file is created from .env.example
- And database credentials are pre-filled
- And I'm prompted to edit any remaining values

---

## 14. Node.js Support

### US-033: Install Node.js Version
**Priority**: Low | **Phase**: 3 | **Points**: 5

**As a** full-stack developer,
**I want** to manage Node.js versions like I manage PHP versions,
**so that** I can work on Node.js projects alongside PHP projects.

**Acceptance Criteria**:
- Given I run `devflow node install 20`
- When the installation completes
- Then Node.js 20 is installed via NVM
- And I can use it for my projects
- And I see a confirmation message

### US-034: Create Node.js Site
**Priority**: Low | **Phase**: 3 | **Points**: 5

**As a** full-stack developer,
**I want** to create sites for Node.js applications,
**so that** I can host Express/Next.js apps alongside PHP sites.

**Acceptance Criteria**:
- Given I run `devflow site create api.test node20`
- When the site is created
- Then an Nginx/Apache reverse proxy is configured
- And I can run my Node.js app
- And it's accessible at `http://api.test`

---

## 15. Help and Documentation

### US-035: Contextual Help
**Priority**: High | **Phase**: MVP | **Points**: 3

**As a** user,
**I want** to see help for any command,
**so that** I can learn how to use it without leaving the terminal.

**Acceptance Criteria**:
- Given I run `devflow site create --help`
- When the command runs
- Then I see usage information
- And I see parameter descriptions
- And I see examples
- And I see related commands

### US-036: Error Help
**Priority**: High | **Phase**: MVP | **Points**: 2

**As a** user encountering an error,
**I want** to see suggestions for how to fix it,
**so that** I can resolve the issue quickly.

**Acceptance Criteria**:
- Given an error occurs
- When I see the error message
- Then I see what went wrong
- And I see why it happened
- And I see how to fix it with specific commands

---

## 16. System Health

### US-037: Health Check
**Priority**: Medium | **Phase**: 2 | **Points**: 5

**As a** user,
**I want** to check if my system is configured correctly,
**so that** I can diagnose and fix issues.

**Acceptance Criteria**:
- Given I run `devflow doctor`
- When the command completes
- Then I see a list of checks performed
- And I see which checks passed/failed
- And I see suggestions for fixing failures
- And I see overall system health status

---

## 17. Updates

### US-038: Update DevFlow
**Priority**: Medium | **Phase**: 2 | **Points**: 3

**As a** user,
**I want** to easily update DevFlow to the latest version,
**so that** I can get new features and bug fixes.

**Acceptance Criteria**:
- Given I run `devflow update`
- When the update completes
- Then DevFlow is updated to the latest version
- And I see a changelog of what's new
- And my configuration is preserved

---

## Story Summary

### By Priority
- **Critical**: 6 stories (75 points)
- **High**: 14 stories (50 points)
- **Medium**: 15 stories (51 points)
- **Low**: 3 stories (12 points)

**Total**: 38 user stories, 188 story points

### By Phase
- **MVP (Phase 1)**: 15 stories (58 points)
- **Phase 2**: 20 stories (82 points)
- **Phase 3**: 3 stories (13 points)

---

## Document History

| Version | Date       | Author        | Changes                          |
|---------|------------|---------------|----------------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial user stories document    |

---

**Document Status**: Draft
**Next Review Date**: After SRS/PRD validation
**Approval**: Pending
