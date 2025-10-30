#!/usr/bin/env bash
set -euo pipefail

# macOS/Linux one-shot setup: start Compose, wait for app, print URL
APP_URL="${APP_URL:-http://localhost:5678}"
ATTEMPTS="${ATTEMPTS:-30}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}" # Allow overriding

echo "== setup.sh =="
echo "Target URL: $APP_URL"
echo "Using compose file: $COMPOSE_FILE"

has() { command -v "$1" >/dev/null 2>&1; }

# 1) Prereqs
if ! has docker; then
  echo "❌ Docker not found. Install Docker Desktop (macOS) or Docker Engine (Linux) and re-run."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
elif has docker-compose; then
  COMPOSE_CMD="docker-compose -f $COMPOSE_FILE"
else
  echo "❌ Docker Compose not found. Install Docker Compose and re-run."
  exit 1
fi

# Tip for Linux users not in docker group
if [[ "$(uname -s)" == "Linux" ]]; then
  if ! id -nG "$USER" | grep -qw docker; then
    echo "ℹ️ Tip: add yourself to 'docker' group to avoid sudo:"
    echo "   sudo usermod -aG docker $USER && newgrp docker"
  fi
fi

# 2) Start cloudflared first
echo "▶️  Starting Cloudflare tunnel..."
$COMPOSE_CMD up -d cloudflared

# 3) Wait for and get the tunnel URL
echo "⏳ Waiting for tunnel URL..."
TUNNEL_URL=""
# We loop 10 times (20s total) for the tunnel to register and log its URL
for i in $(seq 1 10); do
  # Use "|| true" to prevent pipefail from exiting the script if grep finds no match
  # 2>/dev/null hides stderr from logs command (e.g., "container not ready")
  TUNNEL_URL=$($COMPOSE_CMD logs cloudflared 2>/dev/null | grep -E -o "https://[a-zA-Z0-9-]+\.trycloudflare\.com" | tail -n 1 || true)
  if [ -n "$TUNNEL_URL" ]; then
    echo "✅ Got public URL: $TUNNEL_URL"
    break
  fi
  echo "   Attempt $i/10 - Waiting for tunnel URL..."
  sleep 2
done

# Fail if we couldn't get a URL
if [ -z "$TUNNEL_URL" ]; then
  echo "❌ Could not determine Cloudflare Tunnel URL after 20 seconds."
  echo "   Check logs: $COMPOSE_CMD logs cloudflared"
  exit 1
fi

# Export the URL for docker compose to use
export N8N_PUBLIC_URL="$TUNNEL_URL"

# 4) Start n8n (and its dependency, postgres)
echo "▶️  Starting n8n and postgres services..."
$COMPOSE_CMD up -d n8n

# 5) Health: treat 2xx/3xx/4xx (e.g., 401 Basic Auth) as 'ready'
echo "⏳ Waiting for local service at $APP_URL ..."
for _ in $(seq 1 "$ATTEMPTS"); do
  # Use "|| true" to prevent curl from exiting on connection failure
  code="$(curl -s -o /dev/null -w '%{http_code}' "$APP_URL" || true)"
  case "$code" in
    2*|3*|4*) 
      echo "✅ Ready (Local): $APP_URL  (HTTP $code)"
      echo "✅ Ready (Public): $N8N_PUBLIC_URL"
      exit 0
      ;;
  esac
  echo "   Attempt... waiting for $APP_URL"
  sleep "$SLEEP_BETWEEN"
done

echo "⚠️  Containers started, but $APP_URL didn't respond yet."
echo "   Check logs: $COMPOSE_CMD logs -f"
exit 1