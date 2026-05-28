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
local HttpService       = game:GetService("HttpService")
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

-- ─── GAME ROUTING ────────────────────────────────────────────
local PLACE_IDS = {
    CDID = 6911148748,
    DDS  = 131378148336503,
}

local AUTOEXEC = [[
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(7)
local ok, err = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/brain.lua"))()
end)
if not ok then print("[BRAIN] Autoexec error: " .. tostring(err)) end
]]

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

local ejectBtn = Instance.new("TextButton", logGui)
ejectBtn.Size             = UDim2.new(0, 140, 0, 34)
ejectBtn.Position         = UDim2.new(0, 10, 0, 10)
ejectBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
ejectBtn.BorderSizePixel  = 0
ejectBtn.Font             = Enum.Font.GothamBold
ejectBtn.TextSize         = 13
ejectBtn.TextColor3       = Color3.new(1, 1, 1)
ejectBtn.Text             = "⏏  EJECT BRAIN"
ejectBtn.ZIndex           = 20
Instance.new("UICorner", ejectBtn).CornerRadius = UDim.new(0, 6)

-- Semua thread yang di-spawn disimpan di sini supaya bisa di-cancel semua waktu eject
local _threads = {}
local function safeSpawn(fn)
    local t = task.spawn(fn)
    _threads[#_threads + 1] = t
    return t
end

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
--  WRONG GAME POPUP
-- ═══════════════════════════════════
local function showWrongGamePopup(shouldBe)
    pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local ex = pg:FindFirstChild("SamlongWrongGame")
        if ex then ex:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name           = "SamlongWrongGame"
        gui.ResetOnSpawn   = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        gui.DisplayOrder   = 999
        gui.Parent         = pg

        local overlay = Instance.new("Frame", gui)
        overlay.Size                   = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        overlay.BackgroundTransparency = 0.45
        overlay.BorderSizePixel        = 0
        overlay.ZIndex                 = 100

        local box = Instance.new("Frame", gui)
        box.Size             = UDim2.new(0, 540, 0, 230)
        box.Position         = UDim2.new(0.5, -270, 0.5, -115)
        box.BackgroundColor3 = Color3.fromRGB(170, 15, 15)
        box.BorderSizePixel  = 0
        box.ZIndex           = 101
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 16)

        local topBar = Instance.new("Frame", box)
        topBar.Size             = UDim2.new(1, 0, 0, 7)
        topBar.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
        topBar.BorderSizePixel  = 0
        topBar.ZIndex           = 102
        Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 16)

        local title = Instance.new("TextLabel", box)
        title.Size                   = UDim2.new(1, 0, 0, 60)
        title.Position               = UDim2.new(0, 0, 0, 15)
        title.BackgroundTransparency = 1
        title.Text                   = "⚠️  GAME TIDAK SESUAI"
        title.TextColor3             = Color3.fromRGB(255, 255, 255)
        title.Font                   = Enum.Font.GothamBold
        title.TextSize               = 28
        title.TextXAlignment         = Enum.TextXAlignment.Center
        title.ZIndex                 = 102

        local div = Instance.new("Frame", box)
        div.Size             = UDim2.new(1, -40, 0, 2)
        div.Position         = UDim2.new(0, 20, 0, 78)
        div.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        div.BorderSizePixel  = 0
        div.ZIndex           = 102

        local msg = Instance.new("TextLabel", box)
        msg.Size                   = UDim2.new(1, -20, 0, 90)
        msg.Position               = UDim2.new(0, 10, 0, 88)
        msg.BackgroundTransparency = 1
        msg.Text                   = player.Name .. " SEHARUSNYA MASUK KE MAP:\n" .. shouldBe
        msg.TextColor3             = Color3.fromRGB(255, 230, 60)
        msg.Font                   = Enum.Font.GothamBold
        msg.TextSize               = 22
        msg.TextWrapped            = true
        msg.TextXAlignment         = Enum.TextXAlignment.Center
        msg.ZIndex                 = 102

        local okBtn = Instance.new("TextButton", box)
        okBtn.Size                   = UDim2.new(0, 160, 0, 36)
        okBtn.Position               = UDim2.new(0.5, -80, 0, 184)
        okBtn.BackgroundColor3       = Color3.fromRGB(220, 50, 50)
        okBtn.BorderSizePixel        = 0
        okBtn.Text                   = "OK, MENGERTI"
        okBtn.TextColor3             = Color3.fromRGB(255, 255, 255)
        okBtn.Font                   = Enum.Font.GothamBold
        okBtn.TextSize               = 14
        okBtn.ZIndex                 = 103
        Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 8)
        okBtn.MouseButton1Click:Connect(function()
            gui:Destroy()
        end)
    end)
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

