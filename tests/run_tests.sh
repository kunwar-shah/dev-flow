#!/usr/bin/env bash

#######################################
# DevFlow Test Runner
# Runs BATS tests with coverage reporting
#
# Usage:
#   ./tests/run_tests.sh [OPTIONS] [TEST_FILE...]
#
# Options:
#   --unit          Run unit tests only
#   --integration   Run integration tests only
#   --verbose       Verbose output
#   --help          Show help
#
# Examples:
#   # Run all tests
#   ./tests/run_tests.sh
#
#   # Run specific test file
#   ./tests/run_tests.sh tests/unit/core/test_utils.bats
#
#   # Run unit tests only
#   ./tests/run_tests.sh --unit
#######################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default options
RUN_UNIT=true
RUN_INTEGRATION=true
VERBOSE=false
TEST_FILES=()

#######################################
# Print functions
#######################################

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                 ${GREEN}DevFlow Test Runner${NC}                     ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#######################################
# Show help
#######################################
show_help() {
    cat << EOF
DevFlow Test Runner

Usage:
  ./tests/run_tests.sh [OPTIONS] [TEST_FILE...]

Options:
  --unit          Run unit tests only
  --integration   Run integration tests only
  --verbose       Verbose test output
  --help          Show this help message

Examples:
  # Run all tests
  ./tests/run_tests.sh

  # Run unit tests only
  ./tests/run_tests.sh --unit

  # Run specific test file
  ./tests/run_tests.sh tests/unit/core/test_utils.bats

  # Run with verbose output
  ./tests/run_tests.sh --verbose

Requirements:
  - BATS (Bash Automated Testing System)
  - Install with: sudo apt install bats

EOF
}

#######################################
# Parse arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unit)
                RUN_UNIT=true
                RUN_INTEGRATION=false
                shift
                ;;
            --integration)
                RUN_UNIT=false
                RUN_INTEGRATION=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *.bats)
                TEST_FILES+=("$1")
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run './tests/run_tests.sh --help' for usage"
                exit 1
                ;;
        esac
    done
}

#######################################
# Check if BATS is installed
#######################################
check_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        print_error "BATS is not installed"
        echo ""
        echo "Install BATS with:"
        echo "  sudo apt install bats"
        echo ""
        echo "Or from source:"
        echo "  git clone https://github.com/bats-core/bats-core.git"
        echo "  cd bats-core"
        echo "  sudo ./install.sh /usr/local"
        echo ""
        return 1
    fi

    print_success "BATS is installed: $(bats --version)"
    return 0
}

#######################################
# Collect test files
#######################################
collect_tests() {
    local tests=()

    # If specific files provided, use them
    if [ ${#TEST_FILES[@]} -gt 0 ]; then
        tests=("${TEST_FILES[@]}")
    else
        # Collect based on flags
        if [ "$RUN_UNIT" = true ]; then
            while IFS= read -r -d '' file; do
                tests+=("$file")
            done < <(find "$SCRIPT_DIR/unit" -name "*.bats" -print0 2>/dev/null || true)
        fi

        if [ "$RUN_INTEGRATION" = true ]; then
            while IFS= read -r -d '' file; do
                tests+=("$file")
            done < <(find "$SCRIPT_DIR/integration" -name "*.bats" -print0 2>/dev/null || true)
        fi
    fi

    # Return test files
    printf '%s\n' "${tests[@]}"
}

#######################################
# Run tests
#######################################
run_tests() {
    local test_files
    mapfile -t test_files < <(collect_tests)

    if [ ${#test_files[@]} -eq 0 ]; then
        print_error "No test files found"
        return 1
    fi

    print_info "Found ${#test_files[@]} test file(s)"
    echo ""

    local bats_opts=()
    if [ "$VERBOSE" = true ]; then
        bats_opts+=("--verbose" "--print-output-on-failure")
    fi

    # Run BATS
    if bats "${bats_opts[@]}" "${test_files[@]}"; then
        echo ""
        print_success "All tests passed!"
        return 0
    else
        echo ""
        print_error "Some tests failed"
        return 1
    fi
}

#######################################
# Main
#######################################
main() {
    parse_args "$@"

    print_header

    # Check BATS installation
    if ! check_bats; then
        exit 1
    fi

    echo ""

    # Export required variables
    export DEVFLOW_LIB_DIR="$PROJECT_ROOT/lib"

    # Run tests
    if run_tests; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
