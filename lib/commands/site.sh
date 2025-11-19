#!/usr/bin/env bash

#######################################
# Site Management Commands
# Handles creation, deletion, and management of development sites
#
# Commands:
#   site create   - Create a new site
#   site list     - List all sites
#   site delete   - Delete a site
#   site info     - Show site information
#   site open     - Open site in browser
#   site enable   - Enable a site
#   site disable  - Disable a site
#######################################

#######################################
# Show site command help
#######################################
site_show_help() {
    cat << 'EOF'
Site Management Commands

Usage:
  devflow site <command> [options] [arguments]

Commands:
  create <name> <php-version> [docroot]   Create a new development site
  list                                     List all sites
  delete <name>                            Delete a site
  info <name>                              Show site information
  open <name>                              Open site in browser
  enable <name>                            Enable a site
  disable <name>                           Disable a site

Examples:
  # Create a site with PHP 8.2
  devflow site create myapp.test php8.2

  # Create a site with custom document root
  devflow site create api.test php8.3 public

  # List all sites
  devflow site list

  # Delete a site
  devflow site delete myapp.test

  # Show site details
  devflow site info myapp.test

  # Open site in browser
  devflow site open myapp.test

See also:
  devflow php list        List installed PHP versions
  devflow ssl create      Create SSL certificate
  devflow db create       Create database

EOF
}

