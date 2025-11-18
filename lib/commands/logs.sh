#!/usr/bin/env bash

#######################################
# Log Management Commands
# View and manage logs for sites and services
#
# Commands:
#   logs site      - View site logs
#   logs service   - View service logs
#   logs tail      - Tail logs in real-time
#   logs clear     - Clear logs
#######################################

#######################################
# Show logs command help
#######################################
logs_show_help() {
    cat << 'EOF'
Log Management Commands

Usage:
  devflow logs <command> [options] [arguments]

Commands:
  site <name> [type]       View site logs (access|error|both)
  service <name> [lines]   View service logs
  tail <name>              Tail logs in real-time
  clear <name>             Clear site logs
  list                     List all log files

Examples:
  # View site error log
  devflow logs site myapp.test error

  # View both access and error logs
  devflow logs site myapp.test

  # Tail Apache logs
  devflow logs tail apache2

  # View last 100 lines of service log
  devflow logs service mysql 100

  # Clear site logs
  devflow logs clear myapp.test

  # List all logs
  devflow logs list

Notes:
  - Site logs: /var/log/apache2/<sitename>-{access,error}.log
  - Service logs: journalctl -u <service>
  - Use Ctrl+C to stop tailing

EOF
}

#######################################
# View site logs
# Arguments:
#   $1 - Site name
#   $2 - Log type (access|error|both, default: both)
# Returns:
#   0 on success, 1 on error
#######################################
logs_site() {
    local site_name="$1"
    local log_type="${2:-both}"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow logs site <name> [access|error|both]"
        return 1
    fi

    # Check if site exists
    if ! site_exists "$site_name"; then
        log_error "Site not found: $site_name"
        return 1
    fi

    local error_log="/var/log/apache2/${site_name}-error.log"
    local access_log="/var/log/apache2/${site_name}-access.log"
    local ssl_error_log="/var/log/apache2/${site_name}-ssl-error.log"
    local ssl_access_log="/var/log/apache2/${site_name}-ssl-access.log"

    case "$log_type" in
        error)
            print_info "Error Log: $error_log"
            echo ""
            if [ -f "$error_log" ]; then
                sudo tail -n 50 "$error_log"
            else
                print_warning "Log file not found"
            fi

            if [ -f "$ssl_error_log" ]; then
                echo ""
                print_info "SSL Error Log: $ssl_error_log"
                echo ""
                sudo tail -n 50 "$ssl_error_log"
            fi
            ;;
        access)
            print_info "Access Log: $access_log"
            echo ""
            if [ -f "$access_log" ]; then
                sudo tail -n 50 "$access_log"
            else
                print_warning "Log file not found"
            fi

            if [ -f "$ssl_access_log" ]; then
                echo ""
                print_info "SSL Access Log: $ssl_access_log"
                echo ""
                sudo tail -n 50 "$ssl_access_log"
            fi
            ;;
        both)
            # Show error logs first
            print_info "Error Logs:"
            echo ""
            if [ -f "$error_log" ]; then
                echo "==> $error_log <=="
                sudo tail -n 25 "$error_log"
            fi

            if [ -f "$ssl_error_log" ]; then
                echo ""
                echo "==> $ssl_error_log <=="
                sudo tail -n 25 "$ssl_error_log"
            fi

            echo ""
            echo ""
            print_info "Access Logs:"
            echo ""
            if [ -f "$access_log" ]; then
                echo "==> $access_log <=="
                sudo tail -n 25 "$access_log"
            fi

            if [ -f "$ssl_access_log" ]; then
                echo ""
                echo "==> $ssl_access_log <=="
                sudo tail -n 25 "$ssl_access_log"
            fi
            ;;
        *)
            log_error "Invalid log type: $log_type"
            echo "Valid types: access, error, both"
            return 1
            ;;
    esac

    echo ""
    return 0
}

#######################################
# View service logs
# Arguments:
#   $1 - Service name
#   $2 - Number of lines (default: 50)
# Returns:
#   0 on success
#######################################
logs_service() {
    local service="$1"
    local lines="${2:-50}"

    if [ -z "$service" ]; then
        log_error "Service name is required"
        echo "Usage: devflow logs service <name> [lines]"
        return 1
    fi

    print_info "Showing last $lines lines for $service"
    echo ""

    sudo journalctl -u "$service" -n "$lines" --no-pager

    return 0
}

