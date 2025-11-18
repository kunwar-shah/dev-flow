# Implementation Guide
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0  
**Date**: 2025-11-13  
**Status**: Draft

---

## 1. Getting Started

### Prerequisites
- Ubuntu 22.04+ or Debian 11+ (WSL2 or native)
- Bash 4.4+
- Git
- Text editor (VS Code recommended)

### Setup Development Environment
```bash
# Clone repository
git clone https://github.com/your-org/devflow.git
cd devflow

# Install dependencies
sudo apt update
sudo apt install -y jq shellcheck bats apache2

# Make scripts executable
chmod +x bin/devflow
chmod +x scripts/*.sh
```

---

## 2. Project Structure

Follow this structure when implementing:
```
devflow/
├── bin/devflow              # Main entry point - implement first
├── lib/
│   ├── core/               # Core libraries - implement second
│   │   ├── config.sh
│   │   ├── logger.sh
│   │   ├── utils.sh
│   │   └── validator.sh
│   ├── commands/           # Command modules - implement third
│   ├── templates/          # Config templates
│   └── installers/         # Installation scripts
├── scripts/
│   ├── install.sh          # Main installer
│   └── uninstall.sh
└── tests/
    ├── unit/
    └── integration/
```

---

## 3. Implementation Order

### Phase 1, Week 1: Core Infrastructure

**Day 1-2**: Setup & Core Libraries
1. Create `bin/devflow` skeleton
2. Implement `lib/core/config.sh`
3. Implement `lib/core/logger.sh`
4. Write unit tests

**Day 3-4**: Utilities & Validation
1. Implement `lib/core/utils.sh`
2. Implement `lib/core/validator.sh`
3. Write unit tests

**Day 5**: Installation Script
1. Implement `scripts/install.sh`
2. Test on fresh WSL

### Phase 1, Week 2: Site Management

**Day 1-2**: Site Creation
1. Implement `site_create()` in `lib/commands/site.sh`
2. Create Apache vhost template
3. Test manually

**Day 3**: Site Deletion & Listing
1. Implement `site_delete()`
2. Implement `site_list()`
3. Implement `site_info()`

**Day 4-5**: Testing & Polish
1. Write integration tests
2. Fix bugs
3. Improve error messages

---

## 4. Coding Standards

### Bash Style Guide

Follow Google Shell Style Guide:

**Variables**:
```bash
# Constants: UPPERCASE
WEBSITES_ROOT="/home/user/websites"

# Local variables: lowercase
local site_name="myapp.test"

# Function names: snake_case
function my_function() {
    ...
}
```

**Error Handling**:
```bash
# Always check return codes
mkdir "$dir" || return 1

# Use set -euo pipefail
set -euo pipefail

# Handle errors explicitly
if ! validate_input "$input"; then
    log_error "Invalid input"
    return 1
fi
```

**Quoting**:
```bash
# Always quote variables
echo "$variable"
cp "$source" "$dest"

# Use arrays for lists
local files=("file1" "file2" "file3")
for file in "${files[@]}"; do
    echo "$file"
done
```

---

## 5. Testing Guidelines

### Unit Test Example
```bash
#!/usr/bin/env bats

setup() {
    # Setup before each test
    source lib/core/utils.sh
}

@test "str_trim removes whitespace" {
    result=$(str_trim "  hello  ")
    [ "$result" = "hello" ]
}
```

### Integration Test Example
```bash
@test "full site creation workflow" {
    # Setup
    export DEVFLOW_CONFIG_DIR="/tmp/devflow-test"
    mkdir -p "$DEVFLOW_CONFIG_DIR"

    # Test
    run bin/devflow site create test.local php8.2
    [ "$status" -eq 0 ]
    [ -d "$HOME/websites/test.local" ]

    # Cleanup
    bin/devflow site delete test.local --yes
    rm -rf "$DEVFLOW_CONFIG_DIR"
}
```

---

## 6. Configuration Management

### Loading Configuration
```bash
config_load() {
    local config_file="$HOME/.devflow/config.json"

    if [ ! -f "$config_file" ]; then
        config_create_default
        return 0
    fi

    # Validate JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Invalid config file"
        return 1
    fi

    # Cache in memory
    CONFIG_JSON=$(cat "$config_file")
    export CONFIG_JSON
}
```

### Getting Configuration Values
```bash
config_get() {
    local key="$1"
    local default="${2:-}"

    local value=$(echo "$CONFIG_JSON" | jq -r ".$key // empty")

    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}
```

---

## 7. Apache Vhost Generation

