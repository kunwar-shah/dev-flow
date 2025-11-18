#!/usr/bin/env bash

#######################################
# DevFlow Installation Script
# Installs DevFlow and its dependencies on WSL2/Linux
#
# Usage:
#   ./scripts/install.sh [OPTIONS]
#
# Options:
#   --skip-deps     Skip dependency installation
#   --prefix PATH   Install to custom path (default: /opt/devflow)
#   --user          Install to user directory (~/.local/devflow)
#   --help          Show this help message
#
# Requirements:
#   - Ubuntu 22.04+, Debian 11+, or WSL2
#   - Root access (sudo)
#   - Internet connection
#######################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation defaults
INSTALL_PREFIX="${INSTALL_PREFIX:-/opt/devflow}"
SKIP_DEPS=false
USER_INSTALL=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

#######################################
# Print functions
#######################################

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}           ${GREEN}DevFlow Installation Script${NC}                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}     Laragon-style Development Environment for WSL/Linux   ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BLUE}==>${NC} ${1}"
}

#######################################
# Show help
#######################################
show_help() {
    cat << EOF
DevFlow Installation Script

Usage:
  ./scripts/install.sh [OPTIONS]

Options:
  --skip-deps     Skip dependency installation (Apache, PHP, MySQL)
  --prefix PATH   Install to custom path (default: /opt/devflow)
  --user          Install to user directory (~/.local/devflow)
  --help          Show this help message

Examples:
  # Standard installation (requires sudo)
  ./scripts/install.sh

  # User installation (no sudo required)
  ./scripts/install.sh --user

  # Custom location
  ./scripts/install.sh --prefix /usr/local/devflow

  # Skip dependencies (if already installed)
  ./scripts/install.sh --skip-deps

Requirements:
  - Ubuntu 22.04+, Debian 11+, or WSL2 (Ubuntu 24.04 recommended)
  - Root access for system installation
  - Internet connection for downloading packages

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            --user)
                USER_INSTALL=true
                INSTALL_PREFIX="$HOME/.local/devflow"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run './scripts/install.sh --help' for usage"
                exit 1
                ;;
        esac
    done
}

#######################################
# Check system requirements
#######################################
check_requirements() {
    print_step "Checking system requirements"

    local errors=0

    # Check OS
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        print_info "OS: $NAME $VERSION"

        # Check for Ubuntu 22.04+ or Debian 11+
        local supported=0
        if [ "$ID" = "ubuntu" ]; then
            local version_num="${VERSION_ID%.*}"
            if [ "$version_num" -ge 22 ]; then
                supported=1
            fi
        elif [ "$ID" = "debian" ]; then
            local version_num="${VERSION_ID%.*}"
            if [ "$version_num" -ge 11 ]; then
                supported=1
            fi
        fi

        if [ $supported -eq 0 ]; then
            print_warning "OS may not be fully supported (Ubuntu 22.04+ or Debian 11+ recommended)"
        else
            print_success "OS is supported"
        fi
    else
        print_warning "Could not detect OS version"
    fi

    # Check systemd
    if pidof systemd >/dev/null 2>&1; then
        print_success "systemd is running"
    else
        print_error "systemd is not running (required for service management)"
        echo "  For WSL2, enable systemd in /etc/wsl.conf:"
        echo "  [boot]"
        echo "  systemd=true"
        ((errors++))
    fi

    # Check for sudo access (if not user install)
    if [ "$USER_INSTALL" = false ]; then
        if sudo -n true 2>/dev/null; then
            print_success "Sudo access available"
        else
            print_error "Sudo access required for system installation"
            echo "  Run with --user flag for user-level installation"
            ((errors++))
        fi
    fi

    # Check disk space (minimum 10GB)
    local available
    available=$(df "$HOME" | awk 'NR==2 {print $4}')
    local available_gb=$((available / 1024 / 1024))

    if [ "$available_gb" -ge 10 ]; then
        print_success "Sufficient disk space ($available_gb GB available)"
    else
        print_warning "Low disk space ($available_gb GB available, 10+ GB recommended)"
    fi

    if [ $errors -gt 0 ]; then
        print_error "$errors requirement(s) not met"
        return 1
    fi

    print_success "All system requirements met"
    return 0
}

#######################################
# Install dependencies
#######################################
install_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        print_step "Skipping dependency installation (--skip-deps)"
        return 0
    fi

    print_step "Installing dependencies"

    # Update package list
    print_info "Updating package lists..."
    sudo apt-get update -qq

    # Install basic dependencies
    print_info "Installing basic tools (jq, curl, git)..."
    sudo apt-get install -y -qq jq curl git software-properties-common

    print_success "Basic dependencies installed"

    # Ask user what to install
    echo ""
    print_info "DevFlow requires Apache, PHP, and MySQL/MariaDB"
    echo "  Do you want to install these now? (recommended for first-time setup)"
    echo ""
    echo "  Options:"
    echo "  1) Install all (Apache + PHP 8.2 + MariaDB)"
    echo "  2) Install Apache only"
    echo "  3) Install PHP 8.2 only"
    echo "  4) Install MariaDB only"
    echo "  5) Skip (I'll install them manually later)"
    echo ""
    read -rp "  Choose [1-5]: " choice

    case "$choice" in
        1)
            install_apache
            install_php "8.2"
            install_mysql
            ;;
        2)
            install_apache
            ;;
        3)
            install_php "8.2"
            ;;
        4)
            install_mysql
            ;;
        5)
            print_info "Skipping service installation"
            ;;
        *)
            print_warning "Invalid choice, skipping service installation"
            ;;
    esac

    return 0
}

