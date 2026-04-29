#!/usr/bin/env bash
# =============================================================================
# IDM Portal — Production Deployment Script
# Gunicorn + Nginx + HTTPS (self-signed, upgradeable to Let's Encrypt)
# Target: leluserver @ 192.168.31.146
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
# CONFIGURATION — edit these before running, or pass as env vars
# =============================================================================

# If you later get a domain, re-run the script with:
#   DOMAIN=yourdomain.com ./deploy_production.sh
# The script will use Let's Encrypt instead of self-signed.

SERVER_IP="${SERVER_IP:-192.168.31.146}"
DOMAIN="${DOMAIN:-}"                          # leave empty = IP only (self-signed)
PROJECT_DIR="${PROJECT_DIR:-/home/lelu/idm_portal}"
APP_USER="${APP_USER:-lelu}"
VENV_DIR="$PROJECT_DIR/venv"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-3}"      # rule of thumb: 2x CPU cores + 1
DJANGO_PORT="8000"                             # internal Gunicorn port
SERVICE_NAME="idm_portal"

# Derive the host Nginx will listen/serve for
if [[ -n "$DOMAIN" ]]; then
  SERVER_NAME="$DOMAIN"
  USE_LETSENCRYPT=true
else
  SERVER_NAME="$SERVER_IP"
  USE_LETSENCRYPT=false
fi

# =============================================================================
# 0. PREFLIGHT
# =============================================================================
echo -e "${CYAN}"
cat << 'EOF'
  ___  ____  __  __   ____            _
 |_ _||  _ \|  \/  | |  _ \ ___ _ __ | | ___  _   _
  | | | | | | |\/| | | | | / _ \ '_ \| |/ _ \| | | |
  | | | |_| | |  | | | |_| |  __/ |_) | | (_) | |_| |
 |___||____/|_|  |_| |____/ \___| .__/|_|\___/ \__, |
  Production Setup               |_|            |___/
EOF
echo -e "${NC}"

[[ "$EUID" -eq 0 ]] && die "Do not run as root. Use a sudo-capable user."
[[ ! -f "$PROJECT_DIR/manage.py" ]] && die "manage.py not found in $PROJECT_DIR"
[[ ! -d "$VENV_DIR" ]] && die "Virtual environment not found. Run install.sh first."
[[ ! -f "$PROJECT_DIR/.env" ]] && die ".env not found. Run install.sh first."

info "Deploying to: $SERVER_NAME"
info "Project dir:  $PROJECT_DIR"
info "App user:     $APP_USER"
info "HTTPS mode:   $([ "$USE_LETSENCRYPT" = true ] && echo 'LetsEncrypt' || echo 'Self-signed')"
echo ""

# =============================================================================
# 1. SYSTEM PACKAGES
# =============================================================================
info "Installing Nginx, Gunicorn dependencies, and SSL tools..."
sudo apt-get update -qq
sudo apt-get install -y nginx openssl

if [[ "$USE_LETSENCRYPT" == true ]]; then
  sudo apt-get install -y certbot python3-certbot-nginx
fi
success "System packages ready."

# =============================================================================
# 2. HARDEN .env
# =============================================================================
info "Hardening .env for production..."

ENV_FILE="$PROJECT_DIR/.env"

# Rotate SECRET_KEY
NEW_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(45))")

# Update or add each production value
set_env() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

set_env "DEBUG"         "False"
set_env "SECRET_KEY"    "$NEW_SECRET"
set_env "ALLOWED_HOSTS" "$SERVER_NAME"

success ".env hardened (DEBUG=False, fresh SECRET_KEY, ALLOWED_HOSTS locked)."

# =============================================================================
# 3. FIX CORS FOR PRODUCTION  (Bug #4 from install)
# =============================================================================
info "Fixing CORS settings for production..."

SETTINGS_FILE="$PROJECT_DIR/config/settings.py"

# Remove CORS_ALLOW_ALL_ORIGINS if present
if grep -q "CORS_ALLOW_ALL_ORIGINS" "$SETTINGS_FILE"; then
  sed -i '/^CORS_ALLOW_ALL_ORIGINS/d' "$SETTINGS_FILE"
  warn "  Removed CORS_ALLOW_ALL_ORIGINS = True (was overriding whitelist)"
fi

# Ensure CORS_ALLOWED_ORIGINS includes the server
python3 << PYEOF
import re

path = "$SETTINGS_FILE"
with open(path) as f:
    content = f.read()

entry_http  = f'    "http://$SERVER_NAME",'
entry_https = f'    "https://$SERVER_NAME",'

if entry_https not in content:
    content = re.sub(
        r'(CORS_ALLOWED_ORIGINS\s*=\s*\[)',
        f'\\1\n{entry_http}\n{entry_https}',
        content
    )
    with open(path, "w") as f:
        f.write(content)
    print("  Added server origin to CORS_ALLOWED_ORIGINS.")
else:
    print("  CORS_ALLOWED_ORIGINS already contains server origin.")
PYEOF

success "CORS configured."

# =============================================================================
# 4. INSTALL GUNICORN INTO VENV
# =============================================================================
info "Installing Gunicorn..."
source "$VENV_DIR/bin/activate"
pip install gunicorn --quiet
success "Gunicorn installed."

# =============================================================================
# 5. COLLECT STATIC FILES
# =============================================================================
info "Collecting static files..."
source "$VENV_DIR/bin/activate"
cd "$PROJECT_DIR"
python manage.py collectstatic --noinput
success "Static files collected."

# =============================================================================
# 6. GUNICORN SYSTEMD SERVICE
# =============================================================================
info "Creating Gunicorn systemd service..."

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=IDM Portal — Gunicorn
After=network.target postgresql.service

