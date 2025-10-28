#!/usr/bin/env bash
echo "Looking for your public n8n URL..."
url=$(docker compose logs --tail 200 cloudflared 2>&1 | grep -oE 'https://[^ ]+' | head -n1)
if [ -n "$url" ]; then
  echo -e "\nYour public n8n URL is:\n$url\n"
else
  echo "No tunnel URL found yet. Wait a few seconds and try again."
fi
