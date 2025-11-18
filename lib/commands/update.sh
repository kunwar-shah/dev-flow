#!/usr/bin/env bash

#######################################
# Update Command
# Updates DevFlow to the latest version
#
# Commands:
#   update check   - Check for updates
#   update install - Install latest version
#   update        - Check and prompt to install
#######################################

GITHUB_REPO="kunwar-shah/dev-flow"
GITHUB_API="https://api.github.com/repos/$GITHUB_REPO"

#######################################
# Show update command help
#######################################
update_show_help() {
    cat << 'EOF'
Update Command

Usage:
  devflow update [command]

Commands:
  check      Check for available updates
  install    Install latest version
  changelog  Show changelog for latest version

Examples:
  # Check for updates
  devflow update check

  # Update to latest version
  devflow update install

  # Show changelog
  devflow update changelog

Notes:
  - Requires internet connection
  - Checks GitHub releases
  - Creates backup before updating
  - Preserves configuration and sites

EOF
}

#######################################
# Check for updates
# Returns:
#   0 if update available, 1 if current
#######################################
update_check() {
    print_info "Checking for updates..."
    echo ""

    # Get current version
    local current_version="$DEVFLOW_VERSION"
    print_info "Current version: $current_version"

    # Get latest release from GitHub
    print_step "Fetching latest release..."
    local latest_release
    if ! latest_release=$(curl -s "$GITHUB_API/releases/latest" 2>/dev/null); then
        log_error "Failed to fetch latest release"
        echo "Check your internet connection or GitHub availability."
        return 1
    fi

    # Parse version
    local latest_version
    latest_version=$(echo "$latest_release" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//')

    if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
        print_warning "No releases found on GitHub"
        return 1
    fi

    print_info "Latest version: $latest_version"
    echo ""

    # Compare versions
    if [ "$current_version" = "$latest_version" ]; then
        print_success "DevFlow is up to date!"
        return 1
    else
        print_warning "Update available: $current_version → $latest_version"
        echo ""

        # Show release notes
        local release_notes
        release_notes=$(echo "$latest_release" | jq -r '.body' 2>/dev/null)

        if [ -n "$release_notes" ] && [ "$release_notes" != "null" ]; then
            echo "Release Notes:"
            echo "$release_notes" | head -n 10
            echo ""
        fi

        echo "Update with:"
        echo "  devflow update install"
        echo ""

        return 0
    fi
}

#######################################
# Install latest version
# Returns:
#   0 on success, 1 on error
#######################################
update_install() {
    print_info "Installing latest DevFlow version..."
    echo ""

    # Check for updates first
    if ! curl -s "$GITHUB_API/releases/latest" >/dev/null 2>&1; then
        log_error "Cannot connect to GitHub"
        return 1
    fi

    local latest_release
    latest_release=$(curl -s "$GITHUB_API/releases/latest")

    local latest_version
    latest_version=$(echo "$latest_release" | jq -r '.tag_name' | sed 's/^v//')

    if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
        log_error "Failed to get latest version"
        return 1
    fi

    # Confirm update
    echo "Current version: $DEVFLOW_VERSION"
    echo "Latest version: $latest_version"
    echo ""
    read -rp "Do you want to update? [Y/n]: " confirm

    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo "Update cancelled"
        return 0
    fi

    echo ""

    # Determine installation directory
    local install_dir
    if [ -w "$DEVFLOW_LIB_DIR/.." ]; then
        install_dir="$DEVFLOW_LIB_DIR/.."
    else
        install_dir="/tmp/devflow-update-$$"
    fi

    # Download latest release
    print_step "Downloading latest version"
    local download_url
    download_url=$(echo "$latest_release" | jq -r '.tarball_url')

    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        # Fallback to archive URL
        download_url="https://github.com/$GITHUB_REPO/archive/refs/heads/main.tar.gz"
    fi

    local temp_file="/tmp/devflow-latest.tar.gz"
    if ! curl -L -o "$temp_file" "$download_url" 2>/dev/null; then
        log_error "Failed to download update"
        return 1
    fi
    print_success "Downloaded"

    # Backup current installation
    print_step "Creating backup"
    local backup_dir="$DEVFLOW_CONFIG_DIR/backup/devflow-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    if [ -d "$DEVFLOW_LIB_DIR" ]; then
        cp -r "$DEVFLOW_LIB_DIR" "$backup_dir/" 2>/dev/null || true
        cp -r "$DEVFLOW_LIB_DIR/../bin" "$backup_dir/" 2>/dev/null || true
    fi
    print_success "Backup created: $backup_dir"

    # Extract update
    print_step "Installing update"
    local extract_dir="/tmp/devflow-extract-$$"
    mkdir -p "$extract_dir"

    if ! tar -xzf "$temp_file" -C "$extract_dir" --strip-components=1 2>/dev/null; then
        log_error "Failed to extract update"
        rm -rf "$extract_dir" "$temp_file"
        return 1
    fi

    # Install files
    if [ "$install_dir" = "$DEVFLOW_LIB_DIR/.." ]; then
        # Update in place
        cp -r "$extract_dir"/lib/* "$DEVFLOW_LIB_DIR/" 2>/dev/null || true
        cp -r "$extract_dir"/bin/* "$DEVFLOW_LIB_DIR/../bin/" 2>/dev/null || true
        chmod +x "$DEVFLOW_LIB_DIR/../bin/devflow"
    else
        # Need sudo for system install
        sudo cp -r "$extract_dir"/lib/* "$DEVFLOW_LIB_DIR/" 2>/dev/null || true
        sudo cp -r "$extract_dir"/bin/* "$DEVFLOW_LIB_DIR/../bin/" 2>/dev/null || true
        sudo chmod +x "$DEVFLOW_LIB_DIR/../bin/devflow"
    fi

    # Cleanup
    rm -rf "$extract_dir" "$temp_file"
    print_success "Update installed"

    echo ""
    print_success "DevFlow updated successfully!"
    echo ""
    echo "Updated to version: $latest_version"
    echo "Backup location: $backup_dir"
    echo ""
    echo "Verify update:"
    echo "  devflow --version"
    echo ""

    return 0
}

#######################################
# Show changelog
# Returns:
#   0 on success
#######################################
update_changelog() {
    print_info "Fetching changelog..."
    echo ""

    local latest_release
    if ! latest_release=$(curl -s "$GITHUB_API/releases/latest" 2>/dev/null); then
        log_error "Failed to fetch changelog"
        return 1
    fi

    local version
    version=$(echo "$latest_release" | jq -r '.tag_name')

    local release_notes
    release_notes=$(echo "$latest_release" | jq -r '.body')

    echo "Changelog for $version:"
    echo "$(printf '%.0s=' {1..60})"
    echo ""

    if [ -n "$release_notes" ] && [ "$release_notes" != "null" ]; then
        echo "$release_notes"
    else
        echo "(No release notes available)"
    fi

    echo ""
    return 0
}

#######################################
# Route update subcommands
# Arguments:
#   All command-line arguments
# Returns:
#   Command exit code
#######################################
update_command() {
    local subcommand="${1:-check}"

    case "$subcommand" in
        check)
            update_check
            ;;
        install|upgrade)
            update_install
            ;;
        changelog|changes)
            update_changelog
            ;;
        help|--help|-h)
            update_show_help
            return 0
            ;;
        *)
            # Default to check
            update_check
            ;;
    esac
}
