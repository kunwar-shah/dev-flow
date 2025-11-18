#!/usr/bin/env bash

#######################################
# PHP Version Management Commands
# Handles installation and management of multiple PHP versions
#
# Commands:
#   php install   - Install a PHP version
#   php list      - List all PHP versions
#   php uninstall - Remove a PHP version
#   php switch    - Switch default PHP version
#   php info      - Show PHP information
#######################################

# Supported PHP versions
SUPPORTED_PHP_VERSIONS=("7.4" "8.0" "8.1" "8.2" "8.3")

#######################################
# Show PHP command help
#######################################
php_show_help() {
    cat << 'EOF'
PHP Version Management Commands

Usage:
  devflow php <command> [options] [arguments]

Commands:
  install <version>     Install a PHP version (7.4, 8.0, 8.1, 8.2, 8.3)
  list                  List all PHP versions (installed and available)
  uninstall <version>   Remove a PHP version
  switch <version>      Switch default PHP version
  info <version>        Show PHP version information

Examples:
  # Install PHP 8.3
  devflow php install 8.3

  # List all PHP versions
  devflow php list

  # Switch default to PHP 8.2
  devflow php switch 8.2

  # Uninstall PHP 7.4
  devflow php uninstall 7.4

  # Show PHP info
  devflow php info 8.2

Notes:
  - PHP versions are installed via Ondřej Surý's PPA
  - Each version runs its own PHP-FPM service
  - Sites can use different PHP versions simultaneously

See also:
  devflow site create     Create site with specific PHP version
  devflow service status  Check PHP-FPM service status

EOF
}

#######################################
# Install PHP version
# Arguments:
#   $1 - PHP version (e.g., 8.2 or php8.2)
# Returns:
#   0 on success, 1 on error
#######################################
php_install() {
    local version="$1"

    if [ -z "$version" ]; then
        log_error "PHP version is required"
        echo "Usage: devflow php install <version>"
        echo "Available: ${SUPPORTED_PHP_VERSIONS[*]}"
        return 1
    fi

    # Normalize and validate version
    version=$(normalize_php_version "$version")
    if ! validate_php_version "$version"; then
        return 1
    fi

    # Check if already installed
    if php_is_installed "$version"; then
        print_warning "PHP $version is already installed"
        return 0
    fi

    print_info "Installing PHP $version..."
    echo ""

    # Add Ondřej Surý's PPA
    print_step "Adding PHP repository"
    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        if ! sudo add-apt-repository -y ppa:ondrej/php; then
            log_error "Failed to add PHP repository"
            return 1
        fi
        print_success "Repository added"

        print_info "Updating package lists..."
        if ! sudo apt-get update -qq; then
            log_error "Failed to update package lists"
            return 1
        fi
        print_success "Package lists updated"
    else
        print_success "Repository already added"
    fi

    # Install PHP-FPM and common extensions
    print_step "Installing PHP $version packages"
    local packages=(
        "php${version}-fpm"
        "php${version}-cli"
        "php${version}-common"
        "php${version}-mysql"
        "php${version}-curl"
        "php${version}-gd"
        "php${version}-mbstring"
        "php${version}-xml"
        "php${version}-zip"
        "php${version}-bcmath"
        "php${version}-intl"
        "php${version}-soap"
        "php${version}-imagick"
        "php${version}-opcache"
    )

    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"; then
        log_error "Failed to install PHP $version"
        return 1
    fi
    print_success "PHP $version installed"

    # Start and enable PHP-FPM service
    print_step "Starting PHP-FPM service"
    if ! sudo systemctl start "php${version}-fpm"; then
        log_error "Failed to start PHP-FPM service"
        return 1
    fi

    if ! sudo systemctl enable "php${version}-fpm" >/dev/null 2>&1; then
        print_warning "Failed to enable PHP-FPM auto-start"
    fi
    print_success "PHP-FPM service started"

    # Update config
    print_step "Updating configuration"
    update_php_config "$version"
    print_success "Configuration updated"

    echo ""
    print_success "PHP $version installed successfully!"
    echo ""
    echo "PHP-FPM service: php${version}-fpm"
    echo "Socket: /run/php/php${version}-fpm.sock"
    echo "Config: /etc/php/${version}/fpm/php.ini"
    echo ""
    echo "Create a site with this PHP version:"
    echo "  devflow site create myapp.test php${version}"
    echo ""

    return 0
}

