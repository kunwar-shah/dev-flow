#!/usr/bin/env bash

#######################################
# Service Management Commands
# Manages Apache, PHP-FPM, MySQL/MariaDB services
#
# Commands:
#   service status    - Show service status
#   service start     - Start services
#   service stop      - Stop services
#   service restart   - Restart services
#   service reload    - Reload services
#   service enable    - Enable auto-start
#   service disable   - Disable auto-start
#######################################

# Supported services
CORE_SERVICES=("apache2" "mysql" "mariadb")

#######################################
# Show service command help
#######################################
service_show_help() {
    cat << 'EOF'
Service Management Commands

Usage:
  devflow service <command> [service...]

Commands:
  status              Show status of all services
  start [service]     Start service(s)
  stop [service]      Stop service(s)
  restart [service]   Restart service(s)
  reload [service]    Reload service(s)
  enable [service]    Enable service auto-start
  disable [service]   Disable service auto-start
  logs [service]      View service logs

Services:
  apache2             Apache web server
  mysql               MySQL database (or mariadb)
  mariadb             MariaDB database
  php<version>-fpm    PHP-FPM (e.g., php8.2-fpm)
  all                 All services

Examples:
  # Show status of all services
  devflow service status

  # Start Apache
  devflow service start apache2

  # Restart all PHP-FPM services
  devflow service restart all

  # View Apache logs
  devflow service logs apache2

  # Enable MySQL auto-start
  devflow service enable mysql

Notes:
  - 'all' applies to apache2, mysql/mariadb, and all PHP-FPM services
  - Use 'reload' for Apache to apply config changes without downtime
  - PHP-FPM services are php7.4-fpm, php8.0-fpm, php8.1-fpm, etc.

EOF
}

#######################################
# Get all PHP-FPM services
# Outputs:
#   List of PHP-FPM service names
#######################################
get_php_services() {
    systemctl list-units --type=service --all --no-pager | \
        grep -oP 'php\d+\.\d+-fpm' | \
        sort -u || true
}

#######################################
# Get database service name
# Outputs:
#   mysql or mariadb (whichever is installed)
#######################################
get_db_service() {
    if systemctl list-unit-files | grep -q "^mariadb.service"; then
        echo "mariadb"
    elif systemctl list-unit-files | grep -q "^mysql.service"; then
        echo "mysql"
    else
        echo ""
    fi
}

