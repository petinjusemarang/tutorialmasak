-- SAMLONG AUTO BRAIN — Combined autojoin + autoexec
-- State-aware controller: auto detect lobby / ingame, auto fetch job, auto execute

-- ═══════════════════════════════════
--  ANTI DOUBLE RUN
-- ═══════════════════════════════════
if getgenv()._samlongBrainRunning then
    print("[BRAIN] Already running, exit.")
    return
end
getgenv()._samlongBrainRunning = true

-- ═══════════════════════════════════
--  WAIT GAME LOADED
-- ═══════════════════════════════════
if not game:IsLoaded() then game.Loaded:Wait() end

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local player            = Players.LocalPlayer
local rp                = ReplicatedStorage

-- ═══════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════
local SHEETS_URL = "https://script.google.com/macros/s/AKfycbzBFd5ASlqRLk1pS4Kx3cvBujvFsCIr0QKrdtVO9xZv8fBPHp0L1CKKRwnjpQwD7qHrIw/exec"
local API_URL    = "https://samlongweb-production.up.railway.app"
local API_KEY    = "slg_prod_nJjQZJQ4kR98l9zTfTJ56CBgeDrzxaws0eFk7rYJg2SAhvu7WRloXti3KkiXRnYN"

-- ═══════════════════════════════════
--  LOG UI (debug, lobby phase)
-- ═══════════════════════════════════
local logGui = Instance.new("ScreenGui", player.PlayerGui)
logGui.Name         = "SamlongBrainLog"
logGui.ResetOnSpawn = false

local logFrame = Instance.new("Frame", logGui)
logFrame.Size            = UDim2.new(0, 420, 0, 250)
logFrame.Position        = UDim2.new(0, 20, 0, 100)
logFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
logFrame.BackgroundTransparency = 0.15
logFrame.BorderSizePixel = 0

local logText = Instance.new("TextLabel", logFrame)
logText.Size                   = UDim2.new(1, -10, 1, -10)
logText.Position               = UDim2.new(0, 5, 0, 5)
logText.BackgroundTransparency = 1
logText.TextXAlignment         = Enum.TextXAlignment.Left
logText.TextYAlignment         = Enum.TextYAlignment.Top
logText.Font                   = Enum.Font.Code
logText.TextSize               = 13
logText.TextColor3             = Color3.new(1, 1, 1)
logText.TextWrapped            = true

local logs = ""
local function log(msg)
    print("[BRAIN] " .. msg)
    logs = logs .. msg .. "\n"
    -- Keep last ~20 lines
    local lines = {}
    for l in logs:gmatch("[^\n]+") do table.insert(lines, l) end
    if #lines > 20 then
        local trimmed = {}
        for i = #lines - 19, #lines do trimmed[#trimmed + 1] = lines[i] end
        logs = table.concat(trimmed, "\n") .. "\n"
    end
    logText.Text = logs
end

-- ═══════════════════════════════════
--  QUEUE ON TELEPORT
--  Antri script untuk auto-run saat tiba di place baru.
--  Support: Synapse X, KRNL, dan executor lain yg expose queue_on_teleport.
-- ═══════════════════════════════════
local function queueOnTeleport(code)
    if syn and syn.queue_on_teleport then
        syn.queue_on_teleport(code)
        return true
    elseif type(queue_on_teleport) == "function" then
        queue_on_teleport(code)
        return true
    end
    return false
end

-- ═══════════════════════════════════
--  HTTP HELPER
-- ═══════════════════════════════════
local function req(opt)
    local r = (syn and syn.request) or (http and http.request) or request
    if not r then log("[ERROR] HTTP NOT SUPPORTED"); return end
    local ok, res = pcall(function() return r(opt) end)
    if ok and res then
        log("[HTTP] " .. opt.Method .. " " .. res.StatusCode)
        return res
    else
        log("[HTTP ERROR] " .. opt.Url)
    end
end

-- ═══════════════════════════════════
--  API FUNCTIONS
-- ═══════════════════════════════════

-- GET /api/private-server?username=xxx → { server_code, jenis, jump_mode, region }
local function getPS(username)
    log("[API] GET " .. username)
    local res = req({
        Url     = API_URL .. "/api/private-server?username=" .. HttpService:UrlEncode(username),
        Method  = "GET",
        Headers = { ["x-api-key"] = API_KEY },
    })
    if res and res.StatusCode == 200 then
        log("[API] OK")
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok then return data end
    end
    log("[API] FAIL")
end

-- POST /api/private-server  { username, server_code }
local function setPS(username, code)
    req({
        Url     = API_URL .. "/api/private-server",
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = API_KEY },
        Body    = HttpService:JSONEncode({ username = username, server_code = code }),
    })
    log("[SET] " .. code)
end

local function sheetsRequest(url)
    pcall(function()
        local r = (syn and syn.request) or (http and http.request) or request
        if r then r({ Url = url, Method = "GET" })
        elseif game and game.HttpGet then game:HttpGet(url) end
    end)
end

local function sendUpdate(points)
    sheetsRequest(SHEETS_URL .. "?username=" .. player.Name .. "&points=" .. tostring(points) .. "&action=update")
end

local function sendInit(points)
    sheetsRequest(SHEETS_URL .. "?username=" .. player.Name .. "&points=" .. tostring(points) .. "&action=init")
end

local function apiUpdate(username, rawPoints)
    pcall(function()
        local r = (syn and syn.request) or (http and http.request) or request
        if r then
            r({
                Url     = API_URL .. "/api/update",
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = API_KEY },
                Body    = HttpService:JSONEncode({
                    username         = username,
                    current_progress = rawPoints,
                    current_amount   = rawPoints,
                    user_id          = player.UserId,
                }),
            })
        end
    end)
end

-- Throttled wrapper: max 1 send per 60s, skips if value unchanged
local _lastSend  = -math.huge
local _lastValue = nil

local function safeApiUpdate(username, value)
    local now = os.clock()
    if now - _lastSend < 60 then return end
    if value == _lastValue then return end
    _lastSend  = now
    _lastValue = value
    apiUpdate(username, value)
end

local function serverLock()
    pcall(function()
        rp:WaitForChild("NetworkContainer")
          :WaitForChild("RemoteEvents")
          :WaitForChild("Private Server")
          :FireServer("serverlock", {})
    end)
end

local function formatUang(raw)
    local num = tonumber((raw:gsub("[^%d]", ""))) or 0
    if num >= 1000000000000 then
        local val = num / 1000000000000
        local dec = math.floor(val * 10) / 10
        if dec == math.floor(dec) then return string.format("%dT", math.floor(dec))
        else return string.format("%.1fT", dec):gsub("%.", ",") end
    elseif num >= 1000000000 then
        local val = num / 1000000000
        local dec = math.floor(val * 10) / 10
        if dec == math.floor(dec) then return string.format("%dM", math.floor(dec))
        else return string.format("%.1fM", dec):gsub("%.", ",") end
    elseif num >= 1000000 then
        local val = num / 1000000
        local dec = math.floor(val * 10) / 10
        if dec == math.floor(dec) then return string.format("%djt", math.floor(dec))
        else return string.format("%.1fjt", dec):gsub("%.", ",") end
    elseif num >= 1000 then
        local val = num / 1000
        local dec = math.floor(val * 10) / 10
        if dec == math.floor(dec) then return string.format("%dK", math.floor(dec))
        else return string.format("%.1fK", dec):gsub("%.", ",") end
    else
        return tostring(num)
    end