#######################################
# List PHP versions
# Returns:
#   0 on success
#######################################
php_list() {
    echo ""
    echo "PHP Versions:"
    echo ""
    printf "%-10s %-15s %-15s %-20s\n" "VERSION" "STATUS" "SERVICE" "SOCKET"
    printf "%-10s %-15s %-15s %-20s\n" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..20})"

    for version in "${SUPPORTED_PHP_VERSIONS[@]}"; do
        local status="Not Installed"
        local service_status="-"
        local socket_status="-"

        if php_is_installed "$version"; then
            status="Installed"

            # Check service
            if systemctl is-active --quiet "php${version}-fpm"; then
                service_status="Running"
            else
                service_status="Stopped"
            fi

            # Check socket
            if [ -S "/run/php/php${version}-fpm.sock" ]; then
                socket_status="Available"
            else
                socket_status="Not Found"
            fi
        fi

        printf "%-10s %-15s %-15s %-20s\n" "$version" "$status" "$service_status" "$socket_status"
    done

    echo ""

    # Show default
    local default_php
    default_php=$(config_get_default_php)
    echo "Default PHP: $default_php"
    echo ""

    # Show installation command
    echo "Install a version:"
    echo "  devflow php install <version>"
    echo ""

    return 0
}

#######################################
# Uninstall PHP version
# Arguments:
#   $1 - PHP version
# Returns:
#   0 on success, 1 on error
#######################################
php_uninstall() {
    local version="$1"

    if [ -z "$version" ]; then
        log_error "PHP version is required"
        echo "Usage: devflow php uninstall <version>"
        return 1
    fi

    # Normalize and validate version
    version=$(normalize_php_version "$version")
    if ! validate_php_version "$version"; then
        return 1
    fi

    # Check if installed
    if ! php_is_installed "$version"; then
        log_error "PHP $version is not installed"
        return 1
    fi

    # Check if any sites are using this version
    local sites_using
    sites_using=$(site_list .sites[] | jq -r "select(.php_version == \"$version\") | .name" 2>/dev/null)

    if [ -n "$sites_using" ]; then
        print_warning "The following sites are using PHP $version:"
        echo "$sites_using"
        echo ""
        read -rp "Do you want to continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Uninstall cancelled"
            return 0
        fi
    fi

    print_info "Uninstalling PHP $version..."
    echo ""

    # Stop PHP-FPM service
    print_step "Stopping PHP-FPM service"
    sudo systemctl stop "php${version}-fpm" 2>/dev/null || true
    sudo systemctl disable "php${version}-fpm" 2>/dev/null || true
    print_success "Service stopped"

    # Remove packages
    print_step "Removing PHP $version packages"
    if ! sudo apt-get remove -y -qq "php${version}*"; then
        print_warning "Failed to remove some packages"
    fi
    print_success "Packages removed"

    # Autoremove
    print_info "Cleaning up..."
    sudo apt-get autoremove -y -qq 2>/dev/null || true

    echo ""
    print_success "PHP $version uninstalled successfully!"
    echo ""

    return 0
}

#######################################
# Switch default PHP version
# Arguments:
#   $1 - PHP version
# Returns:
#   0 on success, 1 on error
#######################################
php_switch() {
    local version="$1"

    if [ -z "$version" ]; then
        log_error "PHP version is required"
        echo "Usage: devflow php switch <version>"
        return 1
    fi

    # Normalize and validate version
    version=$(normalize_php_version "$version")
    if ! validate_php_version "$version"; then
        return 1
    fi

    # Check if installed
    if ! php_is_installed "$version"; then
        log_error "PHP $version is not installed"
        echo "Install it with: devflow php install $version"
        return 1
    fi

    print_info "Switching default PHP to $version..."

    # Update config
    if ! config_set "settings.default_php" "$version"; then
        log_error "Failed to update configuration"
        return 1
    fi

    print_success "Default PHP version set to $version"
    echo ""
    echo "New sites will use PHP $version by default"
    echo "Existing sites keep their configured PHP version"
    echo ""

    return 0
}

