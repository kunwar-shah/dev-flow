# Acceptance Criteria
## DevFlow - Laragon-style Development Environment for WSL/Linux

**Version**: 1.0
**Date**: 2025-11-13
**Status**: Draft

---

## 1. Introduction

This document defines the acceptance criteria for DevFlow features and releases. Each criterion must be met for the feature/release to be considered complete.

---

## 2. MVP (Phase 1) Acceptance Criteria

### 2.1 Installation & Setup

**AC-001: One-Command Installation**
- [ ] Installation completes with single command
- [ ] Installation takes < 5 minutes on fresh Ubuntu WSL
- [ ] All dependencies auto-installed
- [ ] `devflow` command available after install
- [ ] No errors during installation
- [ ] Success message displayed with next steps

**AC-002: System Requirements Check**
- [ ] Installer checks OS version (Ubuntu 22.04+)
- [ ] Installer checks for systemd
- [ ] Installer checks available disk space (>10GB)
- [ ] Clear error messages if requirements not met
- [ ] Suggestions provided for missing requirements

### 2.2 Site Management

**AC-003: Site Creation**
- [ ] `devflow site create myapp.test php8.2` creates working site
- [ ] Command completes in < 30 seconds
- [ ] Directory created at `~/websites/myapp.test/public`
- [ ] Apache vhost created and enabled
- [ ] Site accessible at `http://myapp.test`
- [ ] Permissions set correctly (user:www-data, 775/664)
- [ ] Site added to registry
- [ ] Success message shows URL and next steps

**AC-004: Site Deletion**
- [ ] `devflow site delete myapp.test` removes site
- [ ] Confirmation prompt shown before deletion
- [ ] Apache vhost disabled and removed
- [ ] Files deleted (after confirmation)
- [ ] Site removed from registry
- [ ] Apache reloads without errors
- [ ] Summary of actions displayed

**AC-005: Site Listing**
- [ ] `devflow site list` shows all sites
- [ ] Table displays: name, PHP version, status, SSL, path
- [ ] Sites sorted alphabetically
- [ ] Total count displayed
- [ ] Empty list handled gracefully
- [ ] Output fits standard terminal width

**AC-006: Site Information**
- [ ] `devflow site info myapp.test` shows complete details
- [ ] Displays: URL, path, PHP version, document root
- [ ] Shows SSL status
- [ ] Shows database information (if configured)
- [ ] Shows disk usage
- [ ] Shows creation date
- [ ] Shows recent error count
- [ ] Clear "site not found" error if invalid name

### 2.3 PHP Management

**AC-007: PHP Installation**
- [ ] `devflow php install 8.2` installs PHP 8.2
- [ ] PHP-FPM and CLI both installed
- [ ] Common extensions installed (mbstring, xml, mysql, curl, zip, gd)
- [ ] PHP-FPM service starts automatically
- [ ] Socket created at `/run/php/php8.2-fpm.sock`
- [ ] Installation progress shown
- [ ] Success message with PHP version confirmation

**AC-008: PHP Version Listing**
- [ ] `devflow php list` shows installed versions
- [ ] Shows CLI default version (marked)
- [ ] Shows FPM status for each version
- [ ] Shows site count for each version
- [ ] Handles no installed versions gracefully

**AC-009: PHP CLI Switch**
- [ ] `devflow php switch 8.2` changes default
- [ ] `php -v` shows new version after switch
- [ ] Change persists in new terminal sessions
- [ ] Confirmation message displayed
- [ ] Error if version not installed

### 2.4 Service Management

**AC-010: Service Status Display**
- [ ] `devflow service status` shows all services
- [ ] Displays: service name, status, uptime, memory
- [ ] Color-coded (green=running, red=stopped)
- [ ] Shows ports in use
- [ ] Shows auto-start status
- [ ] Updates reflect current system state

**AC-011: Service Control**
- [ ] `devflow service restart apache2` restarts Apache
- [ ] `devflow service stop php8.2-fpm` stops PHP-FPM
- [ ] `devflow service start all` starts all services
- [ ] Operations complete without errors
- [ ] Status changes reflected immediately
- [ ] Confirmation messages clear

### 2.5 Project Migration

**AC-012: Migration from /mnt**
- [ ] `devflow migrate /mnt/c/Projects/app app.test` works
- [ ] Dry-run preview shown first
- [ ] User must confirm before transfer
- [ ] Files transferred successfully
- [ ] Git history preserved
- [ ] Permissions fixed automatically
- [ ] Excludes node_modules, vendor
- [ ] Progress bar shown for large transfers
- [ ] Offers to create vhost
- [ ] Offers to create database
- [ ] Displays next steps after migration

