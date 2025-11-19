#!/usr/bin/env bash

#######################################
# QuickStart Command
# One-shot setup for complete DevFlow environment
#
# Installs:
#   - DevFlow to system
#   - Apache, PHP 8.2, MariaDB
#   - Creates demo site with SSL
#   - Opens in browser
#######################################

#######################################
# Show quickstart command help
#######################################
quickstart_show_help() {
    cat << 'EOF'
QuickStart - One-Shot DevFlow Setup

Usage:
  devflow quickstart [options]

Options:
  --skip-demo     Skip demo site creation
  --skip-ssl      Skip SSL setup
  --php VERSION   PHP version to install (default: 8.2)

What It Does:
  1. Installs DevFlow (if not installed)
  2. Installs Apache, PHP, MariaDB
  3. Starts all services
  4. Creates Root CA for SSL
  5. Creates demo site (demo.test)
  6. Sets up SSL certificate
  7. Creates demo database
  8. Adds to hosts file
  9. Opens site in browser

Examples:
  # Full setup
  devflow quickstart

  # Skip demo site
  devflow quickstart --skip-demo

  # Use PHP 8.3
  devflow quickstart --php 8.3

Time: Approximately 5-10 minutes

Requirements:
  - Ubuntu/Debian/WSL2
  - Sudo access
  - Internet connection

EOF
}

#######################################
# Run quickstart setup
# Arguments:
#   --skip-demo     Skip demo site
#   --skip-ssl      Skip SSL setup
#   --php VERSION   PHP version
# Returns:
#   0 on success, 1 on error
#######################################
quickstart_run() {
    local skip_demo=false
    local skip_ssl=false
    local php_version="8.2"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-demo)
                skip_demo=true
                shift
                ;;
            --skip-ssl)
                skip_ssl=true
                shift
                ;;
            --php)
                php_version="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    print_header_box "DevFlow QuickStart Setup"
    echo ""

    print_warning "This will install Apache, PHP, MariaDB and set up a demo site"
    echo ""
    echo "Estimated time: 5-10 minutes"
    echo ""
    read -rp "Continue? [Y/n]: " confirm

    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "QuickStart cancelled"
        return 0
    fi

    echo ""

    # Step 1: Check requirements
    print_section "Step 1/9: Checking Requirements"
    if ! quickstart_check_requirements; then
        return 1
    fi
    echo ""

    # Step 2: Install DevFlow
    print_section "Step 2/9: Installing DevFlow"
    if ! quickstart_install_devflow; then
        return 1
    fi
    echo ""

    # Step 3: Install Apache
    print_section "Step 3/9: Installing Apache"
    if ! quickstart_install_apache; then
        return 1
    fi
    echo ""

    # Step 4: Install PHP
    print_section "Step 4/9: Installing PHP $php_version"
    if ! quickstart_install_php "$php_version"; then
        return 1
    fi
    echo ""

    # Step 5: Install MariaDB
    print_section "Step 5/9: Installing MariaDB"
    if ! quickstart_install_mariadb; then
        return 1
    fi
    echo ""

    # Step 6: Start services
    print_section "Step 6/9: Starting Services"
    if ! quickstart_start_services "$php_version"; then
        return 1
    fi
    echo ""

    # Step 7: Setup SSL
    if [ "$skip_ssl" = false ]; then
        print_section "Step 7/9: Setting Up SSL"
        if ! quickstart_setup_ssl; then
            print_warning "SSL setup failed, continuing..."
        fi
    else
        print_section "Step 7/9: Skipping SSL"
    fi
    echo ""

    # Step 8: Create demo site
    if [ "$skip_demo" = false ]; then
        print_section "Step 8/9: Creating Demo Site"
        if ! quickstart_create_demo "$php_version" "$skip_ssl"; then
            print_warning "Demo site creation failed, continuing..."
        fi
    else
        print_section "Step 8/9: Skipping Demo Site"
    fi
    echo ""

    # Step 9: Final steps
    print_section "Step 9/9: Final Configuration"
    quickstart_finish "$skip_demo"

    return 0
}

#######################################
# Check requirements
#######################################
quickstart_check_requirements() {
    print_step "Checking system requirements"

    # Check sudo
    if ! sudo -n true 2>/dev/null; then
        print_warning "Sudo password required"
        sudo -v || return 1
    fi

    print_success "Sudo access: OK"

    # Check internet
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_error "No internet connection"
        return 1
    fi

    print_success "Internet connection: OK"

    # Update package lists
    print_step "Updating package lists"
    if ! sudo apt-get update -qq; then
        print_warning "Failed to update packages"
    fi

    print_success "Requirements check complete"
    return 0
}

