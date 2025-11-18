#!/usr/bin/env bash

#######################################
# System Health Check Command
# Diagnoses system configuration and issues
#
# Commands:
#   doctor          - Run all health checks
#   doctor quick    - Quick health check
#   doctor verbose  - Verbose diagnostics
#######################################

#######################################
# Show doctor command help
#######################################
doctor_show_help() {
    cat << 'EOF'
System Health Check Command

Usage:
  devflow doctor [options]

Options:
  quick       Quick health check
  verbose     Verbose diagnostics with details
  fix         Attempt to fix common issues

Examples:
  # Run all health checks
  devflow doctor

  # Quick check
  devflow doctor quick

  # Verbose output
  devflow doctor verbose

  # Auto-fix issues
  devflow doctor fix

What It Checks:
  - System requirements (OS, systemd, disk space)
  - DevFlow installation and configuration
  - Service status (Apache, MySQL, PHP-FPM)
  - PHP versions and extensions
  - File permissions
  - Network and ports
  - Site configurations
  - Common issues

EOF
}

#######################################
# Run all health checks
# Arguments:
#   $1 - Mode (quick|verbose|fix)
# Returns:
#   0 if healthy, 1 if issues found
#######################################
doctor_run() {
    local mode="${1:-normal}"
    local issues=0
    local warnings=0

    print_header_box "DevFlow Health Check"
    echo ""

    # System Requirements
    print_section "System Requirements"
    if ! check_system_requirements_doctor "$mode"; then
        ((issues++))
    fi
    echo ""

    # DevFlow Installation
    print_section "DevFlow Installation"
    if ! check_devflow_installation "$mode"; then
        ((issues++))
    fi
    echo ""

    # Services
    print_section "Services Status"
    if ! check_services_doctor "$mode"; then
        ((issues++))
    fi
    echo ""

    # PHP Configuration
    print_section "PHP Configuration"
    if ! check_php_doctor "$mode"; then
        ((issues++))
    fi
    echo ""

    # File Permissions
    if [ "$mode" != "quick" ]; then
        print_section "File Permissions"
        if ! check_permissions_doctor "$mode"; then
            ((warnings++))
        fi
        echo ""
    fi

    # Network and Ports
    print_section "Network & Ports"
    if ! check_network_doctor "$mode"; then
        ((warnings++))
    fi
    echo ""

    # Sites Configuration
    print_section "Sites Configuration"
    if ! check_sites_doctor "$mode"; then
        ((warnings++))
    fi
    echo ""

    # Summary
    print_section "Summary"
    echo ""

    if [ $issues -eq 0 ] && [ $warnings -eq 0 ]; then
        print_success "System is healthy!"
        echo "All checks passed. DevFlow is ready to use."
    elif [ $issues -eq 0 ]; then
        print_warning "$warnings warning(s) found"
        echo "System is functional but could be improved."
    else
        print_error "$issues critical issue(s) and $warnings warning(s) found"
        echo ""
        echo "Fix critical issues before using DevFlow."
        if [ "$mode" != "fix" ]; then
            echo "Run 'devflow doctor fix' to attempt automatic fixes."
        fi
    fi

    echo ""

    [ $issues -eq 0 ]
}

#######################################
# Helper: Print section header
#######################################
print_section() {
    echo -e "${BLUE}▶ $1${NC}"
    echo "$(printf '%.0s─' {1..60})"
}