#######################################
# Install Apache
#######################################
install_apache() {
    print_info "Installing Apache..."
    sudo apt-get install -y -qq apache2

    # Enable required modules
    sudo a2enmod rewrite proxy_fcgi setenvif ssl headers

    print_success "Apache installed"
}

#######################################
# Install PHP
#######################################
install_php() {
    local version="$1"
    print_info "Installing PHP $version..."

    # Add Ondřej Surý's PPA for multiple PHP versions
    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        print_info "Adding PHP repository..."
        sudo add-apt-repository -y ppa:ondrej/php
        sudo apt-get update -qq
    fi

    # Install PHP-FPM and common extensions
    sudo apt-get install -y -qq \
        "php${version}-fpm" \
        "php${version}-cli" \
        "php${version}-common" \
        "php${version}-mysql" \
        "php${version}-curl" \
        "php${version}-gd" \
        "php${version}-mbstring" \
        "php${version}-xml" \
        "php${version}-zip" \
        "php${version}-bcmath" \
        "php${version}-intl"

    print_success "PHP $version installed"
}

#######################################
# Install MySQL/MariaDB
#######################################
install_mysql() {
    print_info "Installing MariaDB..."
    sudo apt-get install -y -qq mariadb-server mariadb-client

    # Start MariaDB
    sudo systemctl start mariadb
    sudo systemctl enable mariadb

    print_success "MariaDB installed"
    print_warning "Remember to run 'sudo mysql_secure_installation' to secure your database"
}

#######################################
# Install DevFlow files
#######################################
install_devflow() {
    print_step "Installing DevFlow to $INSTALL_PREFIX"

    # Create installation directory
    if [ "$USER_INSTALL" = true ]; then
        mkdir -p "$INSTALL_PREFIX"
    else
        sudo mkdir -p "$INSTALL_PREFIX"
    fi

    # Copy files
    print_info "Copying files..."

    if [ "$USER_INSTALL" = true ]; then
        cp -r "$PROJECT_ROOT"/{bin,lib,config,share} "$INSTALL_PREFIX/"
        chmod +x "$INSTALL_PREFIX/bin/devflow"
    else
        sudo cp -r "$PROJECT_ROOT"/{bin,lib,config,share} "$INSTALL_PREFIX/"
        sudo chmod +x "$INSTALL_PREFIX/bin/devflow"
    fi

    print_success "Files copied to $INSTALL_PREFIX"

    # Create symlink
    local bin_link="/usr/local/bin/devflow"
    if [ "$USER_INSTALL" = true ]; then
        bin_link="$HOME/.local/bin/devflow"
        mkdir -p "$HOME/.local/bin"
    fi

    print_info "Creating symlink: $bin_link"

    if [ "$USER_INSTALL" = true ]; then
        ln -sf "$INSTALL_PREFIX/bin/devflow" "$bin_link"
    else
        sudo ln -sf "$INSTALL_PREFIX/bin/devflow" "$bin_link"
    fi

    print_success "Symlink created"

    # Add to PATH if user install
    if [ "$USER_INSTALL" = true ]; then
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            print_info "Adding ~/.local/bin to PATH"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            print_warning "Please run: source ~/.bashrc"
        fi
    fi
}

#######################################
# Initialize user configuration
#######################################
init_config() {
    print_step "Initializing configuration"

    export DEVFLOW_LIB_DIR="$INSTALL_PREFIX/lib"

    # Source config library
    # shellcheck source=../lib/core/config.sh
    source "$INSTALL_PREFIX/lib/core/config.sh"

    # Initialize config
    if config_init; then
        print_success "Configuration initialized at ~/.devflow"
    else
        print_error "Failed to initialize configuration"
        return 1
    fi

    # Create websites directory
    local websites_root="$HOME/websites"
    if [ ! -d "$websites_root" ]; then
        mkdir -p "$websites_root"
        print_success "Created websites directory: $websites_root"
    else
        print_info "Websites directory already exists: $websites_root"
    fi

    return 0
}

#######################################
# Show completion message
#######################################
show_completion() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}               ${GREEN}Installation Complete!${NC}                       ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_success "DevFlow has been installed to: $INSTALL_PREFIX"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Verify installation:"
    echo "     $ devflow --version"
    echo ""
    echo "  2. Check system health:"
    echo "     $ devflow doctor"
    echo ""
    echo "  3. View available commands:"
    echo "     $ devflow --help"
    echo ""
    print_warning "IMPORTANT: DevFlow is experimental software (Pre-Alpha)"
    print_warning "Not all features are implemented yet"
    echo ""
    echo "Configuration:"
    echo "  - Install location: $INSTALL_PREFIX"
    echo "  - Config directory: ~/.devflow"
    echo "  - Websites directory: ~/websites"
    echo ""
    echo "Report issues: https://github.com/kunwar-shah/dev-flow/issues"
    echo ""
}

#######################################
# Main installation flow
#######################################
main() {
    # Parse arguments
    parse_args "$@"

    # Show header
    print_header

    # Warning
    print_warning "This is experimental software - use at your own risk!"
    echo ""
    read -rp "Do you want to continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    # Check requirements
    if ! check_requirements; then
        print_error "System requirements not met"
        exit 1
    fi

    # Install dependencies
    if ! install_dependencies; then
        print_error "Failed to install dependencies"
        exit 1
    fi

    # Install DevFlow
    if ! install_devflow; then
        print_error "Failed to install DevFlow"
        exit 1
    fi

    # Initialize configuration
    if ! init_config; then
        print_error "Failed to initialize configuration"
        exit 1
    fi

    # Show completion
    show_completion

    exit 0
}

# Run main
main "$@"
