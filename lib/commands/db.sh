#!/usr/bin/env bash

#######################################
# Database Management Commands
# Manages MySQL/MariaDB databases
#
# Commands:
#   db create    - Create a new database
#   db list      - List all databases
#   db delete    - Delete a database
#   db import    - Import SQL file
#   db export    - Export database to SQL
#   db user      - Manage database users
#######################################

#######################################
# Show database command help
#######################################
db_show_help() {
    cat << 'EOF'
Database Management Commands

Usage:
  devflow db <command> [options] [arguments]

Commands:
  create <name> [user] [password]   Create database with optional user
  list                               List all databases
  delete <name>                      Delete database
  import <name> <file>               Import SQL file into database
  export <name> [file]               Export database to SQL file
  user create <user> <password>     Create database user
  user delete <user>                 Delete database user
  user list                          List all users

Examples:
  # Create database
  devflow db create myapp_db

  # Create database with user
  devflow db create myapp_db myapp_user mypassword

  # List databases
  devflow db list

  # Import SQL file
  devflow db import myapp_db backup.sql

  # Export database
  devflow db export myapp_db backup.sql

  # Create user
  devflow db user create myuser mypassword

  # Delete database
  devflow db delete myapp_db

Notes:
  - Root password may be required for operations
  - User passwords are generated securely if not provided
  - Credentials are stored in ~/.devflow/db-credentials.json
  - Exports are compressed with gzip by default

See also:
  devflow service status mysql     Check database service status

EOF
}

#######################################
# Get MySQL root credentials
# Returns connection string for mysql command
#######################################
get_mysql_creds() {
    # Try without password first (unix socket auth)
    if sudo mysql -e "SELECT 1" >/dev/null 2>&1; then
        echo "sudo mysql"
        return 0
    fi

    # Ask for password
    echo "mysql -u root -p"
    return 0
}