#######################################
# Helper: Print header box
#######################################
print_header_box() {
    local text="$1"
    local len=${#text}
    local padding=$(( (60 - len) / 2 ))

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    printf "║%*s%s%*s║\n" $padding "" "$text" $padding ""
    echo "╚══════════════════════════════════════════════════════════════╝"
}

#######################################
# Check system requirements
#######################################
check_system_requirements_doctor() {
    local mode="$1"
    local errors=0

    # OS Check
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        print_check_item "OS" "$NAME $VERSION_ID" "✓"
    else
        print_check_item "OS" "Unknown" "⚠"
        ((errors++))
    fi

    # systemd
    if is_systemd_running; then
        print_check_item "systemd" "Running" "✓"
    else
        print_check_item "systemd" "Not running" "✗"
        ((errors++))
    fi

    # Disk space
    local available
    available=$(df "$HOME" | awk 'NR==2 {print $4}')
    local available_gb=$((available / 1024 / 1024))

    if [ "$available_gb" -ge 10 ]; then
        print_check_item "Disk Space" "${available_gb}GB available" "✓"
    else
        print_check_item "Disk Space" "${available_gb}GB available (low)" "⚠"
    fi

    # Required commands
    for cmd in jq curl git; do
        if command_exists "$cmd"; then
            print_check_item "$cmd" "Installed" "✓"
        else
            print_check_item "$cmd" "Not installed" "✗"
            ((errors++))
        fi
    done

    return $errors
}

#######################################
# Check DevFlow installation
#######################################
check_devflow_installation() {
    local mode="$1"
    local errors=0

    # DevFlow binary
    if [ -x "$DEVFLOW_LIB_DIR/../bin/devflow" ]; then
        print_check_item "DevFlow Binary" "Found" "✓"
    else
        print_check_item "DevFlow Binary" "Not found" "✗"
        ((errors++))
    fi

    # Core libraries
    local libs=("config" "logger" "utils" "validator")
    local missing=0
    for lib in "${libs[@]}"; do
        if [ ! -f "$DEVFLOW_LIB_DIR/core/${lib}.sh" ]; then
            ((missing++))
        fi
    done

    if [ $missing -eq 0 ]; then
        print_check_item "Core Libraries" "All present (${#libs[@]})" "✓"
    else
        print_check_item "Core Libraries" "$missing missing" "✗"
        ((errors++))
    fi

    # Configuration
    if [ -f "$DEVFLOW_CONFIG_FILE" ]; then
        print_check_item "Configuration" "Found" "✓"
    else
        print_check_item "Configuration" "Not initialized" "⚠"
    fi

    # Sites registry
    if [ -f "$DEVFLOW_SITES_FILE" ]; then
        local site_count
        site_count=$(jq '.sites | length' "$DEVFLOW_SITES_FILE" 2>/dev/null || echo "0")
        print_check_item "Sites Registry" "$site_count site(s)" "✓"
    else
        print_check_item "Sites Registry" "Not found" "⚠"
    fi

    return $errors
}

#######################################
# Check services
#######################################
check_services_doctor() {
    local mode="$1"
    local errors=0

    # Apache
    if systemctl list-unit-files apache2.service >/dev/null 2>&1; then
        if systemctl is-active --quiet apache2; then
            print_check_item "Apache" "Running" "✓"
        else
            print_check_item "Apache" "Stopped" "⚠"
        fi
    else
        print_check_item "Apache" "Not installed" "✗"
        ((errors++))
    fi

    # MySQL/MariaDB
    local db_service
    db_service=$(get_db_service)

    if [ -n "$db_service" ]; then
        if systemctl is-active --quiet "$db_service"; then
            print_check_item "Database ($db_service)" "Running" "✓"
        else
            print_check_item "Database ($db_service)" "Stopped" "⚠"
        fi
    else
        print_check_item "Database" "Not installed" "✗"
        ((errors++))
    fi

    # PHP-FPM services
    local php_services
    php_services=$(get_php_services | wc -l)

    if [ "$php_services" -gt 0 ]; then
        print_check_item "PHP-FPM Services" "$php_services installed" "✓"
    else
        print_check_item "PHP-FPM Services" "None installed" "⚠"
    fi

    return $errors
}

#######################################
# Check PHP configuration
#######################################
check_php_doctor() {
    local mode="$1"
    local errors=0

    # Check for PHP installations
    local php_versions=(7.4 8.0 8.1 8.2 8.3)
    local installed_count=0

    for version in "${php_versions[@]}"; do
        if php_is_installed "$version"; then
            ((installed_count++))

            if [ "$mode" = "verbose" ]; then
                # Check PHP-FPM socket
                local socket="/run/php/php${version}-fpm.sock"
                if [ -S "$socket" ]; then
                    print_check_item "  PHP $version Socket" "Available" "✓"
                else
                    print_check_item "  PHP $version Socket" "Not found" "⚠"
                fi
            fi
        fi
    done

    if [ $installed_count -gt 0 ]; then
        print_check_item "PHP Versions" "$installed_count installed" "✓"
    else
        print_check_item "PHP Versions" "None installed" "✗"
        ((errors++))
    fi

    return $errors
}

#######################################
# Check file permissions
#######################################
check_permissions_doctor() {
    local mode="$1"
    local warnings=0

    # Check websites root
    local websites_root
    websites_root=$(config_get_websites_root 2>/dev/null || echo "$HOME/websites")

    if [ -d "$websites_root" ]; then
        if [ -w "$websites_root" ]; then
            print_check_item "Websites Directory" "Writable" "✓"
        else
            print_check_item "Websites Directory" "Not writable" "⚠"
            ((warnings++))
        fi
    else
        print_check_item "Websites Directory" "Not created" "⚠"
    fi

    # Check DevFlow config directory
    if [ -d "$DEVFLOW_CONFIG_DIR" ]; then
        local perms
        perms=$(stat -c %a "$DEVFLOW_CONFIG_DIR" 2>/dev/null)

        if [ "$perms" = "700" ]; then
            print_check_item "Config Directory" "Secure (700)" "✓"
        else
            print_check_item "Config Directory" "Permissions: $perms" "⚠"
            ((warnings++))
        fi
    fi

    return $warnings
}

#######################################
# Check network and ports
#######################################
check_network_doctor() {
    local mode="$1"
    local warnings=0

    # Check port 80
    if sudo netstat -tuln 2>/dev/null | grep -q ":80 " || sudo ss -tuln 2>/dev/null | grep -q ":80 "; then
        print_check_item "Port 80 (HTTP)" "In use" "✓"
    else
        print_check_item "Port 80 (HTTP)" "Not in use" "⚠"
        ((warnings++))
    fi

    # Check port 443
    if sudo netstat -tuln 2>/dev/null | grep -q ":443 " || sudo ss -tuln 2>/dev/null | grep -q ":443 "; then
        print_check_item "Port 443 (HTTPS)" "In use" "✓"
    else
        print_check_item "Port 443 (HTTPS)" "Not in use" "⚠"
    fi

    # Check port 3306
    if sudo netstat -tuln 2>/dev/null | grep -q ":3306 " || sudo ss -tuln 2>/dev/null | grep -q ":3306 "; then
        print_check_item "Port 3306 (MySQL)" "In use" "✓"
    else
        print_check_item "Port 3306 (MySQL)" "Not in use" "⚠"
    fi

    return $warnings
}

#######################################
# Check sites configuration
#######################################
check_sites_doctor() {
    local mode="$1"
    local warnings=0

    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        print_check_item "Sites" "No sites registry" "⚠"
        return 0
    fi

    local site_count
    site_count=$(jq '.sites | length' "$DEVFLOW_SITES_FILE" 2>/dev/null || echo "0")

    if [ "$site_count" -eq 0 ]; then
        print_check_item "Sites" "No sites configured" "ℹ"
        return 0
    fi

    print_check_item "Sites" "$site_count configured" "✓"

    # Check each site in verbose mode
    if [ "$mode" = "verbose" ]; then
        local sites
        sites=$(jq -r '.sites[].name' "$DEVFLOW_SITES_FILE" 2>/dev/null)

        while IFS= read -r site_name; do
            # Check if vhost exists
            if [ -f "/etc/apache2/sites-available/${site_name}.conf" ]; then
                print_check_item "  $site_name" "Vhost exists" "✓"
            else
                print_check_item "  $site_name" "Vhost missing" "⚠"
                ((warnings++))
            fi
        done <<< "$sites"
    fi

    return $warnings
}

#######################################
# Helper: Print check item
#######################################
print_check_item() {
    local name="$1"
    local status="$2"
    local icon="$3"

    case "$icon" in
        "✓")
            printf "  ${GREEN}%-25s${NC} %s\n" "$name" "$status"
            ;;
        "✗")
            printf "  ${RED}%-25s${NC} %s\n" "$name" "$status"
            ;;
        "⚠")
            printf "  ${YELLOW}%-25s${NC} %s\n" "$name" "$status"
            ;;
        *)
            printf "  ${BLUE}%-25s${NC} %s\n" "$name" "$status"
            ;;
    esac
}

#######################################
# Route doctor subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
doctor_command() {
    local subcommand="${1:-normal}"

    case "$subcommand" in
        quick)
            doctor_run "quick"
            ;;
        verbose)
            doctor_run "verbose"
            ;;
        fix)
            doctor_run "fix"
            ;;
        help|--help|-h)
            doctor_show_help
            return 0
            ;;
        *)
            doctor_run "normal"
            ;;
    esac
}
