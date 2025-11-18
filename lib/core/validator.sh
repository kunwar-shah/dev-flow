#!/usr/bin/env bash

#######################################
# Input Validation
# Validates user input and system requirements
#
# Functions:
# - Site name validation
# - PHP version validation
# - Path validation
# - Database name validation
# - System requirements checking
#######################################

###############################################################################
# SITE VALIDATION
###############################################################################

#######################################
# Validate site name
# Site names must be:
# - Lowercase only
# - Alphanumeric, hyphen, dot allowed
# - Must contain at least one dot (TLD)
# - Length: 4-253 characters
# - DNS-safe format
#
# Arguments:
#   $1 - Site name to validate
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_site_name() {
    local name="$1"

    # Check if empty
    if [ -z "$name" ]; then
        log_error "Site name cannot be empty"
        return 1
    fi

    # Check length
    local len=${#name}
    if [ "$len" -lt 4 ] || [ "$len" -gt 253 ]; then
        log_error "Site name must be 4-253 characters long"
        return 1
    fi

    # Check if contains at least one dot (TLD)
    if [[ ! "$name" =~ \. ]]; then
        log_error "Site name must contain a TLD (e.g., .test, .local)"
        return 1
    fi

    # Check format: lowercase, alphanumeric, hyphen, dot only
    if [[ ! "$name" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]; then
        log_error "Invalid site name format"
        echo "  Site name must:"
        echo "  - Be lowercase"
        echo "  - Contain only letters, numbers, hyphens, and dots"
        echo "  - Not start or end with a hyphen"
        echo "  - Have a valid TLD (e.g., .test, .local)"
        echo ""
        echo "  Examples:"
        echo "  ✓ myapp.test"
        echo "  ✓ my-app.local"
        echo "  ✓ app123.dev"
        echo "  ✗ MyApp.test (uppercase)"
        echo "  ✗ -myapp.test (starts with hyphen)"
        echo "  ✗ myapp (no TLD)"
        return 1
    fi

    return 0
}

###############################################################################
# PHP VERSION VALIDATION
###############################################################################

#######################################
# Validate PHP version
# Valid versions: 7.4, 8.0, 8.1, 8.2, 8.3
#
# Arguments:
#   $1 - PHP version (e.g., "8.2" or "php8.2")
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_php_version() {
    local version="$1"

    # Remove "php" prefix if present
    version="${version#php}"

    # List of valid versions
    local valid_versions=("7.4" "8.0" "8.1" "8.2" "8.3")

    # Check if version is in valid list
    if array_contains "$version" "${valid_versions[@]}"; then
        return 0
    fi

    log_error "Invalid PHP version: $version"
    echo "  Valid versions: ${valid_versions[*]}"
    return 1
}

#######################################
# Normalize PHP version
# Converts "8.2" or "php8.2" to "8.2"
#
# Arguments:
#   $1 - PHP version
# Outputs:
#   Normalized version
# Returns:
#   0 on success
#######################################
normalize_php_version() {
    local version="$1"
    # Remove "php" prefix if present
    echo "${version#php}"
}

###############################################################################
# PATH VALIDATION
###############################################################################

#######################################
# Validate path is safe
# Checks for:
# - Path traversal attempts (..)
# - Null bytes
# - Invalid characters
#
# Arguments:
#   $1 - Path to validate
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_path() {
    local path="$1"

    # Check for empty path
    if [ -z "$path" ]; then
        log_error "Path cannot be empty"
        return 1
    fi

    # Check for path traversal (..)
    if [[ "$path" == *".."* ]]; then
        log_error "Path contains '..' (path traversal)"
        return 1
    fi

    # Check for null bytes
    if [[ "$path" == *$'\0'* ]]; then
        log_error "Path contains null bytes"
        return 1
    fi

    return 0
}

#######################################
# Validate absolute path
# Arguments:
#   $1 - Path to validate
# Returns:
#   0 if valid absolute path, 1 if not
#######################################
validate_absolute_path() {
    local path="$1"

    # Must start with /
    if [[ ! "$path" =~ ^/ ]]; then
        log_error "Path must be absolute (start with /)"
        return 1
    fi

    # General path validation
    validate_path "$path"
}

#######################################
# Validate path exists
# Arguments:
#   $1 - Path to check
# Returns:
#   0 if exists, 1 if not
#######################################
path_exists() {
    local path="$1"

    if [ ! -e "$path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi

    return 0
}

#######################################
# Validate path is within allowed directory
# Arguments:
#   $1 - Path to check
#   $2 - Allowed base directory
# Returns:
#   0 if within base, 1 if not
#######################################
validate_path_within() {
    local path="$1"
    local base="$2"

    # Resolve to absolute paths
    local abs_path
    abs_path=$(realpath -m "$path" 2>/dev/null)
    local abs_base
    abs_base=$(realpath -m "$base" 2>/dev/null)

    if [ -z "$abs_path" ] || [ -z "$abs_base" ]; then
        return 1
    fi

    # Check if path starts with base
    if [[ ! "$abs_path" =~ ^"$abs_base" ]]; then
        log_error "Path outside allowed directory"
        echo "  Path: $abs_path"
        echo "  Allowed base: $abs_base"
        return 1
    fi

    return 0
}

###############################################################################
# DATABASE VALIDATION
###############################################################################

#######################################
# Validate database name
# Database names must:
# - Start with letter or underscore
# - Contain only alphanumeric and underscore
# - Length: 1-64 characters
# - Not be a reserved word
#
# Arguments:
#   $1 - Database name
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_db_name() {
    local name="$1"

    # Check if empty
    if [ -z "$name" ]; then
        log_error "Database name cannot be empty"
        return 1
    fi

    # Check length
    local len=${#name}
    if [ "$len" -lt 1 ] || [ "$len" -gt 64 ]; then
        log_error "Database name must be 1-64 characters long"
        return 1
    fi

    # Check format
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        log_error "Invalid database name format"
        echo "  Database name must:"
        echo "  - Start with a letter or underscore"
        echo "  - Contain only letters, numbers, and underscores"
        echo ""
        echo "  Examples:"
        echo "  ✓ myapp_db"
        echo "  ✓ _test_database"
        echo "  ✓ db123"
        echo "  ✗ 123db (starts with number)"
        echo "  ✗ my-app-db (contains hyphen)"
        return 1
    fi

    # Check for reserved words
    local reserved_words=("mysql" "information_schema" "performance_schema" "sys")
    if array_contains "$name" "${reserved_words[@]}"; then
        log_error "Database name is a reserved word: $name"
        return 1
    fi

    return 0
}

###############################################################################
# SYSTEM VALIDATION
###############################################################################

#######################################
# Check if command exists
# Arguments:
#   $1 - Command name
# Returns:
#   0 if exists, 1 if not
#######################################
check_command() {
    local cmd="$1"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        return 1
    fi

    return 0
}

#######################################
# Check if package is installed
# Arguments:
#   $1 - Package name
# Returns:
#   0 if installed, 1 if not
#######################################
check_package() {
    local pkg="$1"

    if command_exists dpkg; then
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            return 0
        fi
    fi

    log_error "Required package not installed: $pkg"
    return 1
}

#######################################
# Check if service exists
# Arguments:
#   $1 - Service name
# Returns:
#   0 if exists, 1 if not
#######################################
check_service() {
    local service="$1"

    if systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
        return 0
    fi

    log_error "Service not found: $service"
    return 1
}

#######################################
# Check if service is running
# Arguments:
#   $1 - Service name
# Returns:
#   0 if running, 1 if not
#######################################
check_service_running() {
    local service="$1"

    if systemctl is-active --quiet "$service"; then
        return 0
    fi

    log_error "Service not running: $service"
    return 1
}

#######################################
# Validate system requirements
# Checks:
# - OS compatibility
# - systemd availability
# - Required commands
# - Disk space
#
# Returns:
#   0 if all requirements met, 1 if not
#######################################
validate_system_requirements() {
    local errors=0

    print_info "Checking system requirements..."
    echo ""

    # Check OS
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "  OS: $NAME $VERSION"

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
            print_warning "OS may not be supported (Ubuntu 22.04+ or Debian 11+ recommended)"
        else
            print_success "OS supported"
        fi
    else
        print_warning "Could not detect OS version"
    fi

    # Check systemd
    if is_systemd_running; then
        print_success "systemd is running"
    else
        print_error "systemd is not running (required for service management)"
        echo "  For WSL, enable systemd in /etc/wsl.conf:"
        echo "  [boot]"
        echo "  systemd=true"
        ((errors++))
    fi

    # Check required commands
    local required_commands=("jq" "curl" "git")
    for cmd in "${required_commands[@]}"; do
        if check_command "$cmd"; then
            print_success "$cmd is installed"
        else
            print_error "$cmd is not installed"
            ((errors++))
        fi
    done

    # Check disk space (minimum 10GB)
    local available
    available=$(get_available_space "$HOME")
    local available_gb=$((available / 1024 / 1024 / 1024))

    if [ "$available_gb" -ge 10 ]; then
        print_success "Sufficient disk space ($available_gb GB available)"
    else
        print_warning "Low disk space ($available_gb GB available, 10+ GB recommended)"
    fi

    echo ""

    if [ $errors -gt 0 ]; then
        print_error "$errors requirement(s) not met"
        return 1
    fi

    print_success "All system requirements met"
    return 0
}

#######################################
# Validate Apache configuration
# Runs apachectl configtest
#
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_apache_config() {
    if ! sudo apachectl configtest 2>&1 | grep -q "Syntax OK"; then
        log_error "Apache configuration test failed"
        return 1
    fi

    return 0
}

#######################################
# Validate JSON string
# Arguments:
#   $1 - JSON string
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_json() {
    local json="$1"

    if ! echo "$json" | jq empty 2>/dev/null; then
        log_error "Invalid JSON"
        return 1
    fi

    return 0
}
