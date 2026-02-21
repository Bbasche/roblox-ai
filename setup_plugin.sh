#!/bin/bash
# setup_plugin.sh — Copy the RobloxAI plugin to Roblox Studio's plugins folder

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$SCRIPT_DIR/plugin/RobloxAI.lua"

echo "🔌  Installing RobloxAI plugin to Roblox Studio..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    PLUGINS_DIR="$HOME/Library/Application Support/Roblox/Plugins"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash)
    PLUGINS_DIR="$LOCALAPPDATA/Roblox/Plugins"
else
    echo "❌  Unsupported OS: $OSTYPE"
    echo "   Manually copy plugin/RobloxAI.lua to your Roblox Plugins folder."
    exit 1
fi

mkdir -p "$PLUGINS_DIR"
cp "$PLUGIN_SRC" "$PLUGINS_DIR/RobloxAI.lua"

echo "✅  Plugin installed to: $PLUGINS_DIR/RobloxAI.lua"
echo ""
echo "Next: Restart Roblox Studio, then run ./start.sh"
