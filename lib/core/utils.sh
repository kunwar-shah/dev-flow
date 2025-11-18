#!/usr/bin/env bash

#######################################
# Utility Functions
# Common helper functions used throughout DevFlow
#
# Functions:
# - String manipulation
# - File operations
# - System information
# - Progress indicators
# - User prompts
#######################################

# Colors (will be set by init)
: "${COLOR_RED:=}"
: "${COLOR_GREEN:=}"
: "${COLOR_YELLOW:=}"
: "${COLOR_BLUE:=}"
: "${COLOR_CYAN:=}"
: "${COLOR_RESET:=}"

#######################################
# Initialize utilities
# Sets up colors if terminal supports them
# Returns:
#   0 on success
#######################################
utils_init() {
    if [ -t 1 ] && [ "${DEVFLOW_NO_COLOR:-0}" != "1" ]; then
        COLOR_RED='\033[0;31m'
        COLOR_GREEN='\033[0;32m'
        COLOR_YELLOW='\033[1;33m'
        COLOR_BLUE='\033[0;34m'
        COLOR_CYAN='\033[0;36m'
        COLOR_RESET='\033[0m'
    fi
    return 0
}

###############################################################################
# STRING UTILITIES
###############################################################################

#######################################
# Trim whitespace from string
# Arguments:
#   $1 - String to trim
# Outputs:
#   Trimmed string
#######################################
str_trim() {
    local str="$1"
    # Remove leading whitespace
    str="${str#"${str%%[![:space:]]*}"}"
    # Remove trailing whitespace
    str="${str%"${str##*[![:space:]]}"}"
    echo "$str"
}

#######################################
# Convert string to lowercase
# Arguments:
#   $1 - String to convert
# Outputs:
#   Lowercase string
#######################################
str_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

#######################################
# Convert string to uppercase
# Arguments:
#   $1 - String to convert
# Outputs:
#   Uppercase string
#######################################
str_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

#######################################
# Check if string contains substring
# Arguments:
#   $1 - Haystack (string to search in)
#   $2 - Needle (string to search for)
# Returns:
#   0 if found, 1 if not found
#######################################
str_contains() {
    [[ "$1" == *"$2"* ]]
}

###############################################################################
# OUTPUT UTILITIES
###############################################################################

#######################################
# Print success message
# Arguments:
#   $1 - Message
# Outputs:
#   Green checkmark + message
#######################################
print_success() {
    if [ "${DEVFLOW_QUIET:-0}" != "1" ]; then
        echo -e "${COLOR_GREEN}✓${COLOR_RESET} $1"
    fi
}

#######################################
# Print error message
# Arguments:
#   $1 - Message
# Outputs:
#   Red X + message to stderr
#######################################
print_error() {
    echo -e "${COLOR_RED}✗${COLOR_RESET} $1" >&2
}

#######################################
# Print warning message
# Arguments:
#   $1 - Message
# Outputs:
#   Yellow warning + message
#######################################
print_warning() {
    if [ "${DEVFLOW_QUIET:-0}" != "1" ]; then
        echo -e "${COLOR_YELLOW}⚠${COLOR_RESET}  $1"
    fi
}

#######################################
# Print info message
# Arguments:
#   $1 - Message
# Outputs:
#   Blue info + message
#######################################
print_info() {
    if [ "${DEVFLOW_QUIET:-0}" != "1" ]; then
        echo -e "${COLOR_BLUE}ℹ${COLOR_RESET}  $1"
    fi
}

###############################################################################
# PROGRESS INDICATORS
###############################################################################

#######################################
# Show progress bar
# Arguments:
#   $1 - Current value
#   $2 - Total value
# Outputs:
#   Progress bar to stdout
#######################################
show_progress() {
    local current=$1
    local total=$2

    if [ "$total" -eq 0 ]; then
        return 0
    fi

    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    printf "\r["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percent"

    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

#######################################
# Show spinner while command runs
# Arguments:
#   $1 - PID of background process
#   $2 - Message to display
# Outputs:
#   Spinning animation with message
#######################################
show_spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(((i + 1) % 10))
        printf "\r%s %s" "${spin:$i:1}" "$message"
        sleep 0.1
    done

    printf "\r✓ %s\n" "$message"
}

###############################################################################
# USER PROMPTS
###############################################################################

#######################################
# Confirmation prompt
# Arguments:
#   $1 - Prompt message
#   $2 - Default value (Y or N, default: N)
# Returns:
#   0 for yes, 1 for no
#######################################
confirm() {
    local prompt="$1"
    local default="${2:-N}"
    local response

    if [ "$default" = "Y" ] || [ "$default" = "y" ]; then
        read -r -p "$prompt [Y/n]: " response
        response=${response:-Y}
    else
        read -r -p "$prompt [y/N]: " response
        response=${response:-N}
    fi

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

###############################################################################
# FILE UTILITIES
###############################################################################

#######################################
# Ensure directory exists
# Arguments:
#   $1 - Directory path
# Returns:
#   0 on success, 1 on error
#######################################
ensure_dir() {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || return 1
    fi

    return 0
}

#######################################
# Backup file with timestamp
# Arguments:
#   $1 - File path
# Returns:
#   0 on success, 1 on error
#######################################
backup_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        return 1
    fi

    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    cp "$file" "${file}.backup-${timestamp}" || return 1

    return 0
}

#######################################
# Check if path is writable
# Arguments:
#   $1 - Path to check
# Returns:
#   0 if writable, 1 if not
#######################################
is_writable() {
    local path="$1"

    if [ -e "$path" ]; then
        [ -w "$path" ]
    else
        # Check parent directory
        local parent
        parent=$(dirname "$path")
        [ -w "$parent" ]
    fi
}

#######################################
# Get file size in human-readable format
# Arguments:
#   $1 - File path
# Outputs:
#   File size (e.g., "1.5M", "234K")
# Returns:
#   0 on success
#######################################
get_file_size() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo "0"
        return 0
    fi

    du -h "$file" 2>/dev/null | cut -f1
}