---

## 3. Phase 2 Acceptance Criteria

### 3.1 SSL Management

**AC-013: Root CA Installation**
- [ ] `devflow ssl install-ca` creates root CA
- [ ] Private key created with 600 permissions
- [ ] Root certificate created
- [ ] Saved to `~/.devflow/ssl/ca/`
- [ ] Browser trust instructions displayed
- [ ] Platform-specific instructions (Windows, Linux)
- [ ] Instructions for Chrome, Firefox, Edge

**AC-014: Site SSL Enablement**
- [ ] `devflow ssl create myapp.test` enables HTTPS
- [ ] Creates root CA if not exists
- [ ] Generates private key for site
- [ ] Generates CSR
- [ ] Signs certificate with root CA
- [ ] Creates Apache SSL vhost
- [ ] Site accessible at `https://myapp.test`
- [ ] Certificate trusted if CA installed
- [ ] Updates site registry (ssl_enabled: true)

### 3.2 Database Management

**AC-015: Database Creation**
- [ ] `devflow db create myapp_db` creates database
- [ ] Database created with UTF-8 encoding
- [ ] Dedicated user created
- [ ] Secure password generated
- [ ] Connection details displayed
- [ ] Credentials saved securely
- [ ] .env format example provided

**AC-016: Database Import**
- [ ] `devflow db import myapp_db backup.sql` works
- [ ] Handles large SQL files
- [ ] Supports .sql.gz files
- [ ] Progress bar shown
- [ ] Import summary displayed (tables, rows)
- [ ] Time taken shown
- [ ] Errors reported clearly

**AC-017: Database Export**
- [ ] `devflow db export myapp_db` creates dump
- [ ] Filename includes timestamp
- [ ] Export location displayed
- [ ] File size shown
- [ ] Optional compression works
- [ ] Progress shown for large databases

**AC-018: Database Listing**
- [ ] `devflow db list` shows all databases
- [ ] Excludes system databases
- [ ] Shows database size
- [ ] Shows associated site (if any)
- [ ] Total size calculated

### 3.3 Xdebug Support

**AC-019: Xdebug Enable**
- [ ] `devflow xdebug enable 8.2` enables Xdebug
- [ ] Installs if not present
- [ ] Configures xdebug.ini correctly
- [ ] PHP-FPM restarted
- [ ] IDE config shown (VS Code, PhpStorm)
- [ ] Port 9003 configured
- [ ] Path mappings explained

**AC-020: Xdebug Disable**
- [ ] `devflow xdebug disable 8.2` disables Xdebug
- [ ] Extension disabled
- [ ] PHP-FPM restarted
- [ ] Performance improvement noted
- [ ] Confirmation displayed

### 3.4 Log Management

**AC-021: Log Viewing**
- [ ] `devflow logs myapp.test` shows logs
- [ ] Aggregates Apache access, error, PHP-FPM logs
- [ ] Last 50 lines shown by default
- [ ] Errors highlighted in red
- [ ] Timestamps shown
- [ ] Can filter by type (--error, --access)

**AC-022: Real-Time Tail**
- [ ] `devflow logs myapp.test --tail` tails logs
- [ ] Updates in real-time
- [ ] Color-coded by severity
- [ ] Can be stopped with Ctrl+C
- [ ] Multiple log sources merged

### 3.5 Backup & Restore

**AC-023: Backup Creation**
- [ ] `devflow backup create myapp.test` creates backup
- [ ] Files backed up and compressed
- [ ] Database backed up and compressed
- [ ] Configuration saved
- [ ] Backup ID includes timestamp
- [ ] Backup location displayed
- [ ] Total size shown

**AC-024: Backup Restoration**
- [ ] `devflow backup restore [id] newsite.test` restores
- [ ] Backup details shown
- [ ] Confirmation required
- [ ] Files restored
- [ ] Database restored
- [ ] New site created
- [ ] Configuration applied
- [ ] Success message with URL

### 3.6 Windows Integration

**AC-025: Hosts File Management**
- [ ] `devflow hosts add myapp.test` works
- [ ] PowerShell command generated
- [ ] Manual instructions provided
- [ ] Hosts file path shown (Windows)
- [ ] Verification steps provided

---

## 4. Non-Functional Acceptance Criteria

### 4.1 Performance