end

-- ═══════════════════════════════════
--  ANTI-AFK (global, sekali)
-- ═══════════════════════════════════
player.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ═══════════════════════════════════
--  JUMP / NOJUMP
-- ═══════════════════════════════════
local activeMovementThread = nil

local function stopMovementLoop()
    if activeMovementThread then
        task.cancel(activeMovementThread)
        activeMovementThread = nil
    end
end

local function startJumpLoop()
    stopMovementLoop()
    activeMovementThread = task.spawn(function()
        while true do
            pcall(function()
                rp:WaitForChild("NetworkContainer")
                  :WaitForChild("RemoteEvents")
                  :WaitForChild("Minigames")
                  :FireServer("Enter", "2021Avanza15CVT")
            end)
            local char     = player.Character
            local pl       = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if pl and humanoid then
                local location        = CFrame.new(-4991, 20.7, 883.3)
                local respawnLocation = CFrame.new(-5000, 20.7, 880.0)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.1)
                pl.CFrame = location
                task.wait(2)
                local touchPart = workspace:FindFirstChild("Interaksi")
                if touchPart then
                    pcall(function() firetouchinterest(pl, touchPart, 0) end)
                    pcall(function() firetouchinterest(pl, touchPart, 1) end)
                end
                while player.Character
                      and player.Character:FindFirstChild("Humanoid")
                      and player.Character.Humanoid.Health > 0 do
                    game.Players.LocalPlayer.Character.Humanoid.Jump = true
                    wait(0.1)
                end
                task.wait(3)
                local nc = player.Character
                if nc and nc:FindFirstChild("HumanoidRootPart") then
                    nc.HumanoidRootPart.CFrame = respawnLocation
                end
            else
                task.wait(1)
            end
        end
    end)
end

local function startNoJumpLoop()
    stopMovementLoop()
    activeMovementThread = task.spawn(function()
        while true do
            pcall(function()
                rp:WaitForChild("NetworkContainer")
                  :WaitForChild("RemoteEvents")
                  :WaitForChild("Minigames")
                  :FireServer("Enter", "2021Avanza15CVT")
            end)
            local char     = player.Character
            local pl       = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if pl and humanoid then
                local location        = CFrame.new(-4991, 20.7, 883.3)
                local respawnLocation = CFrame.new(-5000, 20.7, 880.0)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                task.wait(0.1)
                pl.CFrame = location
                task.wait(2)
                local touchPart = workspace:FindFirstChild("Interaksi")
                if touchPart then
                    pcall(function() firetouchinterest(pl, touchPart, 0) end)
                    pcall(function() firetouchinterest(pl, touchPart, 1) end)
                end
                while player.Character
                      and player.Character:FindFirstChild("Humanoid")
                      and player.Character.Humanoid.Health > 0 do
                    task.wait(0.1)
                end
                task.wait(3)
                local nc = player.Character
                if nc and nc:FindFirstChild("HumanoidRootPart") then
                    nc.HumanoidRootPart.CFrame = respawnLocation
                end
            else
                task.wait(1)
            end
        end
    end)
end

