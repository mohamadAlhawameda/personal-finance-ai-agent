#!/bin/bash
# Restart Cloudflare Tunnel and Get New URL

set -e

echo "🔄 Restarting Cloudflare Tunnel..."

# Check if Docker Compose is available
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not found!"
    exit 1
fi

# Check Docker health first
echo "🔍 Checking Docker container status..."

# Check if n8n is running
if docker ps --filter "name=n8n" --filter "status=running" --format "table {{.Names}}" | grep -q "n8n"; then
    echo "✅ n8n container is running"
else
    echo "⚠️  n8n container is not running. Starting the full stack first..."
    $COMPOSE_CMD up -d
    sleep 10
fi

# Check if cloudflared exists
if docker ps -a --filter "name=cloudflared" --format "table {{.Names}}" | grep -q "cloudflared"; then
    echo "✅ Cloudflared container found"
else
    echo "❌ Cloudflared container not found. Make sure it's uncommented in docker-compose.yml"
    exit 1
fi

# Stop cloudflared container
echo "⏹️  Stopping cloudflared container..."
$COMPOSE_CMD stop cloudflared

# Wait a moment
sleep 3

# Start cloudflared container
echo "▶️  Starting cloudflared container..."
$COMPOSE_CMD start cloudflared

# Wait for tunnel to establish
echo "⏳ Waiting for tunnel to establish (15 seconds)..."
sleep 15

# Get the new tunnel URL with retries
echo "🔍 Getting tunnel URL..."
MAX_RETRIES=3
TUNNEL_URL=""

for i in $(seq 1 $MAX_RETRIES); do
    TUNNEL_URL=$($COMPOSE_CMD logs cloudflared | grep -oE 'https://[^[:space:]]*\.trycloudflare\.com' | tail -1)
    
    if [ -n "$TUNNEL_URL" ]; then
        break
    else
        echo "⏳ Attempt $i/$MAX_RETRIES - Waiting for tunnel URL..."
        sleep 10
    fi
done

if [ -n "$TUNNEL_URL" ]; then
    echo ""
    echo "✅ Tunnel restarted successfully!"
    echo "🌐 New Tunnel URL: $TUNNEL_URL"
    echo ""
    
    # Try to copy to clipboard (if available)
    if command -v pbcopy &> /dev/null; then
        echo "$TUNNEL_URL" | pbcopy
        echo "✅ URL copied to clipboard! (macOS)"
    elif command -v xclip &> /dev/null; then
        echo "$TUNNEL_URL" | xclip -selection clipboard
        echo "✅ URL copied to clipboard! (Linux)"
    elif command -v wl-copy &> /dev/null; then
        echo "$TUNNEL_URL" | wl-copy
        echo "✅ URL copied to clipboard! (Wayland)"
    else
        echo "📋 Copy the URL above manually"
    fi
    
    # Test the URL
    echo "🧪 Testing tunnel connectivity..."
    if command -v curl &> /dev/null; then
        if curl -I -s --connect-timeout 10 "$TUNNEL_URL" > /dev/null; then
            echo "✅ Tunnel is responding"
        else
            echo "⚠️  Tunnel URL found but not responding yet. Give it a moment..."
        fi
    else
        echo "💡 Install curl to test tunnel connectivity"
    fi
    
else
    echo "❌ Could not find tunnel URL in logs after $MAX_RETRIES attempts"
    echo "📋 Check logs manually:"
    echo "   $COMPOSE_CMD logs cloudflared"
    exit 1
fi

echo ""
echo "💡 Tip: If the tunnel disconnects again, run this script: ./restart_tunnel.sh"
