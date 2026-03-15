#!/usr/bin/env bash
# =============================================================================
# Board Game Catalog — One-time server setup for boardgames.tendimensions.com
# =============================================================================
#
# Run this script ONCE on the Linode to create the nginx virtual host that
# routes traffic for boardgames.tendimensions.com to the Docker container.
#
# Usage (run directly on the server, or pipe through SSH from your machine):
#
#   On the server:
#     sudo bash ~/server-setup.sh
#
#   From your Windows machine:
#     scp server-setup.sh user@<linode-ip>:~/
#     ssh user@<linode-ip> "sudo bash ~/server-setup.sh"
#
#   To add SSL after DNS has propagated (run again with --with-ssl):
#     ssh user@<linode-ip> "sudo bash ~/server-setup.sh --with-ssl"
#
# Prerequisites on the server:
#   - nginx installed  (sudo apt install nginx)
#   - Docker + docker compose installed
#   - The deploy.ps1 deployment run at least once so the container exists
#
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

DOMAIN="boardgames.tendimensions.com"
CONTAINER_PORT="8000"
NGINX_AVAILABLE="/etc/nginx/sites-available/${DOMAIN}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}"
WITH_SSL=false

# ── Argument parsing ──────────────────────────────────────────────────────────

for arg in "$@"; do
  case $arg in
    --with-ssl) WITH_SSL=true ;;
    --help|-h)
      echo "Usage: sudo bash server-setup.sh [--with-ssl]"
      echo ""
      echo "  (no flag)    Create HTTP-only nginx config. Run this first."
      echo "  --with-ssl   Run certbot to add HTTPS. Run after DNS has propagated."
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg  (use --help)" >&2
      exit 1
      ;;
  esac
done

# ── Colour helpers ────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
step()  { echo -e "\n${CYAN}▶  $*${NC}"; }
ok()    { echo -e "   ${GREEN}✓  $*${NC}"; }
warn()  { echo -e "   ${YELLOW}⚠  $*${NC}"; }
fail()  { echo -e "   ${RED}✗  $*${NC}"; }

# ── Root check ────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  fail "This script must be run as root (use: sudo bash $0)"
  exit 1
fi

# ── nginx present? ────────────────────────────────────────────────────────────

step "Checking for nginx..."
if ! command -v nginx &>/dev/null; then
  fail "nginx is not installed."
  echo "     Install it with:  sudo apt update && sudo apt install -y nginx"
  exit 1
fi
ok "nginx found: $(nginx -v 2>&1 | head -1)"

# ── Port conflict check ───────────────────────────────────────────────────────

step "Checking port ${CONTAINER_PORT}..."
if ss -tlnp 2>/dev/null | grep -q ":${CONTAINER_PORT} " || \
   netstat -tlnp 2>/dev/null | grep -q ":${CONTAINER_PORT} "; then
  warn "Something is already listening on port ${CONTAINER_PORT}."
  warn "If it is not the boardgame_catalog container, you may have a conflict."
  warn "Check with:  ss -tlnp | grep :${CONTAINER_PORT}"
else
  ok "Port ${CONTAINER_PORT} looks free (container will bind to it)"
fi

# ── SSL branch: run certbot and exit ─────────────────────────────────────────

