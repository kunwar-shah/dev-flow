#!/usr/bin/env bash

#######################################
# Backup and Restore Commands
# Backup sites, databases, and configurations
#
# Commands:
#   backup site      - Backup site files
#   backup db        - Backup database
#   backup all       - Backup everything
#   restore site     - Restore site
#   restore db       - Restore database
#   list             - List backups
#######################################

# Backup directory
BACKUP_DIR="$DEVFLOW_CONFIG_DIR/backup"

#######################################
# Show backup command help
#######################################
backup_show_help() {
    cat << 'EOF'
Backup and Restore Commands

Usage:
  devflow backup <command> [options] [arguments]

Commands:
  site <name>              Backup site files
  db <database>            Backup database
  all <sitename>           Backup site + database
  restore site <file>      Restore site from backup
  restore db <file>        Restore database from backup
  list                     List all backups
  clean [days]             Delete old backups

Examples:
  # Backup site
  devflow backup site myapp.test

  # Backup database
  devflow backup db myapp_db

  # Backup everything for a site
  devflow backup all myapp.test

  # List backups
  devflow backup list

  # Restore site
  devflow backup restore site myapp-20250118-143000.tar.gz

  # Restore database
  devflow backup restore db myapp_db-20250118-143000.sql.gz

  # Clean old backups (>30 days)
  devflow backup clean 30

Notes:
  - Backups stored in: ~/.devflow/backup/
  - Automatic compression with gzip
  - Site backups exclude: node_modules, vendor, .git
  - Database backups use mysqldump
  - Timestamps in format: YYYYMMDD-HHMMSS

EOF
}

#######################################
# Backup site files
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
backup_site() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow backup site <name>"
        return 1
    fi

    # Check if site exists
    if ! site_exists "$site_name"; then
        log_error "Site not found: $site_name"
        return 1
    fi

    print_info "Backing up site: $site_name"
    echo ""

    # Get site path
    local site_info
    site_info=$(site_get "$site_name")
    local site_path
    site_path=$(echo "$site_info" | jq -r '.path')

    # Create backup directory
    ensure_dir "$BACKUP_DIR/sites"

    # Generate backup filename
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/sites/${site_name}-${timestamp}.tar.gz"

    print_step "Creating compressed archive"
    echo "  Source: $site_path"
    echo "  Backup: $backup_file"
    echo ""

    # Create tar archive with exclusions
    if ! tar -czf "$backup_file" \
        --exclude='node_modules' \
        --exclude='vendor' \
        --exclude='.git' \
        --exclude='storage/logs' \
        --exclude='*.log' \
        -C "$(dirname "$site_path")" \
        "$(basename "$site_path")" 2>/dev/null; then
        log_error "Failed to create backup"
        return 1
    fi

    print_success "Backup created"

    # Show backup info
    local size
    size=$(du -h "$backup_file" | cut -f1)
    echo ""
    echo "Backup Details:"
    echo "  File: $backup_file"
    echo "  Size: $size"
    echo "  Timestamp: $timestamp"
    echo ""

    return 0
}

#######################################
# Backup database
# Arguments:
#   $1 - Database name
# Returns:
#   0 on success, 1 on error
#######################################
backup_db() {
    local db_name="$1"

    if [ -z "$db_name" ]; then
        log_error "Database name is required"
        echo "Usage: devflow backup db <database>"
        return 1
    fi

    print_info "Backing up database: $db_name"
    echo ""

    # Check if database exists
    local mysql_cmd
    mysql_cmd=$(get_mysql_creds)

    if ! $mysql_cmd -e "USE $db_name" 2>/dev/null; then
        log_error "Database not found: $db_name"
        return 1
    fi

    # Create backup directory
    ensure_dir "$BACKUP_DIR/databases"

    # Generate backup filename
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/databases/${db_name}-${timestamp}.sql.gz"

    print_step "Exporting database"
    echo "  Database: $db_name"
    echo "  Backup: $backup_file"
    echo ""

    # Export database
    local mysqldump_cmd
    if [[ "$mysql_cmd" == "sudo mysql" ]]; then
        mysqldump_cmd="sudo mysqldump"
    else
        mysqldump_cmd="mysqldump"
    fi

    if ! $mysqldump_cmd --single-transaction --quick "$db_name" | gzip > "$backup_file"; then
        log_error "Failed to backup database"
        return 1
    fi

    print_success "Backup created"

    # Show backup info
    local size
    size=$(du -h "$backup_file" | cut -f1)
    echo ""
    echo "Backup Details:"
    echo "  File: $backup_file"
    echo "  Size: $size"
    echo "  Timestamp: $timestamp"
    echo ""

    return 0
}

