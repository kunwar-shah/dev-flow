#!/usr/bin/env bats

#######################################
# Unit Tests for lib/core/validator.sh
#######################################

# Load test helper
load ../../test_helper

# Setup
setup() {
    load_devflow_lib "utils"
    load_devflow_lib "logger"
    load_devflow_lib "validator"
    setup_test_env
}

# Teardown
teardown() {
    teardown_test_env
}

###############################################################################
# Site Name Validation Tests
###############################################################################

@test "validate_site_name accepts valid site name" {
    run validate_site_name "myapp.test"
    assert_success
}

@test "validate_site_name accepts site with hyphens" {
    run validate_site_name "my-app.test"
    assert_success
}

@test "validate_site_name accepts multi-level domain" {
    run validate_site_name "api.myapp.test"
    assert_success
}

@test "validate_site_name rejects uppercase letters" {
    run validate_site_name "MyApp.test"
    assert_failure
    assert_output_contains "lowercase"
}

@test "validate_site_name rejects site without TLD" {
    run validate_site_name "myapp"
    assert_failure
    assert_output_contains "TLD"
}

@test "validate_site_name rejects site starting with hyphen" {
    run validate_site_name "-myapp.test"
    assert_failure
}

@test "validate_site_name rejects empty name" {
    run validate_site_name ""
    assert_failure
    assert_output_contains "empty"
}

@test "validate_site_name rejects too short name" {
    run validate_site_name "a.b"
    assert_failure
}

@test "validate_site_name rejects special characters" {
    run validate_site_name "my_app.test"
    assert_failure
}

###############################################################################
# PHP Version Validation Tests
###############################################################################

@test "validate_php_version accepts valid version 8.2" {
    run validate_php_version "8.2"
    assert_success
}

@test "validate_php_version accepts version with php prefix" {
    run validate_php_version "php8.2"
    assert_success
}

@test "validate_php_version accepts all supported versions" {
    for version in "7.4" "8.0" "8.1" "8.2" "8.3"; do
        run validate_php_version "$version"
        assert_success
    done
}

@test "validate_php_version rejects invalid version" {
    run validate_php_version "7.3"
    assert_failure
    assert_output_contains "Invalid PHP version"
}

@test "validate_php_version rejects non-numeric version" {
    run validate_php_version "latest"
    assert_failure
}

@test "normalize_php_version removes php prefix" {
    run normalize_php_version "php8.2"
    assert_success
    assert_equal "8.2" "$output"
}

@test "normalize_php_version handles version without prefix" {
    run normalize_php_version "8.2"
    assert_success
    assert_equal "8.2" "$output"
}

###############################################################################
# Path Validation Tests
###############################################################################

@test "validate_path accepts valid path" {
    run validate_path "/home/user/websites"
    assert_success
}

@test "validate_path rejects empty path" {
    run validate_path ""
    assert_failure
    assert_output_contains "empty"
}

@test "validate_path rejects path traversal" {
    run validate_path "/home/user/../etc/passwd"
    assert_failure
    assert_output_contains "path traversal"
}

@test "validate_path rejects null bytes" {
    run validate_path $'/home/user\x00/file'
    assert_failure
    assert_output_contains "null bytes"
}

@test "validate_absolute_path accepts absolute path" {
    run validate_absolute_path "/home/user/file"
    assert_success
}

@test "validate_absolute_path rejects relative path" {
    run validate_absolute_path "relative/path"
    assert_failure
    assert_output_contains "absolute"
}

@test "path_exists returns 0 for existing path" {
    run path_exists "${BATS_TMPDIR}"
    assert_success
}

@test "path_exists returns 1 for non-existing path" {
    run path_exists "/this/path/does/not/exist/12345"
    assert_failure
}

###############################################################################
# Database Name Validation Tests
###############################################################################

@test "validate_db_name accepts valid database name" {
    run validate_db_name "myapp_db"
    assert_success
}

@test "validate_db_name accepts name starting with underscore" {
    run validate_db_name "_test_database"
    assert_success
}

@test "validate_db_name accepts alphanumeric with underscores" {
    run validate_db_name "db123_test_456"
    assert_success
}

@test "validate_db_name rejects name starting with number" {
    run validate_db_name "123db"
    assert_failure
}

@test "validate_db_name rejects name with hyphen" {
    run validate_db_name "my-app-db"
    assert_failure
}

@test "validate_db_name rejects reserved word mysql" {
    run validate_db_name "mysql"
    assert_failure
    assert_output_contains "reserved"
}

@test "validate_db_name rejects reserved word information_schema" {
    run validate_db_name "information_schema"
    assert_failure
}

@test "validate_db_name rejects empty name" {
    run validate_db_name ""
    assert_failure
}

@test "validate_db_name rejects too long name" {
    # Create a 65-character name (max is 64)
    local long_name="$(printf 'a%.0s' {1..65})"
    run validate_db_name "$long_name"
    assert_failure
}

###############################################################################
# System Validation Tests
###############################################################################

@test "check_command succeeds for existing command" {
    run check_command "bash"
    assert_success
}

@test "check_command fails for non-existing command" {
    run check_command "nonexistent-command-12345"
    assert_failure
}

@test "validate_json accepts valid JSON" {
    run validate_json '{"key": "value"}'
    assert_success
}

@test "validate_json rejects invalid JSON" {
    run validate_json '{invalid json}'
    assert_failure
}

@test "validate_json accepts empty object" {
    run validate_json '{}'
    assert_success
}

@test "validate_json accepts array" {
    run validate_json '[1, 2, 3]'
    assert_success
}
