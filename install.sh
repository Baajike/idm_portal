#!/usr/bin/env bash
# =============================================================================
# IDM Portal — Installation Script (REFINED)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
die()     { error "$*"; exit 1; }

# =============================================================================
# 0. PREFLIGHT
# =============================================================================
if [[ "$EUID" -eq 0 ]]; then
  die "Do not run this script as root. Use a regular user with sudo access."
fi

if command -v apt-get &>/dev/null; then
  PKG_MGR="apt"
elif command -v dnf &>/dev/null; then
  PKG_MGR="dnf"
else
  die "Unsupported distro."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-$SCRIPT_DIR}"
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
    git curl unzip build-essential libzbar0 libzbar-dev 2>/dev/null
elif [[ "$PKG_MGR" == "dnf" ]]; then
  sudo dnf install -y \
    python3 python3-pip python3-devel \
    postgresql postgresql-server postgresql-contrib libpq-devel \
    git curl unzip gcc zbar zbar-devel 2>/dev/null
fi
success "System dependencies installed."

# =============================================================================
# 2. VIRTUAL ENVIRONMENT & PIP
# =============================================================================
VENV_DIR="$PROJECT_DIR/venv"
if [[ ! -d "$VENV_DIR" ]]; then
  info "Creating virtual environment..."
  python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip --quiet
pip install -r requirements.txt
pip install gunicorn --quiet
success "Python dependencies installed."

# =============================================================================
# 3. ENVIRONMENT FILE (.env)
# =============================================================================
if [[ ! -f ".env" ]]; then
  info "Generating default .env file..."
  SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(45))")
  cat > .env << EOF
SECRET_KEY=${SECRET}
DEBUG=True
ALLOWED_HOSTS=192.168.31.146,127.0.0.1,100.104.198.95

DB_ENGINE=django.db.backends.postgresql
DB_NAME=idm_portal_db
DB_USER=postgres
DB_PASSWORD=Baby2004.
DB_HOST=localhost
DB_PORT=5432
EOF
  success ".env file generated."
fi

# =============================================================================
# 4. POSTGRESQL SETUP
# =============================================================================
info "Setting up PostgreSQL..."
if [[ "$PKG_MGR" == "apt" ]]; then
  sudo service postgresql start 2>/dev/null || sudo systemctl start postgresql 2>/dev/null || true
elif [[ "$PKG_MGR" == "dnf" ]]; then
  if [[ ! -f /var/lib/pgsql/data/PG_VERSION ]]; then
    sudo postgresql-setup --initdb
  fi
  sudo systemctl enable postgresql --now 2>/dev/null || true
fi

DB_NAME=$(grep DB_NAME .env | cut -d= -f2)
DB_USER=$(grep DB_USER .env | cut -d= -f2)
DB_PASS=$(grep DB_PASSWORD .env | cut -d= -f2)

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || true

sudo -u postgres psql -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || true
success "PostgreSQL configured."

# =============================================================================
# 5. DJANGO OPERATIONS
# =============================================================================
info "Running migrations and collecting static files..."
python manage.py migrate --noinput
python manage.py collectstatic --noinput
mkdir -p media/staff_photos
success "Django ready."

# =============================================================================
# 6. DATA FIX (Prepending '0')
# =============================================================================
if [[ -f "fix_staff_contacts.py" ]]; then
  info "Applying phone number format fix..."
  python manage.py shell < fix_staff_contacts.py || warn "Data fix failed or skipped (likely no data yet)."
fi

success "Installation complete. IDM Portal is ready for development."
success "Run 'python manage.py runserver' to start."
