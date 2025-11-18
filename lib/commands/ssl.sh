#!/usr/bin/env bash

#######################################
# SSL Certificate Management Commands
# Manages SSL certificates and Root CA
#
# Commands:
#   ssl install-ca  - Create and install Root CA
#   ssl create      - Create SSL certificate for site
#   ssl list        - List all certificates
#   ssl delete      - Delete certificate
#   ssl trust       - Trust Root CA in system/browser
#######################################

# SSL Configuration
SSL_CA_DIR="$DEVFLOW_CONFIG_DIR/ssl/ca"
SSL_CERTS_DIR="$DEVFLOW_CONFIG_DIR/ssl/certs"
SSL_CA_DAYS=3650  # 10 years
SSL_CERT_DAYS=825 # 825 days (current browser max)

#######################################
# Show SSL command help
#######################################
ssl_show_help() {
    cat << 'EOF'
SSL Certificate Management Commands

Usage:
  devflow ssl <command> [options] [arguments]

Commands:
  install-ca               Create and install Root CA
  create <sitename>        Create SSL certificate for site
  list                     List all certificates
  delete <sitename>        Delete certificate for site
  trust                    Install Root CA in system trust store
  info <sitename>          Show certificate information

Examples:
  # Install Root CA (first time setup)
  devflow ssl install-ca

  # Create SSL for site
  devflow ssl create myapp.test

  # List certificates
  devflow ssl list

  # Trust Root CA in system
  devflow ssl trust

  # Delete certificate
  devflow ssl delete myapp.test

Notes:
  - Root CA must be installed before creating site certificates
  - Certificates are valid for 825 days
  - Root CA is valid for 10 years
  - Sites are automatically configured with HTTPS vhost

See also:
  devflow site create     Create site (use --ssl for HTTPS)

EOF
}