```bash
generate_vhost() {
    local site_name="$1"
    local php_version="$2"
    local docroot_sub="$3"

    local site_path="$WEBSITES_ROOT/$site_name"
    local docroot="$site_path/$docroot_sub"
    local vhost_file="/etc/apache2/sites-available/${site_name}.conf"

    # Load template
    local template=$(cat lib/templates/apache-vhost.conf)

    # Replace variables
    template=${template//\$\{SITENAME\}/$site_name}
    template=${template//\$\{DOCROOT\}/$docroot}
    template=${template//\$\{PHPVER\}/php$php_version}

    # Write vhost
    echo "$template" | sudo tee "$vhost_file" > /dev/null
}
```

---

## 8. Error Handling Patterns

### Pattern 1: Early Return
```bash
my_function() {
    # Validate inputs
    validate_input "$1" || return 1

    # Check preconditions
    check_precondition || return 1

    # Do work
    do_something || return 1

    return 0
}
```

### Pattern 2: Rollback on Error
```bash
create_with_rollback() {
    local rollback_actions=()

    # Step 1
    mkdir "$dir" || return 1
    rollback_actions+=("rm -rf $dir")

    # Step 2
    create_file "$file" || {
        execute_rollback "${rollback_actions[@]}"
        return 1
    }
    rollback_actions+=("rm $file")

    # Success - clear rollback
    return 0
}
```

---

## 9. Logging Implementation

```bash
log() {
    local level="$1"
    local message="$2"
    local context="${3:-{}}"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Console output
    case "$level" in
        DEBUG) echo "[DEBUG] $message" ;;
        INFO)  echo "[INFO] $message" ;;
        WARN)  echo -e "\033[33m[WARN]\033[0m $message" ;;
        ERROR) echo -e "\033[31m[ERROR]\033[0m $message" >&2 ;;
    esac

    # File output (JSON)
    local log_entry=$(jq -n \
        --arg ts "$timestamp" \
        --arg lvl "$level" \
        --arg msg "$message" \
        --argjson ctx "$context" \
        '{timestamp: $ts, level: $lvl, message: $msg, context: $ctx}')

    echo "$log_entry" >> "$LOG_FILE"
}
```

---

## 10. Progress Indicators

### Progress Bar
```bash
show_progress() {
    local current="$1"
    local total="$2"

    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    printf "\rProgress: ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%%" "$percent"
}
```

### Spinner
```bash
show_spinner() {
    local pid="$1"
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    while kill -0 "$pid" 2>/dev/null; do
        for i in $(seq 0 9); do
            printf "\r%s %s" "${spin:$i:1}" "$message"
            sleep 0.1
        done
    done
    printf "\r✓ %s\n" "$message"
}
```

---

## 11. Common Patterns

### Pattern: Confirmation Prompt
```bash
confirm() {
    local prompt="$1"
    local default="${2:-N}"

    if [ "$default" = "Y" ]; then
        read -p "$prompt [Y/n]: " response
        response=${response:-Y}
    else
        read -p "$prompt [y/N]: " response
        response=${response:-N}
    fi

    case "$response" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}
```

### Pattern: Safe File Write
```bash
safe_write() {
    local content="$1"
    local file="$2"

    # Write to temp file
    echo "$content" > "${file}.tmp" || return 1

    # Validate if applicable
    validate_file "${file}.tmp" || {
        rm "${file}.tmp"
        return 1
    }

    # Atomic move
    mv "${file}.tmp" "$file"
}
```

---

## 12. Debugging

### Enable Debug Mode
```bash
# Set in config.json
{
    "logging": {
        "level": "DEBUG"
    }
}

# Or via environment variable
export DEVFLOW_DEBUG=1
devflow site create test.local php8.2
```

### Debug Output
```bash
if [ "${DEVFLOW_DEBUG:-0}" = "1" ]; then
    set -x  # Enable command tracing
fi
```

---

## 13. Common Pitfalls

### Pitfall 1: Unquoted Variables
```bash
# Bad
cd $directory

# Good
cd "$directory"
```

### Pitfall 2: Using eval
```bash
# Bad - command injection!
eval "mkdir $user_input"

# Good
mkdir "$user_input"
```

### Pitfall 3: Not Checking Return Codes
```bash
# Bad
mkdir "$dir"
cd "$dir"  # Could fail if mkdir failed!

# Good
mkdir "$dir" || return 1
cd "$dir" || return 1
```

---

## 14. Performance Tips

- Use native bash features over external commands
- Cache parsed JSON
- Batch operations
- Use `[[ ]]` instead of `[ ]`
- Avoid subshells where possible

---

## 15. Release Checklist

Before releasing:
- [ ] All tests passing
- [ ] shellcheck clean
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped
- [ ] Git tag created

---

## Document History

| Version | Date       | Author        | Changes                    |
|---------|------------|---------------|----------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial implementation guide |

