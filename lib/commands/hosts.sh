#!/usr/bin/env bash

#######################################
# Hosts File Management Commands
# Manages /etc/hosts and Windows hosts file (WSL)
#
# Commands:
#   hosts add      - Add entry to hosts file
#   hosts remove   - Remove entry from hosts file
#   hosts list     - List DevFlow entries
#   hosts sync     - Sync all sites to hosts file
#######################################

LINUX_HOSTS_FILE="/etc/hosts"
WINDOWS_HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"

#######################################
# Show hosts command help
#######################################
hosts_show_help() {
    cat << 'EOF'
Hosts File Management Commands

Usage:
  devflow hosts <command> [options] [arguments]

Commands:
  add <hostname> [ip]      Add entry to hosts file
  remove <hostname>        Remove entry from hosts file
  list                     List DevFlow entries
  sync                     Sync all sites to hosts file
  clean                    Remove all DevFlow entries

Examples:
  # Add entry
  devflow hosts add myapp.test

  # Add with custom IP
  devflow hosts add myapp.test 192.168.1.100

  # Remove entry
  devflow hosts remove myapp.test

  # Sync all sites
  devflow hosts sync

  # List entries
  devflow hosts list

  # Clean DevFlow entries
  devflow hosts clean

Notes:
  - Linux hosts: /etc/hosts (requires sudo)
  - Windows hosts: C:\Windows\System32\drivers\etc\hosts (WSL only)
  - Default IP: 127.0.0.1
  - Entries are marked with # DevFlow

EOF
}

#######################################
# Add entry to hosts file
# Arguments:
#   $1 - Hostname
#   $2 - IP address (optional, default: 127.0.0.1)
# Returns:
#   0 on success, 1 on error
#######################################
hosts_add() {
    local hostname="$1"
    local ip="${2:-127.0.0.1}"

    if [ -z "$hostname" ]; then
        log_error "Hostname is required"
        echo "Usage: devflow hosts add <hostname> [ip]"
        return 1
    fi

    print_info "Adding hosts entry: $hostname"
    echo ""

    # Add to Linux hosts
    if hosts_entry_exists "$hostname" "$LINUX_HOSTS_FILE"; then
        print_info "Entry already exists in Linux hosts"
    else
        print_step "Adding to Linux hosts file"
        if ! echo "$ip $hostname # DevFlow" | sudo tee -a "$LINUX_HOSTS_FILE" >/dev/null; then
            log_error "Failed to add to Linux hosts"
            return 1
        fi
        print_success "Added to Linux hosts"
    fi

    # Add to Windows hosts if WSL
    if is_wsl && [ -f "$WINDOWS_HOSTS_FILE" ]; then
        if hosts_entry_exists "$hostname" "$WINDOWS_HOSTS_FILE"; then
            print_info "Entry already exists in Windows hosts"
        else
            print_step "Adding to Windows hosts file"
            # Use PowerShell to add (proper permissions)
            if /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "Add-Content -Path C:\\Windows\\System32\\drivers\\etc\\hosts -Value '$ip $hostname # DevFlow'" 2>/dev/null; then
                print_success "Added to Windows hosts"
            else
                print_warning "Failed to add to Windows hosts (run as Administrator)"
            fi
        fi
    fi

    echo ""
    print_success "Hosts entry added: $hostname -> $ip"
    echo ""

    return 0
}

#######################################
# Remove entry from hosts file
# Arguments:
#   $1 - Hostname
# Returns:
#   0 on success, 1 on error
#######################################
hosts_remove() {
    local hostname="$1"

    if [ -z "$hostname" ]; then
        log_error "Hostname is required"
        echo "Usage: devflow hosts remove <hostname>"
        return 1
    fi

    print_info "Removing hosts entry: $hostname"
    echo ""

    # Remove from Linux hosts
    print_step "Removing from Linux hosts file"
    if sudo sed -i "/$hostname.*# DevFlow/d" "$LINUX_HOSTS_FILE"; then
        print_success "Removed from Linux hosts"
    else
        print_warning "Failed to remove from Linux hosts"
    fi

    # Remove from Windows hosts if WSL
    if is_wsl && [ -f "$WINDOWS_HOSTS_FILE" ]; then
        print_step "Removing from Windows hosts file"
        if /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "(Get-Content C:\\Windows\\System32\\drivers\\etc\\hosts) | Where-Object {\$_ -notmatch '$hostname.*# DevFlow'} | Set-Content C:\\Windows\\System32\\drivers\\etc\\hosts" 2>/dev/null; then
            print_success "Removed from Windows hosts"
        else
            print_warning "Failed to remove from Windows hosts (run as Administrator)"
        fi
    fi

    echo ""
    print_success "Hosts entry removed: $hostname"
    echo ""

    return 0
}