#######################################
# Create a new site
# Arguments:
#   $1 - Site name (e.g., myapp.test)
#   $2 - PHP version (e.g., php8.2 or 8.2)
#   $3 - Document root subdirectory (optional, default: public)
# Returns:
#   0 on success, 1 on error
#######################################
site_create() {
    local site_name="$1"
    local php_version="$2"
    local docroot="${3:-public}"

    # Validate inputs
    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow site create <name> <php-version> [docroot]"
        return 1
    fi

    if [ -z "$php_version" ]; then
        log_error "PHP version is required"
        echo "Usage: devflow site create <name> <php-version> [docroot]"
        return 1
    fi

    # Validate site name
    if ! validate_site_name "$site_name"; then
        return 1
    fi

    # Normalize and validate PHP version
    php_version=$(normalize_php_version "$php_version")
    if ! validate_php_version "$php_version"; then
        return 1
    fi

    # Check if site already exists
    if site_exists "$site_name"; then
        log_error "Site already exists: $site_name"
        return 1
    fi

    print_info "Creating site: $site_name"
    echo ""

    # Get configuration
    local websites_root
    websites_root=$(config_get_websites_root)
    local site_path="$websites_root/$site_name"
    local document_root="$site_path/$docroot"

    # Check if PHP version is installed
    if ! check_php_installed "$php_version"; then
        print_warning "PHP $php_version is not installed"
        echo ""
        read -rp "Do you want to install PHP $php_version now? [y/N]: " install_php
        if [[ "$install_php" =~ ^[Yy]$ ]]; then
            if ! install_php_version "$php_version"; then
                log_error "Failed to install PHP $php_version"
                return 1
            fi
        else
            log_error "Cannot create site without PHP $php_version"
            return 1
        fi
    fi

    # Create directory structure
    print_step "Creating directory structure"
    if ! mkdir -p "$document_root"; then
        log_error "Failed to create directory: $document_root"
        return 1
    fi
    print_success "Created: $document_root"

    # Create index.php
    cat > "$document_root/index.php" <<EOF
<?php
phpinfo();
EOF
    print_success "Created: index.php"

    # Set permissions
    print_step "Setting permissions"
    chown -R "$USER:www-data" "$site_path" 2>/dev/null || true
    find "$site_path" -type d -exec chmod 775 {} \; 2>/dev/null || true
    find "$site_path" -type f -exec chmod 664 {} \; 2>/dev/null || true
    print_success "Permissions set"

    # Create Apache vhost
    print_step "Creating Apache virtual host"
    if ! create_vhost "$site_name" "$document_root" "$php_version"; then
        log_error "Failed to create virtual host"
        rm -rf "$site_path"
        return 1
    fi

    # Add to site registry
    print_step "Registering site"
    local site_json
    site_json=$(cat <<EOF
{
  "name": "$site_name",
  "path": "$site_path",
  "document_root": "$document_root",
  "docroot_subdir": "$docroot",
  "php_version": "$php_version",
  "ssl_enabled": false,
  "enabled": true,
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "updated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

    if ! site_add "$site_json"; then
        log_error "Failed to register site"
        sudo a2dissite "${site_name}.conf" >/dev/null 2>&1 || true
        sudo rm -f "/etc/apache2/sites-available/${site_name}.conf"
        rm -rf "$site_path"
        return 1
    fi

    print_success "Site registered"

    # Success message
    echo ""
    print_success "Site created successfully!"
    echo ""
    echo "Site Details:"
    echo "  Name: $site_name"
    echo "  Path: $site_path"
    echo "  Document Root: $document_root"
    echo "  PHP Version: $php_version"
    echo "  URL: http://$site_name"
    echo ""
    echo "Next steps:"
    echo "  1. Add to hosts file:"
    echo "     echo '127.0.0.1 $site_name' | sudo tee -a /etc/hosts"
    echo ""
    echo "  2. Open in browser:"
    echo "     devflow site open $site_name"
    echo ""
    echo "  3. Create SSL certificate (optional):"
    echo "     devflow ssl create $site_name"
    echo ""

    return 0
}

#######################################
# Create Apache virtual host
# Arguments:
#   $1 - Site name
#   $2 - Document root path
#   $3 - PHP version
# Returns:
#   0 on success, 1 on error
#######################################
create_vhost() {
    local site_name="$1"
    local document_root="$2"
    local php_version="$3"

    local vhost_file="/etc/apache2/sites-available/${site_name}.conf"
    local template_file="${DEVFLOW_LIB_DIR}/templates/vhost.conf.template"
    local php_fpm_socket="/run/php/php${php_version}-fpm.sock"

    # Check if template exists
    if [ ! -f "$template_file" ]; then
        log_error "Template not found: $template_file"
        return 1
    fi

    # Read template and substitute variables
    local vhost_content
    vhost_content=$(cat "$template_file")
    vhost_content="${vhost_content//\{\{SITE_NAME\}\}/$site_name}"
    vhost_content="${vhost_content//\{\{DOCUMENT_ROOT\}\}/$document_root}"
    vhost_content="${vhost_content//\{\{PHP_FPM_SOCKET\}\}/$php_fpm_socket}"

    # Write vhost file
    if ! echo "$vhost_content" | sudo tee "$vhost_file" >/dev/null; then
        log_error "Failed to write vhost file"
        return 1
    fi

    print_success "Created vhost: $vhost_file"

    # Test Apache configuration
    print_info "Testing Apache configuration..."
    if ! sudo apachectl configtest 2>&1 | grep -q "Syntax OK"; then
        log_error "Apache configuration test failed"
        sudo rm -f "$vhost_file"
        return 1
    fi
    print_success "Apache configuration OK"

    # Enable site
    if ! sudo a2ensite "${site_name}.conf" >/dev/null 2>&1; then
        log_error "Failed to enable site"
        sudo rm -f "$vhost_file"
        return 1
    fi
    print_success "Site enabled"

    # Reload Apache
    print_info "Reloading Apache..."
    if ! sudo systemctl reload apache2; then
        log_error "Failed to reload Apache"
        sudo a2dissite "${site_name}.conf" >/dev/null 2>&1 || true
        sudo rm -f "$vhost_file"
        return 1
    fi
    print_success "Apache reloaded"

    return 0
}

#######################################
# List all sites
# Returns:
#   0 on success
#######################################
site_list_command() {
    # Get sites from registry using config.sh's site_list function
    # We need to call it explicitly to avoid recursion
    local sites
    if [ ! -f "$DEVFLOW_SITES_FILE" ]; then
        print_info "No sites found"
        echo ""
        echo "Create a site with:"
        echo "  devflow site create myapp.test php8.2"
        return 0
    fi

    sites=$(jq -c '.sites[]' "$DEVFLOW_SITES_FILE" 2>/dev/null || echo "")

    # Check if there are any sites
    local count
    count=$(echo "$sites" | jq -s 'length' 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ]; then
        print_info "No sites found"
        echo ""
        echo "Create a site with:"
        echo "  devflow site create myapp.test php8.2"
        return 0
    fi

    # Print header
    echo ""
    echo "Registered Sites:"
    echo ""
    printf "%-30s %-10s %-10s %-10s\n" "NAME" "PHP" "SSL" "STATUS"
    printf "%-30s %-10s %-10s %-10s\n" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..10})"

    # Print each site
    while IFS= read -r site; do
        local name php_version ssl_enabled enabled
        name=$(echo "$site" | jq -r '.name')
        php_version=$(echo "$site" | jq -r '.php_version')
        ssl_enabled=$(echo "$site" | jq -r '.ssl_enabled')
        enabled=$(echo "$site" | jq -r '.enabled')

        local ssl_status="No"
        [ "$ssl_enabled" = "true" ] && ssl_status="Yes"

        local status="Enabled"
        [ "$enabled" = "false" ] && status="Disabled"

        printf "%-30s %-10s %-10s %-10s\n" "$name" "$php_version" "$ssl_status" "$status"
    done <<< "$sites"

    echo ""
    echo "Total: $count site(s)"
    echo ""

    return 0
}

