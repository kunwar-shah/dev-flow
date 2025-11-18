#!/usr/bin/env bash

#######################################
# Project Migration Commands
# Migrates projects from Windows (/mnt/c) to WSL filesystem
#
# Commands:
#   migrate <source> <sitename>  - Migrate project to WSL
#   migrate scan                 - Scan for projects in /mnt/c
#######################################

#######################################
# Show migrate command help
#######################################
migrate_show_help() {
    cat << 'EOF'
Project Migration Commands

Usage:
  devflow migrate <source> <sitename> [php-version]
  devflow migrate scan [path]

Commands:
  migrate <source> <sitename> [php]  Migrate project from Windows to WSL
  scan [path]                        Scan for projects to migrate

Arguments:
  source        Source directory (e.g., /mnt/c/Projects/myapp)
  sitename      Target site name (e.g., myapp.test)
  php-version   PHP version (default: 8.2)

Examples:
  # Migrate Laravel project
  devflow migrate /mnt/c/Projects/myapp myapp.test php8.2

  # Scan for projects
  devflow migrate scan /mnt/c/Projects

  # Migrate with auto-detection
  devflow migrate /mnt/c/xampp/htdocs/myapp myapp.test

Why Migrate?
  - 10-100x faster I/O performance
  - No Windows Defender interference
  - Better performance with AI coding tools (Claude Code, Copilot)
  - Native Linux filesystem benefits

Notes:
  - Uses rsync for efficient transfer
  - Preserves file permissions and timestamps
  - Excludes node_modules, vendor, .git by default
  - Detects project type (Laravel, WordPress, etc.)
  - Creates database and imports if SQL file found

See also:
  devflow site create     Create new site after migration

EOF
}

