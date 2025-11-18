Great — you can get Laragon-level flexibility in WSL. Below is a compact, practical guide showing:

* how to run **multiple PHP versions** (per-site via php-fpm + CLI switching),
* how to run **composer** and other CLI tools with the right PHP,
* how to handle **MySQL/MariaDB** (single native instance + options for multiple versions), and
* how to install **Redis, PostgreSQL, MongoDB** (system services) — plus when to use Docker for extra DB-version flexibility.

I’ll give commands you can paste into your WSL Ubuntu (24.04) terminal and short explanations so you know why each step exists.

---

# 1) PHP: multiple versions (per-site + CLI)

We use Ondřej Surý’s PPA (you already did earlier). Each PHP version runs its own `php-fpm` service and socket. Apache vhosts point to the socket for the version you want.

Install PHP versions you need:

```bash
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# install the versions you need (example)
sudo apt install -y php7.4-fpm php7.4-cli php7.4-mbstring php7.4-xml php7.4-mysql
sudo apt install -y php8.0-fpm php8.0-cli php8.0-mbstring php8.0-xml php8.0-mysql
sudo apt install -y php8.2-fpm php8.2-cli php8.2-mbstring php8.2-xml php8.2-mysql
```

Per-site PHP (Apache + php-fpm)

* In your vhost, use the `SetHandler "proxy:unix:/run/php/phpX.Y-fpm.sock|fcgi://localhost/"` line — that sends PHP requests for that site to that version’s FPM.
* To change a site’s PHP version, edit its vhost and change the socket to another `/run/php/phpX.Y-fpm.sock` and `sudo systemctl reload apache2`.

PHP-FPM config & pools

* Each `phpX.Y-fpm` has `/etc/php/X.Y/fpm/` with `php.ini` and pools in `/etc/php/X.Y/fpm/pool.d/`. If you need per-site memory limits or upload sizes, create a custom pool file there.

CLI PHP (composer etc.)

* You can run composer with whichever PHP CLI you choose:

```bash
# ensure composer installed globally
php8.2 -r "copy('https://getcomposer.org/installer','composer-setup.php');"
php8.2 composer-setup.php
sudo mv composer.phar /usr/local/bin/composer-8.2
sudo chmod +x /usr/local/bin/composer-8.2

# run composer using specific php:
php7.4 /usr/local/bin/composer-8.2 install
# or simply run PHP directly:
php8.2 /usr/local/bin/composer.phar require vendor/package
```

Optional: set a default `php` in CLI with `update-alternatives`:

```bash
sudo update-alternatives --install /usr/bin/php php /usr/bin/php7.4 74
sudo update-alternatives --install /usr/bin/php php /usr/bin/php8.2 82
# choose default
sudo update-alternatives --config php
```

But be explicit in scripts — calling `php7.4`/`php8.2` is safer.

Tip: create small shell wrappers if you often run composer with a non-default php:

```bash
alias composer74='php7.4 /usr/local/bin/composer.phar'
alias composer82='php8.2 /usr/local/bin/composer.phar'
```

---

# 2) MySQL / MariaDB — options & practical approach

**Option A — single system MariaDB (simple, fast, stable)**
Install (example):

```bash
sudo apt install -y mariadb-server
sudo systemctl enable --now mariadb
sudo mysql_secure_installation
```

Use this as your primary DB for development. Import dumps with `mysql -u root -p dbname < dump.sql`.

**Option B — multiple DB versions (recommended approach: Docker)**
If you need to replicate different server versions (e.g., MySQL 5.7 vs 8.0 or MariaDB 10.6 vs 11), the easiest safe approach is Docker containers:

* Start a container with a specific version and a different port (e.g., `3307`).
* Point the site `.env` to `DB_HOST=127.0.0.1` and `DB_PORT=3307` for that project.

Example Docker quick-run (if you change your mind about Docker):

```bash
# MySQL 5.7 on port 3307
docker run -d --name mysql57 -e MYSQL_ROOT_PASSWORD=root -p 3307:3306 mysql:5.7

# MariaDB 10.6 on port 3308
docker run -d --name mariadb106 -e MYSQL_ROOT_PASSWORD=root -p 3308:3306 mariadb:10.6
```

**Option C — multiple native instances without Docker**
Possible but more involved: install a second MariaDB from tarball, create a new datadir, service unit and run on different port. I can supply step-by-step if you want to avoid Docker entirely — but it’s more work and fragile compared to Docker.

Recommendation: use the **native MariaDB** for day-to-day dev and **Docker** for projects that require an older/newer DB version.

---