#######################################
# Install Root CA
# Creates a new self-signed Root CA
# Returns:
#   0 on success, 1 on error
#######################################
ssl_install_ca() {
    print_info "Installing DevFlow Root CA..."
    echo ""

    # Check if CA already exists
    if [ -f "$SSL_CA_DIR/ca.crt" ]; then
        print_warning "Root CA already exists"
        echo ""
        read -rp "Do you want to recreate it? This will invalidate all existing certificates. [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            return 0
        fi
        rm -rf "$SSL_CA_DIR"/*
    fi

    # Create CA directory
    ensure_dir "$SSL_CA_DIR"

    # Generate CA private key
    print_step "Generating Root CA private key"
    if ! openssl genrsa -out "$SSL_CA_DIR/ca.key" 4096 2>/dev/null; then
        log_error "Failed to generate CA private key"
        return 1
    fi
    chmod 600 "$SSL_CA_DIR/ca.key"
    print_success "Private key generated"

    # Generate CA certificate
    print_step "Generating Root CA certificate"
    if ! openssl req -x509 -new -nodes \
        -key "$SSL_CA_DIR/ca.key" \
        -sha256 \
        -days "$SSL_CA_DAYS" \
        -out "$SSL_CA_DIR/ca.crt" \
        -subj "/C=US/ST=State/L=City/O=DevFlow/OU=Development/CN=DevFlow Root CA" \
        2>/dev/null; then
        log_error "Failed to generate CA certificate"
        return 1
    fi
    print_success "Root CA certificate generated"

    # Create serial file
    echo "1000" > "$SSL_CA_DIR/serial"

    echo ""
    print_success "Root CA installed successfully!"
    echo ""
    echo "Root CA location: $SSL_CA_DIR/ca.crt"
    echo "Valid for: $SSL_CA_DAYS days (~10 years)"
    echo ""
    echo "Next steps:"
    echo "  1. Trust the Root CA:"
    echo "     devflow ssl trust"
    echo ""
    echo "  2. Create SSL certificate for site:"
    echo "     devflow ssl create myapp.test"
    echo ""

    return 0
}

#######################################
# Create SSL certificate for site
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
ssl_create() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow ssl create <sitename>"
        return 1
    fi

    # Validate site name
    if ! validate_site_name "$site_name"; then
        return 1
    fi

    # Check if Root CA exists
    if [ ! -f "$SSL_CA_DIR/ca.crt" ]; then
        log_error "Root CA not found"
        echo "Install Root CA first: devflow ssl install-ca"
        return 1
    fi

    # Check if site exists
    if ! site_exists "$site_name"; then
        log_error "Site not found: $site_name"
        echo "Create site first: devflow site create $site_name php8.2"
        return 1
    fi

    print_info "Creating SSL certificate for: $site_name"
    echo ""

    # Create site cert directory
    local cert_dir="$SSL_CERTS_DIR/$site_name"
    ensure_dir "$cert_dir"

    # Generate private key
    print_step "Generating private key"
    if ! openssl genrsa -out "$cert_dir/privkey.pem" 2048 2>/dev/null; then
        log_error "Failed to generate private key"
        return 1
    fi
    chmod 600 "$cert_dir/privkey.pem"
    print_success "Private key generated"

    # Generate CSR
    print_step "Generating certificate signing request"
    if ! openssl req -new \
        -key "$cert_dir/privkey.pem" \
        -out "$cert_dir/cert.csr" \
        -subj "/C=US/ST=State/L=City/O=DevFlow/CN=$site_name" \
        2>/dev/null; then
        log_error "Failed to generate CSR"
        return 1
    fi
    print_success "CSR generated"

    # Create certificate extensions file
    cat > "$cert_dir/cert.ext" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $site_name
DNS.2 = www.$site_name
EOF

    # Sign certificate with Root CA
    print_step "Signing certificate with Root CA"
    local serial
    serial=$(cat "$SSL_CA_DIR/serial")

    if ! openssl x509 -req \
        -in "$cert_dir/cert.csr" \
        -CA "$SSL_CA_DIR/ca.crt" \
        -CAkey "$SSL_CA_DIR/ca.key" \
        -set_serial "$serial" \
        -out "$cert_dir/fullchain.pem" \
        -days "$SSL_CERT_DAYS" \
        -sha256 \
        -extfile "$cert_dir/cert.ext" \
        2>/dev/null; then
        log_error "Failed to sign certificate"
        return 1
    fi
    print_success "Certificate signed"

    # Increment serial
    echo $((serial + 1)) > "$SSL_CA_DIR/serial"

    # Cleanup CSR and extensions file
    rm -f "$cert_dir/cert.csr" "$cert_dir/cert.ext"

    # Create SSL vhost
    print_step "Creating HTTPS virtual host"
    if ! create_ssl_vhost "$site_name"; then
        log_error "Failed to create SSL vhost"
        return 1
    fi

    # Update site registry
    print_step "Updating site registry"
    site_update "$site_name" ".ssl_enabled = true"
    print_success "Site registry updated"

    echo ""
    print_success "SSL certificate created successfully!"
    echo ""
    echo "Certificate: $cert_dir/fullchain.pem"
    echo "Private Key: $cert_dir/privkey.pem"
    echo "Valid for: $SSL_CERT_DAYS days"
    echo ""
    echo "HTTPS URL: https://$site_name"
    echo ""
    echo "If you see certificate warnings, trust the Root CA:"
    echo "  devflow ssl trust"
    echo ""

    return 0
}

#######################################
# Create SSL virtual host
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
create_ssl_vhost() {
    local site_name="$1"

    # Get site info
    local site_info
    site_info=$(site_get "$site_name")
    local document_root
    document_root=$(echo "$site_info" | jq -r '.document_root')
    local php_version
    php_version=$(echo "$site_info" | jq -r '.php_version')

    local vhost_file="/etc/apache2/sites-available/${site_name}-ssl.conf"
    local template_file="${DEVFLOW_LIB_DIR}/templates/vhost-ssl.conf.template"
    local php_fpm_socket="/run/php/php${php_version}-fpm.sock"
    local cert_path="$SSL_CERTS_DIR/$site_name/fullchain.pem"
    local key_path="$SSL_CERTS_DIR/$site_name/privkey.pem"

    # Check if template exists
    if [ ! -f "$template_file" ]; then
        log_error "SSL template not found: $template_file"
        return 1
    fi

    # Read template and substitute variables
    local vhost_content
    vhost_content=$(cat "$template_file")
    vhost_content="${vhost_content//\{\{SITE_NAME\}\}/$site_name}"
    vhost_content="${vhost_content//\{\{DOCUMENT_ROOT\}\}/$document_root}"
    vhost_content="${vhost_content//\{\{PHP_FPM_SOCKET\}\}/$php_fpm_socket}"
    vhost_content="${vhost_content//\{\{SSL_CERT_PATH\}\}/$cert_path}"
    vhost_content="${vhost_content//\{\{SSL_KEY_PATH\}\}/$key_path}"

    # Write vhost file
    if ! echo "$vhost_content" | sudo tee "$vhost_file" >/dev/null; then
        log_error "Failed to write SSL vhost file"
        return 1
    fi

    # Test Apache configuration
    if ! sudo apachectl configtest 2>&1 | grep -q "Syntax OK"; then
        log_error "Apache configuration test failed"
        sudo rm -f "$vhost_file"
        return 1
    fi

    # Enable SSL module
    sudo a2enmod ssl >/dev/null 2>&1 || true

    # Enable site
    if ! sudo a2ensite "${site_name}-ssl.conf" >/dev/null 2>&1; then
        log_error "Failed to enable SSL site"
        sudo rm -f "$vhost_file"
        return 1
    fi

    # Reload Apache
    if ! sudo systemctl reload apache2; then
        log_error "Failed to reload Apache"
        sudo a2dissite "${site_name}-ssl.conf" >/dev/null 2>&1 || true
        sudo rm -f "$vhost_file"
        return 1
    fi

    print_success "SSL vhost created"
    return 0
}

#######################################
# List SSL certificates
# Returns:
#   0 on success
#######################################
ssl_list() {
    echo ""
    echo "SSL Certificates:"
    echo ""

    if [ ! -d "$SSL_CERTS_DIR" ] || [ -z "$(ls -A "$SSL_CERTS_DIR" 2>/dev/null)" ]; then
        print_info "No certificates found"
        echo ""
        echo "Create a certificate with:"
        echo "  devflow ssl create myapp.test"
        return 0
    fi

    printf "%-30s %-12s %-20s %-20s\n" "SITE" "STATUS" "EXPIRES" "VALID DAYS"
    printf "%-30s %-12s %-20s %-20s\n" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..12})" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..20})"

    for cert_dir in "$SSL_CERTS_DIR"/*; do
        if [ ! -d "$cert_dir" ]; then
            continue
        fi

        local site_name
        site_name=$(basename "$cert_dir")
        local cert_file="$cert_dir/fullchain.pem"

        if [ ! -f "$cert_file" ]; then
            continue
        fi

        # Get certificate expiration
        local expiry valid_days status
        expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
        expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
        current_epoch=$(date +%s)
        valid_days=$(( (expiry_epoch - current_epoch) / 86400 ))

        if [ "$valid_days" -lt 0 ]; then
            status="Expired"
        elif [ "$valid_days" -lt 30 ]; then
            status="Expiring Soon"
        else
            status="Valid"
        fi

        printf "%-30s %-12s %-20s %-20s\n" "$site_name" "$status" "$expiry" "$valid_days days"
    done

    echo ""
    return 0
}

#######################################
# Delete SSL certificate
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
ssl_delete() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow ssl delete <sitename>"
        return 1
    fi

    local cert_dir="$SSL_CERTS_DIR/$site_name"

    if [ ! -d "$cert_dir" ]; then
        log_error "Certificate not found for: $site_name"
        return 1
    fi

    print_info "Deleting SSL certificate for: $site_name"
    echo ""

    # Disable SSL vhost
    print_step "Removing SSL virtual host"
    sudo a2dissite "${site_name}-ssl.conf" >/dev/null 2>&1 || true
    sudo rm -f "/etc/apache2/sites-available/${site_name}-ssl.conf"
    print_success "SSL vhost removed"

    # Reload Apache
    sudo systemctl reload apache2 2>/dev/null || true

    # Remove certificate directory
    print_step "Removing certificate files"
    rm -rf "$cert_dir"
    print_success "Certificate files removed"

    # Update site registry
    print_step "Updating site registry"
    site_update "$site_name" ".ssl_enabled = false"
    print_success "Site registry updated"

    echo ""
    print_success "SSL certificate deleted successfully!"
    echo ""

    return 0
}

#######################################
# Trust Root CA
# Installs Root CA in system trust store
# Returns:
#   0 on success, 1 on error
#######################################
ssl_trust() {
    if [ ! -f "$SSL_CA_DIR/ca.crt" ]; then
        log_error "Root CA not found"
        echo "Install Root CA first: devflow ssl install-ca"
        return 1
    fi

    print_info "Installing Root CA in system trust store..."
    echo ""

    # Copy CA to system trust directory
    print_step "Copying Root CA to system"
    if ! sudo cp "$SSL_CA_DIR/ca.crt" /usr/local/share/ca-certificates/devflow-root-ca.crt; then
        log_error "Failed to copy Root CA"
        return 1
    fi
    print_success "Root CA copied"

    # Update CA certificates
    print_step "Updating CA certificates"
    if ! sudo update-ca-certificates >/dev/null 2>&1; then
        log_error "Failed to update CA certificates"
        return 1
    fi
    print_success "CA certificates updated"

    echo ""
    print_success "Root CA trusted in system!"
    echo ""
    echo "For Windows browsers (WSL):"
    echo "  1. Copy CA certificate to Windows:"
    echo "     cp $SSL_CA_DIR/ca.crt /mnt/c/Users/\$USER/Downloads/devflow-ca.crt"
    echo ""
    echo "  2. Open Certificate Manager in Windows:"
    echo "     certmgr.msc"
    echo ""
    echo "  3. Import certificate to 'Trusted Root Certification Authorities'"
    echo ""

    return 0
}

#######################################
# Route SSL subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
ssl_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        ssl_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        install-ca|init)
            ssl_install_ca "$@"
            ;;
        create|new)
            ssl_create "$@"
            ;;
        list|ls)
            ssl_list "$@"
            ;;
        delete|rm|remove)
            ssl_delete "$@"
            ;;
        trust)
            ssl_trust "$@"
            ;;
        help|--help|-h)
            ssl_show_help
            return 0
            ;;
        *)
            log_error "Unknown SSL command: $subcommand"
            echo ""
            echo "Run 'devflow ssl --help' for available commands."
            return 1
            ;;
    esac
}