#######################################
# Show PHP information
# Arguments:
#   $1 - PHP version
# Returns:
#   0 on success, 1 on error
#######################################
php_info() {
    local version="$1"

    if [ -z "$version" ]; then
        log_error "PHP version is required"
        echo "Usage: devflow php info <version>"
        return 1
    fi

    # Normalize and validate version
    version=$(normalize_php_version "$version")
    if ! validate_php_version "$version"; then
        return 1
    fi

    # Check if installed
    if ! php_is_installed "$version"; then
        log_error "PHP $version is not installed"
        return 1
    fi

    echo ""
    echo "PHP $version Information"
    echo "$(printf '%.0s=' {1..60})"
    echo ""

    # PHP version
    local php_version_full
    php_version_full=$("php${version}" -v 2>/dev/null | head -n 1 || echo "Unknown")
    echo "Version: $php_version_full"
    echo ""

    # Service status
    echo "Service:"
    echo "  Name:              php${version}-fpm"
    if systemctl is-active --quiet "php${version}-fpm"; then
        echo "  Status:            Running"
    else
        echo "  Status:            Stopped"
    fi
    echo ""

    # Paths
    echo "Paths:"
    echo "  Binary:            /usr/bin/php${version}"
    echo "  FPM Socket:        /run/php/php${version}-fpm.sock"
    echo "  Config (CLI):      /etc/php/${version}/cli/php.ini"
    echo "  Config (FPM):      /etc/php/${version}/fpm/php.ini"
    echo "  FPM Pool:          /etc/php/${version}/fpm/pool.d/www.conf"
    echo ""

    # Extensions
    echo "Loaded Extensions:"
    "php${version}" -m | sed 's/^/  /'
    echo ""

    # Sites using this version
    local sites_count
    sites_count=$(site_list .sites[] | jq -r "select(.php_version == \"$version\") | .name" 2>/dev/null | wc -l)
    echo "Sites using PHP $version: $sites_count"
    echo ""

    return 0
}

#######################################
# Check if PHP version is installed
# Arguments:
#   $1 - PHP version
# Returns:
#   0 if installed, 1 if not
#######################################
php_is_installed() {
    local version="$1"

    # Check if PHP binary exists
    if [ -f "/usr/bin/php${version}" ]; then
        return 0
    fi

    # Check if package is installed
    if dpkg -l "php${version}-fpm" 2>/dev/null | grep -q "^ii"; then
        return 0
    fi

    return 1
}

#######################################
# Update PHP configuration in DevFlow config
# Arguments:
#   $1 - PHP version
# Returns:
#   0 on success
#######################################
update_php_config() {
    local version="$1"

    # Get current installed versions from config
    local installed
    installed=$(config_get "php.installed_versions" "[]")

    # Add version if not already in list
    if ! echo "$installed" | jq -e ". | contains([\"$version\"])" >/dev/null 2>&1; then
        installed=$(echo "$installed" | jq ". + [\"$version\"] | sort")
        config_set "php.installed_versions" "$installed"
    fi

    return 0
}

#######################################
# Route PHP subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
php_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        php_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        install|add)
            php_install "$@"
            ;;
        list|ls)
            php_list "$@"
            ;;
        uninstall|remove|rm)
            php_uninstall "$@"
            ;;
        switch|use)
            php_switch "$@"
            ;;
        info|show)
            php_info "$@"
            ;;
        help|--help|-h)
            php_show_help
            return 0
            ;;
        *)
            log_error "Unknown PHP command: $subcommand"
            echo ""
            echo "Run 'devflow php --help' for available commands."
            return 1
            ;;
    esac
}