###############################################################################
# SYSTEM UTILITIES
###############################################################################

#######################################
# Get OS information
# Outputs:
#   OS name and version
# Returns:
#   0 on success
#######################################
get_os_info() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "$NAME $VERSION"
    elif [ -f /etc/lsb-release ]; then
        # shellcheck disable=SC1091
        . /etc/lsb-release
        echo "$DISTRIB_DESCRIPTION"
    else
        uname -s
    fi
}

#######################################
# Check if running in WSL
# Returns:
#   0 if WSL, 1 if not
#######################################
is_wsl() {
    if [ -f /proc/version ]; then
        grep -qi microsoft /proc/version
        return $?
    fi
    return 1
}

#######################################
# Check if systemd is running
# Returns:
#   0 if running, 1 if not
#######################################
is_systemd_running() {
    if [ -d /run/systemd/system ]; then
        return 0
    fi
    return 1
}

#######################################
# Get available disk space
# Arguments:
#   $1 - Path to check
# Outputs:
#   Available space in bytes
# Returns:
#   0 on success
#######################################
get_available_space() {
    local path="$1"

    df -B1 "$path" 2>/dev/null | awk 'NR==2 {print $4}'
}

#######################################
# Get available disk space (human-readable)
# Arguments:
#   $1 - Path to check
# Outputs:
#   Available space (e.g., "10G", "500M")
# Returns:
#   0 on success
#######################################
get_available_space_human() {
    local path="$1"

    df -h "$path" 2>/dev/null | awk 'NR==2 {print $4}'
}

#######################################
# Check if command exists
# Arguments:
#   $1 - Command name
# Returns:
#   0 if exists, 1 if not
#######################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#######################################
# Get current timestamp (ISO 8601)
# Outputs:
#   Timestamp string
# Returns:
#   0 on success
#######################################
timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

#######################################
# Format timestamp for display
# Arguments:
#   $1 - ISO 8601 timestamp
# Outputs:
#   Formatted timestamp
# Returns:
#   0 on success
#######################################
format_timestamp() {
    local ts="$1"
    date -d "$ts" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts"
}

#######################################
# Generate random string
# Arguments:
#   $1 - Length (default: 16)
# Outputs:
#   Random alphanumeric string
# Returns:
#   0 on success
#######################################
generate_random_string() {
    local length="${1:-16}"

    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

#######################################
# Generate secure password
# Arguments:
#   $1 - Length (default: 24)
# Outputs:
#   Random password with special characters
# Returns:
#   0 on success
#######################################
generate_password() {
    local length="${1:-24}"

    tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' < /dev/urandom | head -c "$length"
}

###############################################################################
# ARRAY UTILITIES
###############################################################################

#######################################
# Check if array contains element
# Arguments:
#   $1 - Element to find
#   $@ - Array elements
# Returns:
#   0 if found, 1 if not
#######################################
array_contains() {
    local element="$1"
    shift

    local item
    for item in "$@"; do
        if [ "$item" = "$element" ]; then
            return 0
        fi
    done

    return 1
}

#######################################
# Join array elements with delimiter
# Arguments:
#   $1 - Delimiter
#   $@ - Array elements
# Outputs:
#   Joined string
# Returns:
#   0 on success
#######################################
array_join() {
    local delimiter="$1"
    shift

    local result=""
    local first=1

    for item in "$@"; do
        if [ $first -eq 1 ]; then
            result="$item"
            first=0
        else
            result="${result}${delimiter}${item}"
        fi
    done

    echo "$result"
}

# Initialize on load
utils_init
