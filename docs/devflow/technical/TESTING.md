# Testing Strategy
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0  
**Date**: 2025-11-13  
**Status**: Draft

---

## 1. Testing Overview

### Test Pyramid
```
           E2E Tests (10%)
         Integration Tests (30%)
       Unit Tests (60%)
```

**Coverage Target**: >80% for core functions

---

## 2. Unit Testing

### Framework: BATS (Bash Automated Testing System)

**Installation**:
```bash
sudo apt install bats
```

**Test Structure**:
```
tests/unit/
├── core/
│   ├── test_config.bats
│   ├── test_logger.bats
│   ├── test_utils.bats
│   └── test_validator.bats
└── commands/
    ├── test_site.bats
    ├── test_php.bats
    └── test_db.bats
```

**Example Test**:
```bash
#!/usr/bin/env bats

setup() {
    source lib/core/utils.sh
}

@test "str_trim removes whitespace" {
    result=$(str_trim "  hello  ")
    [ "$result" = "hello" ]
}

@test "confirm returns 0 for yes" {
    run bash -c 'echo "y" | confirm "Test?"'
    [ "$status" -eq 0 ]
}
```

**Run Tests**:
```bash
bats tests/unit/**/*.bats
```

---

## 3. Integration Testing

**Tests**: End-to-end workflows  
**Location**: `tests/integration/`

**Example**:
```bash
@test "complete site creation workflow" {
    # Setup
    export DEVFLOW_TEST=1
    
    # Create site
    run devflow site create test.local php8.2
    [ "$status" -eq 0 ]
    [ -d "$HOME/websites/test.local" ]
    
    # Verify vhost
    [ -f "/etc/apache2/sites-available/test.local.conf" ]
    
    # Test HTTP
    run curl -s http://test.local
    [ "$status" -eq 0 ]
    
    # Cleanup
    devflow site delete test.local --yes
}
```

---

## 4. Test Coverage

**Measure Coverage**:
```bash
# Using kcov
kcov coverage/ bats tests/
```

**Target**: >80% line coverage

---

## 5. CI/CD Testing

**GitHub Actions** (`.github/workflows/test.yml`):
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: sudo apt install -y bats jq shellcheck
      - run: shellcheck lib/**/*.sh
      - run: bats tests/
```

---

## Document History

| Version | Date       | Author        | Changes           |
|---------|------------|---------------|-------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial testing doc |

