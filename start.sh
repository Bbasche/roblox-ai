#!/bin/bash
# start.sh — Start the Roblox AI game builder
# Usage: ./start.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "🎮  Roblox AI Game Builder"
echo "─────────────────────────────────────────"
echo ""

# Check Python
if ! command -v python3 &>/dev/null; then
    echo "❌  Python 3 not found. Install it from https://python.org"
    exit 1
fi

# Install deps if needed
if ! python3 -c "import fastapi, uvicorn, httpx, mcp" 2>/dev/null; then
    echo "📦  Installing Python dependencies..."
    pip3 install -r "$SCRIPT_DIR/requirements.txt" -q
    echo "✅  Dependencies installed."
    echo ""
fi

# Start bridge server in background
echo "🔌  Starting bridge server on localhost:8765..."
python3 "$SCRIPT_DIR/bridge_server.py" &
BRIDGE_PID=$!
sleep 1

# Verify it started
if ! kill -0 $BRIDGE_PID 2>/dev/null; then
    echo "❌  Bridge server failed to start. Check for port conflicts on 8765."
    exit 1
fi

echo "✅  Bridge server running (PID $BRIDGE_PID)"
echo ""
echo "─────────────────────────────────────────"
echo "📋  Now do these steps in Roblox Studio:"
echo "     1. Open Roblox Studio → open any place"
echo "     2. Plugins tab → click  'AI Assistant'  to connect"
echo "     3. You should see 'Connected' in the plugin panel"
echo "─────────────────────────────────────────"
echo ""
echo "💬  Opening Claude Code... start chatting to build your game!"
echo "     (Press Ctrl+C here to stop everything)"
echo ""

# Open Claude Code with MCP config
claude --mcp-config "$SCRIPT_DIR/mcp_config.json" --dangerously-skip-permissions

# Cleanup on exit
echo ""
echo "Shutting down bridge server..."
kill $BRIDGE_PID 2>/dev/null
echo "Done. Goodbye!"