# 3) Redis, PostgreSQL, MongoDB — install as system services

You can install them directly inside WSL and run them as services (systemd required — WSL supports systemd on Ubuntu 24.04 if enabled).

### Redis

```bash
sudo apt update
sudo apt install -y redis-server
sudo systemctl enable --now redis-server
# test
redis-cli ping
# should reply: PONG
```

### PostgreSQL

```bash
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
# create a dev user & database
sudo -u postgres createuser -s $USER
createdb myproject_dev
```

### MongoDB (recommended: official repo, but simple apt first)

Ubuntu package naming and versions drift. Easiest quick install:

```bash
sudo apt install -y mongodb
sudo systemctl enable --now mongodb
# or if mongodb.service not available, use 'mongod' package from official repo
# test
mongosh --eval 'db.runCommand({ ping: 1 })'
```

If you want a specific MongoDB version, I can give the precise steps to add MongoDB's official repo for 7.x or 6.x.

**Note**: If you run into systemd issues inside WSL, ensure `systemd=true` is set in `/etc/wsl.conf` (as you configured earlier) and `wsl --shutdown` from Windows to restart WSL.

---

# 4) How to run terminal commands for each project (Composer, Artisan, npm)

Best practice: open VS Code from WSL in the project folder (Remote - WSL). Then the integrated terminal is the same WSL shell with correct PHP and path.

Examples (in project folder inside WSL):

```bash
# for a Laravel project wanting PHP 8.2
php8.2 /usr/local/bin/composer.phar install
php8.2 artisan migrate

# or if composer set for php8.2 as alias:
composer82 install

# node/npm (installed in WSL)
npm install
npm run dev
```

If you must run a command from Windows PowerShell, prefix with `wsl`:

```powershell
# run composer install for project in WSL folder
wsl -d ubuntu -- bash -lc "cd ~/websites/mylaravel.test && php8.2 /usr/local/bin/composer.phar install"
```

But prefer opening the project in WSL and using the integrated terminal.

---

# 5) Per-site services & ports (how to point a project to different DB/Redis)

Your local `.env` or config should point to service host/port, e.g.:

* Native default DB: `DB_HOST=127.0.0.1` `DB_PORT=3306`
* Docker container DB on port `3307`: `DB_HOST=127.0.0.1` `DB_PORT=3307`
* Redis default: `REDIS_HOST=127.0.0.1` `REDIS_PORT=6379`
* PostgreSQL default: `DB_PORT=5432`

This is the same pattern Laragon uses — different projects can have different DB host/port combos.

---

# 6) Quick sample workflow (one project)

1. move project into `~/websites/myproj.test`
2. create-site `myproj.test php8.2 public`
3. import DB into native MariaDB or start a Docker DB
4. set `.env` accordingly
5. in WSL terminal: `cd ~/websites/myproj.test && php8.2 /usr/local/bin/composer.phar install && php8.2 artisan migrate`
6. open browser: `http://myproj.test`

---

# 7) When to use Docker (short guide)

* Use Docker when you need to run multiple different DB versions concurrently, or want to replicate a server environment exactly.
* For PHP/webserver you already have a fast WSL native setup — it’s simpler to keep Apache + php-fpm native and use Docker only for DB/queues (Redis) or special services.

Example: run Redis 6 in a container while running native Redis 7:

```bash
docker run -d --name redis6 -p 6379:6379 redis:6
# or map to different port 6380 to avoid conflict:
docker run -d --name redis6 -p 6380:6379 redis:6
```

Then change your project `REDIS_PORT` to `6380`.

---

# 8) Helpful utilities & tips

* Use `systemctl status <service>` to check service health, e.g. `systemctl status redis-server`.
* Use `ss -tulpn | grep php` or `ss -tulpn | grep :3306` to verify sockets/ports.
* Keep PHP `opcache` disabled for local dev (or low TTL) for faster iterative editing.
* Use `composer install --no-dev --optimize-autoloader` only for production; local use normal install.
* Keep at least 15–20% free SSD space for swap and temp files while running multiple services.

---

# 9) Want me to produce scripts?

I can produce:

* a script that installs chosen PHP versions + php-fpm + composer and configures `update-alternatives` for CLI, and sample vhost; **or**
* a script that installs Redis, Postgres, Mongo (with official repo options), and configures services; **or**
* a docker-compose file for isolated DB services (MySQL 5.7, MariaDB 10.6, Mongo 6, Redis 6) you can run alongside the native Apache/php-fpm.

Tell me which script you want first (PHP setup / DB services / docker-compose for DBs) and I’ll generate it ready-to-run.