-- ═══════════════════════════════════
--  MODE: MINIGAME
-- ═══════════════════════════════════
local function startMinigame()
    if CoreGui:FindFirstChild("SamlongGUI") then CoreGui.SamlongGUI:Destroy() end

    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name         = "SamlongGUI"
    gui.ResetOnSpawn = false

    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size                   = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundTransparency = 1

    local buyBtn = Instance.new("TextButton", mainFrame)
    buyBtn.Size             = UDim2.new(0, 180, 0, 40)
    buyBtn.Position         = UDim2.new(0.75, 0, 0, 30)
    buyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    buyBtn.Font             = Enum.Font.GothamBold
    buyBtn.TextSize         = 18
    buyBtn.TextColor3       = Color3.new(1, 1, 1)
    buyBtn.Text             = "BUY AVANZA"
    buyBtn.BorderSizePixel  = 0
    buyBtn.AutoButtonColor  = true

    local notif = Instance.new("TextLabel", mainFrame)
    notif.Size                   = UDim2.new(1, 0, 0, 30)
    notif.Position               = UDim2.new(0, 0, 0, 10)
    notif.BackgroundTransparency = 1
    notif.Font                   = Enum.Font.GothamBold
    notif.TextSize               = 18
    notif.TextColor3             = Color3.fromRGB(255, 70, 70)
    notif.TextStrokeTransparency = 0.5
    notif.TextStrokeColor3       = Color3.new(0, 0, 0)
    notif.TextWrapped            = true
    notif.TextXAlignment         = Enum.TextXAlignment.Center
    notif.Text                   = ""

    local pointBG = Instance.new("Frame", mainFrame)
    pointBG.Size                   = UDim2.new(0, 420, 0, 160)
    pointBG.Position               = UDim2.new(0.5, -210, 0.4, -80)
    pointBG.BackgroundColor3       = Color3.new(0, 0, 0)
    pointBG.BackgroundTransparency = 0.2
    pointBG.BorderSizePixel        = 0

    local usernameLabel = Instance.new("TextLabel", pointBG)
    usernameLabel.Size                   = UDim2.new(1, 0, 0.3, 0)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Font                   = Enum.Font.GothamBlack
    usernameLabel.TextScaled             = true
    usernameLabel.TextColor3             = Color3.fromRGB(255, 220, 80)
    usernameLabel.TextStrokeTransparency = 0.3
    usernameLabel.Text                   = player.Name

    local pointLabel = Instance.new("TextLabel", pointBG)
    pointLabel.Size                   = UDim2.new(1, 0, 0.7, 0)
    pointLabel.Position               = UDim2.new(0, 0, 0.3, 0)
    pointLabel.BackgroundTransparency = 1
    pointLabel.Font                   = Enum.Font.GothamBlack
    pointLabel.TextScaled             = true
    pointLabel.TextColor3             = Color3.new(1, 1, 1)
    pointLabel.TextStrokeTransparency = 0.3
    pointLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    pointLabel.Text                   = "..."

    local lastPlayedLabel = Instance.new("TextLabel", pointBG)
    lastPlayedLabel.Size                   = UDim2.new(1, 0, 0, 30)
    lastPlayedLabel.Position               = UDim2.new(0, 0, 1, -35)
    lastPlayedLabel.BackgroundTransparency = 1
    lastPlayedLabel.Font                   = Enum.Font.Gotham
    lastPlayedLabel.TextSize               = 16
    lastPlayedLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
    lastPlayedLabel.TextStrokeTransparency = 0.5
    lastPlayedLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    lastPlayedLabel.Text                   = "Last: N/A"

    local popupFrame = Instance.new("Frame", mainFrame)
    popupFrame.Size             = UDim2.new(0.8, 0, 0.4, 0)
    popupFrame.Position         = UDim2.new(0.1, 0, 0.3, 0)
    popupFrame.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
    popupFrame.BorderSizePixel  = 0
    popupFrame.ZIndex           = 1000
    popupFrame.Visible          = false

    local popupText = Instance.new("TextLabel", popupFrame)
    popupText.Size                   = UDim2.new(1, 0, 0.7, 0)
    popupText.BackgroundTransparency = 1
    popupText.Font                   = Enum.Font.GothamBlack
    popupText.TextScaled             = true
    popupText.TextColor3             = Color3.new(1, 1, 1)
    popupText.TextStrokeTransparency = 0.2
    popupText.TextStrokeColor3       = Color3.new(0, 0, 0)
    popupText.Text                   = "STUCK YA ALLAHH"
    popupText.ZIndex                 = 1001

    local okBtn = Instance.new("TextButton", popupFrame)
    okBtn.Size             = UDim2.new(0, 120, 0, 50)
    okBtn.Position         = UDim2.new(0.5, -60, 0.75, 0)
    okBtn.Font             = Enum.Font.GothamBold
    okBtn.TextSize         = 22
    okBtn.Text             = "OK"
    okBtn.BackgroundColor3 = Color3.new(1, 1, 1)
    okBtn.TextColor3       = Color3.new(0, 0, 0)
    okBtn.BorderSizePixel  = 0
    okBtn.ZIndex           = 1001
    okBtn.Visible          = false

    local lastPlayTime    = os.time()
    local lastValChange   = os.time()
    local alerted         = false
    local STUCK_THRESHOLD = 600

    local function updateLastPlayed()
        local diff = os.difftime(os.time(), lastPlayTime)
        lastPlayedLabel.Text = ("Last: %dm %ds"):format(math.floor(diff / 60), diff % 60)
    end

    task.delay(5, function()
        local guiInst = player:FindFirstChild("PlayerGui")
        local lbl     = guiInst
            and guiInst:FindFirstChild("BoxShop")
            and guiInst.BoxShop.Container.Box:FindFirstChild("MinigamePoint")
        if lbl then
            local val = (lbl.Text or ""):gsub("%D", "")
            if val == "" then val = "0" end
            sendInit(val)
            sendUpdate(val)
            apiUpdate(player.Name, tonumber(val) or 0)
        end
    end)

    local function updatePoint()
        for _ = 1, 30 do
            local guiInst = player:FindFirstChild("PlayerGui")
            local lbl     = guiInst
                and guiInst:FindFirstChild("BoxShop")
                and guiInst.BoxShop:FindFirstChild("Container")
                and guiInst.BoxShop.Container:FindFirstChild("Box")
                and guiInst.BoxShop.Container.Box:FindFirstChild("MinigamePoint")
            if lbl and lbl:IsA("TextLabel") then
                local function refresh()
                    local val = lbl.Text:match("%d+") or "0"
                    if val ~= pointLabel.Text then
                        lastPlayTime  = os.time()
                        lastValChange = os.time()
                        alerted       = false
                    end
                    pointLabel.Text = val
                end
                refresh()
                lbl:GetPropertyChangedSignal("Text"):Connect(refresh)
                return
            end
            task.wait(1)
        end
        pointLabel.Text = "0"
    end

    local function tryBuyAvanza()
        local cashLabel = player.PlayerGui:FindFirstChild("Main")
            and player.PlayerGui.Main:FindFirstChild("Container")
            and player.PlayerGui.Main.Container:FindFirstChild("Hub")
            and player.PlayerGui.Main.Container.Hub:FindFirstChild("CashFrame")
            and player.PlayerGui.Main.Container.Hub.CashFrame.Frame:FindFirstChild("TextLabel")
        if not cashLabel then warn("Cash label not found!"); return end
        local uang        = tonumber(cashLabel.Text:gsub("%D", "")) or 0
        local hargaAvanza = 232850000
        if uang >= hargaAvanza then
            rp:WaitForChild("NetworkContainer")
              :WaitForChild("RemoteFunctions")
              :WaitForChild("Dealership")
              :InvokeServer("Buy", "2021Avanza15CVT", "White", "Toyota")
        else
            notif.Text = ("UANG KURANG: %s / %s"):format(uang, hargaAvanza)
            task.delay(3, function() notif.Text = "" end)
        end
    end

    buyBtn.MouseButton1Click:Connect(tryBuyAvanza)

    -- Auto-buy Avanza CVT sekali saat join minigame
    task.delay(5, tryBuyAvanza)

    getgenv().minigame_jump   = function() startJumpLoop() end
    getgenv().minigame_nojump = function() startNoJumpLoop() end

    okBtn.MouseButton1Click:Connect(function()
        popupFrame.Visible   = false
        okBtn.Visible        = false
        lastValChange        = os.time()
        lastPlayTime         = os.time()
        lastPlayedLabel.Text = "Last: 0m 0s"
        alerted              = false
    end)

    task.spawn(updatePoint)
    task.spawn(function()
        while true do updateLastPlayed(); task.wait(1) end
    end)
    task.spawn(function()
        while true do
            if not alerted and os.difftime(os.time(), lastValChange) >= STUCK_THRESHOLD then
                popupFrame.Visible = true
                okBtn.Visible      = true
                alerted            = true
            end
            task.wait(1)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(60)
            local guiInst = player:FindFirstChild("PlayerGui")
            local lbl     = guiInst
                and guiInst:FindFirstChild("BoxShop")
                and guiInst.BoxShop:FindFirstChild("Container")
                and guiInst.BoxShop.Container:FindFirstChild("Box")
                and guiInst.BoxShop.Container.Box:FindFirstChild("MinigamePoint")
            if lbl and lbl:IsA("TextLabel") then
                local val = (lbl.Text or ""):gsub("%D", "")
                if val == "" then val = "0" end
                sendUpdate(val)
                safeApiUpdate(player.Name, tonumber(val) or 0)
            end
        end
    end)
end

