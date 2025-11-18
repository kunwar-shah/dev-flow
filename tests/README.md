# DevFlow Tests

This directory contains the test suite for DevFlow using [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core).

## Structure

```
tests/
├── test_helper.bash           # Common test utilities and setup
├── run_tests.sh              # Test runner script
├── unit/                      # Unit tests
│   └── core/                  # Core library tests
│       ├── test_utils.bats
│       ├── test_validator.bats
│       ├── test_config.bats
│       └── test_logger.bats
├── integration/               # Integration tests (future)
└── fixtures/                  # Test fixtures and data (future)
```

## Prerequisites

Install BATS:

```bash
# Ubuntu/Debian
sudo apt install bats

# Or from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Running Tests

### Run All Tests

```bash
./tests/run_tests.sh
```

### Run Specific Test File

```bash
./tests/run_tests.sh tests/unit/core/test_utils.bats
```

### Run Unit Tests Only

```bash
./tests/run_tests.sh --unit
```

### Run with Verbose Output

```bash
./tests/run_tests.sh --verbose
```

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats

# Load test helper
load ../../test_helper

# Setup before each test
setup() {
    load_devflow_lib "utils"
    setup_test_env
}

# Teardown after each test
teardown() {
    teardown_test_env
}

# Test case
@test "function_name does something" {
    run function_name "arg1" "arg2"
    assert_success
    assert_output_contains "expected output"
}
```

### Available Assertions

From `test_helper.bash`:

- `assert_success` - Assert command exited with 0
- `assert_failure` - Assert command exited with non-zero
- `assert_output_contains "text"` - Assert output contains text
- `assert_output_not_contains "text"` - Assert output doesn't contain text
- `assert_file_exists "/path"` - Assert file exists
- `assert_file_not_exists "/path"` - Assert file doesn't exist
- `assert_dir_exists "/path"` - Assert directory exists
- `assert_equal "expected" "actual"` - Assert values are equal

### Test Environment Variables

- `DEVFLOW_TEST_MODE=1` - Indicates test mode
- `DEVFLOW_LIB_DIR` - Path to lib directory
- `DEVFLOW_CONFIG_DIR` - Temporary test config directory
- `BATS_TMPDIR` - BATS temporary directory
- `BATS_TEST_DIRNAME` - Directory containing current test

## Testing Guidelines

### 1. Test Naming

- Use descriptive test names: `@test "validate_site_name rejects uppercase letters"`
- Group related tests together
- Test both success and failure cases

### 2. Test Isolation

- Each test should be independent
- Use `setup()` to create clean environment
- Use `teardown()` to cleanup
- Don't rely on test execution order

### 3. Mock External Dependencies

```bash
# Mock a command
setup() {
    mock_command "apachectl" 0 "Syntax OK"
}

teardown() {
    restore_command "apachectl"
}
```

### 4. Test Coverage Goals

- Core libraries: 80%+ coverage
- Command modules: 70%+ coverage
- Integration tests: Critical paths

## Current Test Status

### ✅ Implemented

- Unit tests for `lib/core/utils.sh`
- Unit tests for `lib/core/validator.sh`
- Test helper utilities
- Test runner script

### ⏳ Pending

- Unit tests for `lib/core/config.sh`
- Unit tests for `lib/core/logger.sh`
- Integration tests for command modules
- End-to-end tests

## Continuous Integration

Tests will run automatically on:
- Pull requests
- Commits to main branch
- Release tags

GitHub Actions workflow (future):

```yaml
- name: Run tests
  run: |
    sudo apt install bats
    ./tests/run_tests.sh
```

## Debugging Failed Tests

### Run Single Test with Verbose Output

```bash
./tests/run_tests.sh --verbose tests/unit/core/test_utils.bats
```

### Run BATS Directly

```bash
bats tests/unit/core/test_utils.bats
```

### Add Debug Output in Tests

```bash
@test "my test" {
    echo "Debug: variable value is $var" >&3
    run my_function
    assert_success
}
```

### Check Test Environment

```bash
@test "show environment" {
    echo "DEVFLOW_LIB_DIR: $DEVFLOW_LIB_DIR" >&3
    echo "DEVFLOW_CONFIG_DIR: $DEVFLOW_CONFIG_DIR" >&3
    echo "BATS_TMPDIR: $BATS_TMPDIR" >&3
}
```

## Contributing

When adding new features:

1. Write tests first (TDD approach recommended)
2. Ensure all tests pass before committing
3. Maintain test coverage above 80% for core libraries
4. Document complex test scenarios
5. Update this README if adding new test patterns

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS GitHub](https://github.com/bats-core/bats-core)
- [Google Shell Style Guide - Testing](https://google.github.io/styleguide/shellguide.html#s7-tests)