#######################################
# List DevFlow hosts entries
# Returns:
#   0 on success
#######################################
hosts_list() {
    echo ""
    echo "DevFlow Hosts Entries:"
    echo ""

    # Linux hosts
    echo "Linux (/etc/hosts):"
    if grep "# DevFlow" "$LINUX_HOSTS_FILE" >/dev/null 2>&1; then
        grep "# DevFlow" "$LINUX_HOSTS_FILE" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  (none)"
    fi

    echo ""

    # Windows hosts (if WSL)
    if is_wsl && [ -f "$WINDOWS_HOSTS_FILE" ]; then
        echo "Windows (C:\\Windows\\System32\\drivers\\etc\\hosts):"
        if grep "# DevFlow" "$WINDOWS_HOSTS_FILE" >/dev/null 2>&1; then
            grep "# DevFlow" "$WINDOWS_HOSTS_FILE" | while read -r line; do
                echo "  $line"
            done
        else
            echo "  (none)"
        fi
    fi

    echo ""
    return 0
}

#######################################
# Sync all sites to hosts file
# Returns:
#   0 on success
#######################################
hosts_sync() {
    print_info "Syncing all sites to hosts file..."
    echo ""

    # Get all sites
    local sites
    sites=$(site_list .sites[] 2>/dev/null)

    if [ -z "$sites" ]; then
        print_info "No sites found"
        return 0
    fi

    local count=0
    while IFS= read -r site; do
        local name
        name=$(echo "$site" | jq -r '.name')

        if ! hosts_entry_exists "$name" "$LINUX_HOSTS_FILE"; then
            print_step "Adding: $name"
            hosts_add "$name" "127.0.0.1"
            ((count++))
        fi
    done <<< "$sites"

    echo ""
    if [ $count -eq 0 ]; then
        print_success "All sites already in hosts file"
    else
        print_success "Added $count site(s) to hosts file"
    fi
    echo ""

    return 0
}

#######################################
# Clean DevFlow entries from hosts file
# Returns:
#   0 on success
#######################################
hosts_clean() {
    print_warning "This will remove ALL DevFlow entries from hosts file"
    echo ""
    read -rp "Are you sure? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
    fi

    print_info "Cleaning DevFlow entries..."
    echo ""

    # Clean Linux hosts
    print_step "Cleaning Linux hosts file"
    sudo sed -i '/# DevFlow/d' "$LINUX_HOSTS_FILE"
    print_success "Linux hosts cleaned"

    # Clean Windows hosts if WSL
    if is_wsl && [ -f "$WINDOWS_HOSTS_FILE" ]; then
        print_step "Cleaning Windows hosts file"
        /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "(Get-Content C:\\Windows\\System32\\drivers\\etc\\hosts) | Where-Object {\$_ -notmatch '# DevFlow'} | Set-Content C:\\Windows\\System32\\drivers\\etc\\hosts" 2>/dev/null || true
        print_success "Windows hosts cleaned"
    fi

    echo ""
    print_success "All DevFlow entries removed"
    echo ""

    return 0
}

#######################################
# Check if hosts entry exists
# Arguments:
#   $1 - Hostname
#   $2 - Hosts file path
# Returns:
#   0 if exists, 1 if not
#######################################
hosts_entry_exists() {
    local hostname="$1"
    local hosts_file="$2"

    grep -q "$hostname" "$hosts_file" 2>/dev/null
}

#######################################
# Route hosts subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
hosts_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        hosts_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        add)
            hosts_add "$@"
            ;;
        remove|rm|delete)
            hosts_remove "$@"
            ;;
        list|ls)
            hosts_list "$@"
            ;;
        sync)
            hosts_sync "$@"
            ;;
        clean)
            hosts_clean "$@"
            ;;
        help|--help|-h)
            hosts_show_help
            return 0
            ;;
        *)
            log_error "Unknown hosts command: $subcommand"
            echo ""
            echo "Run 'devflow hosts --help' for available commands."
            return 1
            ;;
    esac
}
