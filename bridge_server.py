#!/usr/bin/env python3
"""
Roblox AI Bridge Server — runs on localhost:8765
Bridges the MCP server (Claude) <-> Roblox Studio Plugin
"""

import asyncio
import uuid
import time
from collections import deque
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="Roblox AI Bridge")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# State
pending_commands: deque = deque()
results: dict = {}
last_plugin_ping: float = 0


class Result(BaseModel):
    id: str
    success: bool
    result: str = ""
    error: str = ""


class ExecuteRequest(BaseModel):
    lua_code: str
    description: str = ""


@app.get("/api/command")
async def get_command():
    """Roblox Studio plugin polls this endpoint every 0.5s"""
    global last_plugin_ping
    last_plugin_ping = time.time()
    if pending_commands:
        return pending_commands.popleft()
    return None


@app.post("/api/result")
async def post_result(result: Result):
    """Plugin sends execution results back here"""
    results[result.id] = result.dict()
    return {"ok": True}


@app.post("/api/execute")
async def execute(req: ExecuteRequest):
    """MCP server posts Lua commands here and waits for the result"""
    cmd_id = str(uuid.uuid4())
    pending_commands.append({
        "id": cmd_id,
        "lua_code": req.lua_code,
        "description": req.description,
    })

    # Wait up to 30 seconds for Studio to execute and return
    for _ in range(600):
        await asyncio.sleep(0.05)
        if cmd_id in results:
            return results.pop(cmd_id)

    # Timed out — clean up pending queue
    try:
        pending_commands.remove(next(c for c in pending_commands if c["id"] == cmd_id))
    except (StopIteration, ValueError):
        pass

    return {
        "id": cmd_id,
        "success": False,
        "result": "",
        "error": (
            "Timeout: Roblox Studio didn't respond in 30 seconds. "
            "Is the plugin running and activated? Click 'AI Assistant' in the Studio toolbar."
        ),
    }


@app.get("/api/status")
async def status():
    plugin_connected = (time.time() - last_plugin_ping) < 3.0
    return {
        "bridge": "running",
        "plugin_connected": plugin_connected,
        "pending_commands": len(pending_commands),
        "last_ping_ago": round(time.time() - last_plugin_ping, 1) if last_plugin_ping > 0 else None,
    }


if __name__ == "__main__":
    print("🎮 Roblox AI Bridge Server starting on http://localhost:8765")
    print("   Keep this running while using the AI assistant in Roblox Studio.\n")
    uvicorn.run(app, host="127.0.0.1", port=8765, log_level="warning")
