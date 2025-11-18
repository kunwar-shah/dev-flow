# Configuration Templates

This directory contains **default configuration templates** used by DevFlow during installation and initialization.

## Files

### devflow.conf.json
Default configuration template that is copied to `~/.devflow/config.json` when:
- DevFlow is run for the first time
- User runs `devflow config reset`
- User's config file is missing or corrupted

## Template Variables

Configuration files support the following variables that are expanded at runtime:

- `$HOME` - User's home directory
- `$USER` - Current username
- `$DEVFLOW_CONFIG_DIR` - User config directory (default: `~/.devflow`)
- `$DEVFLOW_LIB_DIR` - DevFlow library directory
- `{VERSION}` - PHP version placeholder (e.g., `8.2`)

## How It Works

1. **Installation**: `scripts/install.sh` reads these templates
2. **First Run**: `lib/core/config.sh:config_init()` checks if user config exists
3. **If Missing**: Template is copied and variables are expanded
4. **User Customization**: User can modify `~/.devflow/config.json` safely

## Modifying Defaults

To change default values:
1. Edit [devflow.conf.json](devflow.conf.json)
2. Test with: `devflow config reset` (warning: overwrites user config)
3. Commit changes to repository

## Configuration Structure

```
Project Root (wsl-lamp/)
├── config/                           # Default templates (version controlled)
│   └── devflow.conf.json            # Default config template
│
User Home (~/)
└── .devflow/                         # User runtime config (not in git)
    ├── config.json                   # User's actual config
    ├── sites.json                    # Site registry
    └── db-credentials.json           # Database credentials
```

## See Also

- [lib/core/config.sh](../lib/core/config.sh) - Configuration management implementation
- [.claude.md](../.claude.md) - Project development context
