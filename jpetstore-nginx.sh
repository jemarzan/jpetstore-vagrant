#!/bin/bash
# ==============================================================================
# Nginx Provisioning Script — JPetStore 6 Reverse Proxy
# For: Vagrant VM (Ubuntu-based — ubuntu/jammy64)
# Usage: Add to Vagrantfile as: config.vm.provision "shell", path: "jpetstore-nginx.sh"
# ==============================================================================

# ── CHANGE THESE BEFORE USE ───────────────────────────────────────────────────
NGINX_PORT=80                      # Port Nginx listens on (public-facing)

APP_HOST="192.168.56.12"           # app01 VM IP — where Tomcat is running
APP_PORT=8080                      # Tomcat port on app01
APP_CONTEXT="jpetstore"            # WAR context path (e.g. jpetstore → /jpetstore)

SERVER_NAME="web01"                # Nginx server_name (hostname or domain)
# ─────────────────────────────────────────────────────────────────────────────

echo "##################################################"
echo "   JPetStore 6 — Nginx Provisioning Started"
echo "##################################################"

# -----------------------------------------------------------------------------
# STEP 1 — System update & install Nginx
# -----------------------------------------------------------------------------
echo "[1/5] Updating system and installing Nginx..."
sudo apt-get update -y
sudo apt-get install -y nginx

# -----------------------------------------------------------------------------
# STEP 2 — Start and enable Nginx
# -----------------------------------------------------------------------------
echo "[2/5] Starting Nginx service..."
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl status nginx --no-pager

# -----------------------------------------------------------------------------
# STEP 3 — Write Nginx reverse proxy config for JPetStore
# -----------------------------------------------------------------------------
echo "[3/5] Configuring Nginx as reverse proxy → ${APP_HOST}:${APP_PORT}/${APP_CONTEXT}..."

sudo bash -c "cat > /etc/nginx/sites-available/jpetstore <<'NGINXCONF'
upstream jpetstore_app {
    server ${APP_HOST}:${APP_PORT};
}

server {
    listen ${NGINX_PORT};
    server_name ${SERVER_NAME};

    # Redirect root to /jpetstore
    location = / {
        return 301 /jpetstore;
    }

    # Proxy all /jpetstore requests to Tomcat app01
    location /${APP_CONTEXT} {
        proxy_pass         http://jpetstore_app/${APP_CONTEXT};
        proxy_http_version 1.1;

        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;

        # Timeouts — give Tomcat time to respond
        proxy_connect_timeout  60s;
        proxy_send_timeout     60s;
        proxy_read_timeout     60s;

        # Buffer settings for better performance
        proxy_buffering    on;
        proxy_buffer_size  8k;
        proxy_buffers      8 8k;
    }

    # Serve a simple health check endpoint
    location /health {
        return 200 'Nginx is up\n';
        add_header Content-Type text/plain;
    }

    # Custom error pages
    error_page 502 503 504 /50x.html;
    location = /50x.html {
        return 503 'App server is not reachable. Make sure app01 (Tomcat) is running.\n';
        add_header Content-Type text/plain;
    }
}
NGINXCONF"

# -----------------------------------------------------------------------------
# STEP 4 — Enable the site and remove the default config
# -----------------------------------------------------------------------------
echo "[4/5] Enabling site config..."

# Enable jpetstore site
sudo ln -sf /etc/nginx/sites-available/jpetstore /etc/nginx/sites-enabled/jpetstore

# Disable the default Nginx welcome page
sudo rm -f /etc/nginx/sites-enabled/default

# Test the config before reloading (catches typos before breaking Nginx)
echo "      Testing Nginx config..."
sudo nginx -t

# Reload Nginx to apply the new config
sudo systemctl reload nginx

# -----------------------------------------------------------------------------
# STEP 5 — Open firewall port 80
# -----------------------------------------------------------------------------
echo "[5/5] Configuring firewall..."

# Ubuntu uses ufw by default
sudo ufw allow 'Nginx Full'   2>/dev/null || true
sudo ufw allow 22/tcp         2>/dev/null || true   # keep SSH open!
sudo ufw --force enable       2>/dev/null || true

sudo systemctl restart nginx

# -----------------------------------------------------------------------------
# Done — print a quick summary
# -----------------------------------------------------------------------------
echo ""
echo "##################################################"
echo "   Provisioning Complete!"
echo "##################################################"
echo "  Nginx Port     : ${NGINX_PORT}"
echo "  Server Name    : ${SERVER_NAME}"
echo "  Upstream App   : ${APP_HOST}:${APP_PORT}"
echo "  App Context    : /${APP_CONTEXT}"
echo "  Service        : nginx (enabled on boot)"
echo "##################################################"
echo ""
echo "  Access the app at:"
echo "  http://192.168.56.11"
echo "  (redirects to http://192.168.56.11/${APP_CONTEXT})"
echo ""
echo "  Health check:"
echo "  http://192.168.56.11/health"
echo "##################################################"
