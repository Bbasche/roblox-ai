#!/usr/bin/env python3
"""
Roblox AI MCP Server
Exposes tools to Claude Code so it can control Roblox Studio in real time.
"""

import httpx
from mcp.server.fastmcp import FastMCP

BRIDGE_URL = "http://localhost:8765"

mcp = FastMCP("Roblox Studio AI")


# ─── Internal helper ────────────────────────────────────────────────────────

async def _call_bridge(lua_code: str, description: str = "") -> dict:
    try:
        async with httpx.AsyncClient(timeout=35.0) as client:
            resp = await client.post(
                f"{BRIDGE_URL}/api/execute",
                json={"lua_code": lua_code, "description": description},
            )
            return resp.json()
    except httpx.ConnectError:
        return {
            "success": False,
            "error": "Bridge server not running. Open a terminal and run: python bridge_server.py",
        }
    except Exception as e:
        return {"success": False, "error": f"Bridge error: {e}"}


def _fmt(result: dict) -> str:
    if result.get("success"):
        return f"✅ {result.get('result', 'Done')}"
    return f"❌ {result.get('error', 'Unknown error')}"


# ─── Tools ──────────────────────────────────────────────────────────────────

@mcp.tool()
async def execute_lua(code: str, description: str = "") -> str:
    """
    Execute Lua code inside Roblox Studio RIGHT NOW.

    Use this tool for EVERY change the user wants to make to their game —
    adding parts, writing scripts, changing lighting, building structures, etc.

    Args:
        code: Valid Lua code. Should end with:
              return "description of what was created/changed"
        description: One-line summary of what the code does (shown in Studio log).

    Returns:
        Confirmation message or error details from Studio.
    """
    return _fmt(await _call_bridge(code, description))


@mcp.tool()
async def get_game_state() -> str:
    """
    Read the current structure of the Roblox game (workspace tree, scripts, etc.)
    Call this before making edits so you know what's already in the game.
    Returns a JSON tree of all objects in the workspace.
    """
    lua = """
local HttpService = game:GetService("HttpService")
local function tree(inst, depth)
    depth = depth or 0
    if depth > 4 then return {name=inst.Name, class=inst.ClassName} end
    local node = {name=inst.Name, class=inst.ClassName, children={}}
    if inst:IsA("BasePart") then
        node.pos      = tostring(inst.Position)
        node.size     = tostring(inst.Size)
        node.color    = tostring(inst.BrickColor)
        node.anchored = inst.Anchored
    end
    for _, c in ipairs(inst:GetChildren()) do
        if not c:IsA("Terrain") then
            table.insert(node.children, tree(c, depth+1))
        end
    end
    return node
end
local out = {workspace = tree(game.Workspace), scripts = {}}
for _, c in ipairs(game.ServerScriptService:GetChildren()) do
    table.insert(out.scripts, {name=c.Name, class=c.ClassName})
end
return HttpService:JSONEncode(out)
"""
    result = await _call_bridge(lua, "get_game_state")
    if result.get("success"):
        return result.get("result", "{}")
    return f"Could not read game state: {result.get('error')}"


@mcp.tool()
async def check_connection() -> str:
    """
    Check whether Roblox Studio is connected and the bridge server is running.
    Call this if you're unsure whether Studio is ready to receive commands.
    """
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            s = (await client.get(f"{BRIDGE_URL}/api/status")).json()
        if s.get("plugin_connected"):
            return "✅ Roblox Studio is connected and ready!"
        lag = s.get("last_ping_ago")
        if lag is None:
            return (
                "⚠️  Studio plugin hasn't connected yet.\n"
                "Steps:\n"
                "  1. Open Roblox Studio\n"
                "  2. Install the RobloxAI plugin (see README)\n"
                "  3. Click 'AI Assistant' in the Plugins toolbar to activate it"
            )
        return f"⚠️  Plugin last seen {lag}s ago — it may have disconnected. Re-click the button in Studio."
    except Exception:
        return "❌ Bridge server not running. Run: python bridge_server.py"


@mcp.tool()
async def clear_workspace() -> str:
    """
    Remove ALL parts, models, and scripts from the current game.
    Use this when the user wants to start fresh.
    """
    lua = """
local count = 0
for _, child in ipairs(workspace:GetChildren()) do
    if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") then
        child:Destroy(); count = count + 1
    end
end
for _, child in ipairs(game.ServerScriptService:GetChildren()) do
    child:Destroy()
end
for _, child in ipairs(game.StarterGui:GetChildren()) do
    child:Destroy()
end
return "Cleared workspace — removed " .. count .. " objects and all scripts"
"""
    return _fmt(await _call_bridge(lua, "clear_workspace"))


if __name__ == "__main__":
    mcp.run()
