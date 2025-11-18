#!/usr/bin/env bash

#######################################
# Logging System
# Provides structured logging with levels
#
# Log Levels:
#   DEBUG - Detailed diagnostic information
#   INFO  - General informational messages
#   WARN  - Warning messages
#   ERROR - Error messages
#
# Features:
# - Console output with colors
# - File output in JSON format
# - Log rotation support
# - Configurable log level
#######################################

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Current log level (default: INFO)
CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Log file
LOG_FILE="${LOG_FILE:-$HOME/.devflow/logs/devflow.log}"

# Colors for console output
if [ -t 1 ] && [ "${DEVFLOW_NO_COLOR:-0}" != "1" ]; then
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[1;33m'
    COLOR_BLUE='\033[0;34m'
    COLOR_CYAN='\033[0;36m'
    COLOR_RESET='\033[0m'
else
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_CYAN=''
    COLOR_RESET=''
fi

#######################################
# Initialize logging system
# Creates log directory and file
# Globals:
#   LOG_FILE
# Returns:
#   0 on success
#######################################
log_init() {
    local log_dir
    log_dir=$(dirname "$LOG_FILE")

    # Create log directory if it doesn't exist
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null || true
    fi

    # Create log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || true
    fi

    return 0
}

#######################################
# Set log level
# Arguments:
#   $1 - Log level (DEBUG, INFO, WARN, ERROR)
# Globals:
#   CURRENT_LOG_LEVEL
# Returns:
#   0 on success, 1 on invalid level
#######################################
log_set_level() {
    local level="$1"

    case "${level^^}" in
        DEBUG)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
            ;;
        INFO)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
        WARN|WARNING)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN
            ;;
        ERROR)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

#######################################
# Generic log function
# Arguments:
#   $1 - Log level (DEBUG, INFO, WARN, ERROR)
#   $2 - Message
#   $3 - Optional context (JSON string)
# Outputs:
#   Log message to console and file
# Returns:
#   0 on success
#######################################
log() {
    local level="$1"
    local message="$2"
    local context="${3:-{}}"

    # Get numeric level
    local level_num
    case "${level^^}" in
        DEBUG) level_num=$LOG_LEVEL_DEBUG ;;
        INFO)  level_num=$LOG_LEVEL_INFO ;;
        WARN)  level_num=$LOG_LEVEL_WARN ;;
        ERROR) level_num=$LOG_LEVEL_ERROR ;;
        *) return 1 ;;
    esac

    # Check if we should log this level
    if [ "$level_num" -lt "$CURRENT_LOG_LEVEL" ]; then
        return 0
    fi

    # Format timestamp
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local display_time
    display_time=$(date +"%Y-%m-%d %H:%M:%S")

    # Console output (unless quiet mode)
    if [ "${DEVFLOW_QUIET:-0}" != "1" ]; then
        case "${level^^}" in
            DEBUG)
                echo -e "${COLOR_CYAN}[DEBUG]${COLOR_RESET} $message"
                ;;
            INFO)
                echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $message"
                ;;
            WARN)
                echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $message"
                ;;
            ERROR)
                echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $message" >&2
                ;;
        esac
    fi

    # File output (JSON format)
    if [ -n "$LOG_FILE" ] && [ -w "$(dirname "$LOG_FILE")" ]; then
        local log_entry
        log_entry=$(jq -n \
            --arg ts "$timestamp" \
            --arg lvl "${level^^}" \
            --arg msg "$message" \
            --argjson ctx "$context" \
            '{timestamp: $ts, level: $lvl, message: $msg, context: $ctx}' 2>/dev/null)

        if [ -n "$log_entry" ]; then
            echo "$log_entry" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi

    return 0
}

#######################################
# Log debug message
# Arguments:
#   $1 - Message
#   $2 - Optional context (JSON)
# Returns:
#   0 on success
#######################################
log_debug() {
    log "DEBUG" "$1" "${2:-{}}"
}

#######################################
# Log info message
# Arguments:
#   $1 - Message
#   $2 - Optional context (JSON)
# Returns:
#   0 on success
#######################################
log_info() {
    log "INFO" "$1" "${2:-{}}"
}

#######################################
# Log warning message
# Arguments:
#   $1 - Message
#   $2 - Optional context (JSON)
# Returns:
#   0 on success
#######################################
log_warn() {
    log "WARN" "$1" "${2:-{}}"
}

#######################################
# Log error message
# Arguments:
#   $1 - Message
#   $2 - Optional context (JSON)
# Returns:
#   0 on success
#######################################
log_error() {
    log "ERROR" "$1" "${2:-{}}"
}

#######################################
# Log success message (INFO level with green checkmark)
# Arguments:
#   $1 - Message
# Outputs:
#   Success message with checkmark
# Returns:
#   0 on success
#######################################
log_success() {
    local message="$1"

    if [ "${DEVFLOW_QUIET:-0}" != "1" ]; then
        echo -e "${COLOR_GREEN}✓${COLOR_RESET} $message"
    fi

    log_info "SUCCESS: $message"
}

#######################################
# Log failure message (ERROR level with X mark)
# Arguments:
#   $1 - Message
# Outputs:
#   Error message with X mark
# Returns:
#   0 on success
#######################################
log_failure() {
    local message="$1"

    echo -e "${COLOR_RED}✗${COLOR_RESET} $message" >&2
    log_error "FAILURE: $message"
}

#######################################
# Rotate log file if it's too large
# Globals:
#   LOG_FILE
# Returns:
#   0 on success
#######################################
log_rotate() {
    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi

    # Get file size in MB
    local size_mb
    size_mb=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1)

    # Rotate if larger than 100MB
    if [ "$size_mb" -gt 100 ]; then
        local timestamp
        timestamp=$(date +"%Y%m%d-%H%M%S")
        mv "$LOG_FILE" "${LOG_FILE}.${timestamp}" 2>/dev/null || true

        # Keep only last 5 rotated logs
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        find "$log_dir" -name "$(basename "$LOG_FILE").*" -type f | \
            sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi

    return 0
}

# Initialize logging on load
log_init