[Service]
User=${APP_USER}
Group=www-data
WorkingDirectory=${PROJECT_DIR}
EnvironmentFile=${PROJECT_DIR}/.env
ExecStart=${VENV_DIR}/bin/gunicorn \\
    --workers ${GUNICORN_WORKERS} \\
    --bind 127.0.0.1:${DJANGO_PORT} \\
    --timeout 120 \\
    --access-logfile ${PROJECT_DIR}/logs/gunicorn_access.log \\
    --error-logfile  ${PROJECT_DIR}/logs/gunicorn_error.log \\
    config.wsgi:application
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create log directory
mkdir -p "$PROJECT_DIR/logs"
chown "$APP_USER":www-data "$PROJECT_DIR/logs"

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"
success "Gunicorn service running."

# =============================================================================
# 7. SSL CERTIFICATE
# =============================================================================
SSL_DIR="/etc/ssl/idm_portal"
sudo mkdir -p "$SSL_DIR"

if [[ "$USE_LETSENCRYPT" == true ]]; then
  # ── Let's Encrypt ──────────────────────────────────────────────────────────
  info "Obtaining Let's Encrypt certificate for $DOMAIN..."
  sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
    --register-unsafely-without-email
  CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
  KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
  success "Let's Encrypt certificate issued."

else
  # ── Self-signed (IP only) ───────────────────────────────────────────────────
  info "Generating self-signed certificate for $SERVER_IP..."
  warn "  Browsers and Flutter will show a certificate warning."
  warn "  To trust it on Android: copy /etc/ssl/idm_portal/cert.pem to device"
  warn "  and install via Settings → Security → Install certificate."

  sudo openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$SSL_DIR/key.pem" \
    -out    "$SSL_DIR/cert.pem" \
    -subj   "/CN=$SERVER_IP/O=IDM Portal/C=GH" \
    -addext "subjectAltName=IP:$SERVER_IP"

  CERT_PATH="$SSL_DIR/cert.pem"
  KEY_PATH="$SSL_DIR/key.pem"
  success "Self-signed certificate generated at $SSL_DIR"
fi

# =============================================================================
# 8. NGINX CONFIGURATION
# =============================================================================
info "Configuring Nginx..."

NGINX_CONF="/etc/nginx/sites-available/${SERVICE_NAME}"

sudo tee "$NGINX_CONF" > /dev/null << EOF
# IDM Portal — Nginx config
# To upgrade to a domain later:
#   1. Set DOMAIN=yourdomain.com and re-run this script
#   2. Or manually replace server_name and the ssl_certificate paths

# Redirect HTTP → HTTPS
server {
    listen 80;
    server_name ${SERVER_NAME};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${SERVER_NAME};

    ssl_certificate     ${CERT_PATH};
    ssl_certificate_key ${KEY_PATH};
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # Security headers
    add_header X-Frame-Options           DENY;
    add_header X-Content-Type-Options    nosniff;
    add_header X-XSS-Protection          "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # API
    location /api/ {
        proxy_pass         http://127.0.0.1:${DJANGO_PORT};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120;
    }

    # Admin
    location /admin/ {
        proxy_pass         http://127.0.0.1:${DJANGO_PORT};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    # Static files
    location /static/ {
        alias ${PROJECT_DIR}/staticfiles/;
        expires 7d;
        add_header Cache-Control "public";
    }

    # Media files
    location /media/ {
        alias ${PROJECT_DIR}/media/;
        expires 7d;
        add_header Cache-Control "public";
    }
}
EOF

# Enable site
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/${SERVICE_NAME}

# Remove default Nginx site if present
sudo rm -f /etc/nginx/sites-enabled/default

# Test config
sudo nginx -t
sudo systemctl restart nginx
success "Nginx configured and running."

# =============================================================================
# 9. FIREWALL
# =============================================================================
info "Configuring firewall (ufw)..."
if command -v ufw &>/dev/null; then
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  sudo ufw allow OpenSSH
  sudo ufw --force enable
  success "Firewall rules applied (80, 443, SSH)."
else
  warn "ufw not found — configure your firewall manually to allow ports 80 and 443."
fi

# =============================================================================
# 10. SUMMARY
# =============================================================================
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  IDM Portal production deployment complete!${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BLUE}API base:${NC}     https://${SERVER_NAME}/api/"
echo -e "  ${BLUE}Admin panel:${NC}  https://${SERVER_NAME}/admin/"
echo ""
echo -e "  ${BLUE}Service management:${NC}"
echo "    sudo systemctl status  ${SERVICE_NAME}"
echo "    sudo systemctl restart ${SERVICE_NAME}"
echo "    sudo systemctl restart nginx"
echo ""
echo -e "  ${BLUE}Logs:${NC}"
echo "    tail -f ${PROJECT_DIR}/logs/gunicorn_access.log"
echo "    tail -f ${PROJECT_DIR}/logs/gunicorn_error.log"
echo "    sudo journalctl -u ${SERVICE_NAME} -f"
echo ""

if [[ "$USE_LETSENCRYPT" == false ]]; then
  echo -e "  ${YELLOW}Self-signed cert:${NC} ${CERT_PATH}"
  echo -e "  ${YELLOW}To trust on Android Flutter app:${NC}"
  echo "    adb push ${CERT_PATH} /sdcard/idm_cert.pem"
  echo "    Then: Settings → Security → Install certificate → CA certificate"
  echo ""
  echo -e "  ${YELLOW}To upgrade to a real domain later:${NC}"
  echo "    DOMAIN=yourdomain.com ./deploy_production.sh"
fi

echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"