**AC-100: Site Creation Speed**
- [ ] Site creation completes in < 30 seconds
- [ ] Measured from command execution to Apache reload
- [ ] Consistent across fresh installations
- [ ] No degradation with 100+ sites

**AC-101: File I/O Performance**
- [ ] All operations use native WSL filesystem
- [ ] No operations on /mnt paths (except migration)
- [ ] File I/O throughput > 500 MB/s
- [ ] Claude Code and AI tools run smoothly

**AC-102: Memory Usage**
- [ ] DevFlow CLI uses < 50 MB memory
- [ ] No memory leaks during long-running operations
- [ ] Graceful handling of low memory conditions

**AC-103: Service Startup**
- [ ] All services start in < 10 seconds total
- [ ] Individual service restart < 3 seconds
- [ ] No service conflicts or port issues

### 4.2 Reliability

**AC-110: Configuration Validation**
- [ ] All Apache configs tested before reload
- [ ] `apachectl configtest` passes before applying changes
- [ ] Invalid configs rejected with clear error
- [ ] No service disruption from bad configs

**AC-111: Atomic Operations**
- [ ] Site creation is all-or-nothing
- [ ] Rollback occurs on any error
- [ ] No partial/corrupt states left behind
- [ ] Clear error messages on failure

**AC-112: Data Integrity**
- [ ] Backups are verified for integrity
- [ ] Checksums calculated and verified
- [ ] Corrupted backups detected and reported
- [ ] Restore fails safely if backup corrupted

### 4.3 Usability

**AC-120: Error Messages**
- [ ] All errors follow format: [what] [why] [how to fix]
- [ ] Specific commands provided in fixes
- [ ] No technical jargon in user-facing errors
- [ ] Stack traces hidden unless --verbose

**AC-121: Progress Indicators**
- [ ] Operations > 5 seconds show progress
- [ ] ASCII progress bars for transfers
- [ ] Spinners for checking operations
- [ ] Percentage shown where applicable
- [ ] Time estimates for long operations

**AC-122: Help Documentation**
- [ ] Every command has --help flag
- [ ] Help shows: description, usage, examples, related commands
- [ ] Examples are copy-pasteable
- [ ] Related commands aid discovery

**AC-123: Installation Time**
- [ ] Complete installation in < 5 minutes
- [ ] Fresh Ubuntu WSL installation
- [ ] Includes all dependencies
- [ ] No manual intervention required (except prompts)

### 4.4 Security

**AC-130: File Permissions**
- [ ] Site files owned by user:www-data
- [ ] Directories: 775
- [ ] Files: 664
- [ ] Special handling for storage/ in Laravel (775)
- [ ] Private keys: 600

**AC-131: Credential Storage**
- [ ] Database passwords generated securely (20+ chars)
- [ ] Credentials stored with 600 permissions
- [ ] Encryption used where applicable
- [ ] No credentials in logs or output (masked)

**AC-132: SSL Certificates**
- [ ] Private keys never world-readable
- [ ] CA private key protected (600)
- [ ] Site keys in user-only directory
- [ ] No keys committed to git (gitignore)

### 4.5 Maintainability

**AC-140: Code Quality**
- [ ] All scripts pass shellcheck
- [ ] Google Shell Style Guide followed
- [ ] Functions have header comments
- [ ] Complex logic has inline comments
- [ ] No magic numbers or strings

**AC-141: Test Coverage**
- [ ] >80% test coverage for core functions
- [ ] BATS tests pass
- [ ] CI runs tests on every commit
- [ ] Integration tests for main workflows

**AC-142: Documentation**
- [ ] All commands documented
- [ ] Architecture documented
- [ ] Installation guide complete
- [ ] Troubleshooting guide available
- [ ] Contributing guidelines available

### 4.6 Compatibility

**AC-150: OS Compatibility**
- [ ] Works on Ubuntu 22.04
- [ ] Works on Ubuntu 24.04
- [ ] Works on Debian 11+
- [ ] Works on WSL2 (Ubuntu)
- [ ] Detects and warns on incompatible OS

**AC-151: Dependency Management**
- [ ] All dependencies installable via apt
- [ ] Missing dependencies detected
- [ ] Auto-installation offered
- [ ] Manual installation steps provided if auto fails

---

## 5. Release Acceptance Criteria

### 5.1 MVP Release (v0.1)

**Must Have**:
- [ ] All Phase 1 functional criteria met (AC-001 through AC-012)
- [ ] All performance criteria met (AC-100 through AC-103)
- [ ] All reliability criteria met (AC-110 through AC-112)
- [ ] Installation guide complete
- [ ] Basic troubleshooting guide
- [ ] CLI help for all commands
- [ ] Tested on fresh Ubuntu WSL