#######################################
# Delete a site
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
site_delete() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow site delete <name>"
        return 1
    fi

    # Check if site exists
    if ! site_exists "$site_name"; then
        log_error "Site not found: $site_name"
        return 1
    fi

    # Get site information
    local site_info
    site_info=$(site_get "$site_name")
    local site_path
    site_path=$(echo "$site_info" | jq -r '.path')

    # Confirm deletion
    print_warning "This will delete the site and all its files!"
    echo ""
    echo "Site: $site_name"
    echo "Path: $site_path"
    echo ""
    read -rp "Are you sure you want to delete this site? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled"
        return 0
    fi

    print_info "Deleting site: $site_name"
    echo ""

    # Disable and remove Apache vhost
    print_step "Removing Apache virtual host"
    sudo a2dissite "${site_name}.conf" >/dev/null 2>&1 || true
    sudo rm -f "/etc/apache2/sites-available/${site_name}.conf"
    print_success "Virtual host removed"

    # Reload Apache
    print_info "Reloading Apache..."
    sudo systemctl reload apache2 || true
    print_success "Apache reloaded"

    # Remove site directory
    print_step "Removing site files"
    if [ -d "$site_path" ]; then
        rm -rf "$site_path"
        print_success "Files removed: $site_path"
    fi

    # Remove from registry
    print_step "Unregistering site"
    if ! site_delete "$site_name"; then
        print_warning "Failed to unregister site from registry"
    else
        print_success "Site unregistered"
    fi

    echo ""
    print_success "Site deleted successfully!"
    echo ""
    echo "Don't forget to remove from hosts file:"
    echo "  sudo sed -i '/$site_name/d' /etc/hosts"
    echo ""

    return 0
}

