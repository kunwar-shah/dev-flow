Nice — `~/websites` is a great, clear choice. Below I’ve rewritten everything so it uses `~/websites` as the central Laragon-style root. Copy-paste the commands into your WSL Ubuntu shell.

I include:

* create the folder + perms
* `create-site` script (creates vhost + points to php-fpm socket)
* `move-project` rsync helper (safe move, preserves git)
* small extras: aliases, hosts reminder, troubleshooting tips
* examples of how to use each script

---

# Setup the `~/websites` root

```bash
# create root and set ownership/perm
WEBSITE_ROOT="$HOME/websites"
mkdir -p "$WEBSITE_ROOT"
sudo chown -R $USER:www-data "$WEBSITE_ROOT"
chmod -R 775 "$WEBSITE_ROOT"

# create a sample site skeleton to test
mkdir -p "$WEBSITE_ROOT/example.test/public"
echo "<?php phpinfo();" > "$WEBSITE_ROOT/example.test/public/index.php"
```

Enable Apache modules (if not already):

```bash
sudo a2enmod proxy_fcgi setenvif rewrite
sudo systemctl reload apache2
```

---

# create-site script (automates vhost creation)

Save this as `~/bin/create-site` and make executable.

```bash
mkdir -p ~/bin
cat > ~/bin/create-site <<'EOF'
#!/usr/bin/env bash
# Usage: create-site sitename phpver [docroot_subpath]
# Example: create-site opencart3.test php7.4 public

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: create-site <sitename> <phpver> [docroot_subpath]"
  exit 1
fi

SITENAME="$1"          # e.g. opencart3.test
PHPVER="$2"            # e.g. php7.4  (socket at /run/php/php7.4-fpm.sock)
DOCROOT_SUB="${3:-public}"
WEBSITE_ROOT="$HOME/websites"
SITE_DIR="$WEBSITE_ROOT/$SITENAME"
DOCROOT="$SITE_DIR/$DOCROOT_SUB"

# create directories
mkdir -p "$DOCROOT"

# set ownership & perms
sudo chown -R $USER:www-data "$SITE_DIR"
sudo chmod -R 775 "$SITE_DIR"

# create vhost
VHOST_FILE="/etc/apache2/sites-available/${SITENAME}.conf"

sudo bash -c "cat > $VHOST_FILE" <<APACHE_CONF
<VirtualHost *:80>
    ServerName ${SITENAME}
    ServerAlias www.${SITENAME}
    DocumentRoot ${DOCROOT}

    <Directory ${DOCROOT}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler \"proxy:unix:/run/php/${PHPVER}-fpm.sock|fcgi://localhost/\"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/${SITENAME}_error.log
    CustomLog \${APACHE_LOG_DIR}/${SITENAME}_access.log combined
</VirtualHost>
APACHE_CONF

# enable site and reload apache
sudo a2ensite "${SITENAME}.conf" >/dev/null || true
sudo systemctl reload apache2

echo "Site created: $SITE_DIR"
echo "Document root: $DOCROOT"
echo
echo "Add to your Windows hosts file (run Notepad as admin):"
echo "127.0.0.1 ${SITENAME}"
EOF

chmod +x ~/bin/create-site

# ensure ~/bin is in PATH
if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.profile 2>/dev/null; then
  echo 'export PATH="$HOME/bin:$PATH"' >> ~/.profile
  source ~/.profile
fi
```

Usage examples:

```bash
# Laraval project (public)
create-site mylaravel.test php8.2 public

# OpenCart 3 (uses upload as docroot if needed)
create-site opencart3.test php7.4 upload

# Simple phpinfo test (already created above)
create-site example.test php8.2 public
```

---

# move-project script (safe rsync move from Windows `/mnt/c/...` into `~/websites`)

Save as `~/bin/move-project` and make executable.