-- ═══════════════════════════════════
--  MODE: RACE
-- ═══════════════════════════════════
local function startRace()
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    player.CharacterAdded:Connect(function(newChar)
        char = newChar
        root = newChar:WaitForChild("HumanoidRootPart")
    end)

    local remotes     = rp:WaitForChild("RaceRemotes")
    local NPC_PATH    = workspace.Etc.Race.NPC.DA0ZA
    local PROMPT_PATH = NPC_PATH.HumanoidRootPart.Prompt

    local RUNNING         = false
    local MODE_RACE       = "LOSE"
    local RACE_COUNT      = 0
    local STATUS_TEXT     = "Idle"
    local MAP_DELETED     = false
    local SESSION_START   = os.clock()
    local POINTS_AT_START = 0
    local SPEED           = { WIN = 250, LOSE = 200 }
    local ACCEL           = 5

    local CHECKPOINTS = {
        Vector3.new(126.484, 3.234, -413.750),
        Vector3.new(125.373, 3.228, -1272.303),
        Vector3.new(-173.397, 3.228, -2036.829),
        Vector3.new(-1007.555, 3.228, -2168.953),
        Vector3.new(-1855.214, -6.747, -2227.516),
        Vector3.new(-2649.424, -21.988, -2553.774),
        Vector3.new(-3326.388, -32.172, -3050.381),
        Vector3.new(-2964.084, -34.634, -3808.800),
        Vector3.new(-2547.419, -32.170, -4560.326),
        Vector3.new(-2131.537, -38.320, -5309.163),
        Vector3.new(-1701.094, -34.047, -6051.912),
        Vector3.new(-1256.946, -69.740, -6784.079),
        Vector3.new(-939.994,  -54.307, -7576.575),
        Vector3.new(-1476.921, -54.550, -8167.188),
        Vector3.new(-2226.989, -54.478, -8583.185),
        Vector3.new(-2952.778, -46.232, -9039.672),
        Vector3.new(-3521.273, -41.104, -9671.608),
        Vector3.new(-3932.669, -25.455, -10419.997),
        Vector3.new(-3815.698, -25.321, -11207.516),
        Vector3.new(-3270.269, -86.230, -11871.715),
        Vector3.new(-2767.950, -66.776, -12560.823),
        Vector3.new(-2530.768, -39.475, -13348.704),
        Vector3.new(-2808.955, -38.912, -14160.520),
        Vector3.new(-3094.195, -35.982, -14973.083),
        Vector3.new(-3364.130, -48.026, -15782.974),
        Vector3.new(-3506.115, -34.960, -16628.467),
        Vector3.new(-3555.211, -76.962, -17489.098),
        Vector3.new(-3576.361, -88.727, -18339.076),
        Vector3.new(-3561.386, -63.232, -19195.998),
        Vector3.new(-3541.395, -75.296, -20053.066),
        Vector3.new(-3435.542, -93.999, -20904.252),
        Vector3.new(-3291.255, -50.174, -21745.605),
        Vector3.new(-3142.049, -76.561, -22592.246),
        Vector3.new(-3129.446, -79.572, -23450.859),
        Vector3.new(-3130.823, -79.572, -24307.510),
        Vector3.new(-3130.794, -74.634, -25167.229),
        Vector3.new(-3131.090, -56.682, -26026.822),
        Vector3.new(-3127.974, -79.572, -26880.486),
        Vector3.new(-3128.549, -79.572, -27740.045),
    }

    local WEBHOOK_URLS = {
        "https://discord.com/api/webhooks/1486677758838050886/-4KZKc9XPfhenUsbx5JAmxPHLxpXguU1whbMJYkRyzyfayFWUqnmxV7DRh8dvgFJOxCd",
        "https://discord.com/api/webhooks/1486689239914774600/NNXdfR1GF9CaxVAM4vbrbsAV3pXizxQSHs_PqM0CArPezApql7zEKZQR0rEMUfAl3gh8",
        "https://discord.com/api/webhooks/1486689242179436624/tqSUuI6ww3ok98-qv1NnM5S7UWmD6W_Rq44s034KIZx9Zazh44F-1Nn8GK1Vw5A0dLfN",
        "https://discord.com/api/webhooks/1486689243630796874/8O63v71D3mX8mAzfXaXtal5HxN20CIPHfPzxx_I3KztmefI5xzWR4ro0yasJZbF-1rG7",
        "https://discord.com/api/webhooks/1486689252732436590/xjCM3rmF-Y6H9CRKRO8nUnnGnS94",
    }

    local function corner(p, r)
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
    end

    local function createPlatform(pos, size)
        local part = Instance.new("Part")
        part.Size          = size or Vector3.new(100, 3, 100)
        part.Anchored      = true
        part.Material      = Enum.Material.Asphalt
        part.Color         = Color3.fromRGB(50, 50, 50)
        part.Position      = pos - Vector3.new(0, 3, 0)
        part.CanCollide    = true
        part.TopSurface    = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.Parent        = workspace
    end

    local function createRoad(from, to)
        local fromPos = Vector3.new(from.X, from.Y - 6, from.Z)
        local toPos   = Vector3.new(to.X, to.Y, to.Z)
        local mid     = (fromPos + toPos) / 2
        local dist    = (toPos - fromPos).Magnitude
        local part    = Instance.new("Part")
        part.Size          = Vector3.new(100, 3, dist + 200)
        part.Anchored      = true
        part.Material      = Enum.Material.Asphalt
        part.Color         = Color3.fromRGB(45, 45, 45)
        part.CanCollide    = true
        part.TopSurface    = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.CFrame        = CFrame.lookAt(mid, toPos)
        part.Parent        = workspace
    end

    local function deleteMap()
        if MAP_DELETED then return end
        MAP_DELETED = true
        pcall(function()
            for _, v in pairs(workspace.Map:GetChildren()) do v:Destroy() end
        end)
        for _, name in ipairs({
            "Landmarks","Lampu Merah","Gapura","Lights","Tree","StreetLamp_Pantura",
            "OwnableHouse","NightLight","NPCVehicle","Trees","Bushes","Plants",
            "Decorations","Props","StreetProps","TrafficLight"
        }) do
            local obj = workspace:FindFirstChild(name)
            if obj then obj:Destroy() end
        end
        Lighting.GlobalShadows = false
        Lighting.FogEnd        = 1e10
        Lighting.Brightness    = 1
        Lighting.ClockTime     = 14
        pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    end

    local function buildPlatforms()
        for i = 1, #CHECKPOINTS - 1 do
            local from  = CHECKPOINTS[i]
            local to    = CHECKPOINTS[i + 1]
            local diffY = math.abs(to.Y - from.Y)
            if diffY > 10 then
                local p1 = from + (to - from) * 0.25
                local p2 = from + (to - from) * 0.5
                local p3 = from + (to - from) * 0.75
                createRoad(from, p1); createRoad(p1, p2); createRoad(p2, p3); createRoad(p3, to)
            else
                createRoad(from, to)
            end
        end
        local npcRoot = NPC_PATH:FindFirstChild("HumanoidRootPart")
        if npcRoot then
            createRoad(npcRoot.Position, CHECKPOINTS[1])
            createPlatform(npcRoot.Position - Vector3.new(0, 3, 0), Vector3.new(100, 3, 100))
        end
        createPlatform(CHECKPOINTS[#CHECKPOINTS])
    end

    local function getVehicle()
        local c   = player.Character or player.CharacterAdded:Wait()
        local hum = c:FindFirstChild("Humanoid")
        if hum and hum.SeatPart then
            local v = hum.SeatPart:FindFirstAncestorOfClass("Model")
            if v and v.PrimaryPart then return v end
        end
    end

    local function isRaceHUDVisible()
        local ok, val = pcall(function() return player.PlayerGui.Race.Container.RaceHUD.Visible end)
        return ok and val
    end

    local function runRaceLoop()
        STATUS_TEXT = "Racing..."
        local vehicle = getVehicle()
        if not vehicle then STATUS_TEXT = "No vehicle!"; return end
        local vRoot = vehicle.PrimaryPart
        if not vRoot then return end

        local total    = #CHECKPOINTS
        local maxSpeed = MODE_RACE == "WIN" and SPEED.WIN or SPEED.LOSE

        local bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bodyVel.Parent   = vRoot

        local bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bodyGyro.P         = 10000
        bodyGyro.Parent    = vRoot

        local speed     = 0
        local currentCP = 1
        local lastPos   = vRoot.Position
        local stuckTime = 0
        local raceStart = tick()

        local connection
        connection = RunService.Heartbeat:Connect(function()
            if not RUNNING or not getVehicle() or currentCP > total then
                pcall(function() bodyVel:Destroy() end)
                pcall(function() bodyGyro:Destroy() end)
                if connection then connection:Disconnect() end
                return
            end
            local target    = CHECKPOINTS[currentCP]
            local direction = target - vRoot.Position
            local distance  = direction.Magnitude
            speed           = math.min(speed + ACCEL, maxSpeed)
            bodyVel.Velocity = direction.Unit * speed
            bodyGyro.CFrame  = CFrame.lookAt(vRoot.Position, target)
            if tick() - raceStart > 5 then
                if (vRoot.Position - lastPos).Magnitude < 1 then stuckTime += 1
                else stuckTime = 0 end
                lastPos = vRoot.Position
                if stuckTime > 30 then
                    stuckTime        = 0
                    bodyVel.Velocity = Vector3.zero
                    local fwd = direction.Unit * 50
                    vRoot.CFrame   = CFrame.new(vRoot.Position.X + fwd.X, vRoot.Position.Y + 20, vRoot.Position.Z + fwd.Z)
                    vRoot.Anchored = true
                    task.defer(function()
                        for _ = 1, 20 do
                            if not vRoot or not vRoot.Parent then break end
                            vRoot.CFrame = vRoot.CFrame - Vector3.new(0, 1, 0)
                            task.wait(0.03)
                        end
                        if vRoot and vRoot.Parent then vRoot.Anchored = false end
                    end)
                end
            end
            if distance < 15 then
                currentCP += 1
                if currentCP <= total then
                    STATUS_TEXT = string.format("CP %d/%d", currentCP, total)
                end
            end
        end)

        local timeout = 0
        repeat task.wait(0.2); timeout += 0.2
        until currentCP > total or timeout >= 300 or not RUNNING or not getVehicle()
        if connection and connection.Connected then connection:Disconnect() end
        pcall(function() bodyVel:Destroy() end)
        pcall(function() bodyGyro:Destroy() end)
        if currentCP > total then
            STATUS_TEXT = "Finished!"
            local st = 0
            while st < 3 and RUNNING do
                if not isRaceHUDVisible() then break end
                task.wait(0.5); st += 0.5
            end
        end
    end

    local function approachNPC()
        local npcRoot = NPC_PATH:FindFirstChild("HumanoidRootPart")
        if not npcRoot then return false end
        local npcPos  = npcRoot.Position
        local landPos = npcPos + npcRoot.CFrame.LookVector * 5
        local delay   = MODE_RACE == "WIN" and 1 or 1.5
        STATUS_TEXT   = string.format("NPC (%.0fs)...", delay)
        task.wait(delay)
        root.CFrame = CFrame.new(landPos.X, npcPos.Y + 3, landPos.Z)
        task.wait(1)
        return true
    end

    local function fireNPCPrompt()
        local prompt = PROMPT_PATH
        if prompt and prompt:IsA("ProximityPrompt") then
            STATUS_TEXT = "Opening menu..."
            fireproximityprompt(prompt)
            return true
        end
        return false
    end

    local function waitMenuOpen()
        local raceGuiWait = player.PlayerGui:WaitForChild("Race", 10)
        if not raceGuiWait then return nil end
        local container = raceGuiWait:WaitForChild("Container", 5)
        if not container then return nil end
        local raceMenu  = container:WaitForChild("RaceMenu", 5)
        if not raceMenu then return nil end
        local t = 0
        repeat task.wait(0.1); t += 0.1 until raceMenu.Visible or t > 5
        return raceMenu.Visible and raceMenu or nil
    end

    local function joinLobby(menu)
        local lobbyList = menu:WaitForChild("JoinSection"):WaitForChild("LobbyList")
        for _, lobby in pairs(lobbyList:GetChildren()) do
            if lobby:IsA("Frame") and lobby.Name ~= "LobbyRowTemplate" then
                local hostLabel = lobby:FindFirstChild("HostName", true)
                if hostLabel and hostLabel.Text ~= player.Name then
                    local id = tonumber(lobby.Name:match("%d+"))
                    if id then remotes.JoinLobby:FireServer(id); return true end
                end
            end
        end
        return false
    end

    local function createLobby() remotes.CreateLobby:FireServer(player.Name .. "'s Lobby") end

    local function selectRandomCar()
        local ok, carList = pcall(function()
            return player.PlayerGui.Main.Container.Spawner.ScrollingFrame
        end)
        if not ok or not carList then return end
        local cars = {}
        for _, v in pairs(carList:GetChildren()) do
            if v:IsA("Frame") then table.insert(cars, v.Name) end
        end
        if #cars == 0 then return end
        local chosen = cars[math.random(1, #cars)]
        remotes.SelectCar:FireServer(chosen, chosen)
    end

    local function readyUp() remotes.ToggleReady:FireServer() end

    local POINTS_LABEL
    task.spawn(function()
        POINTS_LABEL = player:WaitForChild("PlayerGui"):WaitForChild("Race")
            :WaitForChild("Container"):WaitForChild("Shop"):WaitForChild("TitleBar")
            :WaitForChild("PointsPill"):WaitForChild("Value")
    end)

    local function getPointsNum()
        if POINTS_LABEL then
            return tonumber((POINTS_LABEL.Text or ""):gsub("%D", "")) or 0
        end
        return 0
    end
    local function getPointsText()
        return POINTS_LABEL and POINTS_LABEL.Text or "0 PTS"
    end

    task.spawn(function()
        local rc = player:WaitForChild("PlayerGui"):WaitForChild("Race"):WaitForChild("Container")
        rc.ChildAdded:Connect(function(child)
            if child.Name == "Scoreboard" then
                task.wait(0.5); pcall(function() child:Destroy() end)
            end
        end)
    end)
    task.spawn(function()
        while true do
            task.wait(10)
            local nf = workspace:FindFirstChild("NPCVehicle")
            if nf then nf:ClearAllChildren() end
        end
    end)

    local oldGui = player.PlayerGui:FindFirstChild("AutoRaceGUI")
    if oldGui then oldGui:Destroy() end
    local raceGui = Instance.new("ScreenGui")
    raceGui.Name           = "AutoRaceGUI"
    raceGui.ResetOnSpawn   = false
    raceGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    raceGui.Parent         = player.PlayerGui

    local centerFrame = Instance.new("Frame", raceGui)
    centerFrame.Size                   = UDim2.new(1, 0, 0, 220)
    centerFrame.Position               = UDim2.new(0, 0, 0.5, -110)
    centerFrame.BackgroundColor3       = Color3.fromRGB(5, 5, 10)
    centerFrame.BackgroundTransparency = 0.1
    centerFrame.BorderSizePixel        = 0

    local rUsernameLabel = Instance.new("TextLabel", centerFrame)
    rUsernameLabel.Size                   = UDim2.new(1, 0, 0, 35)
    rUsernameLabel.Position               = UDim2.new(0, 0, 0, 5)
    rUsernameLabel.BackgroundTransparency = 1
    rUsernameLabel.Text                   = player.Name
    rUsernameLabel.TextColor3             = Color3.fromRGB(255, 220, 80)
    rUsernameLabel.Font                   = Enum.Font.GothamBold
    rUsernameLabel.TextXAlignment         = Enum.TextXAlignment.Center
    rUsernameLabel.TextScaled             = true

    local pointsLabel = Instance.new("TextLabel", centerFrame)
    pointsLabel.Size                   = UDim2.new(1, -10, 0, 65)
    pointsLabel.Position               = UDim2.new(0, 5, 0, 38)
    pointsLabel.BackgroundTransparency = 1
    pointsLabel.Text                   = "0 PTS"
    pointsLabel.TextColor3             = Color3.fromRGB(255, 215, 60)
    pointsLabel.Font                   = Enum.Font.GothamBold
    pointsLabel.TextXAlignment         = Enum.TextXAlignment.Center
    pointsLabel.TextScaled             = true

    local earnedLabel = Instance.new("TextLabel", centerFrame)
    earnedLabel.Size                   = UDim2.new(1, 0, 0, 40)
    earnedLabel.Position               = UDim2.new(0, 0, 0, 103)
    earnedLabel.BackgroundTransparency = 1
    earnedLabel.Text                   = "+0 earned"
    earnedLabel.TextColor3             = Color3.fromRGB(80, 220, 120)
    earnedLabel.Font                   = Enum.Font.GothamBold
    earnedLabel.TextXAlignment         = Enum.TextXAlignment.Center
    earnedLabel.TextScaled             = true

    local ptsHrLabel = Instance.new("TextLabel", centerFrame)
    ptsHrLabel.Size                   = UDim2.new(1, 0, 0, 30)
    ptsHrLabel.Position               = UDim2.new(0, 0, 0, 143)
    ptsHrLabel.BackgroundTransparency = 1
    ptsHrLabel.Text                   = "0 pts/hr"
    ptsHrLabel.TextColor3             = Color3.fromRGB(120, 200, 140)
    ptsHrLabel.Font                   = Enum.Font.GothamBold
    ptsHrLabel.TextXAlignment         = Enum.TextXAlignment.Center
    ptsHrLabel.TextScaled             = true

    local runtimeLabel = Instance.new("TextLabel", raceGui)
    runtimeLabel.Size                   = UDim2.new(0, 100, 0, 20)
    runtimeLabel.Position               = UDim2.new(0, 5, 0, 5)
    runtimeLabel.BackgroundTransparency = 1
    runtimeLabel.Text                   = "00:00:00"
    runtimeLabel.TextColor3             = Color3.fromRGB(180, 180, 220)
    runtimeLabel.Font                   = Enum.Font.GothamBold
    runtimeLabel.TextXAlignment         = Enum.TextXAlignment.Left

    local topInfoLabel = Instance.new("TextLabel", centerFrame)
    topInfoLabel.Size                   = UDim2.new(0.5, 0, 0, 16)
    topInfoLabel.Position               = UDim2.new(0, 5, 0, 178)
    topInfoLabel.BackgroundTransparency = 1
    topInfoLabel.Text                   = "x0"
    topInfoLabel.TextColor3             = Color3.fromRGB(140, 140, 180)
    topInfoLabel.Font                   = Enum.Font.Gotham
    topInfoLabel.TextXAlignment         = Enum.TextXAlignment.Left

    local statusLbl = Instance.new("TextLabel", centerFrame)
    statusLbl.Size                   = UDim2.new(0.5, -5, 0, 16)
    statusLbl.Position               = UDim2.new(0.5, 0, 0, 178)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text                   = "Idle"
    statusLbl.TextColor3             = Color3.fromRGB(100, 100, 140)
    statusLbl.Font                   = Enum.Font.Gotham
    statusLbl.TextXAlignment         = Enum.TextXAlignment.Right

    local botBar = Instance.new("Frame", raceGui)
    botBar.Size                   = UDim2.new(1, 0, 0, 75)
    botBar.Position               = UDim2.new(0, 0, 1, -75)
    botBar.BackgroundColor3       = Color3.fromRGB(10, 10, 20)
    botBar.BackgroundTransparency = 0.3
    botBar.BorderSizePixel        = 0
    local botGrad = Instance.new("UIGradient", botBar)
    botGrad.Rotation     = 270
    botGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.8, 0),
        NumberSequenceKeypoint.new(1, 1),
    })

    task.delay(3, function()
        POINTS_AT_START = getPointsNum()
        SESSION_START   = os.clock()
    end)

    local function refreshRaceGUI()
        pointsLabel.Text = getPointsText()
        local elapsed = os.clock() - SESSION_START
        local earned  = math.max(0, getPointsNum() - POINTS_AT_START)
        local hours   = elapsed / 3600
        local ptsHr   = hours > 0.02 and math.floor(earned / hours) or 0
        ptsHrLabel.Text  = string.format("%d pts/hr", ptsHr)
        earnedLabel.Text = string.format("+%d earned", earned)
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = math.floor(elapsed % 60)
        runtimeLabel.Text  = string.format("%02d:%02d:%02d", h, m, s)
        topInfoLabel.Text  = string.format("x%d races", RACE_COUNT)
        if RUNNING then
            statusLbl.Text       = STATUS_TEXT
            statusLbl.TextColor3 = Color3.fromRGB(90, 200, 120)
        else
            statusLbl.Text       = "Stopped"
            statusLbl.TextColor3 = Color3.fromRGB(100, 100, 140)
        end
    end
    refreshRaceGUI()

    getgenv().racewin = function()
        MODE_RACE       = "WIN"
        RUNNING         = true
        SESSION_START   = os.clock()
        POINTS_AT_START = getPointsNum()
        STATUS_TEXT     = "Starting WIN..."
        refreshRaceGUI()
    end
    getgenv().racelose = function()
        MODE_RACE       = "LOSE"
        RUNNING         = true
        SESSION_START   = os.clock()
        POINTS_AT_START = getPointsNum()
        STATUS_TEXT     = "Starting LOSE..."
        refreshRaceGUI()
    end

    task.spawn(function() while true do task.wait(1); refreshRaceGUI() end end)

    local function sendDiscordWebhook()
        local elapsed = os.clock() - SESSION_START
        local h = math.floor(elapsed / 3600)
        local m = math.floor((elapsed % 3600) / 60)
        local s = math.floor(elapsed % 60)
        local earned  = math.max(0, getPointsNum() - POINTS_AT_START)
        local hours   = elapsed / 3600
        local ptsHr   = hours > 0.02 and math.floor(earned / hours) or 0
        local data    = {
            embeds = {{
                title  = "🏁 " .. player.Name,
                color  = 16769280,
                fields = {
                    { name = "Total Points",   value = getPointsText(),         inline = true },
                    { name = "Earned Session", value = "+" .. tostring(earned), inline = true },
                    { name = "PTS/Hour",       value = tostring(ptsHr),         inline = true },
                    { name = "Races",          value = tostring(RACE_COUNT),    inline = true },
                    { name = "Mode",           value = MODE_RACE,               inline = true },
                    { name = "Runtime",        value = string.format("%02d:%02d:%02d", h, m, s), inline = true },
                },
                footer = { text = "Auto Race v8.3 | " .. os.date("%Y-%m-%d %H:%M:%S") },
            }}
        }
        local url = WEBHOOK_URLS[math.random(1, #WEBHOOK_URLS)]
        pcall(function()
            local r = (syn and syn.request) or (http and http.request) or request
            if r then
                r({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = HttpService:JSONEncode(data) })
            end
        end)
    end

    task.spawn(function()
        while not RUNNING do task.wait(5) end
        task.wait(10); sendDiscordWebhook()
        while true do task.wait(1800); if RUNNING then sendDiscordWebhook() end end
    end)

    task.spawn(function()
        task.wait(25)
        sendInit(tostring(getPointsNum()))
        apiUpdate(player.Name, getPointsNum())
    end)
    task.spawn(function()
        while not RUNNING do task.wait(5) end
        task.wait(10); sendUpdate(tostring(getPointsNum()))
        while true do task.wait(60); if RUNNING then sendUpdate(tostring(getPointsNum())) end end
    end)
    task.spawn(function()
        while not RUNNING do task.wait(5) end
        task.wait(15)
        while true do
            if RUNNING then safeApiUpdate(player.Name, getPointsNum()) end
            task.wait(60)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(1)
            if not RUNNING then continue end
            if not MAP_DELETED then
                STATUS_TEXT = "Deleting map..."; deleteMap(); task.wait(1)
                STATUS_TEXT = "Building platforms..."; buildPlatforms(); task.wait(1)
            end
            local arrived = approachNPC()
            if not arrived or not RUNNING then continue end
            local prompted = fireNPCPrompt()
            if not prompted then task.wait(2); continue end
            local menu = waitMenuOpen()
            if not menu then task.wait(2); continue end
            pcall(function() remotes.LeaveLobby:FireServer() end)
            task.wait(1); fireNPCPrompt(); task.wait(1)
            local menu2 = waitMenuOpen() or menu
            pcall(function() remotes.GetLobbies:InvokeServer() end)
            task.wait(1)
            local joined = false
            if MODE_RACE == "WIN" then
                createLobby(); STATUS_TEXT = "Created lobby (HOST)"
            else
                for attempt = 1, 10 do
                    joined = joinLobby(menu2)
                    if joined then STATUS_TEXT = "Joined lobby"; break end
                    STATUS_TEXT = string.format("No lobby %d/10...", attempt)
                    pcall(function() remotes.GetLobbies:InvokeServer() end)
                    task.wait(3)
                end
                if not joined then STATUS_TEXT = "No lobby..."; task.wait(3); continue end
            end
            task.wait(2); selectRandomCar(); task.wait(0.5); readyUp()
            STATUS_TEXT = "Ready!"
            if MODE_RACE == "WIN" then
                task.spawn(function()
                    while RUNNING and not isRaceHUDVisible() do task.wait(5); remotes.StartRace:FireServer() end
                end)
            end
            STATUS_TEXT = "Waiting race..."
            while RUNNING and not isRaceHUDVisible() do task.wait(0.5) end
            if not RUNNING then continue end
            STATUS_TEXT = "Countdown..."; task.wait(3)
            runRaceLoop()
            pcall(function() player.PlayerGui.Race.Container.Scoreboard:Destroy() end)
            RACE_COUNT += 1
            STATUS_TEXT  = string.format("Done! x%d → NPC", RACE_COUNT)
            local npcRoot2 = NPC_PATH:FindFirstChild("HumanoidRootPart")
            if npcRoot2 and RUNNING then
                local npcPos  = npcRoot2.Position
                local landPos = npcPos + npcRoot2.CFrame.LookVector * 5
                root.CFrame              = CFrame.new(landPos.X, npcPos.Y + 35, landPos.Z)
                root.Anchored            = true
                root.AssemblyLinearVelocity  = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                task.wait(3); root.Anchored = false
                for i = 1, 30 do
                    if not RUNNING then break end
                    root.CFrame = root.CFrame - Vector3.new(0, 1, 0); task.wait(0.03)
                end
                task.wait(0.5)
            end
            local wt = 0
            while RUNNING and isRaceHUDVisible() and wt < 3 do
                task.wait(0.5); wt += 0.5
                pcall(function() player.PlayerGui.Race.Container.RaceHUD.Visible = false end)
            end
        end
    end)
end

-- ═══════════════════════════════════
--  MODE: JOKI UANG
-- ═══════════════════════════════════
local function startJokiUang()
    if not game:IsLoaded() then game.Loaded:Wait() end
    if CoreGui:FindFirstChild("SamlongJokiUI") then CoreGui.SamlongJokiUI:Destroy() end
    serverLock()

    local jokiGui = Instance.new("ScreenGui")
    jokiGui.Name           = "SamlongJokiUI"
    jokiGui.ResetOnSpawn   = false
    jokiGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    jokiGui.Parent         = CoreGui

    local function openSamlongUI()
        local playerGui  = player:WaitForChild("PlayerGui")
        local moneyLabel = playerGui
            :WaitForChild("Main")
            :WaitForChild("Container")
            :WaitForChild("Hub")
            :WaitForChild("CashFrame")
            :WaitForChild("Frame")
            :WaitForChild("TextLabel")

        local shadow = Instance.new("Frame", jokiGui)
        shadow.Size                   = UDim2.new(1, 0, 1, 0)
        shadow.BackgroundColor3       = Color3.new(0, 0, 0)
        shadow.BackgroundTransparency = 0.4

        local mainF = Instance.new("Frame", jokiGui)
        mainF.Size             = UDim2.new(0, 520, 0, 300)
        mainF.Position         = UDim2.new(0.5, 0, 0.5, 0)
        mainF.AnchorPoint      = Vector2.new(0.5, 0.5)
        mainF.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        local cornerJ = Instance.new("UICorner", mainF)
        cornerJ.CornerRadius = UDim.new(0, 16)

        local usernameText = Instance.new("TextLabel", mainF)
        usernameText.Size                   = UDim2.new(1, -40, 0, 50)
        usernameText.Position               = UDim2.new(0, 20, 0, 15)
        usernameText.BackgroundTransparency = 1
        usernameText.Font                   = Enum.Font.GothamBlack
        usernameText.TextScaled             = true
        usernameText.TextColor3             = Color3.fromRGB(255, 220, 80)
        usernameText.Text                   = player.Name

        local uangText = Instance.new("TextLabel", mainF)
        uangText.Size                   = UDim2.new(1, -40, 0, 80)
        uangText.Position               = UDim2.new(0, 20, 0, 65)
        uangText.BackgroundTransparency = 1
        uangText.Font                   = Enum.Font.GothamBlack
        uangText.TextScaled             = true
        uangText.TextColor3             = Color3.new(1, 1, 1)
        uangText.Text                   = moneyLabel.Text

        local earnText = Instance.new("TextLabel", mainF)
        earnText.Size                   = UDim2.new(1, -40, 0, 40)
        earnText.Position               = UDim2.new(0, 20, 0, 150)
        earnText.BackgroundTransparency = 1
        earnText.Font                   = Enum.Font.GothamSemibold
        earnText.TextScaled             = true
        earnText.TextColor3             = Color3.fromRGB(200, 200, 200)
        earnText.Text                   = "Earn terakhir: -"

        local ng = Instance.new("TextLabel", jokiGui)
        ng.Size             = UDim2.new(0, 600, 0, 100)
        ng.Position         = UDim2.new(0.5, 0, 0.85, 0)
        ng.AnchorPoint      = Vector2.new(0.5, 0.5)
        ng.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        ng.Font             = Enum.Font.GothamBlack
        ng.TextScaled       = true
        ng.TextColor3       = Color3.new(1, 1, 1)
        ng.Text             = "SUPIR NGANGGUR BOS!!!"
        ng.Visible          = false
        local c2 = Instance.new("UICorner", ng)
        c2.CornerRadius = UDim.new(0, 12)

        local lastEarn  = os.time()
        local prevMoney = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0

        moneyLabel:GetPropertyChangedSignal("Text"):Connect(function()
            local cur = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
            if cur ~= prevMoney then
                prevMoney = cur
                lastEarn  = os.time()
                uangText.Text = moneyLabel.Text
            end
        end)

        task.spawn(function()
            while true do
                task.wait(1)
                local elapsed = os.time() - lastEarn
                earnText.Text = string.format(
                    "Earn terakhir: %02d menit %02d detik",
                    math.floor(elapsed / 60),
                    elapsed % 60
                )
                if elapsed >= 360 then ng.Visible = true end
            end
        end)

        task.spawn(function()
            task.wait(3)
            local initMoney = formatUang(moneyLabel.Text)
            local initRaw   = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
            sendInit(initMoney)
            apiUpdate(player.Name, initRaw)   -- initial send, bypasses throttle intentionally
            while true do
                task.wait(60)
                local curFmt = formatUang(moneyLabel.Text)
                local curRaw = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
                sendUpdate(curFmt)
                safeApiUpdate(player.Name, curRaw)
            end
        end)
    end

    openSamlongUI()

    pcall(function()
        getgenv().startAutofarm       = true
        getgenv().teleportTime        = "50.5"
        getgenv().recallJobTime       = "0.3"
        getgenv().optimizePerformance = true
        loadstring(game:HttpGet("https://api.luarmor.net/files/v4/loaders/5b6c215f1b2f5b4c696abed7a89c95bf.lua"))()
    end)
end

-- ════════════════════════════════════════════════════════
--  AUTO BRAIN CONTROLLER
-- ════════════════════════════════════════════════════════

-- ─────────────────────────────────────────
--  STATE DETECTION
--  lobby  → PlayerGui.Hub exists (CDID menu before join)
--  ingame → character loaded + PlayerGui.Main exists (in-server)
-- ─────────────────────────────────────────
local function detectState()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end

    -- Primary: Hub GUI only exists in the CDID lobby/menu
    if pg:FindFirstChild("Hub") then
        return "lobby"
    end

    -- Secondary: Main GUI + loaded character = in a private server
    local char = player.Character
    if pg:FindFirstChild("Main")
       and char
       and char:FindFirstChild("HumanoidRootPart") then
        return "ingame"
    end

    return nil
end

-- ─────────────────────────────────────────
--  MODE RESOLVER
--  Maps API fields (jenis + jump_mode) → internal mode string
-- ─────────────────────────────────────────
local function resolveMode(data)
    if not data then return nil end

    local jenis     = (data.jenis     or ""):lower()
    local jumpMode  = (data.jump_mode or ""):lower()

    if jenis == "uang" then
        return "joki_uang"

    elseif jenis == "minigame" then
        if jumpMode == "jump" then return "minigame_jump"
        else                       return "minigame_nojump" end

    elseif jenis == "event" then
        -- event uses same execution as minigame, only jenis differs
        if jumpMode == "jump" then return "event_jump"
        else                       return "event_nojump" end
    end

    return nil
end

-- ─────────────────────────────────────────
--  STATE CONTROLLER
-- ─────────────────────────────────────────
local currentState      = nil
local activeModeRunning = nil  -- prevents re-running same mode

-- ─────────────────────────────────────────
--  ON LOBBY — runs autojoin logic
-- ─────────────────────────────────────────
local function onLobby()
    log("[LOBBY] Started")

    task.spawn(function()
        task.wait(3)

        local username = player.Name
        log("[LOBBY] Player: " .. username)

        -- Get Remote + ServerLabel
        local remote = rp:WaitForChild("NetworkContainer", 10)
        if not remote then log("[LOBBY] No NetworkContainer"); return end
        remote = remote:WaitForChild("RemoteEvents", 5)
        if not remote then log("[LOBBY] No RemoteEvents"); return end
        remote = remote:WaitForChild("PrivateServer", 5)
        if not remote then log("[LOBBY] No PrivateServer remote"); return end

        local pg    = player:WaitForChild("PlayerGui")
        local label = pg
            :WaitForChild("Hub", 10)
        if not label then log("[LOBBY] No Hub"); return end
        label = label
            :WaitForChild("Container", 5)
            :WaitForChild("Window", 5)
            :WaitForChild("PrivateServer", 5)
            :WaitForChild("ServerLabel", 5)
        if not label then log("[LOBBY] No ServerLabel"); return end

        -- Wait for server code to appear in UI
        local waited = 0
        repeat
            task.wait(0.5)
            waited += 0.5
        until label.Text ~= "" or waited >= 15

        local localCode = label.Text
        if localCode == "" then
            log("[LOBBY] ServerLabel empty after wait, aborting")
            return
        end
        log("[LOBBY] UI code: " .. localCode)

        -- Check API
        local data = getPS(username)

        if not data or not data.server_code or data.server_code == "" then
            log("[LOBBY] API empty, sending code")
            setPS(username, localCode)
            task.wait(1)
            -- Re-fetch so we get the group's shared code (backend may redirect to slot 1)
            local fresh = getPS(username)
            data = { server_code = (fresh and fresh.server_code ~= "" and fresh.server_code) or localCode, jenis = (fresh and fresh.jenis) or (data and data.jenis) }
        else
            log("[LOBBY] API code: " .. data.server_code)
        end

        -- Tentukan region berdasarkan jenis
        local jenisFix = (data.jenis or ""):lower()
        local joinRegion
        if jenisFix == "event" then
            joinRegion = "Seasonal"
        elseif jenisFix == "minigame" then
            joinRegion = "Jakarta"
        else
            joinRegion = "JawaTimur"  -- uang / default
        end

        -- Queue autoexec untuk setelah teleport ke map
        local queued = queueOnTeleport([[
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(7)
local ok, err = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/brain.lua"))()
end)
if not ok then print("[BRAIN] Autoexec error: " .. tostring(err)) end
]])
        if queued then
            log("[QUEUE] Autoexec queued OK")
        else
            log("[QUEUE] WARN: queue_on_teleport tidak support di executor ini")
        end

        -- Wait then join
        log("[LOBBY] Waiting 10s before join")
        task.wait(10)
        log("[LOBBY] Joining → " .. data.server_code .. " | region: " .. joinRegion)
        remote:FireServer("Join", data.server_code, joinRegion)
    end)
end

-- ─────────────────────────────────────────
--  ON INGAME — fetch job from API, execute mode
-- ─────────────────────────────────────────
local function onIngame()
    log("[INGAME] Detected")

    task.spawn(function()
        -- Wait for character fully ready
        local char = player.Character or player.CharacterAdded:Wait()
        local waited = 0
        while not char:FindFirstChild("HumanoidRootPart") and waited < 10 do
            task.wait(0.5)
            waited += 0.5
        end
        task.wait(3)  -- extra settle time per CLAUDE.md

        log("[INGAME] Character ready, fetching job...")

        local data = getPS(player.Name)
        if not data then
            log("[INGAME] API returned nil, retry in 10s")
            task.wait(10)
            data = getPS(player.Name)
        end

        if not data then
            log("[INGAME] No data from API, abort")
            return
        end

        local mode = resolveMode(data)
        if not mode then
            log("[INGAME] resolveMode returned nil (jenis=" .. tostring(data.jenis) .. ")")
            return
        end

        -- Anti-double execution
        if activeModeRunning == mode then
            log("[INGAME] Mode already running: " .. mode)
            return
        end

        activeModeRunning = mode
        log("[INGAME] Execute mode: " .. mode)

        if mode == "joki_uang" then
            startJokiUang()

        elseif mode == "minigame_jump" then
            startMinigame()
            task.wait(1)
            getgenv().minigame_jump()

        elseif mode == "minigame_nojump" then
            startMinigame()
            task.wait(1)
            getgenv().minigame_nojump()

        elseif mode == "event_jump" then
            -- jump → racelose (Seasonal map)
            startRace()
            task.wait(1)
            getgenv().racelose()

        elseif mode == "event_nojump" then
            -- nojump → racewin (Seasonal map)
            startRace()
            task.wait(1)
            getgenv().racewin()
        end
    end)
end

-- ─────────────────────────────────────────
--  MAIN DETECTION LOOP
-- ─────────────────────────────────────────
log("[BRAIN] Starting state loop")

task.spawn(function()
    while true do
        task.wait(2)

        local detectedState = detectState()

        if detectedState ~= currentState then
            log("[BRAIN] State: " .. tostring(currentState) .. " → " .. tostring(detectedState))
            currentState = detectedState

            if detectedState == "lobby" then
                activeModeRunning = nil  -- reset on return to lobby
                onLobby()
            elseif detectedState == "ingame" then
                onIngame()
            end
        end
    end
end)