#######################################
# Backup site and database
# Arguments:
#   $1 - Site name
# Returns:
#   0 on success, 1 on error
#######################################
backup_all() {
    local site_name="$1"

    if [ -z "$site_name" ]; then
        log_error "Site name is required"
        echo "Usage: devflow backup all <sitename>"
        return 1
    fi

    print_info "Backing up site and database: $site_name"
    echo ""

    # Backup site
    if ! backup_site "$site_name"; then
        log_error "Failed to backup site"
        return 1
    fi

    echo ""

    # Try to backup database (use site name with underscores)
    local db_name="${site_name//./_}_db"

    print_step "Checking for database: $db_name"
    local mysql_cmd
    mysql_cmd=$(get_mysql_creds)

    if $mysql_cmd -e "USE $db_name" 2>/dev/null; then
        echo ""
        if ! backup_db "$db_name"; then
            print_warning "Failed to backup database"
        fi
    else
        print_info "No database found with name: $db_name"
    fi

    echo ""
    print_success "Backup completed!"
    echo ""

    return 0
}

#######################################
# Restore site from backup
# Arguments:
#   $1 - Backup file
#   $2 - Target site name (optional)
# Returns:
#   0 on success, 1 on error
#######################################
backup_restore_site() {
    local backup_file="$1"
    local target_name="$2"

    if [ -z "$backup_file" ]; then
        log_error "Backup file is required"
        echo "Usage: devflow backup restore site <file> [target-name]"
        return 1
    fi

    # Check if backup file exists
    if [ ! -f "$backup_file" ]; then
        # Try in backup directory
        if [ -f "$BACKUP_DIR/sites/$backup_file" ]; then
            backup_file="$BACKUP_DIR/sites/$backup_file"
        else
            log_error "Backup file not found: $backup_file"
            return 1
        fi
    fi

    print_warning "This will restore site from backup"
    echo ""
    echo "Backup: $backup_file"
    echo ""
    read -rp "Continue? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Restore cancelled"
        return 0
    fi

    print_info "Restoring site from backup..."
    echo ""

    # Get websites root
    local websites_root
    websites_root=$(config_get_websites_root)

    # Extract archive
    print_step "Extracting backup"
    if ! tar -xzf "$backup_file" -C "$websites_root"; then
        log_error "Failed to extract backup"
        return 1
    fi

    print_success "Site restored"
    echo ""

    return 0
}

#######################################
# Restore database from backup
# Arguments:
#   $1 - Backup file
#   $2 - Target database name (optional)
# Returns:
#   0 on success, 1 on error
#######################################
backup_restore_db() {
    local backup_file="$1"
    local target_db="$2"

    if [ -z "$backup_file" ]; then
        log_error "Backup file is required"
        echo "Usage: devflow backup restore db <file> [target-database]"
        return 1
    fi

    # Check if backup file exists
    if [ ! -f "$backup_file" ]; then
        # Try in backup directory
        if [ -f "$BACKUP_DIR/databases/$backup_file" ]; then
            backup_file="$BACKUP_DIR/databases/$backup_file"
        else
            log_error "Backup file not found: $backup_file"
            return 1
        fi
    fi

    # Extract database name from filename if not provided
    if [ -z "$target_db" ]; then
        target_db=$(basename "$backup_file" | sed 's/-[0-9]\{8\}-[0-9]\{6\}\.sql\.gz$//')
    fi

    print_warning "This will restore database from backup"
    echo ""
    echo "Backup: $backup_file"
    echo "Target Database: $target_db"
    echo ""
    read -rp "Continue? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Restore cancelled"
        return 0
    fi

    print_info "Restoring database from backup..."
    echo ""

    # Import database
    if ! db_import "$target_db" "$backup_file"; then
        log_error "Failed to restore database"
        return 1
    fi

    print_success "Database restored"
    echo ""

    return 0
}