**Success Criteria**:
- [ ] Can create and access a PHP site
- [ ] Can create multiple sites with different PHP versions
- [ ] Can migrate a project from /mnt
- [ ] No critical bugs
- [ ] Installation < 5 minutes

### 5.2 Beta Release (v0.5)

**Must Have**:
- [ ] All MVP criteria
- [ ] All Phase 2 functional criteria met (AC-013 through AC-025)
- [ ] All non-functional criteria met (AC-100 through AC-151)
- [ ] Complete documentation
- [ ] Test coverage > 80%
- [ ] Beta tested by 50+ users

**Success Criteria**:
- [ ] All MVP features work reliably
- [ ] HTTPS works with trusted certificates
- [ ] Database management works
- [ ] Xdebug works in VS Code and PhpStorm
- [ ] < 10 critical bugs
- [ ] Positive user feedback

### 5.3 Stable Release (v1.0)

**Must Have**:
- [ ] All Beta criteria
- [ ] All known critical bugs fixed
- [ ] Backup/restore tested extensively
- [ ] Performance benchmarks met
- [ ] Security audit completed
- [ ] Complete test suite
- [ ] Production-ready documentation
- [ ] Contributing guidelines

**Success Criteria**:
- [ ] 100+ active users
- [ ] No critical bugs in 2 weeks
- [ ] Test coverage > 85%
- [ ] Comprehensive documentation
- [ ] GitHub 100+ stars
- [ ] Positive community feedback

---

## 6. Acceptance Testing Process

### 6.1 Testing Checklist

For each release, perform:

1. **Fresh Installation Test**
   - [ ] Install on fresh Ubuntu 22.04 WSL
   - [ ] Install on fresh Ubuntu 24.04 WSL
   - [ ] Follow installation guide exactly
   - [ ] Note any issues or unclear steps

2. **Feature Verification**
   - [ ] Test every AC- criterion
   - [ ] Document pass/fail for each
   - [ ] Log issues for failures
   - [ ] Verify fixes and retest

3. **User Journey Test**
   - [ ] Complete first-time user journey (Junior Developer persona)
   - [ ] Complete migration journey (Senior Developer persona)
   - [ ] Complete team setup journey (DevOps persona)
   - [ ] Time each journey
   - [ ] Note friction points

4. **Performance Test**
   - [ ] Create 10 sites, measure time per site
   - [ ] Create site with SSL, measure total time
   - [ ] Migrate 1GB project, measure transfer speed
   - [ ] Service restart times
   - [ ] Memory usage during operations

5. **Error Handling Test**
   - [ ] Try invalid commands
   - [ ] Try operations without permissions
   - [ ] Try with services stopped
   - [ ] Try with disk full
   - [ ] Verify error messages are helpful

6. **Documentation Test**
   - [ ] Follow installation guide
   - [ ] Try all command examples
   - [ ] Verify troubleshooting steps
   - [ ] Check for outdated information

### 6.2 Sign-Off Requirements

**MVP Release**:
- [ ] Lead developer sign-off
- [ ] All critical AC met
- [ ] Installation guide reviewed
- [ ] At least 1 external tester

**Beta Release**:
- [ ] Lead developer sign-off
- [ ] QA lead sign-off (if applicable)
- [ ] All high-priority AC met
- [ ] 50+ beta testers
- [ ] Community feedback reviewed

**Stable Release**:
- [ ] Product owner sign-off
- [ ] Lead developer sign-off
- [ ] Security review completed
- [ ] All AC met
- [ ] No known critical bugs
- [ ] Documentation complete

---

## 7. Continuous Acceptance

### 7.1 Automated Checks (CI)

Every commit must:
- [ ] Pass all unit tests
- [ ] Pass shellcheck linting
- [ ] Pass integration tests
- [ ] Build successfully

### 7.2 Pre-Release Checks

Before each release:
- [ ] Version number updated
- [ ] CHANGELOG.md updated
- [ ] README.md reviewed
- [ ] All AC verified
- [ ] Tag created
- [ ] Release notes written

---

## Document History

| Version | Date       | Author        | Changes                        |
|---------|------------|---------------|--------------------------------|
| 1.0     | 2025-11-13 | DevFlow Team  | Initial acceptance criteria    |

---

**Document Status**: Draft
**Next Review Date**: Before MVP release
**Approval**: Pending
