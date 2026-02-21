# roblox-ai

**Build Roblox games by chatting with AI — no coding experience needed.**

Describe what you want in plain English. Claude writes and executes the Lua code live in Roblox Studio. Changes appear instantly as you talk.

```
You:    "Make me an obby with 10 platforms and lava at the bottom"
You:    "Add a spinning obstacle on platform 5"
You:    "Give me a leaderboard that tracks coins"
You:    "Make the sky look like sunset"
You:    "Start over — I want to build a tycoon instead"
```

---

## How it works

```
You (Claude Code chat)
        │
   MCP Server (Python)        ← exposes tools to Claude
        │  HTTP
  Bridge Server :8765          ← queues commands locally
        │  polls every 0.5s
 Roblox Studio Plugin (Lua)   ← executes Lua live in Studio
```

Claude generates Lua → bridge relays it → plugin runs it → you see it instantly.

---

## Requirements

- **Python 3.9+**
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** (Claude's CLI — needs a Claude account)
- **Roblox Studio** (free at [roblox.com](https://www.roblox.com/create))

---

## Setup (one time, ~5 minutes)

### 1. Clone the repo

```bash
git clone https://github.com/Bbasche/roblox-ai.git
cd roblox-ai
```

### 2. Install Python dependencies

```bash
pip3 install -r requirements.txt
```

### 3. Install the Roblox Studio plugin

**Mac:**
```bash
./setup_plugin.sh
```

**Windows (PowerShell):**
```powershell
Copy-Item "plugin\RobloxAI.lua" "$env:LOCALAPPDATA\Roblox\Plugins\RobloxAI.lua"
```

**Or manually:** copy `plugin/RobloxAI.lua` to your Roblox Plugins folder, then restart Studio.

> To find your Plugins folder: open Roblox Studio → Plugins tab → Plugins Folder

### 4. Register the MCP server with Claude Code

```bash
claude mcp add roblox-studio python3 /absolute/path/to/roblox-ai/mcp_server.py
```

*(Replace `/absolute/path/to/roblox-ai` with where you cloned the repo.)*

---

## Usage

### Every session

```bash
cd roblox-ai
./start.sh
```

This starts the bridge server and opens Claude Code with `--dangerously-skip-permissions` enabled by default, so Claude can execute game changes without prompting you to approve every single action.

> ⚠️ **Permissions note:** `start.sh` passes `--dangerously-skip-permissions` to Claude Code. This means Claude will execute Lua code in your Roblox Studio session without asking for confirmation each time — which is intentional, since approving every game change would make the experience painful. Only run this on your own machine with a game you're actively building. If you prefer per-action approval, remove `--dangerously-skip-permissions` from the last line of `start.sh`.

Then in **Roblox Studio**:
1. Open a place (File → New, or open an existing one)
2. **Plugins tab → click "AI Assistant"** to connect
3. The plugin panel should show a green "Connected" dot

Now just chat. Claude will modify your game in real time.

---

## Example session

```
You:     What should I build?

Claude:  Let's start with something fun! How about an obby (obstacle course)?
         I can build you platforms, lava, moving obstacles, coins to collect,
         and a leaderboard. Want to try that?

You:     Yes! Make it space-themed

Claude:  [builds 12 platforms with a starry atmosphere, glowing neon obstacles,
          and a dark sky]
         Done! I built a space obby with 12 platforms climbing up to 120 studs.
         There's lava at the bottom, 3 spinning obstacles, and a sunset-purple sky.
         Want me to add coins to collect or a checkpoint halfway through?

You:     Add coins and make one platform shoot you upward

Claude:  [adds 8 spinning gold coins + a launch pad with a script]
         Added 8 coins scattered through the course and a yellow launch pad on
         platform 6 that rockets you up. Want a leaderboard to track the coins?
```

---

## Sharing images for creative direction

You can give Claude visual references — character art, screenshots of games you love, level sketches, color palettes — and it will translate them into your Roblox game.

**How to use it:**

1. Drop the image file into the `roblox-ai/` folder (or anywhere on your computer)
2. Tell Claude: `"Load my reference image: character.png"` (or paste the full path)
3. Claude calls `load_reference_image` and can now **see** the image
4. It describes what it sees and immediately builds it in Studio

```
You:     Load my image: hero_design.png
Claude:  I can see a character with dark armor, glowing blue accents, and a cape.
         Let me build this as a Roblox model — dark grey parts for the body,
         Neon cyan for the accents, and a trailing part for the cape effect...
         [builds it live in Studio]
```

Supported formats: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`

---

## Supported game types

Claude knows how to build (and will guide you through):

| Type | Description |
|------|-------------|
| **Obby** | Obstacle course with platforms, lava, checkpoints |
| **Tycoon** | Base + money dropper + buyable buildings |
| **Simulator** | Click to collect, upgrade, prestige |
| **Roleplay/Town** | Buildings, terrain, NPCs, day-night cycle |
| **Anything else** | Just describe it |

---

## Troubleshooting

**"Bridge server not running"**
→ Start it manually: `python3 bridge_server.py`

**Plugin shows "Cannot reach bridge"**
→ Make sure `bridge_server.py` is running in another terminal first, then click "AI Assistant" again.

**Changes aren't appearing in Studio**
→ Make sure the plugin panel shows the green "Connected" dot. Re-click the button if needed.

**Port 8765 in use**
```bash
lsof -i :8765   # find what's using it
```

---

## File structure

```
roblox-ai/
├── bridge_server.py    ← HTTP bridge (FastAPI, port 8765)
├── mcp_server.py       ← MCP server (Claude's tools)
├── mcp_config.json     ← MCP config reference
├── requirements.txt    ← Python deps
├── start.sh            ← Start everything + open Claude Code
├── setup_plugin.sh     ← Install plugin to Roblox Studio (Mac)
├── CLAUDE.md           ← System prompt auto-loaded by Claude Code
└── plugin/
    └── RobloxAI.lua    ← Roblox Studio plugin
```

---

## Contributing

PRs welcome. Some ideas:
- Windows `start.bat` equivalent of `start.sh`
- More game templates in `CLAUDE.md`
- Better error messages from the plugin
- Support for other AI CLIs (Cursor, Windsurf, etc.)

---

## License

MIT
