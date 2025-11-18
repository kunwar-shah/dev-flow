# Deployment Guide
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0  
**Date**: 2025-11-13  
**Status**: Draft

---

## 1. Installation

### One-Command Install
```bash
curl -fsSL https://get.devflow.sh | bash
```

### Manual Install
```bash
git clone https://github.com/devflow/devflow.git
cd devflow
./scripts/install.sh
```

---

## 2. System Requirements

- **OS**: Ubuntu 22.04+, Debian 11+, WSL2
- **Memory**: 2GB minimum, 4GB recommended
- **Disk**: 10GB free space
- **systemd**: Required

---

## 3. Prerequisites

```bash
# WSL: Enable systemd
echo "[boot]" | sudo tee -a /etc/wsl.conf
echo "systemd=true" | sudo tee -a /etc/wsl.conf

# Restart WSL
wsl --shutdown
```

---

## 4. Installation Steps

The install script performs:
1. Check system requirements
2. Install dependencies (jq, curl, etc.)
3. Install Apache, PHP, MySQL
4. Create configuration files
5. Set up site directory
6. Configure PATH

---

## 5. Post-Installation

```bash
# Verify installation
devflow --version

# Create first site
devflow site create myapp.test php8.2

# Add to Windows hosts
echo "127.0.0.1 myapp.test" | clip
# Paste into C:\Windows\System32\drivers\etc\hosts
```

---

## 6. Uninstallation

```bash
devflow uninstall
```

Removes:
- DevFlow CLI
- Configuration files
- Site registry
- Does NOT remove Apache/PHP/MySQL

---

## Document History

| Version | Date       | Author        | Changes              |
|---------|------------|---------------|----------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial deployment doc |