-- Throttled wrapper: max 1 per 60s; kirim jika nilai berubah ATAU 10 menit berlalu (heartbeat)
local _lastSend  = -math.huge
local _lastValue = nil

local function safeApiUpdate(username, value)
    local now = os.clock()
    if now - _lastSend < 60 then return end
    if value == _lastValue and now - _lastSend < 600 then return end
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
--  SAMLONG LOBBY SYSTEM
--  Auto return to lobby on stuck/disconnect
-- ═══════════════════════════════════
local function ReturnLobby()
    local success, err = pcall(function()
        local realBtn = player.PlayerGui
            .Settings.Canvas.Main.CanvasGroup.ScrollingFrame.ReturnMenu
        firesignal(realBtn.Activated)
    end)

    if success then
        log("[LOBBY] Returning to lobby...")
    else
        log("[LOBBY] ReturnLobby failed: " .. tostring(err))
    end
end

-- Auto reconnect on disconnect
safeSpawn(function()
    local promptGui = CoreGui:WaitForChild("RobloxPromptGui")
    local overlay = promptGui:WaitForChild("promptOverlay")

    overlay.ChildAdded:Connect(function(child)
        if child.Name == "ErrorPrompt" then
            warn("[SAMLONG] Disconnect detected")
            task.wait(3)
            ReturnLobby()
        end
    end)
end)

