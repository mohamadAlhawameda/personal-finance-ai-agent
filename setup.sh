#!/usr/bin/env bash
set -euo pipefail

# macOS/Linux one-shot setup: start Compose, wait for app, print URL
APP_URL="${APP_URL:-http://localhost:5678}"
ATTEMPTS="${ATTEMPTS:-30}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"

echo "== setup.sh =="
echo "Target URL: $APP_URL"

has() { command -v "$1" >/dev/null 2>&1; }

# 1) Prereqs
if ! has docker; then
  echo "❌ Docker not found. Install Docker Desktop (macOS) or Docker Engine (Linux) and re-run."
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif has docker-compose; then
  COMPOSE_CMD="docker-compose"
else
  echo "❌ Docker Compose not found. Install Docker Compose and re-run."
  exit 1
fi

# Tip for Linux users not in docker group (don’t block)
if [[ "$(uname -s)" == "Linux" ]]; then
  if ! id -nG "$USER" | grep -qw docker; then
    echo "ℹ️ Tip: add yourself to 'docker' group to avoid sudo:"
    echo "   sudo usermod -aG docker $USER && newgrp docker"
  fi
fi

# 2) Start stack
echo "▶️  Starting services..."
$COMPOSE_CMD up -d

# 3) Health: treat 2xx/3xx/4xx (e.g., 401 Basic Auth) as 'ready'
echo "⏳ Waiting for service at $APP_URL ..."
for _ in $(seq 1 "$ATTEMPTS"); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$APP_URL" || true)"
  case "$code" in
    2*|3*|4*) echo "✅ Ready: $APP_URL  (HTTP $code)"; exit 0;;
  esac
  sleep "$SLEEP_BETWEEN"
done

echo "⚠️  Containers started, but $APP_URL didn't respond yet."
echo "   Check logs: $COMPOSE_CMD logs -f"
exit 1
