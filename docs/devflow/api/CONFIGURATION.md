# Configuration Reference
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0  
**Date**: 2025-11-13  
**Status**: Draft

---

## Configuration Files

### User Configuration
**Location**: `~/.devflow/config.json`

```json
{
  "version": "1.0",
  "settings": {
    "websites_root": "/home/user/websites",
    "default_php": "8.2",
    "default_docroot": "public",
    "auto_ssl": false,
    "auto_hosts": false
  },
  "services": {
    "apache": {
      "enabled": true,
      "port": 80,
      "ssl_port": 443
    },
    "mysql": {
      "enabled": true,
      "port": 3306,
      "host": "127.0.0.1"
    }
  },
  "php": {
    "installed_versions": ["8.2", "8.3"],
    "default_version": "8.2"
  },
  "logging": {
    "level": "INFO",
    "file": "~/.devflow/logs/devflow.log"
  }
}
```

---

## Site Registry
**Location**: `~/.devflow/sites.json`

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
      "database": {
        "name": "myapp_db",
        "user": "myapp_user"
      }
    }
  ]
}
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEVFLOW_DEBUG` | Enable debug mode | 0 |
| `DEVFLOW_CONFIG_DIR` | Config directory | ~/.devflow |
| `DEVFLOW_WEBSITES_ROOT` | Sites directory | ~/websites |

---

## Document History

| Version | Date       | Author        | Changes          |
|---------|------------|---------------|------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial config doc |

