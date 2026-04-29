#!/usr/bin/env bash
# =============================================================================
# IDM Portal — Installation Script
# Django backend + Flutter frontend setup
# Tested on: Ubuntu 22.04 / Fedora / Debian-based distros
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
die()     { error "$*"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${CYAN}"
cat << 'EOF'
  ___  ____  __  __   ____            _        _
 |_ _||  _ \|  \/  | |  _ \ ___  _ __| |_ __ _| |
  | | | | | | |\/| | | |_) / _ \| '__| __/ _` | |
  | | | |_| | |  | | |  __/ (_) | |  | || (_| | |
 |___||____/|_|  |_| |_|   \___/|_|   \__\__,_|_|
  Installation Script — IDM Portal (Django + Flutter)
EOF
echo -e "${NC}"

# =============================================================================
# 0. PREFLIGHT
# =============================================================================
info "Running preflight checks..."

# Must NOT run as root (venv + Flutter break under root)
if [[ "$EUID" -eq 0 ]]; then
  die "Do not run this script as root. Use a regular user with sudo access."
fi

# Detect package manager
if command -v apt-get &>/dev/null; then
  PKG_MGR="apt"
elif command -v dnf &>/dev/null; then
  PKG_MGR="dnf"
else
  die "Unsupported distro. Script supports apt (Ubuntu/Debian) and dnf (Fedora)."
fi
info "Package manager: $PKG_MGR"

# Resolve project root (where this script lives, or current dir)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$SCRIPT_DIR}"

# Confirm we're in the right place
if [[ ! -f "$PROJECT_DIR/manage.py" ]]; then
  die "manage.py not found in '$PROJECT_DIR'. Run this script from the project root, or pass the path as an argument:\n  ./install.sh /path/to/idm_portal-main"
fi
info "Project root: $PROJECT_DIR"
cd "$PROJECT_DIR"

# =============================================================================
# 1. SYSTEM DEPENDENCIES
# =============================================================================
info "Installing system dependencies..."

if [[ "$PKG_MGR" == "apt" ]]; then
  sudo apt-get update -qq
  sudo apt-get install -y \
    python3 python3-pip python3-venv python3-dev \
    postgresql postgresql-contrib libpq-dev \
    git curl unzip build-essential \
    libzbar0 libzbar-dev \
    2>/dev/null
elif [[ "$PKG_MGR" == "dnf" ]]; then
  sudo dnf install -y \
    python3 python3-pip python3-devel \
    postgresql postgresql-server postgresql-contrib libpq-devel \
    git curl unzip gcc \
    zbar zbar-devel \
    2>/dev/null
fi
success "System dependencies installed."

# =============================================================================
# 2. FIX requirements.txt  (BUG #1 + #2)
# =============================================================================
# BUG #1: Django==6.0.1 does not exist. Latest stable Django is 5.x.
#         Pinning to Django==5.1.4 (current LTS-compatible stable release).
# BUG #2: django-extensions is listed in INSTALLED_APPS in settings.py
#         but is completely absent from requirements.txt — app will crash
#         with ImportError on startup. Added here.
# NOTE:   openpyxl is also used by import_staff.py but missing from reqs.
# NOTE:   qrcode is used by generate_qr.py but missing from reqs.
# =============================================================================

REQS_FILE="$PROJECT_DIR/requirements.txt"
REQS_BACKUP="$PROJECT_DIR/requirements.txt.bak"

info "Patching requirements.txt..."
cp "$REQS_FILE" "$REQS_BACKUP"
warn "  Original backed up to: requirements.txt.bak"

# Replace bad Django version
sed -i 's/^Django==6\.0\.1/Django==5.1.4/' "$REQS_FILE"
warn "  BUG #1 FIXED: Django==6.0.1 → Django==5.1.4 (6.0.1 does not exist)"

# Add missing packages if not already present
add_if_missing() {
  local pkg="$1"
  local reason="$2"
  if ! grep -qi "^${pkg%%[>=<!]*}" "$REQS_FILE"; then
    echo "$pkg" >> "$REQS_FILE"
    warn "  BUG FIXED: Added missing '$pkg' — $reason"
  fi
}

add_if_missing "django-extensions==3.2.3"  "in INSTALLED_APPS but missing from requirements"
add_if_missing "openpyxl>=3.1.0"           "used by import_staff management command"
add_if_missing "qrcode[pil]>=7.4"          "used by generate_qr.py"

success "requirements.txt patched."

# =============================================================================
# 3. PYTHON VIRTUAL ENVIRONMENT
# =============================================================================
VENV_DIR="$PROJECT_DIR/venv"

if [[ -d "$VENV_DIR" ]]; then
  warn "Virtual environment already exists at venv/ — skipping creation."
else
  info "Creating virtual environment..."
  python3 -m venv "$VENV_DIR"
  success "Virtual environment created."
fi

# Activate
# NOTE (README BUG): README says `source venv/Scripts/activate` which is
# Windows-only. On Linux/macOS it is `source venv/bin/activate`.
source "$VENV_DIR/bin/activate"
info "Virtual environment activated."

# Upgrade pip
pip install --upgrade pip --quiet

# =============================================================================
# 4. INSTALL PYTHON DEPENDENCIES
# =============================================================================
info "Installing Python dependencies..."
pip install -r requirements.txt
success "Python dependencies installed."

# =============================================================================
# 5. ENVIRONMENT FILE  (BUG #3 — credentials in settings.py)
# =============================================================================
# BUG #3: settings.py contains a hardcoded SECRET_KEY and database password.
#         These must never be committed. We move them to a .env file and patch
#         settings.py to read from environment variables via os.environ.
# =============================================================================

ENV_FILE="$PROJECT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  warn ".env already exists — skipping generation. Review it manually."
else
  info "Generating .env file from settings.py defaults..."

  # Prompt for DB password (default to the hardcoded one for dev convenience)
  echo ""
  echo -e "${YELLOW}Enter PostgreSQL password for 'idm_portal_db' [default: Baby2004.]: ${NC}"
  read -r -s DB_PASS
  DB_PASS="${DB_PASS:-Baby2004.}"

  cat > "$ENV_FILE" << EOF
# IDM Portal — Environment Configuration
# DO NOT commit this file to version control.

# Django
SECRET_KEY=django-insecure-7zk&5p!+(^\$%!qx%#2=15ialdqyq*s9gedbmz-7y=p7^wj#0%!
DEBUG=True
ALLOWED_HOSTS=*

# Database
DB_ENGINE=django.db.backends.postgresql
DB_NAME=idm_portal_db
DB_USER=postgres
DB_PASSWORD=${DB_PASS}
DB_HOST=localhost
DB_PORT=5432
EOF

  success ".env generated."
  warn "  BUG #3 FIXED: Credentials moved out of settings.py into .env"
  warn "  Remember to regenerate SECRET_KEY for production!"
fi

# Patch settings.py to read from .env using os.environ
# (only patch once — check for marker)
if ! grep -q "# PATCHED_BY_INSTALL_SCRIPT" "$PROJECT_DIR/config/settings.py"; then
  info "Patching settings.py to read credentials from environment..."

  # Install python-decouple to handle .env reading
  if ! grep -qi "python-decouple\|python_decouple" "$REQS_FILE"; then
    echo "python-decouple>=3.8" >> "$REQS_FILE"
    pip install python-decouple --quiet
  fi

  # Write patched settings header
  SETTINGS_FILE="$PROJECT_DIR/config/settings.py"
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"

  python3 << 'PYEOF'
import re

path = "config/settings.py"
with open(path, "r") as f:
    content = f.read()

# Add decouple import after pathlib import
if "from decouple import config" not in content:
    content = content.replace(
        "from pathlib import Path",
        "from pathlib import Path\nfrom decouple import config  # PATCHED_BY_INSTALL_SCRIPT"
    )

# Patch SECRET_KEY
content = re.sub(
    r"SECRET_KEY\s*=\s*'[^']*'",
    "SECRET_KEY = config('SECRET_KEY')",
    content
)

# Patch DEBUG
content = re.sub(
    r"DEBUG\s*=\s*(True|False)",
    "DEBUG = config('DEBUG', default=True, cast=bool)",
    content
)

# Patch DATABASE block
db_block_new = """DATABASES = {
    'default': {
        'ENGINE':   config('DB_ENGINE',   default='django.db.backends.postgresql'),
        'NAME':     config('DB_NAME',     default='idm_portal_db'),
        'USER':     config('DB_USER',     default='postgres'),
        'PASSWORD': config('DB_PASSWORD', default=''),
        'HOST':     config('DB_HOST',     default='localhost'),
        'PORT':     config('DB_PORT',     default='5432'),
    }
}"""

content = re.sub(
    r"DATABASES\s*=\s*\{.*?\}(\s*\n\s*\})?",
    db_block_new,
    content,
    flags=re.DOTALL
)

with open(path, "w") as f:
    f.write(content)

print("settings.py patched successfully.")
PYEOF

  success "settings.py patched."
fi

# =============================================================================
# 6. CORS SETTINGS WARNING  (BUG #4)
# =============================================================================
# BUG #4: settings.py has BOTH:
#   CORS_ALLOW_ALL_ORIGINS = True   ← allows every origin
#   CORS_ALLOWED_ORIGINS = [...]    ← sets specific whitelist
# These contradict each other. The first overrides the second, making the
# whitelist useless. For development this is fine; for production, remove
# CORS_ALLOW_ALL_ORIGINS and rely on CORS_ALLOWED_ORIGINS only.
echo ""
warn "══════════════════════════════════════════════════════"
warn " BUG #4 (manual fix required): Contradicting CORS config in settings.py"
warn " CORS_ALLOW_ALL_ORIGINS = True overrides your CORS_ALLOWED_ORIGINS list."
warn " For production: remove CORS_ALLOW_ALL_ORIGINS from settings.py."
warn "══════════════════════════════════════════════════════"
echo ""

# =============================================================================
# 7. POSTGRESQL SETUP
# =============================================================================
info "Setting up PostgreSQL..."

# Start PostgreSQL service
if [[ "$PKG_MGR" == "apt" ]]; then
  sudo service postgresql start 2>/dev/null || sudo systemctl start postgresql 2>/dev/null || true
elif [[ "$PKG_MGR" == "dnf" ]]; then
  # Fedora: initialise DB first if needed
  if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
    sudo postgresql-setup --initdb
  fi
  sudo systemctl enable postgresql --now 2>/dev/null || true
fi

# Create DB and user (suppress errors if already exist)
DB_PASS_CREATE=$(grep DB_PASSWORD "$ENV_FILE" | cut -d= -f2)

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='idm_portal_db';" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE idm_portal_db;" 2>/dev/null && success "  Database 'idm_portal_db' created." || true

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='postgres';" | grep -q 1 && \
  sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$DB_PASS_CREATE';" 2>/dev/null || true

success "PostgreSQL configured."

# =============================================================================
# 8. DJANGO MIGRATIONS
# =============================================================================
info "Running Django migrations..."
python manage.py migrate --run-syncdb
success "Migrations applied."

# =============================================================================
# 9. COLLECT STATIC FILES
# =============================================================================
info "Collecting static files..."
python manage.py collectstatic --noinput
success "Static files collected."

# =============================================================================
# 10. MEDIA DIRECTORY
# =============================================================================
MEDIA_DIR="$PROJECT_DIR/media/staff_photos"
mkdir -p "$MEDIA_DIR"
success "Media directory ensured: $MEDIA_DIR"

# =============================================================================
# 11. OPTIONAL: IMPORT STAFF DATA
# =============================================================================
if [[ -f "$PROJECT_DIR/staff.xlsx" ]]; then
  echo ""
  echo -e "${YELLOW}staff.xlsx found. Import staff data now? [y/N]: ${NC}"
  read -r IMPORT_NOW
  if [[ "$IMPORT_NOW" =~ ^[Yy]$ ]]; then
    info "Importing staff from staff.xlsx..."
    python manage.py import_staff
    success "Staff import complete."
  else
    info "Skipping staff import. Run manually later with:"
    echo "       python manage.py import_staff"
  fi
fi

# =============================================================================
# 12. CREATE SUPERUSER (interactive)
# =============================================================================
echo ""
echo -e "${YELLOW}Create Django superuser now? (needed for /admin) [y/N]: ${NC}"
read -r CREATE_SU
if [[ "$CREATE_SU" =~ ^[Yy]$ ]]; then
  python manage.py createsuperuser
fi

# =============================================================================
# 13. FLUTTER SETUP  (optional)
# =============================================================================
echo ""
echo -e "${YELLOW}Set up Flutter frontend as well? [y/N]: ${NC}"
read -r SETUP_FLUTTER

if [[ "$SETUP_FLUTTER" =~ ^[Yy]$ ]]; then

  # ── Flutter SDK WARNING (BUG #5) ──────────────────────────────────────────
  # BUG #5: pubspec.yaml requires sdk: ^3.10.3 which does not yet exist.
  #         As of early 2026, Flutter stable is ~3.29.x / Dart ~3.7.x.
  #         The constraint "^3.10.3" is satisfied by >=3.10.3 <4.0.0,
  #         meaning any Flutter with Dart >=3.10.3 works — but that version
  #         doesn't exist yet. The script will try to update Flutter and warn.
  warn "══════════════════════════════════════════════════════"
  warn " BUG #5 (Flutter): pubspec.yaml specifies sdk: '^3.10.3'"
  warn " This Dart SDK version does not exist yet (current stable ~3.7.x)."
  warn " You may need to lower the constraint to '^3.7.0' in pubspec.yaml"
  warn " if 'flutter pub get' fails."
  warn "══════════════════════════════════════════════════════"

  if ! command -v flutter &>/dev/null; then
    error "Flutter not found in PATH."
    info "Install Flutter from https://docs.flutter.dev/get-started/install"
    info "Then re-run: cd $PROJECT_DIR && flutter pub get"
  else
    FLUTTER_VER=$(flutter --version 2>&1 | head -1)
    info "Flutter found: $FLUTTER_VER"

    info "Running flutter pub get..."
    flutter pub get || {
      warn "flutter pub get failed — likely due to sdk constraint mismatch (BUG #5)."
      warn "Manual fix: edit pubspec.yaml and change  sdk: '^3.10.3'  to  sdk: '^3.7.0'"
      warn "Then run: flutter pub get"
    }
  fi
fi

# =============================================================================
# 14. SUMMARY
# =============================================================================
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  IDM Portal installation complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BLUE}Start the dev server:${NC}"
echo "    source venv/bin/activate"
echo "    python manage.py runserver"
echo ""
echo -e "  ${BLUE}Admin panel:${NC}       http://127.0.0.1:8000/admin/"
echo -e "  ${BLUE}API base:${NC}          http://127.0.0.1:8000/api/"
echo -e "  ${BLUE}Verify endpoint:${NC}   POST http://127.0.0.1:8000/api/verify/"
echo -e "  ${BLUE}Scan endpoint:${NC}     POST http://127.0.0.1:8000/api/scan/"
echo -e "  ${BLUE}Recent entry:${NC}      GET  http://127.0.0.1:8000/api/recent/"
echo ""
echo -e "  ${YELLOW}Bugs corrected by this script:${NC}"
echo "  [1] Django==6.0.1 (non-existent) → Django==5.1.4"
echo "  [2] Missing django-extensions, openpyxl, qrcode added to requirements"
echo "  [3] Hardcoded SECRET_KEY + DB password moved to .env"
echo "  [4] Contradicting CORS config — WARNING issued (manual fix for prod)"
echo "  [5] Flutter sdk ^3.10.3 doesn't exist — WARNING issued"
echo ""
echo -e "  ${RED}Remaining manual action:${NC}"
echo "  → For PRODUCTION: rotate SECRET_KEY, set DEBUG=False,"
echo "    fix CORS (remove CORS_ALLOW_ALL_ORIGINS), use a strong DB password."
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
