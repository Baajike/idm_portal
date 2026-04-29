#!/usr/bin/env bash
# =============================================================================
# IDM Portal — Production Deployment Script (REFINED)
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
# CONFIGURATION
# =============================================================================
SERVER_IP="${SERVER_IP:-192.168.31.146}"
PROJECT_DIR="${PROJECT_DIR:-/home/lelu/idm_portal}"
APP_USER="${APP_USER:-lelu}"
VENV_DIR="$PROJECT_DIR/venv"
DJANGO_PORT="8000"
SERVICE_NAME="idm_portal"
SSL_DIR="/etc/ssl/idm_portal"

# =============================================================================
# 0. PREFLIGHT
# =============================================================================
[[ "$EUID" -eq 0 ]] && die "Do not run as root. Use a sudo-capable user."
[[ ! -f "$PROJECT_DIR/manage.py" ]] && die "manage.py not found in $PROJECT_DIR"

# =============================================================================
# 1. HARDEN .env FOR PRODUCTION
# =============================================================================
info "Hardening .env for production..."
if [[ -f "$PROJECT_DIR/.env" ]]; then
  sed -i "s/DEBUG=True/DEBUG=False/" "$PROJECT_DIR/.env"
  success ".env set to DEBUG=False"
fi

# =============================================================================
# 2. SSL CERTIFICATES
# =============================================================================
if [[ ! -f "$SSL_DIR/cert.pem" ]]; then
  info "Generating self-signed SSL certificate..."
  sudo mkdir -p "$SSL_DIR"
  sudo openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$SSL_DIR/key.pem" \
    -out    "$SSL_DIR/cert.pem" \
    -subj   "/CN=$SERVER_IP/O=IDM Portal/C=GH" \
    -addext "subjectAltName=IP:$SERVER_IP"
  success "SSL certificates generated at $SSL_DIR"
fi

# =============================================================================
# 3. GUNICORN SYSTEMD SERVICE
# =============================================================================
info "Setting up Gunicorn service..."
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
    --workers 3 \\
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

mkdir -p "$PROJECT_DIR/logs"
sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl restart "${SERVICE_NAME}"
success "Gunicorn service running."

# =============================================================================
# 4. NGINX CONFIGURATION (PORT 8443)
# =============================================================================
info "Configuring Nginx on port 8443..."
NGINX_CONF="/etc/nginx/sites-available/${SERVICE_NAME}"

sudo tee "$NGINX_CONF" > /dev/null << EOF
server {
    listen 8443 ssl;
    server_name ${SERVER_IP};

    ssl_certificate     ${SSL_DIR}/cert.pem;
    ssl_certificate_key ${SSL_DIR}/key.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    add_header X-Frame-Options           DENY;
    add_header X-Content-Type-Options    nosniff;
    add_header X-XSS-Protection          "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location /api/ {
        proxy_pass         http://127.0.0.1:${DJANGO_PORT};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120;
    }

    location /admin/ {
        proxy_pass         http://127.0.0.1:${DJANGO_PORT};
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location /static/ {
        alias ${PROJECT_DIR}/staticfiles/;
        expires 7d;
        add_header Cache-Control "public";
    }

    location /media/ {
        alias ${PROJECT_DIR}/media/;
        expires 7d;
        add_header Cache-Control "public";
    }

    location / {
        root ${PROJECT_DIR};
        index text.html;
        try_files \$uri \$uri/ =404;
    }
}
EOF

sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/${SERVICE_NAME}
sudo nginx -t
sudo systemctl restart nginx
success "Nginx configured on port 8443."

# =============================================================================
# 5. FIREWALL
# =============================================================================
if command -v ufw &>/dev/null; then
  sudo ufw allow 8443/tcp
  success "Firewall rule for 8443 ensured."
fi

info "Deployment complete! IDM Portal is live at https://${SERVER_IP}:8443"
info "Note: Port 80 and 443 are untouched and reserved for LELU."