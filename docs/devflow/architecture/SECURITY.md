# Security
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft

---

## 1. Security Overview

DevFlow handles sensitive data (database credentials, SSL private keys) and modifies system configuration. This document outlines security measures and best practices.

### 1.1 Security Principles

- **Principle of Least Privilege**: Run with minimum required permissions
- **Defense in Depth**: Multiple layers of security
- **Secure by Default**: Safe defaults out of the box
- **Fail Securely**: Errors don't expose sensitive data
- **No Hardcoded Secrets**: All credentials generated at runtime

---

## 2. File System Security

### 2.1 File Permissions

**Configuration Files**:
```bash
~/.devflow/config.json          # 644 (rw-r--r--)
~/.devflow/sites.json            # 644 (rw-r--r--)
~/.devflow/db-credentials.json   # 600 (rw-------)  # SENSITIVE
```

**SSL Certificates**:
```bash
~/.devflow/ssl/ca/ca.key         # 600 (rw-------)  # SENSITIVE
~/.devflow/ssl/ca/ca.crt         # 644 (rw-r--r--)
~/.devflow/ssl/certs/*/key.pem   # 600 (rw-------)  # SENSITIVE
~/.devflow/ssl/certs/*/cert.pem  # 644 (rw-r--r--)
```

**Site Files**:
```bash
~/websites/site/                 # 775 (rwxrwxr-x) user:www-data
~/websites/site/files/          # 664 (rw-rw-r--) user:www-data
~/websites/site/storage/        # 775 (rwxrwxr-x) user:www-data  # Laravel
```

**Executable Files**:
```bash
/opt/devflow/bin/devflow         # 755 (rwxr-xr-x)
/opt/devflow/lib/**/*.sh         # 644 (rw-r--r--)
```

### 2.2 Directory Access Control

**DevFlow Directories**:
```bash
chmod 700 ~/.devflow                    # Only user can access
chmod 700 ~/.devflow/ssl/ca             # CA private
chmod 755 ~/.devflow/ssl/certs          # Certs readable
chmod 755 ~/websites                    # Sites readable
```

### 2.3 Sensitive File Protection

**Automatic Protection**:
```bash
protect_sensitive_file() {
    local file="$1"
    chmod 600 "$file"
    chown "$USER:$USER" "$file"

    # Verify
    local perms=$(stat -c '%a' "$file")
    if [ "$perms" != "600" ]; then
        log_error "Failed to set permissions on $file"
        return 1
    fi
}
```

---

## 3. Credential Management

### 3.1 Password Generation

**Requirements**:
- Minimum 20 characters
- Alphanumeric + special characters
- Cryptographically secure random

**Implementation**:
```bash
generate_secure_password() {
    # Use /dev/urandom for crypto-grade randomness
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 24
}
```

### 3.2 Credential Storage

**Database Credentials**:
```json
{
  "credentials": [
    {
      "database": "myapp_db",
      "username": "myapp_user",
      "password": "[ENCRYPTED]",
      "created_at": "2025-11-13T14:30:00Z"
    }
  ]
}
```

**Encryption** (optional feature):
```bash
encrypt_credentials() {
    local plaintext="$1"
    local user_password="$2"

    # Use AES-256-CBC
    echo "$plaintext" | openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$user_password"
}
```

### 3.3 Password Display

**Never Log Passwords**:
```bash
# Bad
log_info "Created user with password: $password"

# Good
log_info "Created user: $username"
```

**Mask in Output**:
```bash
display_password() {
    local password="$1"
    local visible_chars=4

    echo "Password: ${password:0:$visible_chars}****** (copied to clipboard)"
}
```

---

## 4. SSL/TLS Security

### 4.1 Certificate Authority

**Root CA Generation**:
```bash
# 4096-bit RSA key
openssl genrsa -out ca.key 4096

# 10-year validity
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt
```

**CA Key Protection**:
- 600 permissions (owner read/write only)
- Stored in user directory (~/.devflow/ssl/ca/)
- Never transmitted
- Backed up separately

### 4.2 Site Certificates

**Certificate Generation**:
```bash
# 2048-bit RSA (sufficient for local dev)
openssl genrsa -out site.key 2048

# Create CSR
openssl req -new -key site.key -out site.csr -subj "/CN=myapp.test"

# Sign with CA
openssl x509 -req -in site.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out site.crt -days 365 -sha256
```

**Certificate Validation**:
```bash
# Verify certificate
openssl x509 -in site.crt -text -noout

# Verify against CA
openssl verify -CAfile ca.crt site.crt
```

### 4.3 Apache SSL Configuration

**Strong SSL Configuration**:
```apache
SSLEngine on
SSLProtocol -all +TLSv1.2 +TLSv1.3
SSLCipherSuite HIGH:!aNULL:!MD5
SSLHonorCipherOrder on
```

---

## 5. Input Validation

### 5.1 Command Injection Prevention

