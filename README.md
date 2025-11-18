# DevFlow

> Laragon-style Development Environment for WSL/Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.0--dev-blue.svg)](https://github.com/devflow/devflow)

**DevFlow** is an open-source command-line tool that provides a Laragon-style development environment optimized for WSL2 and Linux systems. Manage unlimited LAMP stack sites with different PHP versions, SSL certificates, and databases—all through simple CLI commands.

## 🚀 Features

- **⚡ Fast Site Creation** - Create new LAMP sites in < 30 seconds
- **🐘 Multi-PHP Support** - Run PHP 7.4, 8.0, 8.1, 8.2, 8.3 simultaneously
- **🔒 SSL Certificates** - Self-signed HTTPS for all sites
- **💾 Database Management** - Create, import, export MySQL/MariaDB databases
- **📦 Project Migration** - Move projects from Windows to WSL seamlessly
- **🔧 Service Control** - Manage Apache, PHP-FPM, MySQL with ease
- **📊 Log Viewing** - Unified log management and real-time tailing
- **💿 Backup & Restore** - Full site and database backups
- **🌐 Windows Integration** - Automatic hosts file management

## 📋 Requirements

- **OS**: Ubuntu 22.04+, Debian 11+, or WSL2 (Ubuntu 24.04 recommended)
- **Memory**: 2GB minimum, 4GB recommended
- **Disk**: 10GB free space
- **systemd**: Required for service management

## 🎯 Quick Start

### Installation

```bash
# Clone repository
git clone https://github.com/devflow/devflow.git
cd devflow

# Run installation script
./scripts/install.sh
```

### Create Your First Site

```bash
# Create a new Laravel site with PHP 8.2
devflow site create myapp.test php8.2

# Add to Windows hosts file (WSL users)
echo "127.0.0.1 myapp.test" >> /mnt/c/Windows/System32/drivers/etc/hosts

# Open in browser
devflow site open myapp.test
```

## 📖 Documentation

- [Installation Guide](docs/devflow/technical/DEPLOYMENT.md)
- [CLI Reference](docs/devflow/api/CLI_REFERENCE.md)
- [User Guide](docs/devflow/requirements/PRD.md)
- [Architecture](docs/devflow/architecture/SYSTEM_DESIGN.md)

## 🛠️ Development Status

**Current Phase**: Phase 1 - Core Infrastructure (Week 1)
**Version**: 0.1.0-dev (Pre-alpha)

### Completed
- ✅ Project structure and documentation
- ✅ Core libraries (config, logger, utils, validator)
- ✅ Main CLI entry point

### In Progress
- 🔄 Site management commands
- 🔄 PHP version management
- 🔄 Installation script

### Planned
- ⏳ SSL certificate management
- ⏳ Database operations
- ⏳ Backup & restore
- ⏳ Node.js support

## 💻 Usage Examples

```bash
# Site Management
devflow site create myapp.test php8.2 public
devflow site list
devflow site delete oldsite.test

# PHP Management
devflow php install 8.3
devflow php list
devflow php switch 8.2

# SSL Certificates
devflow ssl install-ca
devflow ssl create myapp.test

# Database Operations
devflow db create myapp_db
devflow db import myapp_db backup.sql
devflow db export myapp_db

# Project Migration
devflow migrate /mnt/c/Projects/myapp myapp.test

# Service Management
devflow service status
devflow service restart apache2

# Logs
devflow logs myapp.test --tail
```

## 🏗️ Architecture

DevFlow follows a modular architecture:

```
devflow/
├── bin/devflow              # Main CLI entry point
├── lib/
│   ├── core/               # Core libraries
│   ├── commands/           # Command modules
│   ├── templates/          # Configuration templates
│   └── installers/         # Installation scripts
├── share/                   # Templates & resources
├── scripts/                 # Installation scripts
└── tests/                   # Test suites
```

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone repository
git clone https://github.com/devflow/devflow.git
cd devflow

# Install dependencies
sudo apt install -y jq shellcheck bats

# Run tests
bats tests/

# Run linter
shellcheck lib/**/*.sh
```

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by [Laragon](https://laragon.org/) for Windows
- Built for the WSL and Linux development community
- Powered by open-source tools: Apache, PHP-FPM, jq, BATS

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/devflow/devflow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/devflow/devflow/discussions)
- **Documentation**: [docs/](docs/)

---

**Made with ❤️ for developers who want Laragon simplicity on Linux/WSL**