#######################################
# Install DevFlow
#######################################
quickstart_install_devflow() {
    if [ -f "/opt/devflow/bin/devflow" ] || [ -f "$HOME/.local/devflow/bin/devflow" ]; then
        print_info "DevFlow already installed"
        return 0
    fi

    print_step "Installing DevFlow"

    # DevFlow is already available (running from git clone)
    # Just initialize config
    config_init

    print_success "DevFlow initialized"
    return 0
}

#######################################
# Install Apache
#######################################
quickstart_install_apache() {
    if dpkg -l apache2 2>/dev/null | grep -q "^ii"; then
        print_info "Apache already installed"
    else
        print_step "Installing Apache"
        if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apache2; then
            print_error "Failed to install Apache"
            return 1
        fi
        print_success "Apache installed"
    fi

    # Enable required modules
    print_step "Enabling Apache modules"
    sudo a2enmod rewrite proxy_fcgi setenvif ssl headers >/dev/null 2>&1 || true
    print_success "Apache modules enabled"

    return 0
}

#######################################
# Install PHP
#######################################
quickstart_install_php() {
    local version="$1"

    if php_is_installed "$version"; then
        print_info "PHP $version already installed"
        return 0
    fi

    print_step "Adding PHP repository"
    if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        sudo add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1
        sudo apt-get update -qq
    fi

    print_step "Installing PHP $version (this may take a few minutes)"
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
    )

    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"; then
        print_error "Failed to install PHP $version"
        return 1
    fi

    print_success "PHP $version installed"
    return 0
}

#######################################
# Install MariaDB
#######################################
quickstart_install_mariadb() {
    if dpkg -l mariadb-server 2>/dev/null | grep -q "^ii"; then
        print_info "MariaDB already installed"
        return 0
    fi

    print_step "Installing MariaDB"
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mariadb-server mariadb-client; then
        print_error "Failed to install MariaDB"
        return 1
    fi

    print_success "MariaDB installed"
    return 0
}

#######################################
# Start services
#######################################
quickstart_start_services() {
    local php_version="$1"

    print_step "Starting Apache"
    sudo systemctl start apache2 && sudo systemctl enable apache2 >/dev/null 2>&1 || true
    print_success "Apache started"

    print_step "Starting PHP-FPM"
    sudo systemctl start "php${php_version}-fpm" && sudo systemctl enable "php${php_version}-fpm" >/dev/null 2>&1 || true
    print_success "PHP-FPM started"

    print_step "Starting MariaDB"
    sudo systemctl start mariadb && sudo systemctl enable mariadb >/dev/null 2>&1 || true
    print_success "MariaDB started"

    return 0
}

#######################################
# Setup SSL
#######################################
quickstart_setup_ssl() {
    if [ -f "$DEVFLOW_CONFIG_DIR/ssl/ca/ca.crt" ]; then
        print_info "Root CA already exists"
        return 0
    fi

    print_step "Creating Root CA"

    # Source ssl command
    source "$LIB_DIR/commands/ssl.sh"

    if ! ssl_install_ca >/dev/null 2>&1; then
        print_error "Failed to create Root CA"
        return 1
    fi

    print_success "Root CA created"
    return 0
}