**Dangerous**:
```bash
# NEVER DO THIS
site_name="$1"
eval "mkdir ~/websites/$site_name"  # Command injection!
```

**Safe**:
```bash
# Validate input first
validate_site_name() {
    local name="$1"

    # Only allow safe characters
    if [[ ! "$name" =~ ^[a-z0-9.-]+$ ]]; then
        log_error "Invalid site name: $name"
        return 1
    fi

    return 0
}

# Use quoted variables
mkdir "~/websites/$site_name"
```

### 5.2 Path Traversal Prevention

**Vulnerable**:
```bash
# User provides: ../../etc/passwd
cat "$user_provided_path"  # Could read any file!
```

**Protected**:
```bash
validate_path_safe() {
    local path="$1"
    local base_dir="$2"

    # Resolve to absolute path
    local abs_path=$(realpath -m "$path")

    # Must be within base directory
    if [[ ! "$abs_path" =~ ^"$base_dir" ]]; then
        log_error "Path outside allowed directory: $abs_path"
        return 1
    fi

    # No .. components
    if [[ "$path" == *".."* ]]; then
        log_error "Path contains .. (path traversal attempt)"
        return 1
    fi

    return 0
}
```

### 5.3 SQL Injection Prevention

**Use Parameterized Queries**:
```bash
# Bad
mysql -e "CREATE DATABASE $db_name;"  # SQL injection possible

# Good - validate first
if ! validate_db_name "$db_name"; then
    log_error "Invalid database name"
    return 1
fi

# Use quoted identifier
mysql -e "CREATE DATABASE \`$db_name\`;"
```

---

## 6. Privilege Management

### 6.1 Sudo Usage

**Minimize Sudo**:
- DevFlow runs as regular user
- Sudo only for system operations
- No sudo for normal commands

**Sudo Required For**:
- Apache configuration changes
- Service management (systemctl)
- Package installation
- System-wide file modifications

**Sudo Not Required For**:
- Site file management
- Site creation (in user directory)
- Configuration changes
- Log viewing

### 6.2 Sudo Best Practices

**Explicit Sudo**:
```bash
# Good - explicit sudo for system command
sudo systemctl restart apache2

# Bad - running entire script as root
sudo ./devflow site create myapp.test
```

**Validate Before Sudo**:
```bash
create_apache_vhost() {
    local vhost_content="$1"
    local vhost_file="$2"

    # Validate content first (no sudo)
    validate_apache_config_syntax "$vhost_content" || return 1

    # Only use sudo for write
    echo "$vhost_content" | sudo tee "$vhost_file" > /dev/null
}
```

---

## 7. Apache Security

### 7.1 Vhost Security

**Secure Defaults**:
```apache
<Directory ${DOCROOT}>
    Options -Indexes +FollowSymLinks    # No directory listing
    AllowOverride All                    # .htaccess allowed
    Require all granted                  # Public access
</Directory>

# Deny access to sensitive files
<FilesMatch "^\.env">
    Require all denied
</FilesMatch>

<FilesMatch "^\.git">
    Require all denied
</FilesMatch>
```

### 7.2 PHP Execution Restrictions

**Disable PHP in Uploads** (example for Laravel):
```apache
<Directory ${DOCROOT}/storage/app/public>
    php_flag engine off
</Directory>
```

---

## 8. Database Security

### 8.1 User Privileges

**Principle of Least Privilege**:
```sql
-- Create user with limited privileges
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'secure_password';

-- Grant only necessary privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp_db.* TO 'myapp_user'@'localhost';

-- No GRANT, FILE, SUPER privileges
```

### 8.2 Database Connection Security

**Local Connection Only**:
```bash
# Force localhost connection (Unix socket or 127.0.0.1)
DB_HOST=127.0.0.1  # Not 0.0.0.0 or public IP
```

### 8.3 SQL Dump Security

**Secure Exports**:
```bash
# Set restrictive permissions on dumps
export_database() {
    local db="$1"
    local output="$2"

    mysqldump "$db" > "$output"

    # Protect dump file
    chmod 600 "$output"

    log_info "Database exported to $output (permissions: 600)"
}
```

---

## 9. Backup Security

### 9.1 Backup Encryption

**Encrypt Sensitive Backups**:
```bash
create_encrypted_backup() {
    local site="$1"
    local password="$2"

    tar czf - "$site" | openssl enc -aes-256-cbc -pbkdf2 -pass pass:"$password" > backup.tar.gz.enc
}
```

### 9.2 Backup Storage

**Secure Storage**:
- Backups in user directory: `~/.devflow/backup/`
- Permissions: 700 (directory), 600 (files)
- Optional: Remote encrypted backup

**Do Not Backup**:
- Database credentials (store separately)
- Private keys (user must save CA separately)
- Session data
- Cache files

---

## 10. Logging Security

### 10.1 Sensitive Data in Logs

