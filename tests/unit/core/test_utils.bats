#!/usr/bin/env bats

#######################################
# Unit Tests for lib/core/utils.sh
#######################################

# Load test helper
load ../../test_helper

# Setup
setup() {
    load_devflow_lib "utils"
    setup_test_env
}

# Teardown
teardown() {
    teardown_test_env
}

###############################################################################
# String Utilities Tests
###############################################################################

@test "str_trim removes leading and trailing whitespace" {
    run str_trim "  hello world  "
    assert_success
    assert_equal "hello world" "$output"
}

@test "str_trim handles string with no whitespace" {
    run str_trim "hello"
    assert_success
    assert_equal "hello" "$output"
}

@test "str_lower converts to lowercase" {
    run str_lower "HELLO World"
    assert_success
    assert_equal "hello world" "$output"
}

@test "str_upper converts to uppercase" {
    run str_upper "hello World"
    assert_success
    assert_equal "HELLO WORLD" "$output"
}

@test "str_contains returns 0 when substring found" {
    run str_contains "hello world" "world"
    assert_success
}

@test "str_contains returns 1 when substring not found" {
    run str_contains "hello world" "foo"
    assert_failure
}

###############################################################################
# Array Utilities Tests
###############################################################################

@test "array_contains returns 0 when element found" {
    local arr=("apple" "banana" "cherry")
    run array_contains "banana" "${arr[@]}"
    assert_success
}

@test "array_contains returns 1 when element not found" {
    local arr=("apple" "banana" "cherry")
    run array_contains "orange" "${arr[@]}"
    assert_failure
}

@test "array_join creates comma-separated string" {
    local arr=("a" "b" "c")
    run array_join "," "${arr[@]}"
    assert_success
    assert_equal "a,b,c" "$output"
}

@test "array_join with custom delimiter" {
    local arr=("foo" "bar" "baz")
    run array_join " | " "${arr[@]}"
    assert_success
    assert_equal "foo | bar | baz" "$output"
}

###############################################################################
# File Utilities Tests
###############################################################################

@test "ensure_dir creates directory if not exists" {
    local test_dir="${BATS_TMPDIR}/test-dir-$$"
    run ensure_dir "$test_dir"
    assert_success
    assert_dir_exists "$test_dir"
    rm -rf "$test_dir"
}

@test "ensure_dir succeeds if directory already exists" {
    local test_dir="${BATS_TMPDIR}/test-dir-$$"
    mkdir -p "$test_dir"
    run ensure_dir "$test_dir"
    assert_success
    rm -rf "$test_dir"
}

@test "is_writable returns 0 for writable path" {
    run is_writable "${BATS_TMPDIR}"
    assert_success
}

@test "is_writable returns 1 for non-writable path" {
    skip "Requires testing with non-writable directory"
}

@test "backup_file creates backup with .bak extension" {
    local test_file="${BATS_TMPDIR}/test-file-$$"
    echo "test content" > "$test_file"

    run backup_file "$test_file"
    assert_success
    assert_file_exists "${test_file}.bak"

    rm -f "$test_file" "${test_file}.bak"
}

###############################################################################
# System Utilities Tests
###############################################################################

@test "is_wsl detects WSL environment" {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        run is_wsl
        assert_success
    else
        run is_wsl
        assert_failure
    fi
}

@test "command_exists returns 0 for existing command" {
    run command_exists "bash"
    assert_success
}

@test "command_exists returns 1 for non-existing command" {
    run command_exists "this-command-does-not-exist-12345"
    assert_failure
}

@test "generate_password creates password of specified length" {
    run generate_password 16
    assert_success
    # Check length (base64 output may vary slightly)
    [ ${#output} -ge 16 ]
}

@test "generate_password default length is 32" {
    run generate_password
    assert_success
    [ ${#output} -ge 32 ]
}

###############################################################################
# Confirmation Tests
###############################################################################

@test "confirm returns 0 when user enters 'y'" {
    skip "Interactive test - requires user input"
}

@test "confirm returns 1 when user enters 'n'" {
    skip "Interactive test - requires user input"
}
