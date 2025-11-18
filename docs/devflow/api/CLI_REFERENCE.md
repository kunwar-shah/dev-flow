# CLI Reference
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0  
**Date**: 2025-11-13  
**Status**: Draft

---

## Command Structure

```bash
devflow <command> <subcommand> [options] [arguments]
```

---

## Global Options

| Option | Description |
|--------|-------------|
| `--help`, `-h` | Show help |
| `--version`, `-v` | Show version |
| `--verbose` | Verbose output |
| `--quiet` | Suppress output |

---

## Site Commands

### `devflow site create`
Create a new development site

**Usage**:
```bash
devflow site create <name> <php-version> [docroot]
```

**Arguments**:
- `name` - Site domain (e.g., myapp.test)
- `php-version` - PHP version (e.g., php8.2)
- `docroot` - Document root subdirectory (default: public)

**Example**:
```bash
devflow site create myapp.test php8.2 public
```

### `devflow site list`
List all sites

**Usage**:
```bash
devflow site list [--filter <filter>]
```

### `devflow site delete`
Delete a site

**Usage**:
```bash
devflow site delete <name> [--yes]
```

### `devflow site info`
Show site details

**Usage**:
```bash
devflow site info <name>
```

---

## PHP Commands

### `devflow php install`
Install PHP version

**Usage**:
```bash
devflow php install <version>
```

**Example**:
```bash
devflow php install 8.2
```

### `devflow php list`
List installed PHP versions

**Usage**:
```bash
devflow php list
```

### `devflow php switch`
Switch default CLI PHP version

**Usage**:
```bash
devflow php switch <version>
```

---

## SSL Commands

### `devflow ssl install-ca`
Create root Certificate Authority

**Usage**:
```bash
devflow ssl install-ca
```

### `devflow ssl create`
Enable SSL for site

**Usage**:
```bash
devflow ssl create <sitename>
```

**Example**:
```bash
devflow ssl create myapp.test
```

---

## Database Commands

### `devflow db create`
Create database

**Usage**:
```bash
devflow db create <name>
```

### `devflow db import`
Import SQL dump

**Usage**:
```bash
devflow db import <dbname> <file.sql>
```

### `devflow db export`
Export database

**Usage**:
```bash
devflow db export <dbname> [output.sql]
```

### `devflow db list`
List databases

**Usage**:
```bash
devflow db list
```

---

## Service Commands

### `devflow service status`
Show service status

**Usage**:
```bash
devflow service status [service]
```

### `devflow service restart`
Restart service

**Usage**:
```bash
devflow service restart <service>
```

**Example**:
```bash
devflow service restart apache2
devflow service restart php8.2-fpm
```

---

## Log Commands

### `devflow logs`
View site logs

**Usage**:
```bash
devflow logs <sitename> [--tail] [--error]
```

**Example**:
```bash
devflow logs myapp.test --tail
```

---

## Migration Commands

### `devflow migrate`
Migrate project from Windows

**Usage**:
```bash
devflow migrate <source> <sitename>
```

**Example**:
```bash
devflow migrate /mnt/c/Projects/myapp myapp.test
```

---

## Backup Commands

### `devflow backup create`
Create backup

**Usage**:
```bash
devflow backup create <sitename>
```

### `devflow backup restore`
Restore from backup

**Usage**:
```bash
devflow backup restore <backup-id> <new-sitename>
```

### `devflow backup list`
List backups

**Usage**:
```bash
devflow backup list
```

---

## Utility Commands

### `devflow doctor`
System health check

**Usage**:
```bash
devflow doctor
```

### `devflow update`
Update DevFlow

**Usage**:
```bash
devflow update
```

---

## Document History

| Version | Date       | Author        | Changes           |
|---------|------------|---------------|-------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial CLI ref   |