**Never Log**:
- Passwords
- Database credentials
- Private keys
- Session tokens
- API keys

**Sanitize Log Output**:
```bash
log_command() {
    local command="$1"

    # Mask passwords in logged commands
    local sanitized=$(echo "$command" | sed 's/password=[^ ]*/password=****/g')

    log_info "Executing: $sanitized"
}
```

### 10.2 Log File Permissions

```bash
~/.devflow/logs/devflow.log      # 644 (readable by user)
~/.devflow/logs/error.log        # 644
```

### 10.3 Log Rotation

**Prevent Log File Growth**:
```bash
/etc/logrotate.d/devflow
```
```
/home/*/.devflow/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

---

## 11. Secure Defaults

### 11.1 Configuration Defaults

**Safe Out of the Box**:
```json
{
  "settings": {
    "auto_ssl": false,              // Explicit SSL enablement
    "auto_hosts": false,            // No automatic system changes
    "auto_db": false,               // No automatic DB creation
  },
  "logging": {
    "level": "INFO",                // Not DEBUG (verbose) by default
  },
  "backup": {
    "compress": true,               // Smaller, harder to inspect
    "auto_backup": false            // No surprise backups
  }
}
```

### 11.2 .gitignore

**Prevent Credential Commits**:
```
# DevFlow directories
.devflow/
!.devflow/config.json.example

# Site-specific
.env
.env.*
!.env.example

# Credentials
db-credentials.json
*.key
*.pem

# Backups
*.sql
*.sql.gz
backup/
```

---

## 12. Threat Mitigation

### 12.1 Threat Model

| Threat | Impact | Mitigation |
|--------|--------|------------|
| Credential theft | High | 600 permissions, optional encryption |
| CA key compromise | High | 600 permissions, user directory only |
| Path traversal | Medium | Input validation, realpath checks |
| Command injection | High | Input sanitization, no eval |
| SQL injection | Medium | Input validation, parameterized queries |
| Privilege escalation | High | Minimize sudo, validate before sudo |
| Log information disclosure | Low | Sanitize logs, no sensitive data |

### 12.2 Attack Surface Reduction

**Minimize Exposure**:
- No network listeners (CLI only)
- No remote access features
- Local services only (127.0.0.1)
- User-scoped, not system-wide

**What DevFlow Does NOT Do**:
- Listen on network ports
- Accept remote connections
- Expose services to internet
- Modify system-wide security settings

---

## 13. Security Audit Checklist

### 13.1 Pre-Release Audit

- [ ] All user inputs validated
- [ ] No eval or command substitution on user input
- [ ] All passwords generated securely (20+ chars, crypto-random)
- [ ] All sensitive files have 600 permissions
- [ ] No hardcoded credentials in code
- [ ] No passwords in logs
- [ ] SQL injection prevented
- [ ] Path traversal prevented
- [ ] Sudo minimized and justified
- [ ] SSL certificates properly generated
- [ ] Backup encryption optional but available
- [ ] .gitignore covers all sensitive files

### 13.2 Ongoing Security

- [ ] Regular security updates (apt update)
- [ ] Monitor CVEs for dependencies (jq, openssl, apache, php)
- [ ] Code review for new features
- [ ] User-reported security issues addressed promptly

---

## 14. User Security Guidance

### 14.1 Best Practices for Users

**Do**:
- Use strong passwords for database encryption
- Keep CA private key secure
- Regularly backup CA certificate
- Use SSH keys for git operations
- Keep system updated

**Don't**:
- Commit .env files
- Share database credentials
- Run DevFlow as root
- Expose development sites to internet
- Disable security features

### 14.2 WSL-Specific Security

**Windows File System Access**:
- Don't store credentials on /mnt/c (Windows accessible)
- Keep all DevFlow data in WSL filesystem
- Windows can access WSL files via `\\wsl$\`

**WSL Networking**:
- WSL localhost (127.0.0.1) forwarded to Windows
- Development sites accessible from Windows browser
- Not accessible from external network (safe)

---

## 15. Incident Response

### 15.1 Suspected Credential Compromise

**Steps**:
1. Rotate all database passwords
2. Regenerate SSL certificates
3. Check logs for unauthorized access
4. Review recent site changes
5. Update DevFlow to latest version

**Commands**:
```bash
# Rotate database password
devflow db user update myapp_user --new-password

# Regenerate SSL
devflow ssl renew myapp.test

# Check logs
devflow logs --error --since "1 hour ago"
```

### 15.2 Reporting Security Issues

**Contact**: security@devflow.dev (when available)

**What to Include**:
- Description of vulnerability
- Steps to reproduce
- Impact assessment
- Suggested fix (if any)

**Response Time**: < 48 hours for critical issues

---

## Document History

| Version | Date       | Author        | Changes                    |
|---------|------------|---------------|----------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial security document  |

---

**Document Status**: Draft
**Next Review Date**: Before MVP release
**Approval**: Pending