#######################################
# Tail logs in real-time
# Arguments:
#   $1 - Name (site or service)
# Returns:
#   0 on success
#######################################
logs_tail() {
    local name="$1"

    if [ -z "$name" ]; then
        log_error "Name is required"
        echo "Usage: devflow logs tail <site|service>"
        return 1
    fi

    # Check if it's a site
    if site_exists "$name"; then
        local error_log="/var/log/apache2/${name}-error.log"
        local access_log="/var/log/apache2/${name}-access.log"

        print_info "Tailing logs for site: $name"
        print_info "Press Ctrl+C to stop"
        echo ""

        if [ -f "$error_log" ] && [ -f "$access_log" ]; then
            sudo tail -f "$error_log" "$access_log"
        elif [ -f "$error_log" ]; then
            sudo tail -f "$error_log"
        elif [ -f "$access_log" ]; then
            sudo tail -f "$access_log"
        else
            log_error "No log files found for site: $name"
            return 1
        fi
    else
        # Treat as service
        print_info "Tailing logs for service: $name"
        print_info "Press Ctrl+C to stop"
        echo ""

        sudo journalctl -u "$name" -f
    fi

    return 0
}

#######################################
# Clear site logs
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
logs_clear() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow logs clear <sitename>"
        return 1
    fi

    # Check if site exists
    if ! site_exists "$site_name"; then
        log_error "Site not found: $site_name"
        return 1
    fi

    print_warning "This will delete all log files for: $site_name"
    echo ""
    read -rp "Are you sure? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
    fi

    print_info "Clearing logs for: $site_name"
    echo ""

    # Clear log files
    local logs=(
        "/var/log/apache2/${site_name}-error.log"
        "/var/log/apache2/${site_name}-access.log"
        "/var/log/apache2/${site_name}-ssl-error.log"
        "/var/log/apache2/${site_name}-ssl-access.log"
    )

    local cleared=0
    for log_file in "${logs[@]}"; do
        if [ -f "$log_file" ]; then
            print_step "Clearing: $log_file"
            sudo truncate -s 0 "$log_file"
            print_success "Cleared"
            ((cleared++))
        fi
    done

    echo ""
    if [ $cleared -eq 0 ]; then
        print_info "No log files found"
    else
        print_success "Cleared $cleared log file(s)"
    fi
    echo ""

    return 0
}

#######################################
# List all log files
# Returns:
#   0 on success
#######################################
logs_list() {
    echo ""
    echo "DevFlow Log Files:"
    echo ""

    # Site logs
    echo "Site Logs (/var/log/apache2/):"
    echo ""

    if compgen -G "/var/log/apache2/*-error.log" >/dev/null 2>&1; then
        printf "%-40s %-15s %s\n" "FILE" "SIZE" "MODIFIED"
        printf "%-40s %-15s %s\n" "$(printf '%.0s-' {1..40})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..20})"

        for log_file in /var/log/apache2/*-{error,access}.log; do
            if [ -f "$log_file" ]; then
                local filename size modified
                filename=$(basename "$log_file")
                size=$(du -h "$log_file" 2>/dev/null | cut -f1 || echo "0")
                modified=$(stat -c %y "$log_file" 2>/dev/null | cut -d. -f1 || echo "Unknown")

                printf "%-40s %-15s %s\n" "$filename" "$size" "$modified"
            fi
        done
    else
        echo "  (none)"
    fi

    echo ""
    echo "DevFlow Log:"
    local devflow_log="$DEVFLOW_CONFIG_DIR/logs/devflow.log"
    if [ -f "$devflow_log" ]; then
        local size modified
        size=$(du -h "$devflow_log" 2>/dev/null | cut -f1)
        modified=$(stat -c %y "$devflow_log" 2>/dev/null | cut -d. -f1)
        echo "  $devflow_log"
        echo "  Size: $size, Modified: $modified"
    else
        echo "  (not created yet)"
    fi

    echo ""
    return 0
}

#######################################
# Route logs subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
logs_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        logs_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        site)
            logs_site "$@"
            ;;
        service|svc)
            logs_service "$@"
            ;;
        tail|follow)
            logs_tail "$@"
            ;;
        clear|clean)
            logs_clear "$@"
            ;;
        list|ls)
            logs_list "$@"
            ;;
        help|--help|-h)
            logs_show_help
            return 0
            ;;
        *)
            # Default to tailing if no subcommand matches
            logs_tail "$subcommand" "$@"
            ;;
    esac
}