```bash
cat > ~/bin/move-project <<'EOF'
#!/usr/bin/env bash
# Usage: move-project /mnt/c/Users/ajay/path/to/project sitename [docroot_subpath]
# Example: move-project /mnt/c/Users/ajay/Projects/opencart3 opencart3.test upload

set -euo pipefail
if [ $# -lt 2 ]; then
  echo "Usage: move-project <win_src_path> <sitename> [docroot_subpath]"
  exit 1
fi

SRC="$1"              # e.g. /mnt/c/Users/ajay/Projects/opencart3
SITENAME="$2"         # e.g. opencart3.test
DOCROOT_SUB="${3:-public}"
TARGET="$HOME/websites/$SITENAME"

echo "Dry-run rsync from $SRC to $TARGET ..."
rsync -avh --progress --exclude='node_modules' --exclude='vendor' --exclude='storage/logs' "$SRC/" "$TARGET/" --dry-run

read -p "Proceed with actual transfer? (y/N): " yn
if [[ "$yn" != "y" && "$yn" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

rsync -avh --progress --chown=$(id -u):$(id -g) \
  --exclude='node_modules' --exclude='vendor' --exclude='storage/logs' \
  "$SRC/" "$TARGET/"

# set perms
sudo chown -R $USER:www-data "$TARGET"
sudo find "$TARGET" -type d -exec chmod 775 {} \;
sudo find "$TARGET" -type f -exec chmod 664 {} \;

# Laravel specific perms if present
if [ -d "$TARGET/storage" ] || [ -d "$TARGET/bootstrap" ]; then
  sudo chown -R $USER:www-data "$TARGET/storage" "$TARGET/bootstrap" 2>/dev/null || true
  sudo chmod -R 775 "$TARGET/storage" "$TARGET/bootstrap" 2>/dev/null || true
fi

echo "Project moved to $TARGET"
echo "Now run: cd $TARGET && composer install (if needed)"
EOF

chmod +x ~/bin/move-project
```

Example move command:

```bash
move-project /mnt/c/Users/ajay/OneDrive/Projects/opencart3 opencart3.test upload
# then create vhost pointing to upload:
create-site opencart3.test php7.4 upload
```

---

# Hosts file (Windows) — what to add

Open Notepad as administrator and add lines like:

```
127.0.0.1 opencart3.test
127.0.0.1 opencart4.test
127.0.0.1 mylaravel1.test
127.0.0.1 example.test
```

Save. Then open `http://opencart3.test` in your browser.

> WSL localhost forwarding usually makes `127.0.0.1` work from Windows to WSL Apache. If you use `localhost` names, they map too.

---

# Aliases & tiny conveniences

Add to `~/.bashrc` or `~/.profile`:

```bash
alias websites='cd ~/websites'
alias sites='ls -1 ~/websites'
alias create-site='~/bin/create-site'
```

Then run `source ~/.bashrc`.

---

# Switching PHP per site

* Each vhost points at a php-fpm socket (e.g. `/run/php/php7.4-fpm.sock`).
* To change PHP for a site: edit `/etc/apache2/sites-available/<sitename>.conf` and change the `SetHandler` socket to the desired version, then `sudo systemctl reload apache2`.
* Ensure the php-fpm service exists and is running: `systemctl status php7.4-fpm` etc.

---

# Quick troubleshooting

* 500 errors → check site error log:
  `sudo tail -n 200 /var/log/apache2/<sitename>_error.log`
* php-fpm socket missing → start the service, e.g. `sudo systemctl start php7.4-fpm`
* Permissions → ensure `www-data` can read the docroot; use the chown/chmod steps above
* DB connection → import DB dump to WSL MariaDB and set `DB_HOST=127.0.0.1` in `.env`

---

# Final notes & suggestions

* Keep only LAMP sites in `~/websites` (helps maintain watcher rules and a Laragon-like workflow). Keep other stacks in `~/projects`.
* Always open VS Code from inside WSL for LAMP sites: `cd ~/websites/opencart3.test && code .` (Remote - WSL).
* Back up before moving large projects (tar + DB dump).
* If you want, I can produce a single **bulk-migrate script** that receives 2–3 Windows paths + sitenames + php versions and does the rsync + vhost creation in one go — say the paths and php versions and I’ll generate it ready-to-run.

Want that bulk-migration script now, or are you good to run the create/move commands yourself?
