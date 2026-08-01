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
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
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

-- POST /api/konvoi-advance  { username } → bumps the group's rotation counter.
-- Only the Winner device calls this (backend rejects it from anyone else),
-- once per round, so the next round's leave-list rotates fairly.
local function konvoiAdvance(username)
    local res = req({
        Url     = API_URL .. "/api/konvoi-advance",
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = API_KEY },
        Body    = HttpService:JSONEncode({ username = username }),
    })
    if res and res.StatusCode == 200 then
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok then return data end
    end
end

-- GET /api/konvoi-team-points?username=xxx → { total } summed across the
-- whole Konvoi group. Used instead of this device's own points for the
-- stuck/reconnect check — a Leaver's own points legitimately never move.
local function getKonvoiTeamPoints(username)
    local res = req({
        Url     = API_URL .. "/api/konvoi-team-points?username=" .. HttpService:UrlEncode(username),
        Method  = "GET",
        Headers = { ["x-api-key"] = API_KEY },
    })
    if res and res.StatusCode == 200 then
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok then return data end
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
            local initRaw = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
            sendInit(tostring(initRaw))
            apiUpdate(player.Name, initRaw)   -- initial send, bypasses throttle intentionally
            while true do
                task.wait(60)
                local curRaw = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
                sendUpdate(tostring(curRaw))
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
--  MODE: EVENT (Race Nostalgia)
--  Role (winner/follower) datang dari API jump_mode — tidak ada pilihan
--  manual in-game lagi. nojump = winner (create+start lobby), jump = follower
--  (join lobby, ikut jalan).
-- ═══════════════════════════════════
local RaceBrain = {}
do
    local RaceConfig = {
        LobbyName                 = "ProfessionalUnemploy's Lobby",
        FollowerFindRetryInterval = 5, -- follower: re-poll + refresh GetLobbies tiap N detik sampai lobby winner muncul
        RetryDelay                = 1,
        RaceStartTimeout          = 120,
        StartRaceRetryInterval    = 5,
        StartRaceLoopTimeout      = 300,
        WinnerDriveSpeed          = 220,
        FollowerDriveSpeed        = 190,
        ArriveDistance            = 12,
        CheckpointLegTimeout      = 30,
        ScoreboardTimeout         = 60,
        ScoreboardWaitAttempts    = 5,
        RaceAgainSettleDelay      = 3,
        RequeueAttempts           = 10,
    }
    local IsWinner = true

    local function rlog(msg) log("[RACE] " .. tostring(msg)) end

    local function retry(fn, attempts, delay, label)
        attempts = attempts or 5
        delay    = delay or RaceConfig.RetryDelay
        for i = 1, attempts do
            local ok, err = pcall(fn)
            if ok then return true end
            rlog(string.format("%s failed (%d/%d): %s", label or "action", i, attempts, tostring(err)))
            task.wait(delay)
        end
        return false
    end

    local function waitUntil(conditionFn, timeout, interval, label)
        interval = interval or 0.5
        local elapsed = 0
        while elapsed < timeout do
            local ok, result = pcall(conditionFn)
            if ok and result then return result end
            task.wait(interval)
            elapsed = elapsed + interval
        end
        rlog("Timeout: " .. (label or "condition") .. " not met after " .. timeout .. "s")
        return nil
    end

    -- ── Remotes ──
    local remoteCache = {}
    local function remoteInit()
        local ok, folder = pcall(function()
            return rp:WaitForChild("RaceRemotes", 15)
        end)
        if not ok or not folder then rlog("RaceRemotes folder not found"); return false end

        local names = { "GetLobbies", "CreateLobby", "SelectCar", "ToggleReady", "StartRace", "JoinLobby", "RaceAgainTeleport", "LeaveLobby" }
        for _, name in ipairs(names) do
            local remOk, remote = pcall(function() return folder:WaitForChild(name, 15) end)
            if not remOk or not remote then rlog("Remote not found: " .. name); return false end
            remoteCache[name] = remote
        end
        rlog("RaceRemotes ready")
        return true
    end

    local function getLobbies() return remoteCache.GetLobbies:InvokeServer() end
    local function createLobbyRemote(name) remoteCache.CreateLobby:FireServer(name) end
    local function selectCarRemote(id, name) remoteCache.SelectCar:FireServer(id, name) end
    local function toggleReadyRemote() remoteCache.ToggleReady:FireServer() end
    local function startRaceRemote() remoteCache.StartRace:FireServer() end
    local function joinLobbyRemote(num) remoteCache.JoinLobby:FireServer(num) end
    local function raceAgainTeleportRemote() remoteCache.RaceAgainTeleport:FireServer() end
    local function leaveLobbyRemote() remoteCache.LeaveLobby:FireServer() end

    -- ── Car manager ──
    local function getRandomRaceCar()
        local ok, scrollingFrame = pcall(function()
            return player.PlayerGui.Main.Container.Spawner.ScrollingFrame
        end)
        if not ok or not scrollingFrame then return nil end

        local cars = {}
        for _, car in ipairs(scrollingFrame:GetChildren()) do
            if car:IsA("Frame") then
                local carId   = car.Name
                local carName = carId
                local label = car:FindFirstChildWhichIsA("TextLabel", true)
                if label then carName = label.Text end
                table.insert(cars, { Id = carId, Name = carName })
            end
        end
        if #cars == 0 then return nil end
        math.randomseed(tick())
        local selected = cars[math.random(1, #cars)]
        return selected.Id, selected.Name
    end

    local function selectRandomCar()
        local carId, carName = getRandomRaceCar()
        if not carId then rlog("No car found in Spawner ScrollingFrame"); return false end
        local ok = retry(function() selectCarRemote(carId, carName) end, 5, RaceConfig.RetryDelay, "SelectCar")
        if ok then rlog("Car selected: " .. carId .. " (" .. carName .. ")") end
        return ok
    end

    -- ── Player detector ──
    local function waitForRaceGui(timeout)
        return waitUntil(function()
            local pg = player:FindFirstChild("PlayerGui")
            return pg and pg:FindFirstChild("Race") and pg.Race:FindFirstChild("Container")
        end, timeout or 15, 0.5, "Race GUI")
    end

    local function waitForRaceStart(timeout)
        local label = waitUntil(function()
            return player.PlayerGui.Race.Container.RaceHUD.TimerPanel.TimerLabel
        end, 15, 0.5, "TimerLabel lookup")
        if not label then return false end

        local elapsed  = 0
        local lastText = label.Text
        while elapsed < timeout do
            task.wait(1)
            elapsed = elapsed + 1
            local ok, currentText = pcall(function() return label.Text end)
            if ok and currentText ~= lastText then return true end
            if ok then lastText = currentText end
        end
        rlog("Timeout: race timer never started ticking after " .. timeout .. "s")
        return false
    end

    local function waitForScoreboard(timeout)
        return waitUntil(function()
            return player.PlayerGui.Race.Container.Scoreboard.Visible
        end, timeout, 0.5, "Scoreboard visible")
    end

    local function isScoreboardVisible()
        local ok, visible = pcall(function()
            return player.PlayerGui.Race.Container.Scoreboard.Visible
        end)
        return ok and visible
    end

    -- ── Lobby manager ──
    local lobbyCreated = false
    local function createLobby()
        if lobbyCreated then rlog("Lobby already created, skip"); return true end
        local ok = retry(function() createLobbyRemote(RaceConfig.LobbyName) end, 5, RaceConfig.RetryDelay, "CreateLobby")
        if ok then lobbyCreated = true; rlog("Lobby created: " .. RaceConfig.LobbyName) end
        return ok
    end

    -- Winner kadang telat bikin lobby (baru selesai loading, dsb). Daripada
    -- nyerah setelah satu timeout pendek, follower terus polling + refresh
    -- GetLobbies tiap FollowerFindRetryInterval detik sampai lobby-nya muncul.
    local function findLobby()
        local attempt = 0
        while true do
            attempt = attempt + 1

            local ok, num = pcall(function()
                local lobbyList = player.PlayerGui.Race.Container.RaceMenu.JoinSection.LobbyList
                for _, child in ipairs(lobbyList:GetChildren()) do
                    local n = child.Name:match("^Lobby_(%d+)$")
                    if n then return tonumber(n) end
                end
                return nil
            end)
            if ok and num then return num end

            if attempt % 6 == 0 then
                rlog("Lobby winner belum muncul, masih nunggu... (percobaan " .. attempt .. ")")
            end

            pcall(function() getLobbies() end) -- refresh, siapa tahu lobby baru saja dibuat
            task.wait(RaceConfig.FollowerFindRetryInterval)
        end
    end

    local function joinLobby(lobbyNumber)
        return retry(function() joinLobbyRemote(lobbyNumber) end, 5, RaceConfig.RetryDelay, "JoinLobby")
    end

    local function resetLobby()
        lobbyCreated = false
    end

    -- ── Checkpoint manager ──
    local CHECKPOINT_POSITIONS = {
        Vector3.new(-481.86, 27.92, 2983.69),
        Vector3.new(-717.14, 27.66, 3391.15),
        Vector3.new(-863.58, 55.90, 3668.89),
        Vector3.new(-1137.39, 42.43, 4085.45),
        Vector3.new(-1430.78, 28.54, 4627.20),
        Vector3.new(-1698.45, 28.54, 5089.70),
        Vector3.new(-2308.32, 29.14, 6149.44),
        Vector3.new(-2669.72, 37.53, 6770.76),
        Vector3.new(-2630.33, 37.60, 7130.58),
        Vector3.new(-2399.24, 23.71, 8001.27),
        Vector3.new(-2166.83, 3.84, 8865.56),
        Vector3.new(-2166.83, 3.84, 8865.56),
        Vector3.new(-1698.06, 3.84, 10604.98),
        Vector3.new(-1465.23, 3.84, 11476.92),
        Vector3.new(-1332.28, 3.84, 12362.87),
        Vector3.new(-1333.39, 3.84, 13163.67),
        Vector3.new(-1331.14, 3.84, 14062.68),
        Vector3.new(-1418.81, 3.84, 14950.71),
        Vector3.new(-1650.48, 3.84, 15819.38),
        Vector3.new(-1650.52, 3.84, 15820.18),
        Vector3.new(-2116.05, 3.84, 17558.38),
        Vector3.new(-2350.62, 3.84, 18429.97),
        Vector3.new(-2503.89, 3.84, 19013.32),
        Vector3.new(-2477.80, 3.84, 19329.16),
        Vector3.new(-2243.25, 3.84, 20197.87),
    }
    local FINISH_POSITION = Vector3.new(-2019.57, 4.93, 21066.38)

    local function getVehicle()
        local character = player.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        local seatPart  = humanoid and humanoid.SeatPart
        return seatPart and seatPart:FindFirstAncestorOfClass("Model")
    end

    local function driveTo(targetPosition, index, total)
        local speed = IsWinner and RaceConfig.WinnerDriveSpeed or RaceConfig.FollowerDriveSpeed
        local elapsed = 0
        local sinceScoreboardCheck = 0

        local wasUnseated = false

        while elapsed < RaceConfig.CheckpointLegTimeout do
            local vehicle = getVehicle()
            if not vehicle then
                if isScoreboardVisible() then
                    rlog("Scoreboard appeared while not seated, race ended for the group. Langsung Race Again.")
                    return true
                end
                -- Kepental/keluar dari mobil (tabrakan, dsb.) tapi race belum
                -- selesai buat grup — jangan nyerah karena leg timeout. Tunggu
                -- terus (gak makan budget CheckpointLegTimeout) sampai keseat
                -- lagi ATAU scoreboard-nya muncul (race beneran kelar buat grup).
                if not wasUnseated then
                    rlog("Not seated in a vehicle (mungkin terlempar), menunggu reseat / scoreboard...")
                    wasUnseated = true
                end
                task.wait(1)
            else
                wasUnseated = false

                local currentPos = vehicle:GetPivot().Position
                local offset      = targetPosition - currentPos
                local distance    = offset.Magnitude

                if distance <= RaceConfig.ArriveDistance then
                    rlog(string.format("Checkpoint %d/%d reached", index, total))
                    return true
                end

                local dt = RunService.Heartbeat:Wait()
                elapsed = elapsed + dt

                sinceScoreboardCheck = sinceScoreboardCheck + dt
                if sinceScoreboardCheck >= 0.5 then
                    sinceScoreboardCheck = 0
                    if isScoreboardVisible() then
                        rlog("Scoreboard appeared mid-drive (race already ended for the group), stopping checkpoints")
                        return true
                    end
                end

                local direction = offset.Unit
                local step       = math.min(speed * dt, distance)
                local newPos     = currentPos + direction * step
                vehicle:PivotTo(CFrame.lookAt(newPos, newPos + direction))
            end
        end

        rlog(string.format("Timeout driving to checkpoint %d/%d", index, total))
        return false
    end

    local function runAllCheckpoints()
        local totalLegs = #CHECKPOINT_POSITIONS + 1
        rlog("Driving through " .. totalLegs .. " checkpoints...")
        for i, position in ipairs(CHECKPOINT_POSITIONS) do
            if not driveTo(position, i, totalLegs) then return false end
        end
        if not driveTo(FINISH_POSITION, totalLegs, totalLegs) then return false end
        rlog("Last waypoint reached, waiting for server to confirm finish...")
        return true
    end

    -- ── Ready (shared by winner + follower, never spammed) ──
    local readyToggled = false
    local function toggleReadyOnce()
        if readyToggled then return true end
        local ok = retry(function() toggleReadyRemote() end, 5, RaceConfig.RetryDelay, "ToggleReady")
        if ok then readyToggled = true; rlog("Ready toggled") end
        return ok
    end
    local function resetReadyState()
        readyToggled = false
    end

    -- ── Teleport / interact NPC ──
    local function teleportToNpc()
        local npc = waitUntil(function()
            return Workspace.Etc.Race.NPC:FindFirstChild("DA0ZA")
        end, 15, 0.5, "NPC lookup")
        if not npc then rlog("NPC DA0ZA not found"); return false end

        local targetCFrame
        if npc:IsA("BasePart") then
            targetCFrame = npc.CFrame
        else
            local part = npc:IsA("Model") and (npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true))
            targetCFrame = part and part.CFrame
        end
        if not targetCFrame then rlog("NPC has no usable position"); return false end

        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then rlog("HumanoidRootPart not found"); return false end

        hrp.CFrame = targetCFrame + Vector3.new(0, 3, 5)
        task.wait(1)
        rlog("Teleported to NPC")
        return true
    end

    local function interactNpc()
        local ok = retry(function()
            local prompt = Workspace.Etc.Race.NPC.DA0ZA.HumanoidRootPart.Prompt
            fireproximityprompt(prompt)
        end, 5, RaceConfig.RetryDelay, "InteractNPC")
        if ok then rlog("Interacted with NPC") end
        return ok
    end

    local function closeScoreboard()
        local ok = retry(function()
            player.PlayerGui.Race.Container.Scoreboard.Visible = false
        end, 5, RaceConfig.RetryDelay, "CloseScoreboard")
        if ok then rlog("Scoreboard closed") end
        return ok
    end

    -- ── Winner controller ──
    local function spamStartRaceUntilStarted()
        local label = waitUntil(function()
            return player.PlayerGui.Race.Container.RaceHUD.TimerPanel.TimerLabel
        end, 15, 0.5, "TimerLabel lookup")
        if not label then rlog("TimerLabel not found, cannot confirm race start"); return false end

        local baselineText = label.Text
        local elapsed = 0
        while elapsed < RaceConfig.StartRaceLoopTimeout do
            pcall(function() startRaceRemote() end)
            task.wait(RaceConfig.StartRaceRetryInterval)
            elapsed = elapsed + RaceConfig.StartRaceRetryInterval

            local ok, currentText = pcall(function() return label.Text end)
            if ok and currentText ~= baselineText then rlog("Race started!"); return true end
            rlog(string.format("Race not started yet, retrying StartRace... (%ds elapsed)", elapsed))
        end
        rlog("Race never started after " .. RaceConfig.StartRaceLoopTimeout .. "s of retrying")
        return false
    end

    local function runWinner()
        rlog("Role: WINNER")
        if not createLobby() then return false end
        task.wait(RaceConfig.RetryDelay)
        if not selectRandomCar() then return false end
        if not toggleReadyOnce() then return false end
        rlog("Firing StartRace every " .. RaceConfig.StartRaceRetryInterval .. "s until the race actually begins...")
        return spamStartRaceUntilStarted()
    end

    -- ── Follower controller ──
    local function runFollower()
        rlog("Role: FOLLOWER")
        local lobbyNumber = findLobby()
        rlog("Found lobby #" .. lobbyNumber)
        if not joinLobby(lobbyNumber) then return false end
        task.wait(RaceConfig.RetryDelay)
        if not selectRandomCar() then return false end
        if not toggleReadyOnce() then return false end
        rlog("Ready. Waiting for winner to start race...")
        return true
    end

    -- ── Requeue for next lap ──
    local function requeueForNextLap()
        for attempt = 1, RaceConfig.RequeueAttempts do
            resetLobby()
            resetReadyState()

            local raceAgainOk = retry(function() raceAgainTeleportRemote() end, 5, RaceConfig.RetryDelay, "RaceAgainTeleport")
            if raceAgainOk then
                task.wait(RaceConfig.RaceAgainSettleDelay)
                local leftOk = retry(function() leaveLobbyRemote() end, 5, RaceConfig.RetryDelay, "LeaveLobby")
                if leftOk then return true end
            end

            rlog(string.format("Requeue sequence failed (attempt %d/%d), retrying from RaceAgainTeleport...", attempt, RaceConfig.RequeueAttempts))
            task.wait(RaceConfig.RetryDelay)
        end
        rlog("Requeue sequence never succeeded after " .. RaceConfig.RequeueAttempts .. " attempts")
        return false
    end

    -- ── State machine ──
    local STATE = {
        INIT = "INIT", TELEPORT_NPC = "TELEPORT_NPC", INTERACT_NPC = "INTERACT_NPC",
        OPEN_MENU = "OPEN_MENU", ROLE_DETECTION = "ROLE_DETECTION",
        WINNER_FLOW = "WINNER_FLOW", FOLLOWER_FLOW = "FOLLOWER_FLOW",
        WAIT_RACE_START = "WAIT_RACE_START", RUN_CHECKPOINTS = "RUN_CHECKPOINTS",
        WAIT_SCOREBOARD = "WAIT_SCOREBOARD", REQUEUE = "REQUEUE", FAILED = "FAILED",
    }

    function RaceBrain.run(isWinner)
        IsWinner = isWinner
        rlog("Race Nostalgia starting as " .. (IsWinner and "WINNER" or "FOLLOWER") .. "...")
        local state = STATE.INIT

        while true do
            if state == STATE.INIT then
                state = remoteInit() and STATE.TELEPORT_NPC or STATE.FAILED

            elseif state == STATE.TELEPORT_NPC then
                rlog("Teleporting to NPC...")
                state = teleportToNpc() and STATE.INTERACT_NPC or STATE.FAILED

            elseif state == STATE.INTERACT_NPC then
                rlog("Interacting with NPC...")
                state = interactNpc() and STATE.OPEN_MENU or STATE.FAILED

            elseif state == STATE.OPEN_MENU then
                rlog("Opening race menu...")
                local opened = retry(function() getLobbies() end, 5, RaceConfig.RetryDelay, "OpenMenu")
                state = (opened and waitForRaceGui(15)) and STATE.ROLE_DETECTION or STATE.FAILED

            elseif state == STATE.ROLE_DETECTION then
                state = IsWinner and STATE.WINNER_FLOW or STATE.FOLLOWER_FLOW

            elseif state == STATE.WINNER_FLOW then
                state = runWinner() and STATE.WAIT_RACE_START or STATE.FAILED

            elseif state == STATE.FOLLOWER_FLOW then
                state = runFollower() and STATE.WAIT_RACE_START or STATE.FAILED

            elseif state == STATE.WAIT_RACE_START then
                rlog("Waiting for race to start (timer ticking)...")
                state = waitForRaceStart(RaceConfig.RaceStartTimeout) and STATE.RUN_CHECKPOINTS or STATE.FAILED

            elseif state == STATE.RUN_CHECKPOINTS then
                state = runAllCheckpoints() and STATE.WAIT_SCOREBOARD or STATE.FAILED

            elseif state == STATE.WAIT_SCOREBOARD then
                rlog("Waiting for Scoreboard (all racers finished)...")
                local scoreboardShown = false
                for attempt = 1, RaceConfig.ScoreboardWaitAttempts do
                    if waitForScoreboard(RaceConfig.ScoreboardTimeout) then
                        scoreboardShown = true
                        break
                    end
                    rlog(string.format("Still no Scoreboard after attempt %d/%d, continuing to wait...", attempt, RaceConfig.ScoreboardWaitAttempts))
                end

                if scoreboardShown then
                    closeScoreboard()
                    state = STATE.REQUEUE
                else
                    state = STATE.FAILED
                end

            elseif state == STATE.REQUEUE then
                rlog("Finished! Requeuing for the next lap...")
                state = requeueForNextLap() and STATE.INTERACT_NPC or STATE.FAILED

            elseif state == STATE.FAILED then
                -- Jangan cuma diem — kalau state machine gagal total (mis. sempet
                -- terlempar dari mobil kelamaan dan gak pernah keseat lagi),
                -- gak ada yang manggil RaceAgain/balik ke NPC. Reconnect biar
                -- brain.lua di luar auto rejoin + mulai race baru dari awal.
                rlog("Race Nostalgia failed. Reconnecting to recover...")
                ReturnLobby()
                break
            end
        end
    end
end

local function startEvent(isWinner)
    log("[EVENT] Starting Race Nostalgia for " .. player.Name .. " as " .. (isWinner and "WINNER" or "FOLLOWER"))

    -- Hapus phone / hub
    safeSpawn(function()
        pcall(function()
            local robloxGui = CoreGui:WaitForChild("RobloxGui", 10)
            local backpack  = robloxGui and robloxGui:WaitForChild("Backpack", 10)
            local hotbar    = backpack  and backpack:WaitForChild("Hotbar", 10)
            if hotbar then hotbar:Destroy() end
        end)
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
    evFrame.Size             = UDim2.new(0, 480, 0, 220)
    evFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    evFrame.Position         = UDim2.new(0.5, 0, 0.4, 0)
    evFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    evFrame.BackgroundTransparency = 0.15
    evFrame.BorderSizePixel  = 0
    Instance.new("UICorner", evFrame).CornerRadius = UDim.new(0, 18)

    local stroke = Instance.new("UIStroke", evFrame)
    stroke.Color     = Color3.fromRGB(80, 160, 255)
    stroke.Thickness = 2.5

    local evName = Instance.new("TextLabel", evFrame)
    evName.Size                   = UDim2.new(1, -24, 0, 70)
    evName.Position               = UDim2.new(0, 12, 0, 16)
    evName.BackgroundTransparency = 1
    evName.Font                   = Enum.Font.GothamBlack
    evName.TextScaled             = true
    evName.TextColor3             = Color3.fromRGB(255, 220, 60)
    evName.TextStrokeTransparency = 0.4
    evName.TextStrokeColor3       = Color3.new(0, 0, 0)
    evName.TextXAlignment         = Enum.TextXAlignment.Center
    evName.Text                   = player.Name .. (isWinner and " (WINNER)" or " (FOLLOWER)")

    local evPoints = Instance.new("TextLabel", evFrame)
    evPoints.Size                   = UDim2.new(1, -24, 0, 110)
    evPoints.Position               = UDim2.new(0, 12, 0, 92)
    evPoints.BackgroundTransparency = 1
    evPoints.Font                   = Enum.Font.GothamBlack
    evPoints.TextScaled             = true
    evPoints.TextColor3             = Color3.new(1, 1, 1)
    evPoints.TextStrokeTransparency = 0.4
    evPoints.TextStrokeColor3       = Color3.new(0, 0, 0)
    evPoints.TextXAlignment         = Enum.TextXAlignment.Center
    evPoints.Text                   = "... PTS"

    -- ── Fetch jumlah point ke web (sama seperti mode lain) ──
    safeSpawn(function()
        local function parsePoints(txt)
            local digits = (tostring(txt or ""):gsub("%D", ""))
            if digits == "" then digits = "0" end
            return digits
        end

        local valLabel = nil
        for _ = 1, 30 do
            local ok, lbl = pcall(function()
                return player.PlayerGui.Race.Container.Shop.TitleBar.PointsPill.Value
            end)
            if ok and lbl then valLabel = lbl; break end
            task.wait(1)
        end
        if not valLabel then log("[EVENT] PointsPill Value tidak ditemukan setelah 30s"); return end

        local latestPts     = 0
        local lastValChange = os.time()

        local function onValueChanged()
            local v = tonumber(parsePoints(valLabel.Text)) or 0
            if v > 0 and v ~= latestPts then
                latestPts     = v
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
            initPts = tonumber(parsePoints(valLabel.Text)) or 0
            if initPts > 0 then break end
        end
        latestPts     = initPts
        lastValChange = os.time()
        evPoints.Text = tostring(latestPts) .. " PTS"
        log("[EVENT] Poin awal: " .. tostring(initPts))
        sendInit(tostring(initPts))
        apiUpdate(player.Name, initPts)

        -- Stuck detector: poin ga naik 10 menit → auto reconnect
        safeSpawn(function()
            local STUCK_THRESHOLD = 600
            while true do
                task.wait(60)
                local elapsed = os.difftime(os.time(), lastValChange)
                if elapsed >= STUCK_THRESHOLD then
                    log("[EVENT] Stuck " .. math.floor(elapsed / 60) .. "m — auto reconnect")
                    lastValChange = os.time()  -- reset biar ga spam
                    ReturnLobby()
                end
            end
        end)

        while true do
            task.wait(60)
            local cur = tonumber(parsePoints(valLabel.Text)) or 0
            if cur > 0 and cur ~= latestPts then
                latestPts     = cur
                lastValChange = os.time()
                log("[EVENT] Poin poll: " .. tostring(cur))
            end
            evPoints.Text = tostring(latestPts) .. " PTS"
            sendUpdate(tostring(latestPts))
            safeApiUpdate(player.Name, latestPts)
        end
    end)

    -- ── Race state machine (adaptasi dari racenostalgia.lua) ──
    safeSpawn(function()
        RaceBrain.run(isWinner)
    end)
end

-- ═══════════════════════════════════
--  MODE: EVENT KONVOI
--  Adaptasi dari convoi.lua (KonvoiBrain V1), tapi Winner/Follower dan siapa
--  yang LeaveLobby TIDAK lagi dipilih manual lewat GUI toggle — semuanya
--  datang dari API (jump_mode untuk role, `leave` list untuk giliran leave).
--  4 device masuk 1 lobby; setelah race mulai, backend nentuin 2 dari 4 yang
--  LeaveLobby (prioritas Dummy, lalu rotasi) supaya 2 sisanya selesai & score.
-- ═══════════════════════════════════
local KonvoiBrain = {}
do
    local KonvoiConfig = {
        LobbyName              = "Konvoi ProfessionalUnemploy",
        LobbyMode              = "nostalgia",
        RetryDelay             = 1,
        StartRaceRetryInterval = 5,   -- winner refires StartRace tiap N detik (konvoi cuma butuh 4 player, bukan 5)
        StartRaceLoopTimeout   = 300,
        ResultTimeout          = 5,   -- lama Stay-pick cek popup Result sebelum nyerah nunggu dan tetap lanjut
        RequeueSettleDelay     = 3,
        LeaveListRetries       = 10,  -- percobaan poll leave-list sebelum default ke STAY
    }
    local IsWinner = true
    local DeviceId = nil

    -- Optional UI hooks: set by startKonvoiEvent so the overlay can show
    -- LEAVER/STAY as soon as each round's decision comes back, and get reset
    -- back to neutral when a fresh round starts (otherwise it keeps showing
    -- last round's result while this round hasn't been decided yet, which
    -- reads as "leaver isn't actually leaving" when it's just a stale label).
    KonvoiBrain.onLeaveStatus = nil
    KonvoiBrain.onRoundReset  = nil

    local function klog(msg) log("[KONVOI] " .. tostring(msg)) end

    local function retry(fn, attempts, delay, label)
        attempts = attempts or 5
        delay    = delay or KonvoiConfig.RetryDelay
        for i = 1, attempts do
            local ok, err = pcall(fn)
            if ok then return true end
            klog(string.format("%s failed (%d/%d): %s", label or "action", i, attempts, tostring(err)))
            task.wait(delay)
        end
        return false
    end

    local function waitUntil(conditionFn, timeout, interval, label)
        interval = interval or 0.5
        local elapsed = 0
        while elapsed < timeout do
            local ok, result = pcall(conditionFn)
            if ok and result then return result end
            task.wait(interval)
            elapsed = elapsed + interval
        end
        klog("Timeout: " .. (label or "condition") .. " not met after " .. timeout .. "s")
        return nil
    end

    -- ── Remotes (RaceRemotes folder, shared with the racenostalgia event) ──
    local remoteCache = {}
    local function remoteInit()
        local ok, folder = pcall(function() return rp:WaitForChild("RaceRemotes", 15) end)
        if not ok or not folder then klog("RaceRemotes folder not found"); return false end

        local names = { "GetLobbies", "CreateLobby", "SelectCar", "ToggleReady", "StartRace", "JoinLobby", "LeaveLobby" }
        for _, name in ipairs(names) do
            local remOk, remote = pcall(function() return folder:WaitForChild(name, 15) end)
            if not remOk or not remote then klog("Remote not found: " .. name); return false end
            remoteCache[name] = remote
        end
        klog("RaceRemotes ready")
        return true
    end

    local function getLobbies() return remoteCache.GetLobbies:InvokeServer() end
    local function createLobbyRemote(name, mode) remoteCache.CreateLobby:FireServer(name, mode) end
    local function selectCarRemote(id, name) remoteCache.SelectCar:FireServer(id, name) end
    local function toggleReadyRemote() remoteCache.ToggleReady:FireServer() end
    local function startRaceRemote() remoteCache.StartRace:FireServer() end
    local function joinLobbyRemote(num) remoteCache.JoinLobby:FireServer(num) end
    local function leaveLobbyRemote() remoteCache.LeaveLobby:FireServer() end

    -- ── Car manager ──
    local function getRandomRaceCar()
        local ok, scrollingFrame = pcall(function()
            return player.PlayerGui.Main.Container.Spawner.ScrollingFrame
        end)
        if not ok or not scrollingFrame then return nil end

        local cars = {}
        for _, car in ipairs(scrollingFrame:GetChildren()) do
            if car:IsA("Frame") then
                local carId   = car.Name
                local carName = carId
                local label = car:FindFirstChildWhichIsA("TextLabel", true)
                if label then carName = label.Text end
                table.insert(cars, { Id = carId, Name = carName })
            end
        end
        if #cars == 0 then return nil end
        math.randomseed(tick())
        local selected = cars[math.random(1, #cars)]
        return selected.Id, selected.Name
    end

    local function selectRandomCar()
        local carId, carName = getRandomRaceCar()
        if not carId then klog("No car found in Spawner ScrollingFrame"); return false end
        local ok = retry(function() selectCarRemote(carId, carName) end, 5, KonvoiConfig.RetryDelay, "SelectCar")
        if ok then klog("Car selected: " .. carId .. " (" .. carName .. ")") end
        return ok
    end

    -- ── Player detector ──
    local function waitForRaceGui(timeout)
        return waitUntil(function()
            local pg = player:FindFirstChild("PlayerGui")
            return pg and pg:FindFirstChild("Race") and pg.Race:FindFirstChild("Container")
        end, timeout or 15, 0.5, "Race GUI")
    end

    -- Konvoi has no RaceHUD timer to watch — the real signal the convoy
    -- started is Workspace.NostalgiaWaypoint spawning in.
    local function waitForConvoiStart(timeout)
        return waitUntil(function()
            return Workspace:FindFirstChild("NostalgiaWaypoint") ~= nil
        end, timeout, 0.5, "NostalgiaWaypoint spawn")
    end

    local function waitForResult(timeout)
        return waitUntil(function()
            return player.PlayerGui.NostalgiaEvent.Container.Result.Visible
        end, timeout, 0.5, "Result visible")
    end

    -- ── Lobby manager ──
    local lobbyCreated = false
    local function createLobby()
        if lobbyCreated then klog("Lobby already created, skip"); return true end
        local ok = retry(function() createLobbyRemote(KonvoiConfig.LobbyName, KonvoiConfig.LobbyMode) end,
            5, KonvoiConfig.RetryDelay, "CreateLobby")
        if ok then lobbyCreated = true; klog("Lobby created: " .. KonvoiConfig.LobbyName) end
        return ok
    end

    local function findLobbyNumber(timeout)
        return waitUntil(function()
            local lobbyList = player.PlayerGui.NostalgiaEvent.Container.LobbyMenu.JoinSection.LobbyList
            for _, child in ipairs(lobbyList:GetChildren()) do
                local num = child.Name:match("^Lobby_(%d+)$")
                if num then return tonumber(num) end
            end
            return nil
        end, timeout, 1, "FindLobby")
    end

    -- Winner might not have finished CreateLobby yet (or take a while to
    -- recreate it on later rounds) — scan forever instead of giving up, same
    -- rationale as racenostalgia's findLobby().
    local function joinLobbyBruteForce()
        while true do
            pcall(function() getLobbies() end)

            local lobbyNumber = findLobbyNumber(10)
            if lobbyNumber then
                klog("Found lobby #" .. lobbyNumber .. ", joining...")
                retry(function() joinLobbyRemote(lobbyNumber) end, 5, KonvoiConfig.RetryDelay, "JoinLobby")

                if waitUntil(function() return getRandomRaceCar() ~= nil end, 5, 0.5, "car picker confirm") then
                    klog("Confirmed in lobby (car picker populated)")
                    return true
                end
                klog("JoinLobby(" .. lobbyNumber .. ") didn't seem to land, scanning again...")
            else
                klog("No lobby found yet (winner may not have created it yet), scanning again...")
            end
            task.wait(KonvoiConfig.RetryDelay)
        end
    end

    local function resetLobby()
        lobbyCreated = false
    end

    -- ── Ready (shared by winner + follower, never spammed) ──
    local readyToggled = false
    local function toggleReadyOnce()
        if readyToggled then return true end
        local ok = retry(function() toggleReadyRemote() end, 5, KonvoiConfig.RetryDelay, "ToggleReady")
        if ok then readyToggled = true; klog("Ready toggled") end
        return ok
    end
    local function resetReadyState()
        readyToggled = false
    end

    -- ── Teleport / interact NPC ──
    local function teleportToNpc()
        local npc = waitUntil(function()
            return Workspace.Event.Nostalgia.pisangone
        end, 15, 0.5, "NPC lookup")
        if not npc then klog("NPC pisangone not found"); return false end

        local targetCFrame
        if npc:IsA("BasePart") then
            targetCFrame = npc.CFrame
        else
            local part = npc:IsA("Model") and (npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true))
            targetCFrame = part and part.CFrame
        end
        if not targetCFrame then klog("NPC has no usable position"); return false end

        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart", 10)
        if not hrp then klog("HumanoidRootPart not found"); return false end

        hrp.CFrame = targetCFrame + Vector3.new(0, 3, 5)
        task.wait(1)
        klog("Teleported to NPC")
        return true
    end

    local function findProximityPrompt(npc)
        for _, descendant in ipairs(npc:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") then return descendant end
        end
        return nil
    end

    local function interactNpc()
        local ok = retry(function()
            local npc = Workspace.Event.Nostalgia.pisangone
            local prompt = findProximityPrompt(npc)
            if not prompt then error("ProximityPrompt not found under pisangone") end
            fireproximityprompt(prompt)
        end, 5, KonvoiConfig.RetryDelay, "InteractNPC")
        if ok then klog("Interacted with NPC") end
        return ok
    end

    -- ── Winner controller ──
    -- StartRace is a no-op server-side until enough players are in and
    -- ready, so just fire it periodically and watch for NostalgiaWaypoint
    -- spawning in — that's what actually signals the convoy started.
    local function spamStartRaceUntilStarted()
        local elapsed, sinceLastFire, pollInterval = 0, 0, 0.5
        while elapsed < KonvoiConfig.StartRaceLoopTimeout do
            if sinceLastFire <= 0 then
                pcall(function() startRaceRemote() end)
                sinceLastFire = KonvoiConfig.StartRaceRetryInterval
                klog(string.format("Fired StartRace... (%ds elapsed)", elapsed))
            end
            if Workspace:FindFirstChild("NostalgiaWaypoint") then
                klog("Race started! (waypoint spawned)")
                return true
            end
            task.wait(pollInterval)
            elapsed = elapsed + pollInterval
            sinceLastFire = sinceLastFire - pollInterval
        end
        klog("Race never started after " .. KonvoiConfig.StartRaceLoopTimeout .. "s of retrying")
        return false
    end

    local function runWinner()
        klog("Role: WINNER")
        if not createLobby() then return false end
        task.wait(KonvoiConfig.RetryDelay)
        if not selectRandomCar() then return false end
        if not toggleReadyOnce() then return false end
        klog("Firing StartRace every " .. KonvoiConfig.StartRaceRetryInterval .. "s until the race actually begins...")
        return spamStartRaceUntilStarted()
    end

    -- ── Follower controller ──
    local function runFollower()
        klog("Role: FOLLOWER")
        joinLobbyBruteForce()
        task.wait(KonvoiConfig.RetryDelay)
        if not selectRandomCar() then return false end
        if not toggleReadyOnce() then return false end
        klog("Ready. Waiting for winner to start race...")
        return true
    end

    -- ── Leave-list (backend-driven) ──
    local function isDeviceInLeaveList(list, deviceId)
        if type(list) ~= "table" then return false end
        for _, id in ipairs(list) do
            if id == deviceId then return true end
        end
        return false
    end

    -- Polls the backend's leave-list for this round and checks whether our
    -- own device_id is in it. Defaults to STAY if the API never answers —
    -- safer than leaving a round we weren't actually assigned to leave.
    local function fetchIsLeaverThisRound()
        for attempt = 1, KonvoiConfig.LeaveListRetries do
            local data = getPS(player.Name)
            if data and data.leave then
                local isLeaver = isDeviceInLeaveList(data.leave, DeviceId)
                klog("Leave-list round: " .. (isLeaver and "LEAVER" or "STAY"))
                return isLeaver
            end
            klog("Leave-list belum didapat, retry (" .. attempt .. "/" .. KonvoiConfig.LeaveListRetries .. ")...")
            task.wait(KonvoiConfig.RetryDelay)
        end
        klog("Gagal ambil leave-list, default ke STAY")
        return false
    end

    -- ── Race start handler ──
    local function closeResult()
        local ok = retry(function()
            player.PlayerGui.NostalgiaEvent.Container.Result.Visible = false
        end, 5, KonvoiConfig.RetryDelay, "CloseResult")
        if ok then klog("Result closed") end
        return ok
    end

    -- FireServer never reports back whether the server actually received/
    -- processed it — a single shot has zero protection against a dropped
    -- event (e.g. mid-race while the vehicle is moving fast). Fire it a few
    -- times spaced out instead of trusting one attempt.
    local function leaveAndWait()
        klog("Leaver: leaving lobby now so the stayers win...")
        for i = 1, 3 do
            pcall(function() leaveLobbyRemote() end)
            klog("LeaveLobby fired (" .. i .. "/3)")
            task.wait(0.75)
        end
        klog("Left lobby, waiting " .. KonvoiConfig.RequeueSettleDelay .. "s before heading back to the NPC...")
        task.wait(KonvoiConfig.RequeueSettleDelay)
        return true
    end

    -- Result popup doesn't always show — either way, always head back to NPC.
    local function waitAndCloseResult()
        klog("Stay: checking for the Result popup (win confirmation)...")
        if waitForResult(KonvoiConfig.ResultTimeout) then
            closeResult()
        else
            klog("No Result popup this round, heading back to the NPC right away.")
        end
        return true
    end

    -- Only the Winner calls this, once per round, so the next round's
    -- leave-list rotates. Backend rejects the call from non-winner slots.
    local function advanceRotation()
        local ok = retry(function()
            local result = konvoiAdvance(player.Name)
            if not result or not result.success then error("advance failed") end
        end, 5, KonvoiConfig.RetryDelay, "KonvoiAdvance")
        if ok then klog("Rotation advanced for next round")
        else klog("Rotation advance failed — next round's leave-list may repeat") end
        return ok
    end

    -- ── Points (Shop.TitleBar.PointsPill.Value only populates once the Shop
    -- has fetched DriveShopData, and it doesn't refresh on its own — call
    -- this once per round, plus at startup, opening the Shop just to pull
    -- fresh data in then closing it again immediately). ──
    local function fetchShopDataOnce()
        local ok, err = pcall(function()
            local Network = require(rp.Modules.Network)
            local ShopModule = require(
                player.PlayerGui:WaitForChild("NostalgiaEvent"):WaitForChild("Modules"):WaitForChild("DriveShopModule")
            )
            local data = Network:InvokeServer("DriveShopData")
            if typeof(data) ~= "table" then error("DriveShopData gagal") end

            local uiData = { Point = data.Points or 0 }
            local owned = data.Owned or {}
            for _, reward in ipairs(data.Rewards or {}) do
                uiData[reward.dataKey] = owned[reward.dataKey] and 1 or 0
            end
            ShopModule.SetCatalog(data.Rewards)
            ShopModule.UpdateData(uiData)
            ShopModule.Open()
        end)
        if not ok then klog("fetchShopDataOnce failed: " .. tostring(err)) end
        pcall(function() player.PlayerGui.NostalgiaEvent.Container.Shop.Visible = false end)
    end
    KonvoiBrain.fetchShopDataOnce = fetchShopDataOnce

    -- ── State machine ──
    local STATE = {
        INIT = "INIT", TELEPORT_NPC = "TELEPORT_NPC", INTERACT_NPC = "INTERACT_NPC",
        OPEN_MENU = "OPEN_MENU", ROLE_DETECTION = "ROLE_DETECTION",
        WINNER_FLOW = "WINNER_FLOW", FOLLOWER_FLOW = "FOLLOWER_FLOW",
        WAIT_RACE_START = "WAIT_RACE_START", DETERMINE_LEAVE = "DETERMINE_LEAVE",
        HANDLE_RACE_START = "HANDLE_RACE_START", REQUEUE = "REQUEUE", FAILED = "FAILED",
    }

    function KonvoiBrain.run(isWinner, deviceId)
        IsWinner = isWinner
        DeviceId = deviceId
        klog("Konvoi starting as " .. (IsWinner and "WINNER" or "FOLLOWER") .. ", device " .. tostring(deviceId) .. "...")
        local state = STATE.INIT
        local isLeaverThisRound = false

        while true do
            if state == STATE.INIT then
                if KonvoiBrain.onRoundReset then pcall(KonvoiBrain.onRoundReset) end
                state = remoteInit() and STATE.TELEPORT_NPC or STATE.FAILED

            elseif state == STATE.TELEPORT_NPC then
                klog("Teleporting to NPC...")
                state = teleportToNpc() and STATE.INTERACT_NPC or STATE.FAILED

            elseif state == STATE.INTERACT_NPC then
                klog("Interacting with NPC...")
                state = interactNpc() and STATE.OPEN_MENU or STATE.FAILED

            elseif state == STATE.OPEN_MENU then
                klog("Opening konvoi menu...")
                local opened = retry(function() getLobbies() end, 5, KonvoiConfig.RetryDelay, "OpenMenu")
                state = (opened and waitForRaceGui(15)) and STATE.ROLE_DETECTION or STATE.FAILED

            elseif state == STATE.ROLE_DETECTION then
                state = IsWinner and STATE.WINNER_FLOW or STATE.FOLLOWER_FLOW

            elseif state == STATE.WINNER_FLOW then
                state = runWinner() and STATE.WAIT_RACE_START or STATE.FAILED

            elseif state == STATE.FOLLOWER_FLOW then
                state = runFollower() and STATE.WAIT_RACE_START or STATE.FAILED

            elseif state == STATE.WAIT_RACE_START then
                klog("Waiting for convoy to start (NostalgiaWaypoint to spawn)...")
                state = waitForConvoiStart(KonvoiConfig.StartRaceLoopTimeout) and STATE.DETERMINE_LEAVE or STATE.FAILED

            elseif state == STATE.DETERMINE_LEAVE then
                isLeaverThisRound = fetchIsLeaverThisRound()
                if KonvoiBrain.onLeaveStatus then
                    pcall(KonvoiBrain.onLeaveStatus, isLeaverThisRound)
                end
                state = STATE.HANDLE_RACE_START

            elseif state == STATE.HANDLE_RACE_START then
                if isLeaverThisRound then
                    state = leaveAndWait() and STATE.REQUEUE or STATE.FAILED
                else
                    state = waitAndCloseResult() and STATE.REQUEUE or STATE.FAILED
                end

            elseif state == STATE.REQUEUE then
                klog("Looping back to the NPC for another round (role stays fixed)...")
                if KonvoiBrain.onRoundReset then pcall(KonvoiBrain.onRoundReset) end
                fetchShopDataOnce() -- refresh the points HUD's value for this round
                resetLobby()
                resetReadyState()
                if IsWinner then advanceRotation() end
                state = STATE.TELEPORT_NPC

            elseif state == STATE.FAILED then
                klog("Konvoi failed. Reconnecting to recover...")
                ReturnLobby()
                break
            end
        end
    end
end

local function startKonvoiEvent(isWinner, deviceId)
    log("[KONVOI] Starting Konvoi for " .. player.Name .. " as " .. (isWinner and "WINNER" or "FOLLOWER") .. " (" .. tostring(deviceId) .. ")")

    -- Hapus phone / hub
    safeSpawn(function()
        pcall(function()
            local robloxGui = CoreGui:WaitForChild("RobloxGui", 10)
            local backpack  = robloxGui and robloxGui:WaitForChild("Backpack", 10)
            local hotbar    = backpack  and backpack:WaitForChild("Hotbar", 10)
            if hotbar then hotbar:Destroy() end
        end)
    end)

    -- ── Overlay GUI ──
    pcall(function()
        if CoreGui:FindFirstChild("SamlongKonvoiUI") then CoreGui.SamlongKonvoiUI:Destroy() end
    end)

    local evGui = Instance.new("ScreenGui")
    evGui.Name           = "SamlongKonvoiUI"
    evGui.ResetOnSpawn   = false
    evGui.DisplayOrder   = 9999
    evGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    evGui.Parent         = CoreGui

    local evFrame = Instance.new("Frame", evGui)
    evFrame.Size             = UDim2.new(0, 480, 0, 250)
    evFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    evFrame.Position         = UDim2.new(0.5, 0, 0.4, 0)
    evFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    evFrame.BackgroundTransparency = 0.15
    evFrame.BorderSizePixel  = 0
    Instance.new("UICorner", evFrame).CornerRadius = UDim.new(0, 18)

    local stroke = Instance.new("UIStroke", evFrame)
    stroke.Color     = Color3.fromRGB(180, 100, 255)
    stroke.Thickness = 2.5

    local evName = Instance.new("TextLabel", evFrame)
    evName.Size                   = UDim2.new(1, -24, 0, 50)
    evName.Position               = UDim2.new(0, 12, 0, 12)
    evName.BackgroundTransparency = 1
    evName.Font                   = Enum.Font.GothamBlack
    evName.TextScaled             = true
    evName.TextColor3             = Color3.fromRGB(255, 220, 60)
    evName.TextStrokeTransparency = 0.4
    evName.TextStrokeColor3       = Color3.new(0, 0, 0)
    evName.TextXAlignment         = Enum.TextXAlignment.Center
    evName.Text                   = player.Name .. (isWinner and " (WINNER)" or " (FOLLOWER)") .. " · " .. tostring(deviceId)

    -- Leaver/Stay this round — updated live by KonvoiBrain.onLeaveStatus below.
    local evStatus = Instance.new("TextLabel", evFrame)
    evStatus.Size                   = UDim2.new(1, -24, 0, 36)
    evStatus.Position               = UDim2.new(0, 12, 0, 66)
    evStatus.BackgroundTransparency = 1
    evStatus.Font                   = Enum.Font.GothamBold
    evStatus.TextScaled             = true
    evStatus.TextColor3             = Color3.fromRGB(180, 180, 190)
    evStatus.TextStrokeTransparency = 0.5
    evStatus.TextStrokeColor3       = Color3.new(0, 0, 0)
    evStatus.TextXAlignment         = Enum.TextXAlignment.Center
    evStatus.Text                   = "MENUNGGU RONDE..."

    local evPoints = Instance.new("TextLabel", evFrame)
    evPoints.Size                   = UDim2.new(1, -24, 0, 120)
    evPoints.Position               = UDim2.new(0, 12, 0, 106)
    evPoints.BackgroundTransparency = 1
    evPoints.Font                   = Enum.Font.GothamBlack
    evPoints.TextScaled             = true
    evPoints.TextColor3             = Color3.new(1, 1, 1)
    evPoints.TextStrokeTransparency = 0.4
    evPoints.TextStrokeColor3       = Color3.new(0, 0, 0)
    evPoints.TextXAlignment         = Enum.TextXAlignment.Center
    evPoints.Text                   = "... PTS"

    -- Konvoi state machine reports LEAVER/STAY back here as soon as each
    -- round's decision comes back from the backend.
    KonvoiBrain.onLeaveStatus = function(isLeaver)
        if isLeaver then
            evStatus.Text       = "🚪 LEAVER — akan LeaveLobby"
            evStatus.TextColor3 = Color3.fromRGB(255, 110, 90)
        else
            evStatus.Text       = "🏁 STAY — tunggu menang"
            evStatus.TextColor3 = Color3.fromRGB(90, 220, 140)
        end
    end

    -- Called at the start of every fresh round (INIT + REQUEUE) so the label
    -- doesn't keep showing last round's LEAVER/STAY result while this
    -- round's decision hasn't come back yet.
    KonvoiBrain.onRoundReset = function()
        evStatus.Text       = "MENUNGGU RONDE..."
        evStatus.TextColor3 = Color3.fromRGB(180, 180, 190)
    end

    -- ── Fetch jumlah point ke web (sama seperti mode event lain) ──
    safeSpawn(function()
        local function parsePoints(txt)
            local digits = (tostring(txt or ""):gsub("%D", ""))
            if digits == "" then digits = "0" end
            return digits
        end

        KonvoiBrain.fetchShopDataOnce() -- populate PointsPill.Value for the first time

        local valLabel = nil
        for _ = 1, 30 do
            local ok, lbl = pcall(function()
                return player.PlayerGui.NostalgiaEvent.Container.Shop.TitleBar.PointsPill.Value
            end)
            if ok and lbl then valLabel = lbl; break end
            task.wait(1)
        end
        if not valLabel then log("[KONVOI] PointsPill Value tidak ditemukan setelah 30s"); return end

        local latestPts = 0

        local function onValueChanged()
            local v = tonumber(parsePoints(valLabel.Text)) or 0
            if v > 0 and v ~= latestPts then
                latestPts     = v
                evPoints.Text = tostring(v) .. " PTS"
                sendUpdate(tostring(v))
                safeApiUpdate(player.Name, v)
                log("[KONVOI] Poin update: " .. tostring(v))
            end
        end

        valLabel:GetPropertyChangedSignal("Text"):Connect(onValueChanged)

        local initPts = tonumber(parsePoints(valLabel.Text)) or 0
        latestPts     = initPts
        evPoints.Text = tostring(latestPts) .. " PTS"
        log("[KONVOI] Poin awal: " .. tostring(initPts))
        sendInit(tostring(initPts))
        apiUpdate(player.Name, initPts)

        -- Stuck detector: TOTAL poin 1 tim (bukan poin akun sendiri) ga naik
        -- 10 menit → auto reconnect. Device Leaver by design gak pernah dapet
        -- poin sendiri (yang dapet cuma yang Stay tiap ronde), jadi ngecek
        -- poin sendiri bakal salah nganggep Leaver "stuck" padahal jalan
        -- normal. Total tim tetap naik selama ada Stay player yang beres
        -- tiap ronde, jadi ini sinyal yang bener buat semua role.
        safeSpawn(function()
            local STUCK_THRESHOLD = 600
            local lastTeamTotal  = nil
            local lastTeamChange = os.time()
            while true do
                task.wait(60)
                local teamData = getKonvoiTeamPoints(player.Name)
                if teamData and teamData.total then
                    if lastTeamTotal == nil or teamData.total ~= lastTeamTotal then
                        lastTeamTotal  = teamData.total
                        lastTeamChange = os.time()
                    end
                end
                local elapsed = os.difftime(os.time(), lastTeamChange)
                if elapsed >= STUCK_THRESHOLD then
                    log("[KONVOI] Total poin tim gak naik " .. math.floor(elapsed / 60) .. "m — auto reconnect")
                    lastTeamChange = os.time()
                    ReturnLobby()
                end
            end
        end)

        while true do
            task.wait(60)
            local cur = tonumber(parsePoints(valLabel.Text)) or 0
            if cur > 0 and cur ~= latestPts then
                latestPts = cur
                log("[KONVOI] Poin poll: " .. tostring(cur))
            end
            evPoints.Text = tostring(latestPts) .. " PTS"
            sendUpdate(tostring(latestPts))
            safeApiUpdate(player.Name, latestPts)
        end
    end)

    -- ── Konvoi state machine ──
    safeSpawn(function()
        KonvoiBrain.run(isWinner, deviceId)
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
        -- nojump = winner (create+start lobby), jump = follower (join lobby)
        if jumpMode == "jump" then return "event_follower"
        else                       return "event_winner" end

    elseif jenis == "konvoi" then
        -- Same winner/follower convention as "event"; who LeaveLobby's each
        -- round comes from the API's `leave` list instead, not jump_mode.
        if jumpMode == "jump" then return "konvoi_follower"
        else                       return "konvoi_winner" end
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

        -- Region berdasarkan jenis (Konvoi pakai map yang sama dengan Event biasa)
        local jenisFix = (data and data.jenis or ""):lower()
        local joinRegion
        if jenisFix == "event" or jenisFix == "konvoi" then
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

        elseif mode == "event_winner" then
            startEvent(true)

        elseif mode == "event_follower" then
            startEvent(false)

        elseif mode == "konvoi_winner" then
            startKonvoiEvent(true, data.device_id)

        elseif mode == "konvoi_follower" then
            startKonvoiEvent(false, data.device_id)
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