#######################################
# List all backups
# Returns:
#   0 on success
#######################################
backup_list() {
    echo ""
    echo "DevFlow Backups:"
    echo ""

    # Site backups
    echo "Site Backups:"
    echo ""
    if [ -d "$BACKUP_DIR/sites" ] && compgen -G "$BACKUP_DIR/sites/*.tar.gz" >/dev/null 2>&1; then
        printf "%-50s %-15s %s\n" "FILE" "SIZE" "DATE"
        printf "%-50s %-15s %s\n" "$(printf '%.0s-' {1..50})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..20})"

        for backup in "$BACKUP_DIR/sites"/*.tar.gz; do
            local filename size date_modified
            filename=$(basename "$backup")
            size=$(du -h "$backup" | cut -f1)
            date_modified=$(stat -c %y "$backup" | cut -d. -f1)

            printf "%-50s %-15s %s\n" "$filename" "$size" "$date_modified"
        done
    else
        echo "  (none)"
    fi

    echo ""

    # Database backups
    echo "Database Backups:"
    echo ""
    if [ -d "$BACKUP_DIR/databases" ] && compgen -G "$BACKUP_DIR/databases/*.sql.gz" >/dev/null 2>&1; then
        printf "%-50s %-15s %s\n" "FILE" "SIZE" "DATE"
        printf "%-50s %-15s %s\n" "$(printf '%.0s-' {1..50})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..20})"

        for backup in "$BACKUP_DIR/databases"/*.sql.gz; do
            local filename size date_modified
            filename=$(basename "$backup")
            size=$(du -h "$backup" | cut -f1)
            date_modified=$(stat -c %y "$backup" | cut -d. -f1)

            printf "%-50s %-15s %s\n" "$filename" "$size" "$date_modified"
        done
    else
        echo "  (none)"
    fi

    echo ""
    return 0
}

#######################################
# Clean old backups
# Arguments:
#   $1 - Days to keep (default: 30)
# Returns:
#   0 on success
#######################################
backup_clean() {
    local days="${1:-30}"

    print_info "Cleaning backups older than $days days..."
    echo ""

    local deleted=0

    # Clean site backups
    if [ -d "$BACKUP_DIR/sites" ]; then
        while IFS= read -r -d '' backup; do
            print_step "Deleting: $(basename "$backup")"
            rm -f "$backup"
            ((deleted++))
        done < <(find "$BACKUP_DIR/sites" -name "*.tar.gz" -type f -mtime +"$days" -print0 2>/dev/null)
    fi

    # Clean database backups
    if [ -d "$BACKUP_DIR/databases" ]; then
        while IFS= read -r -d '' backup; do
            print_step "Deleting: $(basename "$backup")"
            rm -f "$backup"
            ((deleted++))
        done < <(find "$BACKUP_DIR/databases" -name "*.sql.gz" -type f -mtime +"$days" -print0 2>/dev/null)
    fi

    echo ""
    if [ $deleted -eq 0 ]; then
        print_info "No old backups found"
    else
        print_success "Deleted $deleted backup(s)"
    fi
    echo ""

    return 0
}

#######################################
# Route backup subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
backup_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        backup_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        site)
            backup_site "$@"
            ;;
        db|database)
            backup_db "$@"
            ;;
        all)
            backup_all "$@"
            ;;
        restore)
            local restore_type="${1:-}"
            shift || true

            case "$restore_type" in
                site)
                    backup_restore_site "$@"
                    ;;
                db|database)
                    backup_restore_db "$@"
                    ;;
                *)
                    log_error "Unknown restore type: $restore_type"
                    echo "Usage: devflow backup restore <site|db> <file>"
                    return 1
                    ;;
            esac
            ;;
        list|ls)
            backup_list "$@"
            ;;
        clean)
            backup_clean "$@"
            ;;
        help|--help|-h)
            backup_show_help
            return 0
            ;;
        *)
            log_error "Unknown backup command: $subcommand"
            echo ""
            echo "Run 'devflow backup --help' for available commands."
            return 1
            ;;
    esac
}