if [[ "$WITH_SSL" == "true" ]]; then
  step "Setting up SSL with Certbot for ${DOMAIN}..."

  if ! command -v certbot &>/dev/null; then
    fail "certbot is not installed."
    echo "     Install it with:"
    echo "       sudo apt install -y certbot python3-certbot-nginx"
    exit 1
  fi

  # Verify DNS resolves to this machine before requesting a certificate
  step "Checking DNS resolution for ${DOMAIN}..."
  SERVER_IP=$(curl -s -4 https://ifconfig.me 2>/dev/null || curl -s -4 https://icanhazip.com 2>/dev/null || echo "UNKNOWN")
  DOMAIN_IP=$(getent hosts "${DOMAIN}" | awk '{print $1}' 2>/dev/null || echo "UNRESOLVED")

  if [[ "$SERVER_IP" == "UNKNOWN" ]]; then
    warn "Could not determine this server's public IP. Proceeding anyway."
  elif [[ "$DOMAIN_IP" != "$SERVER_IP" ]]; then
    warn "${DOMAIN} resolves to ${DOMAIN_IP}, but this server's IP is ${SERVER_IP}."
    warn "DNS has not propagated yet, or the A record is pointing elsewhere."
    warn "Certbot will fail if DNS does not point here. Continue anyway? (y/N)"
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  else
    ok "DNS for ${DOMAIN} → ${DOMAIN_IP} (matches this server)"
  fi

  certbot --nginx \
    --non-interactive \
    --agree-tos \
    --redirect \
    --domain "${DOMAIN}" \
    --email "admin@tendimensions.com"

  ok "Certbot complete. nginx has been updated for HTTPS."
  echo ""
  echo "  Certbot auto-renewal is managed by a systemd timer."
  echo "  Verify with:  sudo systemctl status certbot.timer"
  echo ""
  nginx -t && systemctl reload nginx
  ok "nginx reloaded with SSL config"
  exit 0
fi

# ── Create HTTP-only nginx config ─────────────────────────────────────────────

step "Writing nginx config for ${DOMAIN}..."

if [[ -f "$NGINX_AVAILABLE" ]]; then
  warn "Config already exists at ${NGINX_AVAILABLE}. Overwriting."
fi

cat > "$NGINX_AVAILABLE" << NGINX_EOF
# Board Game Catalog — ${DOMAIN}
# Generated by server-setup.sh
# Run "sudo bash server-setup.sh --with-ssl" after DNS propagates to add HTTPS.

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    # Let Certbot handle its ACME challenge without proxying
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass         http://127.0.0.1:${CONTAINER_PORT};
        proxy_http_version 1.1;

        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;

        # Timeouts — BGG sync can take up to 60 s for large collections
        proxy_read_timeout    90s;
        proxy_connect_timeout 10s;
        proxy_send_timeout    90s;

        # Allow reasonably large uploads (game images, etc.)
        client_max_body_size 10M;
    }
}
NGINX_EOF

ok "Config written to ${NGINX_AVAILABLE}"

# ── Enable the site ───────────────────────────────────────────────────────────

step "Enabling site..."

if [[ -L "$NGINX_ENABLED" ]]; then
  warn "Symlink already exists at ${NGINX_ENABLED}. Skipping."
else
  ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
  ok "Symlink created: ${NGINX_ENABLED}"
fi

# ── Make certbot root dir (needed before certbot runs) ────────────────────────

mkdir -p /var/www/certbot

# ── Test and reload nginx ─────────────────────────────────────────────────────

step "Testing nginx configuration..."
if nginx -t 2>&1; then
  ok "nginx config valid"
else
  fail "nginx config has errors — see output above. Rolling back."
  rm -f "$NGINX_ENABLED"
  exit 1
fi

step "Reloading nginx..."
systemctl reload nginx
ok "nginx reloaded"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  nginx is now routing ${DOMAIN} → localhost:${CONTAINER_PORT}${NC}"
echo ""
echo    "  Next steps:"
echo    ""
echo    "  1. Register the DNS A record for ${DOMAIN}"
echo    "     pointing to this server's IP:  $(curl -s -4 https://ifconfig.me 2>/dev/null || echo '<your-linode-ip>')"
echo    ""
echo    "  2. Deploy the application (from your Windows machine):"
echo    "     .\\deploy.ps1 -Ssh <user>@<linode-ip>"
echo    ""
echo    "  3. Once DNS has propagated, add HTTPS:"
echo    "     sudo apt install -y certbot python3-certbot-nginx"
echo    "     sudo bash ~/server-setup.sh --with-ssl"
echo    ""
echo    "  Useful diagnostics:"
echo    "     sudo nginx -t                          # validate config"
echo    "     sudo systemctl status nginx            # nginx health"
echo    "     docker logs boardgame_catalog          # app logs"
echo    "     curl -H 'Host: ${DOMAIN}' http://localhost/  # test proxy"
echo -e "${GREEN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