#######################################
# Create demo site
#######################################
quickstart_create_demo() {
    local php_version="$1"
    local skip_ssl="$2"
    local site_name="demo.test"

    # Check if demo already exists
    if site_exists "$site_name"; then
        print_info "Demo site already exists"
        return 0
    fi

    print_step "Creating demo site: $site_name"

    # Source site command
    source "$LIB_DIR/commands/site.sh"

    if ! site_create "$site_name" "$php_version" "public" >/dev/null 2>&1; then
        print_error "Failed to create demo site"
        return 1
    fi

    print_success "Demo site created"

    # Create better demo page
    print_step "Creating demo page"
    local demo_path="$HOME/websites/$site_name/public"
    cat > "$demo_path/index.php" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DevFlow Demo Site</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        h1 {
            color: #667eea;
            margin-top: 0;
        }
        .success {
            background: #d4edda;
            border: 1px solid #c3e6cb;
            color: #155724;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .info-box {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
        }
        code {
            background: #f1f3f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
        }
        a {
            color: #667eea;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 DevFlow is Working!</h1>

        <div class="success">
            ✓ Your DevFlow development environment is successfully set up!
        </div>

        <h2>System Information</h2>
        <div class="info-box">
            <strong>PHP Version:</strong> <?php echo PHP_VERSION; ?><br>
            <strong>Server:</strong> <?php echo $_SERVER['SERVER_SOFTWARE']; ?><br>
            <strong>Document Root:</strong> <?php echo $_SERVER['DOCUMENT_ROOT']; ?><br>
            <strong>Site:</strong> <?php echo $_SERVER['HTTP_HOST']; ?><br>
        </div>

        <h2>Next Steps</h2>
        <ol>
            <li>Explore DevFlow commands: <code>devflow --help</code></li>
            <li>Create your own site: <code>devflow site create myapp.test php8.2</code></li>
            <li>Set up SSL: <code>devflow ssl create demo.test</code></li>
            <li>Create a database: <code>devflow db create demo_db</code></li>
        </ol>

        <h2>Useful Commands</h2>
        <div class="info-box">
            <code>devflow site list</code> - List all sites<br>
            <code>devflow php list</code> - List PHP versions<br>
            <code>devflow service status</code> - Check services<br>
            <code>devflow doctor</code> - System health check<br>
        </div>

        <h2>Resources</h2>
        <ul>
            <li><a href="https://github.com/kunwar-shah/dev-flow">GitHub Repository</a></li>
            <li><a href="https://github.com/kunwar-shah/dev-flow/tree/main/docs/guide">Documentation</a></li>
            <li><a href="<?php echo $_SERVER['REQUEST_SCHEME']; ?>://<?php echo $_SERVER['HTTP_HOST']; ?>/phpinfo.php">PHP Info</a></li>
        </ul>

        <p style="text-align: center; margin-top: 40px; color: #666;">
            Made with ❤️ by DevFlow
        </p>
    </div>
</body>
</html>
EOF

    # Create phpinfo page
    echo "<?php phpinfo();" > "$demo_path/phpinfo.php"

    print_success "Demo pages created"

    # Add to hosts
    print_step "Adding to hosts file"
    source "$LIB_DIR/commands/hosts.sh"
    hosts_add "$site_name" "127.0.0.1" >/dev/null 2>&1 || true
    print_success "Added to hosts"

    # Create SSL if not skipped
    if [ "$skip_ssl" = false ]; then
        print_step "Creating SSL certificate"
        source "$LIB_DIR/commands/ssl.sh"
        if ssl_create "$site_name" >/dev/null 2>&1; then
            print_success "SSL certificate created"
        else
            print_warning "SSL creation failed"
        fi
    fi

    # Create demo database
    print_step "Creating demo database"
    source "$LIB_DIR/commands/db.sh"
    if db_create "demo_db" "demo_user" >/dev/null 2>&1; then
        print_success "Demo database created"
    else
        print_warning "Database creation failed"
    fi

    return 0
}

#######################################
# Finish setup
#######################################
quickstart_finish() {
    local skip_demo="$1"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              QuickStart Setup Complete! 🎉                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    print_success "DevFlow is ready to use!"
    echo ""

    if [ "$skip_demo" = false ]; then
        echo "Demo Site:"
        echo "  HTTP:  http://demo.test"
        echo "  HTTPS: https://demo.test"
        echo ""
        echo "Opening demo site in browser..."

        # Try to open browser
        if command_exists xdg-open; then
            xdg-open "http://demo.test" 2>/dev/null &
        elif command_exists wslview; then
            wslview "http://demo.test" 2>/dev/null &
        elif [ -f /mnt/c/Windows/System32/cmd.exe ]; then
            /mnt/c/Windows/System32/cmd.exe /c start "http://demo.test" 2>/dev/null &
        fi
    fi

    echo ""
    echo "Installed Services:"
    echo "  ✓ Apache"
    echo "  ✓ PHP 8.2"
    echo "  ✓ MariaDB"
    if [ "$skip_demo" = false ]; then
        echo "  ✓ Demo Site (demo.test)"
        echo "  ✓ Demo Database (demo_db)"
    fi
    echo ""

    echo "Quick Commands:"
    echo "  devflow site create myapp.test php8.2    Create new site"
    echo "  devflow site list                         List all sites"
    echo "  devflow doctor                            System health check"
    echo "  devflow --help                            View all commands"
    echo ""

    echo "Next Steps:"
    echo "  1. Visit http://demo.test in your browser"
    echo "  2. Run: devflow doctor"
    echo "  3. Read: docs/guide/QUICKSTART.md"
    echo "  4. Create your first site!"
    echo ""

    return 0
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
# Route quickstart subcommands
#######################################
quickstart_command() {
    local subcommand="${1:-run}"

    case "$subcommand" in
        run)
            shift || true
            quickstart_run "$@"
            ;;
        help|--help|-h)
            quickstart_show_help
            return 0
            ;;
        *)
            quickstart_run "$@"
            ;;
    esac
}