log("[BRAIN] Lobby system loaded")

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
    activeMovementThread = safeSpawn(function()
        local function getRandomCar()
            local ok, carList = pcall(function()
                return player.PlayerGui.Main.Container.Spawner.ScrollingFrame
            end)
            if not ok or not carList then return nil end
            local cars = {}
            for _, v in pairs(carList:GetChildren()) do
                if v:IsA("Frame") then table.insert(cars, v.Name) end
            end
            if #cars == 0 then return nil end
            return cars[math.random(1, #cars)]
        end

        while true do
            local chosenCar = getRandomCar()
            if chosenCar then
                pcall(function()
                    rp:WaitForChild("NetworkContainer")
                      :WaitForChild("RemoteEvents")
                      :WaitForChild("Minigames")
                      :FireServer("Enter", chosenCar)
                end)
            end
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
                while game.Players.LocalPlayer.Character
                      and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid")
                      and game.Players.LocalPlayer.Character.Humanoid.Health > 0 do
                    game.Players.LocalPlayer.Character.Humanoid.Jump = true
                    wait(0.1)
                end
                wait(5)
                local newChar = game.Players.LocalPlayer.Character
                if newChar then
                    local newPl = newChar:FindFirstChild("HumanoidRootPart")
                    if newPl then newPl.CFrame = respawnLocation end
                end
            else
                task.wait(1)
            end
        end
    end)
end

local function startNoJumpLoop()
    stopMovementLoop()
    activeMovementThread = safeSpawn(function()
        local function getRandomCar()
            local ok, carList = pcall(function()
                return player.PlayerGui.Main.Container.Spawner.ScrollingFrame
            end)
            if not ok or not carList then return nil end
            local cars = {}
            for _, v in pairs(carList:GetChildren()) do
                if v:IsA("Frame") then table.insert(cars, v.Name) end
            end
            if #cars == 0 then return nil end
            return cars[math.random(1, #cars)]
        end

        while true do
            local chosenCar = getRandomCar()
            if chosenCar then
                pcall(function()
                    rp:WaitForChild("NetworkContainer")
                      :WaitForChild("RemoteEvents")
                      :WaitForChild("Minigames")
                      :FireServer("Enter", chosenCar)
                end)
            end
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
                -- nojump: just wait, don't jump
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
        log("[ERROR] MinigamePoint GUI tidak ditemukan setelah 30s")
    end

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

    safeSpawn(updatePoint)
    safeSpawn(function()
        while true do updateLastPlayed(); task.wait(1) end
    end)
    safeSpawn(function()
        while true do
            if not alerted and os.difftime(os.time(), lastValChange) >= STUCK_THRESHOLD then
                popupFrame.Visible = true
                okBtn.Visible      = true
                alerted            = true
                log("[MINIGAME] Stuck detected! Auto return to lobby...")
                task.wait(3)
                ReturnLobby()
            end
            task.wait(1)
        end
    end)

    safeSpawn(function()
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

        safeSpawn(function()
            while true do
                task.wait(1)
                local elapsed = os.time() - lastEarn
                earnText.Text = string.format(
                    "Earn terakhir: %02d menit %02d detik",
                    math.floor(elapsed / 60),
                    elapsed % 60
                )
                if elapsed >= 360 and not ng.Visible then
                    ng.Visible = true
                    log("[UANG] Supir nganggur! Auto return to lobby...")
                    safeSpawn(function()
                        task.wait(3)
                        ReturnLobby()
                    end)
                end
            end
        end)

        safeSpawn(function()
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
        script_key="QcEodpdBkpQLVHmaaIRvduPLpewFdzTP"; -- keys
loadstring(game:HttpGet("https://raw.githubusercontent.com/bimoraa/Euphoria/refs/heads/main/loader.luau"))()
    end)
end

-- ═══════════════════════════════════
--  MODE: EVENT
-- ═══════════════════════════════════
local function startEvent()
    log("[EVENT] Starting for " .. player.Name)
    serverLock()

    -- Hapus phone / hub
    pcall(function()
        CoreGui.RobloxGui.Backpack.Hotbar:Destroy()
    end)

    -- ── Overlay GUI (selalu di atas, termasuk blackscreen) ──
    pcall(function()
        if CoreGui:FindFirstChild("SamlongEventUI") then
            CoreGui.SamlongEventUI:Destroy()
        end
    end)

    local evGui = Instance.new("ScreenGui")
    evGui.Name         = "SamlongEventUI"
    evGui.ResetOnSpawn = false
    evGui.DisplayOrder = 9999
    evGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    evGui.Parent       = CoreGui

    local evFrame = Instance.new("Frame", evGui)
    evFrame.Size             = UDim2.new(0, 280, 0, 100)
    evFrame.Position         = UDim2.new(1, -295, 0, 15)
    evFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    evFrame.BackgroundTransparency = 0.15
    evFrame.BorderSizePixel  = 0
    Instance.new("UICorner", evFrame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", evFrame)
    stroke.Color     = Color3.fromRGB(80, 160, 255)
    stroke.Thickness = 1.5

    local evName = Instance.new("TextLabel", evFrame)
    evName.Size                   = UDim2.new(1, -16, 0, 42)
    evName.Position               = UDim2.new(0, 8, 0, 6)
    evName.BackgroundTransparency = 1
    evName.Font                   = Enum.Font.GothamBlack
    evName.TextScaled             = true
    evName.TextColor3             = Color3.fromRGB(255, 220, 60)
    evName.TextStrokeTransparency = 0.4
    evName.TextStrokeColor3       = Color3.new(0, 0, 0)
    evName.TextXAlignment         = Enum.TextXAlignment.Center
    evName.Text                   = player.Name

    local evPoints = Instance.new("TextLabel", evFrame)
    evPoints.Size                   = UDim2.new(1, -16, 0, 46)
    evPoints.Position               = UDim2.new(0, 8, 0, 48)
    evPoints.BackgroundTransparency = 1
    evPoints.Font                   = Enum.Font.GothamBlack
    evPoints.TextScaled             = true
    evPoints.TextColor3             = Color3.new(1, 1, 1)
    evPoints.TextStrokeTransparency = 0.4
    evPoints.TextStrokeColor3       = Color3.new(0, 0, 0)
    evPoints.TextXAlignment         = Enum.TextXAlignment.Center
    evPoints.Text                   = "... PTS"

    safeSpawn(function()
        local pg = player:WaitForChild("PlayerGui", 15)
        if not pg then log("[EVENT] PlayerGui not found"); return end
        local eventShop = pg:WaitForChild("EVENT SHOP", 15)
        if not eventShop then log("[EVENT] EVENT SHOP GUI not found"); return end
        local valLabel = eventShop
            :WaitForChild("Shop", 10)
            :WaitForChild("TitleBar", 10)
            :WaitForChild("PointsPill", 10)
            :WaitForChild("Value", 10)
        if not valLabel then log("[EVENT] PointsPill Value not found"); return end

        local function parsePoints(txt)
            txt = tostring(txt or "")
            local nums = {}
            for n in txt:gmatch("%d+") do nums[#nums+1] = n end
            return tonumber(table.concat(nums)) or 0
        end

        local latestPts   = 0
        local lastValChange = os.time()

        local function onValueChanged()
            local v = parsePoints(valLabel.Text)
            if v > 0 and v ~= latestPts then
                latestPts   = v
                lastValChange = os.time()
                evPoints.Text = tostring(v) .. " PTS"
                sendUpdate(tostring(v))
                safeApiUpdate(player.Name, v)
                log("[EVENT] Poin update: " .. tostring(v))
            end
        end

        valLabel:GetPropertyChangedSignal("Text"):Connect(onValueChanged)

        -- Tunggu hingga nilai stabil (game perlu beberapa detik load dari server)
        local initPts = 0
        for _ = 1, 20 do
            task.wait(1)
            initPts = parsePoints(valLabel.Text)
            if initPts > 0 then break end
        end
        if latestPts == 0 then latestPts = initPts end
        lastValChange = os.time()
        evPoints.Text = tostring(latestPts) .. " PTS"
        log("[EVENT] Poin awal: " .. tostring(initPts))
        sendInit(tostring(initPts))
        apiUpdate(player.Name, initPts)

        -- Stuck detector: poin ga naik 10 menit → relog
        safeSpawn(function()
            local STUCK_THRESHOLD = 600
            while true do
                task.wait(60)
                local elapsed = os.difftime(os.time(), lastValChange)
                if elapsed >= STUCK_THRESHOLD then
                    log("[EVENT] Stuck " .. math.floor(elapsed/60) .. "m — auto relog")
                    lastValChange = os.time()  -- reset biar ga spam
                    ReturnLobby()
                end
            end
        end)

        while true do
            task.wait(60)
            local cur = parsePoints(valLabel.Text)
            if cur > 0 and cur ~= latestPts then
                latestPts   = cur
                lastValChange = os.time()
                log("[EVENT] Poin poll: " .. tostring(cur))
            end
            local sendVal = latestPts > 0 and latestPts or cur
            evPoints.Text = tostring(sendVal) .. " PTS"
            sendUpdate(tostring(sendVal))
            safeApiUpdate(player.Name, sendVal)
        end
    end)

    getgenv().key    = "411572f1-0a19-42fc-ab0c-f386ad74bad6"
    getgenv().script = "Adha"
    pcall(function()
        loadstring(game:HttpGet("https://cdn.luviohub.xyz/"))()
    end)
end

-- ═══════════════════════════════════
--  MODE: DDS
-- ═══════════════════════════════════
local function startDDS()
    log("[DDS] Starting for " .. player.Name)

    safeSpawn(function()
        local pd    = player:WaitForChild("PlayerData", 15)
        if not pd then log("[DDS] PlayerData not found"); return end
        local rpVal = pd:WaitForChild("RPValue", 10)
        if not rpVal then log("[DDS] RPValue not found"); return end

        task.wait(3)
        local initRP = rpVal.Value or 0
        log("[DDS] RP awal: " .. tostring(initRP))
        sendInit(tostring(initRP))
        apiUpdate(player.Name, initRP)

        while true do
            task.wait(60)
            local curRP = rpVal.Value or 0
            sendUpdate(tostring(curRP))
            safeApiUpdate(player.Name, curRP)
        end
    end)

    getgenv().key    = "234246b8-cb63-4ba6-b29c-17eaf5f38247"
    getgenv().script = "DDS"
    pcall(function()
        loadstring(game:HttpGet("https://cdn.luviohub.xyz/"))()
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

    local jenis    = (data.jenis     or ""):lower()
    local jumpMode = (data.jump_mode or ""):lower()

    if jenis == "uang" then
        return "joki_uang"

    elseif jenis == "minigame" then
        if jumpMode == "jump" then return "minigame_jump"
        else                       return "minigame_nojump" end

    elseif jenis == "event" then
        return "event"
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

    safeSpawn(function()
        task.wait(3)

        local username = player.Name
        log("[LOBBY] Player: " .. username)

        -- Fetch job FIRST to know which game before doing anything else
        local data = getPS(username)
        local targetGame = data and (data.game or "CDID"):upper() or "CDID"
        log("[LOBBY] Job game: " .. targetGame)

        -- DDS job in CDID lobby: cannot teleport cross-game from here, show popup
        if targetGame == "DDS" then
            log("[LOBBY] Job adalah DDS tapi player di CDID! Tampilkan popup.")
            showWrongGamePopup("DDS (Drag Drive Simulator)")
            return
        end

        -- CDID job: proceed with private server join logic
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

        -- API code takes priority; UI ServerLabel only used as fallback/sync source
        local serverCode = (data and data.server_code ~= "" and data.server_code) or nil

        if not serverCode then
            -- API has no code — try reading from game UI
            local waited = 0
            repeat
                task.wait(0.5); waited += 0.5
            until (label.Text ~= "" and label.Text ~= "None") or waited >= 15

            local uiCode = label.Text
            if uiCode ~= "" and uiCode ~= "None" then
                serverCode = uiCode
                log("[LOBBY] UI code: " .. uiCode .. " → syncing to API")
                setPS(username, uiCode)
                task.wait(1)
                local fresh = getPS(username)
                if fresh then
                    data = fresh
                    if fresh.server_code and fresh.server_code ~= "" then serverCode = fresh.server_code end
                end
            end
        else
            log("[LOBBY] API code: " .. serverCode)
        end

        -- No code yet (dummy/idle slot) → retry setiap 30s sampai order di-assign
        local retries = 0
        while not serverCode and currentState == "lobby" do
            retries += 1
            if retries > 12 then log("[LOBBY] No code after 6min, abort"); return end
            log("[LOBBY] Belum ada order, retry " .. retries .. "/12 in 15s")
            task.wait(15)
            if currentState ~= "lobby" then return end

            -- Re-check UI label first (popup mungkin baru dibuka setelah poll awal)
            if label then
                local uiRetry = label.Text
                if uiRetry ~= "" and uiRetry ~= "None" then
                    serverCode = uiRetry
                    log("[LOBBY] UI code (retry " .. retries .. "): " .. uiRetry .. " → syncing")
                    setPS(username, uiRetry)
                    task.wait(1)
                    local fresh = getPS(username)
                    if fresh then data = fresh end
                    break
                end
            end

            local fresh = getPS(username)
            if fresh then
                data = fresh
                if fresh.server_code and fresh.server_code ~= "" then
                    serverCode = fresh.server_code
                    log("[LOBBY] Code from retry: " .. serverCode)
                end
            end
        end

        if not serverCode then return end

        -- Region berdasarkan jenis
        local jenisFix = (data and data.jenis or ""):lower()
        local joinRegion
        if jenisFix == "event" then
            joinRegion = "Seasonal"
        elseif jenisFix == "minigame" then
            joinRegion = "Jakarta"
        else
            joinRegion = "JawaTimur"
        end

        local queued = queueOnTeleport(AUTOEXEC)
        if queued then
            log("[QUEUE] Autoexec queued OK")
        else
            log("[QUEUE] WARN: queue_on_teleport tidak support di executor ini")
        end

        log("[LOBBY] Waiting 10s before join")
        task.wait(10)
        log("[LOBBY] Joining → " .. serverCode .. " | region: " .. joinRegion)
        remote:FireServer("Join", serverCode, joinRegion)
    end)
end

-- ─────────────────────────────────────────
--  ON INGAME — fetch job from API, execute mode
-- ─────────────────────────────────────────
local function onIngame()
    log("[INGAME] Detected")
    if activeModeRunning then
        log("[INGAME] Mode already running: " .. activeModeRunning .. ", skip re-fetch")
        return
    end

    safeSpawn(function()
        -- Wait for character fully ready
        local char = player.Character or player.CharacterAdded:Wait()
        local waited = 0
        while not char:FindFirstChild("HumanoidRootPart") and waited < 10 do
            task.wait(0.5)
            waited += 0.5
        end
        task.wait(3)

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

        -- Game routing: if job is DDS but we're in CDID, teleport
        local targetGame = (data.game or "CDID"):upper()
        if targetGame == "DDS" then
            if game.PlaceId ~= PLACE_IDS.DDS then
                showWrongGamePopup("DDS (Drag Drive Simulator)")
                log("[INGAME] Job requires DDS, teleporting...")
                task.wait(3)
                activeModeRunning = "dds"
                queueOnTeleport(AUTOEXEC)
                game:GetService("TeleportService"):Teleport(PLACE_IDS.DDS, player)
            else
                activeModeRunning = "dds"
                startDDS()
            end
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

        elseif mode == "event" then
            startEvent()
        end
    end)
end

-- ─────────────────────────────────────────
--  DDS FAST PATH
--  Jika sudah di DDS, skip seluruh CDID state machine
-- ─────────────────────────────────────────
if game.PlaceId == PLACE_IDS.DDS then
    log("[BRAIN] DDS place detected")
    safeSpawn(function()
        local ok, err = pcall(function()
            local char = player.Character or player.CharacterAdded:Wait()
            local w = 0
            while not char:FindFirstChild("HumanoidRootPart") and w < 10 do
                task.wait(0.5); w += 0.5
            end
            task.wait(3)

            log("[DDS] Fetching job...")
            local data = getPS(player.Name)
            if not data then task.wait(10); data = getPS(player.Name) end

            local targetGame = data and (data.game or "CDID"):upper() or "CDID"
            if targetGame ~= "DDS" then
                showWrongGamePopup("CDID (Car Driving Indonesia)")
                log("[DDS] Job is CDID, teleporting back...")
                task.wait(3)
                queueOnTeleport(AUTOEXEC)
                game:GetService("TeleportService"):Teleport(PLACE_IDS.CDID, player)
                return
            end

            startDDS()
        end)
        getgenv()._samlongBrainRunning = false
        if not ok then log("[BRAIN] DDS fast-path error: " .. tostring(err)) end
    end)
    return  -- skip CDID state machine
end

-- ─────────────────────────────────────────
--  EJECT
-- ─────────────────────────────────────────
local mainLoopThread = nil

local function eject()
    getgenv()._samlongBrainRunning = false
    -- Cancel semua thread yang pernah di-spawn (minigame loop, uang loop, reconnect, dll.)
    for _, t in ipairs(_threads) do pcall(task.cancel, t) end
    if mainLoopThread then pcall(task.cancel, mainLoopThread) end
    -- Destroy semua GUI
    pcall(function() logGui:Destroy() end)
    pcall(function() if CoreGui:FindFirstChild("SamlongGUI") then CoreGui.SamlongGUI:Destroy() end end)
    pcall(function() if CoreGui:FindFirstChild("SamlongJokiUI") then CoreGui.SamlongJokiUI:Destroy() end end)
    print("[BRAIN] EJECTED — semua thread dihentikan, aman eksekusi script lain")
end

ejectBtn.MouseButton1Click:Connect(eject)

-- ─────────────────────────────────────────
--  MAIN DETECTION LOOP
-- ─────────────────────────────────────────
log("[BRAIN] Starting state loop")

mainLoopThread = safeSpawn(function()
    local ok, err = pcall(function()
        while true do
            task.wait(2)

            local detectedState = detectState()

            if detectedState ~= currentState then
                log("[BRAIN] State: " .. tostring(currentState) .. " → " .. tostring(detectedState))
                currentState = detectedState

                if detectedState == "lobby" then
                    activeModeRunning = nil
                    onLobby()
                elseif detectedState == "ingame" then
                    onIngame()
                end
            end
        end
    end)
    getgenv()._samlongBrainRunning = false
    if not ok then
        log("[BRAIN] Fatal error: " .. tostring(err))
    end
end)