#######################################
# Migrate project from Windows to WSL
# Arguments:
#   $1 - Source directory
#   $2 - Site name
#   $3 - PHP version (optional)
# Returns:
#   0 on success, 1 on error
#######################################
migrate_project() {
    local source_dir="$1"
    local site_name="$2"
    local php_version="${3:-8.2}"

    if [ -z "$source_dir" ] || [ -z "$site_name" ]; then
        log_error "Source directory and site name are required"
        echo "Usage: devflow migrate <source> <sitename> [php-version]"
        return 1
    fi

    # Validate source directory
    if [ ! -d "$source_dir" ]; then
        log_error "Source directory not found: $source_dir"
        return 1
    fi

    # Normalize PHP version
    php_version=$(normalize_php_version "$php_version")

    # Validate site name
    if ! validate_site_name "$site_name"; then
        return 1
    fi

    # Check if site already exists
    if site_exists "$site_name"; then
        log_error "Site already exists: $site_name"
        return 1
    fi

    print_info "Migrating project to WSL..."
    echo ""
    echo "Source:      $source_dir"
    echo "Destination: $site_name"
    echo "PHP Version: $php_version"
    echo ""

    # Detect project type
    print_step "Detecting project type"
    local project_type
    project_type=$(detect_project_type "$source_dir")
    print_info "Detected: $project_type"

    # Get document root
    local docroot
    docroot=$(get_project_docroot "$project_type" "$source_dir")
    print_info "Document root: $docroot"

    # Calculate size
    print_step "Calculating project size"
    local source_size
    source_size=$(du -sh "$source_dir" 2>/dev/null | cut -f1 || echo "Unknown")
    print_info "Size: $source_size"

    # Confirm migration
    echo ""
    read -rp "Continue with migration? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "Migration cancelled"
        return 0
    fi

    echo ""

    # Get target directory
    local websites_root
    websites_root=$(config_get_websites_root)
    local target_dir="$websites_root/$site_name"

    # Create target directory
    print_step "Creating target directory"
    if ! mkdir -p "$target_dir"; then
        log_error "Failed to create target directory"
        return 1
    fi
    print_success "Created: $target_dir"

    # Perform rsync
    print_step "Copying files (this may take a while)"
    echo ""

    local rsync_excludes=(
        "--exclude=node_modules/"
        "--exclude=vendor/"
        "--exclude=.git/"
        "--exclude=storage/logs/"
        "--exclude=*.log"
        "--exclude=.env"
        "--exclude=.DS_Store"
    )

    if ! rsync -avh --progress \
        "${rsync_excludes[@]}" \
        "$source_dir/" "$target_dir/"; then
        log_error "Failed to copy files"
        rm -rf "$target_dir"
        return 1
    fi

    echo ""
    print_success "Files copied"

    # Set permissions
    print_step "Setting permissions"
    chown -R "$USER:www-data" "$target_dir" 2>/dev/null || true
    find "$target_dir" -type d -exec chmod 775 {} \; 2>/dev/null || true
    find "$target_dir" -type f -exec chmod 664 {} \; 2>/dev/null || true
    print_success "Permissions set"

    # Project-specific setup
    print_step "Running project-specific setup"
    setup_project "$project_type" "$target_dir"

    # Create site
    print_step "Creating DevFlow site"
    echo ""
    if ! site_create "$site_name" "$php_version" "$docroot"; then
        log_error "Failed to create site"
        print_warning "Files have been copied to: $target_dir"
        print_warning "You can manually create the site later"
        return 1
    fi

    # Check for database dump
    local sql_file
    sql_file=$(find "$target_dir" -maxdepth 2 -name "*.sql" -o -name "*.sql.gz" | head -n 1)

    if [ -n "$sql_file" ]; then
        echo ""
        print_info "Found database dump: $(basename "$sql_file")"
        read -rp "Do you want to import it? [Y/n]: " import_db

        if [[ ! "$import_db" =~ ^[Nn]$ ]]; then
            local db_name="${site_name//./_}_db"
            echo ""
            print_step "Creating database: $db_name"
            if db_create "$db_name"; then
                print_step "Importing database"
                db_import "$db_name" "$sql_file"
            fi
        fi
    fi

    # Final message
    echo ""
    echo "$(printf '%.0s=' {1..60})"
    print_success "Migration completed successfully!"
    echo "$(printf '%.0s=' {1..60})"
    echo ""
    echo "Project migrated to: $target_dir"
    echo "Site URL: http://$site_name"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Add to hosts file:"
    echo "     echo '127.0.0.1 $site_name' | sudo tee -a /etc/hosts"
    echo ""

    if [ "$project_type" = "Laravel" ]; then
        echo "  2. Install Composer dependencies:"
        echo "     cd $target_dir"
        echo "     composer install"
        echo ""
        echo "  3. Copy .env file and generate key:"
        echo "     cp .env.example .env"
        echo "     php artisan key:generate"
        echo ""
    elif [ "$project_type" = "WordPress" ]; then
        echo "  2. Update wp-config.php with new database credentials"
        echo ""
    fi

    echo "  3. Open site:"
    echo "     devflow site open $site_name"
    echo ""

    return 0
}

#######################################
# Detect project type
# Arguments:
#   $1 - Project directory
# Outputs:
#   Project type (Laravel, WordPress, Generic PHP, etc.)
#######################################
detect_project_type() {
    local dir="$1"

    # Laravel
    if [ -f "$dir/artisan" ] && [ -f "$dir/composer.json" ]; then
        echo "Laravel"
        return 0
    fi

    # WordPress
    if [ -f "$dir/wp-config.php" ] || [ -f "$dir/wp-config-sample.php" ]; then
        echo "WordPress"
        return 0
    fi

    # Symfony
    if [ -f "$dir/symfony.lock" ] || [ -f "$dir/bin/console" ]; then
        echo "Symfony"
        return 0
    fi

    # CodeIgniter
    if [ -f "$dir/index.php" ] && [ -d "$dir/application" ]; then
        echo "CodeIgniter"
        return 0
    fi

    # Generic PHP
    if find "$dir" -maxdepth 2 -name "*.php" | head -n 1 >/dev/null; then
        echo "Generic PHP"
        return 0
    fi

    # Static HTML
    if find "$dir" -maxdepth 2 -name "*.html" | head -n 1 >/dev/null; then
        echo "Static HTML"
        return 0
    fi

    echo "Unknown"
}