#######################################
# Create database
# Arguments:
#   $1 - Database name
#   $2 - Username (optional)
#   $3 - Password (optional)
# Returns:
#   0 on success, 1 on error
#######################################
db_create() {
    local db_name="$1"
    local db_user="${2:-}"
    local db_pass="${3:-}"

    if [ -z "$db_name" ]; then
        log_error "Database name is required"
        echo "Usage: devflow db create <name> [user] [password]"
        return 1
    fi

    # Validate database name
    if ! validate_db_name "$db_name"; then
        return 1
    fi

    print_info "Creating database: $db_name"
    echo ""

    # Check if database already exists
    local mysql_cmd
    mysql_cmd=$(get_mysql_creds)

    if $mysql_cmd -e "USE $db_name" 2>/dev/null; then
        log_error "Database already exists: $db_name"
        return 1
    fi

    # Create database
    print_step "Creating database"
    if ! $mysql_cmd <<EOF
CREATE DATABASE \`$db_name\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    then
        log_error "Failed to create database"
        return 1
    fi
    print_success "Database created"

    # Create user if specified
    if [ -n "$db_user" ]; then
        print_step "Creating user: $db_user"

        # Generate password if not provided
        if [ -z "$db_pass" ]; then
            db_pass=$(generate_password 16)
            print_info "Generated password: $db_pass"
        fi

        if ! $mysql_cmd <<EOF
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF
        then
            log_error "Failed to create user"
            return 1
        fi
        print_success "User created and granted privileges"

        # Store credentials
        store_db_credentials "$db_name" "$db_user" "$db_pass"
    fi

    echo ""
    print_success "Database created successfully!"
    echo ""
    echo "Database: $db_name"
    if [ -n "$db_user" ]; then
        echo "User: $db_user"
        echo "Password: $db_pass"
        echo ""
        echo "Connection string:"
        echo "  mysql -u $db_user -p$db_pass $db_name"
        echo ""
        echo "Credentials saved to: ~/.devflow/db-credentials.json"
    fi
    echo ""

    return 0
}

#######################################
# List databases
# Returns:
#   0 on success
#######################################
db_list() {
    local mysql_cmd
    mysql_cmd=$(get_mysql_creds)

    print_info "Databases:"
    echo ""

    # Get databases (exclude system databases)
    $mysql_cmd -e "
    SELECT
        SCHEMA_NAME as 'Database',
        DEFAULT_CHARACTER_SET_NAME as 'Charset',
        DEFAULT_COLLATION_NAME as 'Collation',
        ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as 'Size (MB)'
    FROM information_schema.SCHEMATA
    LEFT JOIN information_schema.TABLES ON SCHEMATA.SCHEMA_NAME = TABLES.TABLE_SCHEMA
    WHERE SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY SCHEMA_NAME, DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME
    ORDER BY SCHEMA_NAME;
    " 2>/dev/null || {
        log_error "Failed to list databases"
        return 1
    }

    echo ""
    return 0
}

#######################################
# Delete database
# Arguments:
#   $1 - Database name
# Returns:
#   0 on success, 1 on error
#######################################
db_delete() {
    local db_name="$1"

    if [ -z "$db_name" ]; then
        log_error "Database name is required"
        echo "Usage: devflow db delete <name>"
        return 1
    fi

    # Validate database name
    if ! validate_db_name "$db_name"; then
        return 1
    fi

    local mysql_cmd
    mysql_cmd=$(get_mysql_creds)

    # Check if database exists
    if ! $mysql_cmd -e "USE $db_name" 2>/dev/null; then
        log_error "Database does not exist: $db_name"
        return 1
    fi

    # Confirm deletion
    print_warning "This will permanently delete the database!"
    echo ""
    echo "Database: $db_name"
    echo ""
    read -rp "Are you sure? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled"
        return 0
    fi

    print_info "Deleting database: $db_name"

    if ! $mysql_cmd -e "DROP DATABASE \`$db_name\`;" 2>/dev/null; then
        log_error "Failed to delete database"
        return 1
    fi

    print_success "Database deleted successfully"
    echo ""

    return 0
}

#######################################
# Import SQL file into database
# Arguments:
#   $1 - Database name
#   $2 - SQL file path
# Returns:
#   0 on success, 1 on error
#######################################
db_import() {
    local db_name="$1"
    local sql_file="$2"

    if [ -z "$db_name" ] || [ -z "$sql_file" ]; then
        log_error "Database name and SQL file are required"
        echo "Usage: devflow db import <database> <file>"
        return 1
    fi

    # Check if file exists
    if [ ! -f "$sql_file" ]; then
        log_error "File not found: $sql_file"
        return 1
    fi

    local mysql_cmd
    mysql_cmd=$(get_mysql_creds)

    # Check if database exists
    if ! $mysql_cmd -e "USE $db_name" 2>/dev/null; then
        log_error "Database does not exist: $db_name"
        echo "Create it with: devflow db create $db_name"
        return 1
    fi

    print_info "Importing SQL file into $db_name..."
    echo ""
    echo "File: $sql_file"
    echo "Size: $(du -h "$sql_file" | cut -f1)"
    echo ""

    # Detect if file is compressed
    if [[ "$sql_file" =~ \.gz$ ]]; then
        print_info "Detected gzip compressed file"
        if ! gunzip < "$sql_file" | $mysql_cmd "$db_name"; then
            log_error "Import failed"
            return 1
        fi
    else
        if ! $mysql_cmd "$db_name" < "$sql_file"; then
            log_error "Import failed"
            return 1
        fi
    fi

    echo ""
    print_success "Database imported successfully!"
    echo ""

    return 0
}

#######################################
# Export database to SQL file
# Arguments:
#   $1 - Database name
#   $2 - Output file (optional)
# Returns:
#   0 on success, 1 on error
#######################################
db_export() {
    local db_name="$1"
    local output_file="${2:-}"

    if [ -z "$db_name" ]; then
        log_error "Database name is required"
        echo "Usage: devflow db export <database> [file]"
        return 1
    fi

    # Generate output filename if not provided
    if [ -z "$output_file" ]; then
        output_file="${db_name}_$(date +%Y%m%d_%H%M%S).sql.gz"
    fi

    local mysql_cmd
    mysql_cmd=$(get_mysql_creds)

    # Check if database exists
    if ! $mysql_cmd -e "USE $db_name" 2>/dev/null; then
        log_error "Database does not exist: $db_name"
        return 1
    fi

    print_info "Exporting database: $db_name"
    echo ""
    echo "Output: $output_file"
    echo ""

    # Export database
    local mysqldump_cmd
    if [[ "$mysql_cmd" == "sudo mysql" ]]; then
        mysqldump_cmd="sudo mysqldump"
    else
        mysqldump_cmd="mysqldump"
    fi

    if [[ "$output_file" =~ \.gz$ ]]; then
        print_info "Compressing with gzip..."
        if ! $mysqldump_cmd --single-transaction --quick "$db_name" | gzip > "$output_file"; then
            log_error "Export failed"
            return 1
        fi
    else
        if ! $mysqldump_cmd --single-transaction --quick "$db_name" > "$output_file"; then
            log_error "Export failed"
            return 1
        fi
    fi

    echo ""
    print_success "Database exported successfully!"
    echo ""
    echo "File: $output_file"
    echo "Size: $(du -h "$output_file" | cut -f1)"
    echo ""

    return 0
}

#######################################
# Store database credentials
# Arguments:
#   $1 - Database name
#   $2 - Username
#   $3 - Password
# Returns:
#   0 on success
#######################################
store_db_credentials() {
    local db_name="$1"
    local db_user="$2"
    local db_pass="$3"

    local creds_file="$DEVFLOW_CONFIG_DIR/db-credentials.json"

    # Create file if doesn't exist
    if [ ! -f "$creds_file" ]; then
        echo '{"version":"1.0","credentials":[]}' > "$creds_file"
        chmod 600 "$creds_file"
    fi

    # Read current credentials
    local creds
    creds=$(cat "$creds_file")

    # Add new credential
    local new_cred
    new_cred=$(cat <<EOF
{
  "database": "$db_name",
  "username": "$db_user",
  "password": "$db_pass",
  "host": "localhost",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

    creds=$(echo "$creds" | jq ".credentials += [$new_cred]")

    # Save
    echo "$creds" > "$creds_file"
    chmod 600 "$creds_file"

    return 0
}

#######################################
# Route database subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
db_command() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        db_show_help
        return 0
    fi

    shift || true

    case "$subcommand" in
        create|new)
            db_create "$@"
            ;;
        list|ls)
            db_list "$@"
            ;;
        delete|drop|rm)
            db_delete "$@"
            ;;
        import|restore)
            db_import "$@"
            ;;
        export|dump|backup)
            db_export "$@"
            ;;
        help|--help|-h)
            db_show_help
            return 0
            ;;
        *)
            log_error "Unknown database command: $subcommand"
            echo ""
            echo "Run 'devflow db --help' for available commands."
            return 1
            ;;
    esac
}
