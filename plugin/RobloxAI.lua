-- RobloxAI.lua  —  Roblox Studio Plugin
-- Polls a local bridge server and executes Lua commands sent from Claude AI.
--
-- INSTALL (choose one method):
--   A) Copy this file to:
--        Windows: %LOCALAPPDATA%\Roblox\Plugins\RobloxAI.lua
--        Mac:     ~/Library/Application Support/Roblox/Plugins/RobloxAI.lua
--      Then restart Roblox Studio.
--   B) In Studio → Plugins tab → "Plugins Folder" button → paste file there.
--
-- USAGE:
--   1. Start bridge_server.py first  (python bridge_server.py)
--   2. Open Roblox Studio and open any place
--   3. Click "AI Assistant" in the Plugins toolbar
--   4. Chat with Claude in your terminal — changes appear live in Studio!

local HttpService   = game:GetService("HttpService")
local RunService    = game:GetService("RunService")

local BRIDGE        = "http://127.0.0.1:8765"
local POLL_INTERVAL = 0.5   -- seconds between polls

-- ── Toolbar button ────────────────────────────────────────────────────────
local toolbar = plugin:CreateToolbar("AI Assistant")
local toggleBtn = toolbar:CreateButton(
    "AI Assistant",
    "Activate / Deactivate the Claude AI game-builder",
    "rbxassetid://4483345998"   -- robot-face icon (built-in asset)
)

-- ── Status widget ─────────────────────────────────────────────────────────
local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    false, false,   -- enabled, override-prev-state
    300, 140,       -- default size
    240, 100        -- min size
)
local widget = plugin:CreateDockWidgetPluginGui("RobloxAI_Widget", widgetInfo)
widget.Title = "Claude AI Game Builder"

local bg = Instance.new("Frame")
bg.Size             = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
bg.BorderSizePixel  = 0
bg.Parent           = widget

local function makeLabel(text, yPos, size, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, -20, 0, size or 22)
    lbl.Position            = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3          = color or Color3.fromRGB(210, 210, 210)
    lbl.TextSize            = size or 14
    lbl.Font                = Enum.Font.GothamMedium
    lbl.Text                = text
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.TextWrapped         = true
    lbl.Parent              = bg
    return lbl
end

local statusDot  = makeLabel("⬤  Disconnected", 10, 16, Color3.fromRGB(180, 60, 60))
local statusLine = makeLabel("Click the toolbar button to connect.", 34, 13, Color3.fromRGB(130, 130, 140))
local cmdLine    = makeLabel("", 60, 13, Color3.fromRGB(100, 190, 100))
local errLine    = makeLabel("", 84, 13, Color3.fromRGB(220, 100, 100))
local countLine  = makeLabel("Commands run: 0", 108, 12, Color3.fromRGB(90, 90, 100))

local cmdCount = 0

local function setStatus(dot, line, dotColor)
    statusDot.Text       = "⬤  " .. dot
    statusDot.TextColor3 = dotColor or Color3.fromRGB(210, 210, 210)
    statusLine.Text      = line
end

-- ── Safe Lua executor ─────────────────────────────────────────────────────
local function execLua(src)
    local fn, loadErr = loadstring(src)
    if not fn then
        return false, "Syntax error: " .. tostring(loadErr)
    end
    local ok, res = pcall(fn)
    if not ok then
        return false, "Runtime error: " .. tostring(res)
    end
    return true, tostring(res ~= nil and res or "")
end

-- ── Send result to bridge ─────────────────────────────────────────────────
local function sendResult(id, ok, result, errMsg)
    local payload = HttpService:JSONEncode({
        id      = id,
        success = ok,
        result  = result  or "",
        error   = errMsg  or "",
    })
    pcall(function()
        HttpService:PostAsync(
            BRIDGE .. "/api/result",
            payload,
            Enum.HttpContentType.ApplicationJson
        )
    end)
end

-- ── Main polling loop ─────────────────────────────────────────────────────
local isActive = false
local pollConn  -- coroutine / spawn handle

local function startPolling()
    setStatus("Connected — waiting for commands…", "Chat in Claude Code to build!", Color3.fromRGB(60, 200, 100))
    widget.Enabled = true

    while isActive do
        local ok, raw = pcall(function()
            return HttpService:GetAsync(BRIDGE .. "/api/command", true)
        end)

        if ok and raw and raw ~= "null" and raw ~= "" then
            local dok, cmd = pcall(function()
                return HttpService:JSONDecode(raw)
            end)

            if dok and cmd and cmd.id and cmd.lua_code then
                local label = (cmd.description ~= "" and cmd.description) or "executing…"
                cmdLine.Text = "▶ " .. label
                errLine.Text = ""

                print("[RobloxAI] Running: " .. label)

                local execOk, execRes = execLua(cmd.lua_code)
                cmdCount = cmdCount + 1
                countLine.Text = "Commands run: " .. cmdCount

                if execOk then
                    print("[RobloxAI] ✓ " .. execRes)
                    cmdLine.Text = "✓ " .. execRes:sub(1, 60)
                    sendResult(cmd.id, true, execRes, nil)
                else
                    warn("[RobloxAI] ✗ " .. execRes)
                    errLine.Text = "✗ " .. execRes:sub(1, 60)
                    sendResult(cmd.id, false, nil, execRes)
                end
            end

        elseif not ok then
            -- Lost connection to bridge
            setStatus("Reconnecting…", "Is bridge_server.py still running?", Color3.fromRGB(220, 160, 40))
            wait(2)
            if isActive then
                setStatus("Connected", "Chat in Claude Code to build!", Color3.fromRGB(60, 200, 100))
            end
        end

        wait(POLL_INTERVAL)
    end

    -- Deactivated
    setStatus("Disconnected", "Click the toolbar button to reconnect.", Color3.fromRGB(180, 60, 60))
    widget.Enabled = false
end

-- ── Toolbar click ─────────────────────────────────────────────────────────
toggleBtn.Click:Connect(function()
    if isActive then
        isActive = false
        toggleBtn:SetActive(false)
        print("[RobloxAI] Deactivated.")
        return
    end

    -- Verify bridge is reachable
    local testOk, testErr = pcall(function()
        HttpService:GetAsync(BRIDGE .. "/api/status", true)
    end)
    if not testOk then
        setStatus(
            "Cannot reach bridge!",
            "Run:  python bridge_server.py   in your terminal",
            Color3.fromRGB(220, 60, 60)
        )
        warn("[RobloxAI] Bridge unreachable: " .. tostring(testErr))
        warn("[RobloxAI] Start it with:  python bridge_server.py")
        toggleBtn:SetActive(false)
        widget.Enabled = true
        return
    end

    isActive = true
    toggleBtn:SetActive(true)
    spawn(startPolling)
    print("[RobloxAI] Activated!  Chat in Claude Code to build your game.")
end)

print("[RobloxAI] Plugin loaded.  Click 'AI Assistant' in the Plugins toolbar to connect.")