#######################################
# Get project document root
# Arguments:
#   $1 - Project type
#   $2 - Project directory
# Outputs:
#   Document root subdirectory
#######################################
get_project_docroot() {
    local type="$1"
    local dir="$2"

    case "$type" in
        Laravel)
            echo "public"
            ;;
        WordPress)
            echo "."
            ;;
        Symfony)
            echo "public"
            ;;
        CodeIgniter)
            echo "."
            ;;
        *)
            # Try to detect public directory
            if [ -d "$dir/public" ]; then
                echo "public"
            elif [ -d "$dir/public_html" ]; then
                echo "public_html"
            elif [ -d "$dir/htdocs" ]; then
                echo "htdocs"
            elif [ -d "$dir/web" ]; then
                echo "web"
            else
                echo "."
            fi
            ;;
    esac
}

#######################################
# Setup project-specific configuration
# Arguments:
#   $1 - Project type
#   $2 - Project directory
# Returns:
#   0 on success
#######################################
setup_project() {
    local type="$1"
    local dir="$2"

    case "$type" in
        Laravel)
            # Create storage directories
            mkdir -p "$dir/storage"/{framework/{cache,sessions,views},logs,app/public}
            chmod -R 775 "$dir/storage"
            chmod -R 775 "$dir/bootstrap/cache"
            print_success "Laravel: Created storage directories"
            ;;
        WordPress)
            # Create wp-content uploads directory
            mkdir -p "$dir/wp-content/uploads"
            chmod -R 775 "$dir/wp-content"
            print_success "WordPress: Created uploads directory"
            ;;
        *)
            print_info "No specific setup needed for $type"
            ;;
    esac

    return 0
}

#######################################
# Scan for projects to migrate
# Arguments:
#   $1 - Scan path (optional, default: /mnt/c)
# Returns:
#   0 on success
#######################################
migrate_scan() {
    local scan_path="${1:-/mnt/c}"

    if [ ! -d "$scan_path" ]; then
        log_error "Scan path not found: $scan_path"
        return 1
    fi

    print_info "Scanning for projects in: $scan_path"
    echo "This may take a while..."
    echo ""

    local projects=()

    # Common project locations
    local search_paths=(
        "$scan_path/Projects"
        "$scan_path/xampp/htdocs"
        "$scan_path/laragon/www"
        "$scan_path/Users/*/Documents/Projects"
    )

    for search_path in "${search_paths[@]}"; do
        if [ ! -d "$search_path" ]; then
            continue
        fi

        # Find directories with PHP files
        while IFS= read -r -d '' project_dir; do
            local type
            type=$(detect_project_type "$project_dir")

            if [ "$type" != "Unknown" ]; then
                local size
                size=$(du -sh "$project_dir" 2>/dev/null | cut -f1 || echo "?")
                echo "Found: $project_dir"
                echo "  Type: $type"
                echo "  Size: $size"
                echo ""
                projects+=("$project_dir")
            fi
        done < <(find "$search_path" -maxdepth 2 -type d -print0 2>/dev/null)
    done

    if [ ${#projects[@]} -eq 0 ]; then
        print_info "No projects found"
        return 0
    fi

    echo ""
    echo "Found ${#projects[@]} project(s)"
    echo ""
    echo "To migrate a project:"
    echo "  devflow migrate /path/to/project sitename.test"
    echo ""

    return 0
}

#######################################
# Route migrate subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
migrate_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        migrate_show_help
        return 0
    fi

    case "$subcommand" in
        scan)
            shift || true
            migrate_scan "$@"
            ;;
        help|--help|-h)
            migrate_show_help
            return 0
            ;;
        *)
            # Treat first argument as source directory
            migrate_project "$@"
            ;;
    esac
}