#######################################
# Show site information
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
site_info() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow site info <name>"
        return 1
    fi

    # Check if site exists
    if ! site_exists "$site_name"; then
        log_error "Site not found: $site_name"
        return 1
    fi

    # Get site information
    local site_data
    site_data=$(site_get "$site_name")

    # Extract fields
    local name path document_root php_version ssl_enabled enabled created_at
    name=$(echo "$site_data" | jq -r '.name')
    path=$(echo "$site_data" | jq -r '.path')
    document_root=$(echo "$site_data" | jq -r '.document_root')
    php_version=$(echo "$site_data" | jq -r '.php_version')
    ssl_enabled=$(echo "$site_data" | jq -r '.ssl_enabled')
    enabled=$(echo "$site_data" | jq -r '.enabled')
    created_at=$(echo "$site_data" | jq -r '.created_at')

    # Display information
    echo ""
    echo "Site Information: $name"
    echo "$(printf '%.0s=' {1..60})"
    echo ""
    echo "General:"
    echo "  Name:              $name"
    echo "  Status:            $([ "$enabled" = "true" ] && echo "Enabled" || echo "Disabled")"
    echo "  Created:           $created_at"
    echo ""
    echo "Paths:"
    echo "  Site Path:         $path"
    echo "  Document Root:     $document_root"
    echo ""
    echo "Configuration:"
    echo "  PHP Version:       $php_version"
    echo "  SSL Enabled:       $([ "$ssl_enabled" = "true" ] && echo "Yes" || echo "No")"
    echo ""
    echo "URLs:"
    echo "  HTTP:              http://$name"
    [ "$ssl_enabled" = "true" ] && echo "  HTTPS:             https://$name"
    echo ""
    echo "Apache:"
    echo "  Config File:       /etc/apache2/sites-available/${name}.conf"
    echo "  Error Log:         /var/log/apache2/${name}-error.log"
    echo "  Access Log:        /var/log/apache2/${name}-access.log"
    echo ""

    return 0
}

#######################################
# Open site in browser
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
site_open() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow site open <name>"
        return 1
    fi

    # Check if site exists
    if ! site_exists "$site_name"; then
        log_error "Site not found: $site_name"
        return 1
    fi

    # Get site info
    local site_data
    site_data=$(site_get "$site_name")
    local ssl_enabled
    ssl_enabled=$(echo "$site_data" | jq -r '.ssl_enabled')

    # Determine URL
    local url="http://$site_name"
    [ "$ssl_enabled" = "true" ] && url="https://$site_name"

    print_info "Opening: $url"

    # Try different browser opening methods
    if command_exists xdg-open; then
        xdg-open "$url" 2>/dev/null
    elif command_exists wslview; then
        wslview "$url" 2>/dev/null
    elif [ -f /mnt/c/Windows/System32/cmd.exe ]; then
        /mnt/c/Windows/System32/cmd.exe /c start "$url" 2>/dev/null
    else
        print_warning "Could not open browser automatically"
        echo "Please open: $url"
    fi

    return 0
}

#######################################
# Check if PHP version is installed
# Arguments:
#   $1 - PHP version
# Returns:
#   0 if installed, 1 if not
#######################################
check_php_installed() {
    local version="$1"
    local socket="/run/php/php${version}-fpm.sock"

    # Check if PHP-FPM socket exists or service exists
    if [ -S "$socket" ] || systemctl list-units --full --all | grep -q "php${version}-fpm.service"; then
        return 0
    fi

    return 1
}

#######################################
# Install PHP version
# Arguments:
#   $1 - PHP version
# Returns:
#   0 on success, 1 on error
#######################################
install_php_version() {
    local version="$1"

    print_info "Installing PHP $version..."

    # This is a placeholder - actual implementation would go here
    # For now, just show instructions
    echo ""
    echo "To install PHP $version, run:"
    echo "  sudo add-apt-repository ppa:ondrej/php"
    echo "  sudo apt update"
    echo "  sudo apt install php${version}-fpm php${version}-cli php${version}-common"
    echo ""

    return 1
}

#######################################
# Route site subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
site_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        site_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        create)
            site_create "$@"
            ;;
        list|ls)
            site_list_command "$@"
            ;;
        delete|rm|remove)
            site_delete "$@"
            ;;
        info|show)
            site_info "$@"
            ;;
        open)
            site_open "$@"
            ;;
        help|--help|-h)
            site_show_help
            return 0
            ;;
        *)
            log_error "Unknown site command: $subcommand"
            echo ""
            echo "Run 'devflow site --help' for available commands."
            return 1
            ;;
    esac
}