#######################################
# Expand service names
# Arguments:
#   $@ - Service names (can include 'all')
# Outputs:
#   Expanded list of service names
#######################################
expand_services() {
    local services=()

    if [ $# -eq 0 ] || [ "$1" = "all" ]; then
        # All services
        services+=("apache2")

        local db_service
        db_service=$(get_db_service)
        [ -n "$db_service" ] && services+=("$db_service")

        # Add all PHP-FPM services
        while IFS= read -r php_svc; do
            [ -n "$php_svc" ] && services+=("$php_svc")
        done < <(get_php_services)
    else
        # Specific services
        for svc in "$@"; do
            if [ "$svc" = "mysql" ] || [ "$svc" = "mariadb" ]; then
                local db_service
                db_service=$(get_db_service)
                [ -n "$db_service" ] && services+=("$db_service")
            else
                services+=("$svc")
            fi
        done
    fi

    # Return unique services
    printf '%s\n' "${services[@]}" | sort -u
}

#######################################
# Show service status
# Arguments:
#   $@ - Service names (optional)
# Returns:
#   0 on success
#######################################
service_status() {
    local services
    mapfile -t services < <(expand_services "$@")

    if [ ${#services[@]} -eq 0 ]; then
        print_warning "No services found"
        return 0
    fi

    echo ""
    echo "Service Status:"
    echo ""
    printf "%-20s %-15s %-15s %-30s\n" "SERVICE" "STATUS" "ENABLED" "DESCRIPTION"
    printf "%-20s %-15s %-15s %-30s\n" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..30})"

    for service in "${services[@]}"; do
        local status enabled description

        # Check if service exists
        if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            status="Not Installed"
            enabled="-"
            description="-"
        else
            # Get status
            if systemctl is-active --quiet "$service"; then
                status="Running"
            elif systemctl is-failed --quiet "$service"; then
                status="Failed"
            else
                status="Stopped"
            fi

            # Get enabled status
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                enabled="Enabled"
            else
                enabled="Disabled"
            fi

            # Get description
            description=$(systemctl show "$service" -p Description --value 2>/dev/null | head -c 28)
        fi

        printf "%-20s %-15s %-15s %-30s\n" "$service" "$status" "$enabled" "$description"
    done

    echo ""
    return 0
}

#######################################
# Start services
# Arguments:
#   $@ - Service names
# Returns:
#   0 on success, 1 on error
#######################################
service_start() {
    local services
    mapfile -t services < <(expand_services "$@")

    if [ ${#services[@]} -eq 0 ]; then
        log_error "No services specified"
        return 1
    fi

    print_info "Starting services..."
    echo ""

    local errors=0
    for service in "${services[@]}"; do
        print_step "Starting $service"

        if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            print_error "$service is not installed"
            ((errors++))
            continue
        fi

        if systemctl is-active --quiet "$service"; then
            print_info "$service is already running"
            continue
        fi

        if sudo systemctl start "$service"; then
            print_success "$service started"
        else
            print_error "Failed to start $service"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All services started successfully"
        return 0
    else
        print_error "$errors service(s) failed to start"
        return 1
    fi
}

#######################################
# Stop services
# Arguments:
#   $@ - Service names
# Returns:
#   0 on success, 1 on error
#######################################
service_stop() {
    local services
    mapfile -t services < <(expand_services "$@")

    if [ ${#services[@]} -eq 0 ]; then
        log_error "No services specified"
        return 1
    fi

    print_info "Stopping services..."
    echo ""

    local errors=0
    for service in "${services[@]}"; do
        print_step "Stopping $service"

        if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            print_error "$service is not installed"
            ((errors++))
            continue
        fi

        if ! systemctl is-active --quiet "$service"; then
            print_info "$service is already stopped"
            continue
        fi

        if sudo systemctl stop "$service"; then
            print_success "$service stopped"
        else
            print_error "Failed to stop $service"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All services stopped successfully"
        return 0
    else
        print_error "$errors service(s) failed to stop"
        return 1
    fi
}

#######################################
# Restart services
# Arguments:
#   $@ - Service names
# Returns:
#   0 on success, 1 on error
#######################################
service_restart() {
    local services
    mapfile -t services < <(expand_services "$@")

    if [ ${#services[@]} -eq 0 ]; then
        log_error "No services specified"
        return 1
    fi

    print_info "Restarting services..."
    echo ""

    local errors=0
    for service in "${services[@]}"; do
        print_step "Restarting $service"

        if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            print_error "$service is not installed"
            ((errors++))
            continue
        fi

        if sudo systemctl restart "$service"; then
            print_success "$service restarted"
        else
            print_error "Failed to restart $service"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All services restarted successfully"
        return 0
    else
        print_error "$errors service(s) failed to restart"
        return 1
    fi
}

#######################################
# Reload services
# Arguments:
#   $@ - Service names
# Returns:
#   0 on success, 1 on error
#######################################
service_reload() {
    local services
    mapfile -t services < <(expand_services "$@")

    if [ ${#services[@]} -eq 0 ]; then
        log_error "No services specified"
        return 1
    fi

    print_info "Reloading services..."
    echo ""

    local errors=0
    for service in "${services[@]}"; do
        print_step "Reloading $service"

        if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            print_error "$service is not installed"
            ((errors++))
            continue
        fi

        if sudo systemctl reload "$service" 2>/dev/null; then
            print_success "$service reloaded"
        else
            print_warning "$service doesn't support reload, restarting instead"
            if sudo systemctl restart "$service"; then
                print_success "$service restarted"
            else
                print_error "Failed to restart $service"
                ((errors++))
            fi
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All services reloaded successfully"
        return 0
    else
        print_error "$errors service(s) failed to reload"
        return 1
    fi
}

#######################################
# Enable service auto-start
# Arguments:
#   $@ - Service names
# Returns:
#   0 on success, 1 on error
#######################################
service_enable() {
    local services
    mapfile -t services < <(expand_services "$@")

    if [ ${#services[@]} -eq 0 ]; then
        log_error "No services specified"
        return 1
    fi

    print_info "Enabling services..."
    echo ""

    local errors=0
    for service in "${services[@]}"; do
        print_step "Enabling $service"

        if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            print_error "$service is not installed"
            ((errors++))
            continue
        fi

        if sudo systemctl enable "$service" >/dev/null 2>&1; then
            print_success "$service enabled"
        else
            print_error "Failed to enable $service"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All services enabled"
        return 0
    else
        print_error "$errors service(s) failed to enable"
        return 1
    fi
}

#######################################
# Disable service auto-start
# Arguments:
#   $@ - Service names
# Returns:
#   0 on success, 1 on error
#######################################
service_disable() {
    local services
    mapfile -t services < <(expand_services "$@")

    if [ ${#services[@]} -eq 0 ]; then
        log_error "No services specified"
        return 1
    fi

    print_info "Disabling services..."
    echo ""

    local errors=0
    for service in "${services[@]}"; do
        print_step "Disabling $service"

        if ! systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            print_error "$service is not installed"
            ((errors++))
            continue
        fi

        if sudo systemctl disable "$service" >/dev/null 2>&1; then
            print_success "$service disabled"
        else
            print_error "Failed to disable $service"
            ((errors++))
        fi
    done

    echo ""
    if [ $errors -eq 0 ]; then
        print_success "All services disabled"
        return 0
    else
        print_error "$errors service(s) failed to disable"
        return 1
    fi
}

#######################################
# View service logs
# Arguments:
#   $1 - Service name
#   $2 - Number of lines (optional, default: 50)
# Returns:
#   0 on success
#######################################
service_logs() {
    local service="$1"
    local lines="${2:-50}"

    if [ -z "$service" ]; then
        log_error "Service name is required"
        echo "Usage: devflow service logs <service> [lines]"
        return 1
    fi

    if [ "$service" = "all" ]; then
        log_error "Cannot show logs for 'all' services"
        echo "Specify a service: apache2, mysql, php8.2-fpm, etc."
        return 1
    fi

    print_info "Showing last $lines lines for $service"
    echo ""

    sudo journalctl -u "$service" -n "$lines" --no-pager

    return 0
}

#######################################
# Route service subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
service_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        service_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        status)
            service_status "$@"
            ;;
        start)
            service_start "$@"
            ;;
        stop)
            service_stop "$@"
            ;;
        restart)
            service_restart "$@"
            ;;
        reload)
            service_reload "$@"
            ;;
        enable)
            service_enable "$@"
            ;;
        disable)
            service_disable "$@"
            ;;
        logs)
            service_logs "$@"
            ;;
        help|--help|-h)
            service_show_help
            return 0
            ;;
        *)
            log_error "Unknown service command: $subcommand"
            echo ""
            echo "Run 'devflow service --help' for available commands."
            return 1
            ;;
    esac
}
