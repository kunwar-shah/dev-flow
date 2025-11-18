# DevFlow

> Laragon-style Development Environment for WSL2 and Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.0--dev-blue.svg)](https://github.com/kunwar-shah/dev-flow)
[![Status](https://img.shields.io/badge/status-experimental-orange.svg)](https://github.com/kunwar-shah/dev-flow)

## ⚠️ EXPERIMENTAL - USE AT YOUR OWN RISK

**This project is in early experimental development phase (Pre-Alpha).**

- 🚧 **NOT production-ready** - Core features are still being implemented
- ⚠️ **Breaking changes expected** - APIs and commands may change without notice
- 🧪 **Testing in progress** - Limited test coverage, bugs are expected
- 💥 **Use at your own risk** - May modify system configurations (Apache, PHP, MySQL)
- 🔍 **Review code before running** - Understand what it does to your system

**If you want to try DevFlow:**
- Use it in a **disposable VM or test environment** first
- **Backup your system** before installation
- **Understand bash scripts** and review the code
- Report issues on [GitHub Issues](https://github.com/kunwar-shah/dev-flow/issues)

---

## What is DevFlow?

DevFlow is an open-source command-line tool designed to bring **Laragon-style simplicity** to WSL2 and Linux systems. It provides fast, native LAMP stack management without Docker overhead, optimized for developers who need:

- **High I/O performance** for AI coding tools (Claude Code, GitHub Copilot)
- **Multiple PHP versions** running simultaneously (7.4, 8.0, 8.1, 8.2, 8.3)
- **Quick site creation** (< 30 seconds per site)
- **SSL certificates** (self-signed with Root CA)
- **Database management** (MySQL/MariaDB)
- **Native WSL filesystem** performance (avoiding `/mnt/c` slowness)

### Why DevFlow?

Working with web projects on WSL through `/mnt/c` mount points causes **severe I/O performance issues** (10-100x slower due to 9P protocol overhead). DevFlow solves this by:

1. **Native WSL filesystem** - All development happens in `~/websites` for maximum speed
2. **No Docker overhead** - Native Apache, PHP-FPM, MySQL services
3. **Multiple PHP versions** - Different projects can use different PHP versions
4. **Instant site setup** - Automated vhost configuration, SSL, and service management

**Perfect for:**
- Web developers migrating from Laragon (Windows) to WSL
- Teams needing consistent local development environments
- Developers running AI coding tools that require fast I/O
- Anyone managing multiple LAMP sites on Linux/WSL

---

## 🚀 Current Status

**Phase**: Phase 1, Week 1 - Core Infrastructure
**Version**: 0.1.0-dev (Pre-Alpha)
**Status**: 🏗️ Active Development

### What's Implemented

✅ **Core Infrastructure**
- Project structure and modular architecture
- Configuration management system (JSON-based with jq)
- Logging system (dual output: console + file)
- Input validation and security checks
- Utility functions library

### What's NOT Implemented Yet

❌ Site management commands (create, delete, list)
❌ PHP version installation and switching
❌ SSL certificate generation
❌ Database operations
❌ Apache/MySQL service management
❌ Installation script
❌ Testing framework
❌ Documentation for end users

**TL;DR:** The project has core libraries but NO working features yet. It cannot create sites or manage services.

---

## 📋 Planned Features (When Stable)

- ⚡ **Fast Site Creation** - Create LAMP sites in < 30 seconds
- 🐘 **Multi-PHP Support** - PHP 7.4, 8.0, 8.1, 8.2, 8.3 simultaneously
- 🔒 **SSL Certificates** - Self-signed HTTPS with trusted Root CA
- 💾 **Database Management** - Create, import, export MySQL/MariaDB databases
- 📦 **Project Migration** - Move projects from Windows to WSL seamlessly
- 🔧 **Service Control** - Manage Apache, PHP-FPM, MySQL services
- 📊 **Log Viewing** - Unified log management and real-time tailing
- 💿 **Backup & Restore** - Full site and database backups
- 🌐 **Windows Hosts Integration** - Automatic hosts file management

---

## 🎯 Quick Preview (When Ready)

This is what DevFlow will look like when complete:

```bash
# Install DevFlow
git clone https://github.com/kunwar-shah/dev-flow.git
cd dev-flow
./scripts/install.sh

# Create a new site with PHP 8.2
devflow site create myapp.test php8.2

# List all sites
devflow site list

# Install different PHP version
devflow php install 8.3

# Create SSL certificate
devflow ssl create myapp.test

# Open site in browser
devflow site open myapp.test
```

**⚠️ These commands DON'T WORK YET - Coming soon!**

---

## 📖 Documentation

Since this is experimental, documentation is minimal:

- **[config/](config/)** - Default configuration templates
- **[lib/core/](lib/core/)** - Core library source code

Full user documentation will be created when the project reaches Alpha stage.

---

## 🛠️ Development Roadmap

### Phase 1: MVP (Weeks 1-4) - Core Functionality
- [x] Week 1: Core infrastructure and libraries
- [ ] Week 1: Installation script and testing setup
- [ ] Week 2: Site management commands
- [ ] Week 3: PHP version management
- [ ] Week 4: Service management and migration tools

### Phase 2: Developer Experience (Weeks 5-8)
- [ ] SSL certificate management
- [ ] Database operations
- [ ] Log management
- [ ] Windows hosts integration

### Phase 3: Advanced Features (Weeks 9-12)
- [ ] Backup and restore
- [ ] Node.js support
- [ ] Site templates (Laravel, WordPress)
- [ ] Monitoring and error tracking

---

## 💻 System Requirements

- **OS**: Ubuntu 22.04+, Debian 11+, or WSL2 (Ubuntu 24.04 recommended)
- **Memory**: 2GB minimum, 4GB recommended
- **Disk**: 10GB free space
- **systemd**: Required for service management
- **Root access**: Required for Apache, PHP, MySQL installation

---

## 🤝 Contributing

**Contributions are welcome!** Since this is early development:

1. **Check existing issues** before starting work
2. **Discuss major changes** in issues first
3. **Follow coding standards** in [.claude.md](.claude.md)
4. **Write tests** for new features (when test framework is ready)
5. **Update documentation** for any changes

### Development Setup

```bash
# Clone repository
git clone https://github.com/kunwar-shah/dev-flow.git
cd dev-flow

# Review code structure
ls -la lib/core/

# Install shellcheck for linting
sudo apt install shellcheck

# Run linter
shellcheck bin/devflow lib/core/*.sh
```

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Inspired by [Laragon](https://laragon.org/) for Windows
- Built for the WSL and Linux development community
- Powered by open-source tools: Apache, PHP-FPM, MySQL, jq

---

## 📞 Support & Issues

- **Issues**: [GitHub Issues](https://github.com/kunwar-shah/dev-flow/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kunwar-shah/dev-flow/discussions)

**Remember:** This is experimental software. Use at your own risk!

---

## ⚡ Quick Status Check

```bash
# Current repository status
git clone https://github.com/kunwar-shah/dev-flow.git
cd dev-flow
ls -la bin/ lib/core/

# You'll see:
# - bin/devflow          (main CLI - not functional yet)
# - lib/core/config.sh   (configuration management)
# - lib/core/logger.sh   (logging system)
# - lib/core/utils.sh    (utility functions)
# - lib/core/validator.sh (input validation)
```

**Coming soon:** Installation script, site commands, PHP management

---

**Made with ❤️ for developers who want Laragon simplicity on Linux/WSL**
