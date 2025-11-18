# Command Specifications
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0  
**Date**: 2025-11-13  
**Status**: Draft

---

## Command Design Principles

1. **Intuitive**: Follow git-style subcommand structure
2. **Consistent**: Same patterns across all commands
3. **Safe**: Confirmation for destructive operations
4. **Helpful**: Clear error messages with suggestions

---

## Command Patterns

### Pattern 1: Create Commands
```bash
devflow <resource> create <name> <required-args> [optional-args]
```

**Examples**:
- `devflow site create myapp.test php8.2`
- `devflow db create myapp_db`

### Pattern 2: List Commands
```bash
devflow <resource> list [--filter] [--format]
```

**Examples**:
- `devflow site list`
- `devflow php list`

### Pattern 3: Info Commands
```bash
devflow <resource> info <name>
```

**Examples**:
- `devflow site info myapp.test`

### Pattern 4: Delete Commands
```bash
devflow <resource> delete <name> [--yes]
```

**Examples**:
- `devflow site delete myapp.test`
- `devflow site delete myapp.test --yes` (skip confirmation)

---

## Output Format Standards

### Success Output
```
✓ Operation completed successfully

Details:
  - Key: Value
  - Key: Value

Next steps:
  1. Command to run
  2. Another command
```

### Error Output
```
✗ Error: Operation failed

Reason: Explanation of what went wrong

How to fix:
  1. Try this command
  2. Or this command

Run 'devflow help <command>' for more information
```

### Table Output
```
NAME           VERSION  STATUS   SSL
myapp.test    8.2      active   ✓
old.test      7.4      active   ✗
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Permission denied |
| 4 | Not found |
| 5 | Already exists |

---

## Document History

| Version | Date       | Author        | Changes              |
|---------|------------|---------------|----------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial command spec |

