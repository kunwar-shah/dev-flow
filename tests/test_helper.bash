#!/usr/bin/env bash

#######################################
# BATS Test Helper
# Common functions and setup for all tests
#######################################

# Test environment setup
export DEVFLOW_TEST_MODE=1
export DEVFLOW_LIB_DIR="${BATS_TEST_DIRNAME}/../lib"
export DEVFLOW_CONFIG_DIR="${BATS_TMPDIR}/devflow-test-$$"

# Load core libraries
load_devflow_lib() {
    local lib="$1"
    # shellcheck source=/dev/null
    source "${DEVFLOW_LIB_DIR}/core/${lib}.sh"
}

# Setup test environment
setup_test_env() {
    # Create test config directory
    mkdir -p "$DEVFLOW_CONFIG_DIR"/{ssl/ca,ssl/certs,logs,backup,tmp}

    # Create test sites file
    echo '{"version":"1.0","sites":[]}' > "$DEVFLOW_CONFIG_DIR/sites.json"

    # Create test config file
    cat > "$DEVFLOW_CONFIG_DIR/config.json" <<EOF
{
  "version": "1.0",
  "settings": {
    "websites_root": "${BATS_TMPDIR}/websites",
    "default_php": "8.2",
    "default_docroot": "public"
  }
}
EOF

    # Create test websites directory
    mkdir -p "${BATS_TMPDIR}/websites"
}

# Cleanup test environment
teardown_test_env() {
    rm -rf "$DEVFLOW_CONFIG_DIR"
    rm -rf "${BATS_TMPDIR}/websites"
}

# Assert functions
assert_success() {
    if [ "$status" -ne 0 ]; then
        echo "Expected success (exit 0), got: $status"
        echo "Output: $output"
        return 1
    fi
}

assert_failure() {
    if [ "$status" -eq 0 ]; then
        echo "Expected failure (exit non-zero), got success"
        echo "Output: $output"
        return 1
    fi
}

assert_output_contains() {
    local expected="$1"
    if [[ ! "$output" =~ $expected ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

assert_output_not_contains() {
    local unexpected="$1"
    if [[ "$output" =~ $unexpected ]]; then
        echo "Expected output NOT to contain: $unexpected"
        echo "Actual output: $output"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "Expected file to exist: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "Expected file NOT to exist: $file"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Expected directory to exist: $dir"
        return 1
    fi
}

assert_equal() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" != "$actual" ]; then
        echo "Expected: $expected"
        echo "Actual: $actual"
        return 1
    fi
}

# Mock commands
mock_command() {
    local cmd="$1"
    local return_code="${2:-0}"
    local output="${3:-}"

    # Create mock script
    cat > "${BATS_TMPDIR}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "$output"
exit $return_code
EOF
    chmod +x "${BATS_TMPDIR}/${cmd}"

    # Add to PATH
    export PATH="${BATS_TMPDIR}:$PATH"
}

# Restore real commands
restore_command() {
    local cmd="$1"
    rm -f "${BATS_TMPDIR}/${cmd}"
}
