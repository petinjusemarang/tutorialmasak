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
logFrame.Visible         = false -- panel debug disembunyikan, tapi log() tetap jalan (print + EJECT BRAIN tetap ada)

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

-- GET /api/konvoi-team-points?username=xxx → { total, restart_requested_at }.
-- Konvoi's Winner always stays and Followers always leave every round, so a
-- Follower's own points legitimately never move — watching the GROUP's total
-- instead is what the stuck/reconnect check (and group-restart signal) uses.
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

-- POST /api/konvoi-restart { username } — broadcasts a group-wide restart
-- signal. Called by whichever device first notices the group's total points
-- have stalled, so the other 3 devices reconnect together on their next
-- team-points poll instead of drifting further out of sync (one device
-- reconnecting alone recreates/abandons a lobby the other 3 are still
-- waiting on).
local function konvoiRestart(username)
    local res = req({
        Url     = API_URL .. "/api/konvoi-restart",
        Method  = "POST",
        Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = API_KEY },
        Body    = HttpService:JSONEncode({ username = username }),
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
        return
    end

    -- The GUI button path doesn't always exist (e.g. Settings menu never got
    -- opened this session) — used to just give up here, leaving the whole
    -- automation permanently dead with nothing left to notice or recover.
    -- Force a same-place re-teleport instead, which doesn't depend on any
    -- GUI existing: it always disconnects+reconnects, and
    -- queueOnTeleport(AUTOEXEC) makes brain.lua run fresh again once loaded.
    log("[LOBBY] ReturnLobby GUI button failed (" .. tostring(err) .. "), falling back to hard teleport...")
    local teleOk, teleErr = pcall(function()
        queueOnTeleport(AUTOEXEC)
        game:GetService("TeleportService"):Teleport(game.PlaceId, player)
    end)
    if not teleOk then
        log("[LOBBY] Hard teleport fallback also failed: " .. tostring(teleErr))
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
        LeaveJitterMin            = 1,   -- surender follower: random delay (s) before LeaveLobby, so they don't all fire at once
        LeaveJitterMax            = 2,
    }
    local IsWinner   = true
    local IsSurender = false -- follower-only: leave immediately on race start instead of driving (see event_mode "surender")

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

    -- ── Surender: follower bails out right after race start instead of
    -- driving checkpoints. Same LeaveLobby-with-jitter pattern as Konvoi's
    -- follower, reusing this brain's own RaceRemotes/lobby (not Konvoi's). ──
    local function followerSurender()
        local jitter = RaceConfig.LeaveJitterMin + math.random() * (RaceConfig.LeaveJitterMax - RaceConfig.LeaveJitterMin)
        rlog(string.format("Surender: leaving in %.1fs...", jitter))
        task.wait(jitter)
        for i = 1, 3 do
            pcall(function() leaveLobbyRemote() end)
            rlog("LeaveLobby fired (" .. i .. "/3)")
            task.wait(0.75)
        end
        task.wait(RaceConfig.RaceAgainSettleDelay)
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
        FOLLOWER_SURENDER = "FOLLOWER_SURENDER", REQUEUE_SURENDER = "REQUEUE_SURENDER",
        WAIT_SCOREBOARD = "WAIT_SCOREBOARD", REQUEUE = "REQUEUE", FAILED = "FAILED",
    }

    function RaceBrain.run(isWinner, isSurender)
        IsWinner   = isWinner
        IsSurender = isSurender or false
        rlog("Race Nostalgia starting as " .. (IsWinner and "WINNER" or "FOLLOWER") .. (IsSurender and " (SURENDER)" or "") .. "...")
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
                if not waitForRaceStart(RaceConfig.RaceStartTimeout) then
                    state = STATE.FAILED
                elseif IsSurender and not IsWinner then
                    state = STATE.FOLLOWER_SURENDER
                else
                    state = STATE.RUN_CHECKPOINTS
                end

            elseif state == STATE.FOLLOWER_SURENDER then
                state = followerSurender() and STATE.REQUEUE_SURENDER or STATE.FAILED

            elseif state == STATE.REQUEUE_SURENDER then
                rlog("Surender selesai, balik ke NPC buat ronde berikutnya...")
                resetLobby()
                resetReadyState()
                state = STATE.TELEPORT_NPC

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

local function startEvent(isWinner, isSurender)
    log("[EVENT] Starting Race Nostalgia for " .. player.Name .. " as " .. (isWinner and "WINNER" or "FOLLOWER") .. (isSurender and " (SURENDER)" or ""))

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

        -- Stuck detector: poin ga naik 10 menit → auto reconnect.
        -- Surender mode: a surender Follower's own points never move by design
        -- (it always leaves before finishing), so its own-points check would
        -- false-positive every 10 minutes — watch the GROUP's total instead,
        -- same fix Konvoi already needed for its Follower (reuses the same
        -- /api/konvoi-team-points + /api/konvoi-restart, which now also
        -- accepts event groups toggled to "surender").
        safeSpawn(function()
            local STUCK_THRESHOLD = 600
            if isSurender then
                local sessionStart   = os.time()
                local lastTeamTotal  = nil
                local lastTeamChange = os.time()
                while true do
                    task.wait(60)
                    local teamData = getKonvoiTeamPoints(player.Name)
                    if teamData then
                        if teamData.total and (lastTeamTotal == nil or teamData.total ~= lastTeamTotal) then
                            lastTeamTotal  = teamData.total
                            lastTeamChange = os.time()
                        end
                        if teamData.restart_requested_at and teamData.restart_requested_at > sessionStart then
                            log("[EVENT] Sinyal restart grup diterima — reconnect bareng...")
                            ReturnLobby()
                            return
                        end
                    end
                    local elapsed = os.difftime(os.time(), lastTeamChange)
                    if elapsed >= STUCK_THRESHOLD then
                        log("[EVENT] Total poin tim gak naik " .. math.floor(elapsed / 60) .. "m — broadcast restart ke grup...")
                        konvoiRestart(player.Name)
                        lastTeamChange = os.time()
                        ReturnLobby()
                    end
                end
            else
                while true do
                    task.wait(60)
                    local elapsed = os.difftime(os.time(), lastValChange)
                    if elapsed >= STUCK_THRESHOLD then
                        log("[EVENT] Stuck " .. math.floor(elapsed / 60) .. "m — auto reconnect")
                        lastValChange = os.time()  -- reset biar ga spam
                        ReturnLobby()
                    end
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
        RaceBrain.run(isWinner, isSurender)
    end)
end

-- ═══════════════════════════════════
--  MODE: EVENT KONVOI
--  4 device masuk 1 lobby. Winner (dari jump_mode, fixed sepanjang sesi)
--  SELALU Stay; ketiga Follower SELALU Leave tiap ronde (jeda random 1-2
--  detik per device biar gak nembak LeaveLobby barengan persis). Popup hasil
--  race dipaksa non-visible aja tanpa ditunggu/dikonfirmasi — kesehatan
--  sistem cukup diverifikasi lewat stuck-detector total poin tim.
--  Gak ada leave-list per-ronde dari backend — role Winner/Follower udah
--  cukup nentuin siapa Stay/Leave, jadi cuma 1x fetch job di awal sesi,
--  sama persis kayak pola Winner/Follower event biasa.
-- ═══════════════════════════════════
local KonvoiBrain = {}
do
    local KonvoiConfig = {
        LobbyName              = "Konvoi ProfessionalUnemploy",
        LobbyMode              = "nostalgia",
        RetryDelay             = 1,
        StartRaceRetryInterval = 5,   -- winner refires StartRace tiap N detik (konvoi cuma butuh 4 player, bukan 5)
        StartRaceLoopTimeout   = 300,
        RequeueSettleDelay     = 3,   -- jeda abis Leave sebelum balik ke NPC
        LeaveJitterMin         = 1,   -- Follower nunggu random segini (detik) sebelum LeaveLobby
        LeaveJitterMax         = 2,
        WinnerStayDelay        = 10,  -- Winner nunggu segini abis race mulai sebelum requeue (kasih waktu Follower leave + server proses)
    }
    local IsWinner = true

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
    -- recreate it on later rounds) — scan forever instead of giving up.
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
        klog("Role: WINNER (Stay)")
        if not createLobby() then return false end
        task.wait(KonvoiConfig.RetryDelay)
        if not selectRandomCar() then return false end
        if not toggleReadyOnce() then return false end
        klog("Firing StartRace every " .. KonvoiConfig.StartRaceRetryInterval .. "s until the race actually begins...")
        return spamStartRaceUntilStarted()
    end

    -- ── Follower controller ──
    local function runFollower()
        klog("Role: FOLLOWER (Leave)")
        joinLobbyBruteForce()
        task.wait(KonvoiConfig.RetryDelay)
        if not selectRandomCar() then return false end
        if not toggleReadyOnce() then return false end
        klog("Ready. Waiting for winner to start race...")
        return true
    end

    -- ── Race start handler ──
    -- Winner: stays put, waits long enough for all 3 Followers to jitter +
    -- LeaveLobby + settle, then force-hides whatever "win" popup shows
    -- (never waited on/verified — that's what the stuck-detector on total
    -- team points is for) and moves straight to requeue.
    local function winnerStayAndResolve()
        klog("Winner staying — waiting " .. KonvoiConfig.WinnerStayDelay .. "s for followers to leave and race to resolve...")
        task.wait(KonvoiConfig.WinnerStayDelay)
        pcall(function()
            player.PlayerGui.NostalgiaEvent.Container.Result.Visible = false
        end)
        return true
    end

    -- Follower: random 1-2s jitter (so all 3 don't fire in the exact same
    -- instant), then LeaveLobby 3x spaced out — FireServer gives no delivery
    -- confirmation, so a single shot has no protection against a dropped
    -- event (e.g. mid-race while the vehicle is moving fast).
    local function followerLeaveWithJitter()
        local jitter = KonvoiConfig.LeaveJitterMin + math.random() * (KonvoiConfig.LeaveJitterMax - KonvoiConfig.LeaveJitterMin)
        klog(string.format("Follower leaving in %.1fs...", jitter))
        task.wait(jitter)
        klog("Leaving lobby now...")
        for i = 1, 3 do
            pcall(function() leaveLobbyRemote() end)
            klog("LeaveLobby fired (" .. i .. "/3)")
            task.wait(0.75)
        end
        task.wait(KonvoiConfig.RequeueSettleDelay)
        return true
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
        WAIT_RACE_START = "WAIT_RACE_START",
        HANDLE_RACE_START = "HANDLE_RACE_START", REQUEUE = "REQUEUE", FAILED = "FAILED",
    }

    function KonvoiBrain.run(isWinner, deviceId)
        IsWinner = isWinner
        klog("Konvoi starting as " .. (IsWinner and "WINNER (Stay)" or "FOLLOWER (Leave)") .. ", device " .. tostring(deviceId) .. "...")
        local state = STATE.INIT

        while true do
            if state == STATE.INIT then
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
                state = waitForConvoiStart(KonvoiConfig.StartRaceLoopTimeout) and STATE.HANDLE_RACE_START or STATE.FAILED

            elseif state == STATE.HANDLE_RACE_START then
                if IsWinner then
                    state = winnerStayAndResolve() and STATE.REQUEUE or STATE.FAILED
                else
                    state = followerLeaveWithJitter() and STATE.REQUEUE or STATE.FAILED
                end

            elseif state == STATE.REQUEUE then
                klog("Looping back to the NPC for another round (role stays fixed)...")
                fetchShopDataOnce() -- refresh the points HUD's value for this round
                resetLobby()
                resetReadyState()
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

    -- Role is fixed for the whole session (Winner always Stay, Follower
    -- always Leave), so this is set once — no per-round updates needed.
    local evStatus = Instance.new("TextLabel", evFrame)
    evStatus.Size                   = UDim2.new(1, -24, 0, 36)
    evStatus.Position               = UDim2.new(0, 12, 0, 66)
    evStatus.BackgroundTransparency = 1
    evStatus.Font                   = Enum.Font.GothamBold
    evStatus.TextScaled             = true
    evStatus.TextStrokeTransparency = 0.5
    evStatus.TextStrokeColor3       = Color3.new(0, 0, 0)
    evStatus.TextXAlignment         = Enum.TextXAlignment.Center
    if isWinner then
        evStatus.Text       = "🏁 STAY tiap ronde"
        evStatus.TextColor3 = Color3.fromRGB(90, 220, 140)
    else
        evStatus.Text       = "🚪 LEAVE tiap ronde"
        evStatus.TextColor3 = Color3.fromRGB(255, 110, 90)
    end

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
        -- 10 menit → broadcast restart ke seluruh grup lalu reconnect. Poin
        -- akun sendiri gak reliable buat ini karena Follower emang selalu
        -- Leave tiap ronde (wajar poinnya sendiri gak naik).
        local konvoiSessionStart = os.time()
        safeSpawn(function()
            local STUCK_THRESHOLD = 600
            local lastTeamTotal  = nil
            local lastTeamChange = os.time()
            while true do
                task.wait(60)
                local teamData = getKonvoiTeamPoints(player.Name)
                if teamData then
                    if teamData.total then
                        if lastTeamTotal == nil or teamData.total ~= lastTeamTotal then
                            lastTeamTotal  = teamData.total
                            lastTeamChange = os.time()
                        end
                    end
                    if teamData.restart_requested_at and teamData.restart_requested_at > konvoiSessionStart then
                        log("[KONVOI] Sinyal restart grup diterima — reconnect bareng...")
                        ReturnLobby()
                        return
                    end
                end
                local elapsed = os.difftime(os.time(), lastTeamChange)
                if elapsed >= STUCK_THRESHOLD then
                    log("[KONVOI] Total poin tim gak naik " .. math.floor(elapsed / 60) .. "m — broadcast restart ke grup...")
                    konvoiRestart(player.Name)
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
--  MODE: EVENT MERDEKA
--  Solo — tiap akun main sendiri di private server sendiri (server_code gak
--  di-share, beda dari Event/Konvoi). Gak ada Winner/Follower: create lobby
--  sendiri, ambil bendera, balikin, ulang terus. Adaptasi dari merdeka.lua.
-- ═══════════════════════════════════
local MerdekaBrain = {}
do
    local MerdekaConfig = {
        LobbyName          = "Tim ProfessionalUnemploy",
        LobbyMode          = "merdeka",
        RetryDelay         = 1,
        VehicleWaitTimeout = 60,
        RaceStartTimeout   = 120,
        DriveSpeed         = 600,
        ArriveDistance     = 12,
        DriveLegTimeout    = 30,
        LongDriveTimeout   = 180,
        FlagCaptureTimeout = 30,
        FlagDropTimeout    = 15,
        ReturnYOffset      = 8,
    }

    local function mlog(msg) log("[MERDEKA] " .. tostring(msg)) end

    local function retry(fn, attempts, delay, label)
        attempts = attempts or 5
        delay    = delay or MerdekaConfig.RetryDelay
        for i = 1, attempts do
            local ok, err = pcall(fn)
            if ok then return true end
            mlog(string.format("%s failed (%d/%d): %s", label or "action", i, attempts, tostring(err)))
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
        mlog("Timeout: " .. (label or "condition") .. " not met after " .. timeout .. "s")
        return nil
    end

    -- ── Remotes (RaceRemotes folder, shared with racenostalgia/konvoi) ──
    local remoteCache = {}
    local function remoteInit()
        local ok, folder = pcall(function() return rp:WaitForChild("RaceRemotes", 15) end)
        if not ok or not folder then mlog("RaceRemotes folder not found"); return false end

        local names = { "CreateLobby", "SelectCar", "ToggleReady", "StartRace" }
        for _, name in ipairs(names) do
            local remOk, remote = pcall(function() return folder:WaitForChild(name, 15) end)
            if not remOk or not remote then mlog("Remote not found: " .. name); return false end
            remoteCache[name] = remote
        end
        mlog("RaceRemotes ready")
        return true
    end

    local function createLobbyRemote(name, mode) remoteCache.CreateLobby:FireServer(name, mode) end
    local function selectCarRemote(id, name) remoteCache.SelectCar:FireServer(id, name) end
    local function toggleReadyRemote() remoteCache.ToggleReady:FireServer() end
    local function startRaceRemote() remoteCache.StartRace:FireServer() end

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
        if not carId then mlog("No car found in Spawner ScrollingFrame"); return false end
        local ok = retry(function() selectCarRemote(carId, carName) end, 5, MerdekaConfig.RetryDelay, "SelectCar")
        if ok then
            mlog("Car selected: " .. carId .. " (" .. carName .. ")")
            task.wait(1)
        end
        return ok
    end

    -- ── Teleport / interact NPC ──
    local function teleportToNpc()
        local npc = waitUntil(function()
            return Workspace.Event.Merdeka.LobbyNPC
        end, 15, 0.5, "NPC lookup")
        if not npc then mlog("NPC LobbyNPC not found"); return false end

        local rootPart = npc:WaitForChild("HumanoidRootPart", 10)
        if not rootPart then mlog("LobbyNPC has no HumanoidRootPart"); return false end

        local character = player.Character or player.CharacterAdded:Wait()
        character:WaitForChild("HumanoidRootPart", 10)
        character:PivotTo(rootPart.CFrame * CFrame.new(0, 0, 3))
        task.wait(0.5)
        mlog("Teleported to NPC")
        return true
    end

    local function interactNpc()
        local ok = retry(function()
            local prompt = Workspace.Event.Merdeka.LobbyNPC.HumanoidRootPart:WaitForChild("ProximityPrompt", 10)
            fireproximityprompt(prompt)
        end, 5, MerdekaConfig.RetryDelay, "InteractNPC")
        if ok then
            mlog("Interacted with NPC")
            task.wait(1)
        end
        return ok
    end

    -- ── Lobby (solo — selalu create ulang tiap lap, gak ada join/browse) ──
    -- Tiap remote dikasih jeda 1s setelah sukses (sama seperti merdeka.lua
    -- asli) — server butuh waktu proses CreateLobby/SelectCar/ToggleReady
    -- sebelum remote berikutnya ditembak, kalau kepencet langsung beruntun
    -- dia silently no-op dan macet di menu BUAT TIM/GABUNG TIM.
    local function createLobby()
        local ok = retry(function() createLobbyRemote(MerdekaConfig.LobbyName, MerdekaConfig.LobbyMode) end,
            5, MerdekaConfig.RetryDelay, "CreateLobby")
        if ok then
            mlog("Lobby created: " .. MerdekaConfig.LobbyName)
            task.wait(1)
        end
        return ok
    end

    -- ── Ready ──
    local function toggleReady()
        local ok = retry(function() toggleReadyRemote() end, 5, MerdekaConfig.RetryDelay, "ToggleReady")
        if ok then
            mlog("Ready toggled")
            task.wait(1)
        end
        return ok
    end

    -- ── Start race ──
    local function startRace()
        local ok = retry(function() startRaceRemote() end, 5, MerdekaConfig.RetryDelay, "StartRace")
        if ok then mlog("StartRace fired") end
        return ok
    end

    -- ── Wait sampai duduk di mobil ──
    local function waitInVehicle()
        local chassisInterface = player.PlayerGui:WaitForChild("A-Chassis Interface", MerdekaConfig.VehicleWaitTimeout)
        if chassisInterface then mlog("Sudah di dalam mobil"); return true end
        mlog("Timeout menunggu A-Chassis Interface")
        return false
    end

    -- ── Wait race mulai (TimerLabel berubah) ──
    local function waitRaceStart(timeout)
        timeout = timeout or MerdekaConfig.RaceStartTimeout
        local merdekaGui = player.PlayerGui:WaitForChild("MerdekaEvent", 15)
        if not merdekaGui then mlog("MerdekaEvent GUI not found"); return false end
        local ok, timerLabel = pcall(function()
            return merdekaGui.Container.Progress.TimerRow.TimerLabel
        end)
        if not ok or not timerLabel then mlog("TimerLabel not found"); return false end

        local baseline = timerLabel.Text
        local elapsed = 0
        while elapsed < timeout do
            task.wait(1)
            elapsed = elapsed + 1
            local textOk, currentText = pcall(function() return timerLabel.Text end)
            if textOk and currentText ~= baseline then
                mlog("Race sudah mulai, timer berubah: " .. baseline .. " -> " .. currentText)
                return true
            end
        end
        mlog("Timeout menunggu race mulai")
        return false
    end

    -- ── Drive ke titik bendera (data spot presisi, dari data collection manual) ──
    local FLAG_SPOTS = {
        [1] = Vector3.new(7012.628906, -0.680334, -2591.969238),
        [2] = Vector3.new(-2268.640381, -25.941872, 1519.879395),
        [3] = Vector3.new(1984.369751, -29.652336, -2880.953613),
        [4] = Vector3.new(10740.369141, -14.802860, 3876.270508),
        [5] = Vector3.new(4068.312500, -25.514038, -1497.882935),
        [6] = Vector3.new(2482.523193, 12.362131, 2324.760742),
        [7] = Vector3.new(1698.429932, -13.407356, 103.762543),
        [8] = Vector3.new(1325.503540, -23.932224, -2644.533447),
    }
    local RETURN_FLAG_POSITION = Vector3.new(1956.355713, -20.677620, -4444.123047)

    local function getVehicle()
        local character = player.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        local seatPart  = humanoid and humanoid.SeatPart
        return seatPart and seatPart:FindFirstAncestorOfClass("Model")
    end

    local function readDestinationLabel()
        local ok, label = pcall(function()
            return player.PlayerGui.MerdekaEvent.Container.Progress.DestinationRow.DestinationLabel
        end)
        if not ok or not label then return nil end
        local text = label.Text or ""
        return { Raw = text, FlagNumber = tonumber(text:match("[Bb]endera%s*(%d+)")) }
    end

    local function driveVehicleTo(targetPosition, label, timeout)
        label   = label or "target"
        timeout = timeout or MerdekaConfig.DriveLegTimeout
        local elapsed = 0

        while elapsed < timeout do
            local vehicle = getVehicle()
            if not vehicle then
                mlog("Tidak duduk di vehicle, batal drive ke " .. label)
                return false
            end

            local currentPos = vehicle:GetPivot().Position
            local offset      = targetPosition - currentPos
            local distance     = offset.Magnitude

            if distance <= MerdekaConfig.ArriveDistance then
                mlog("Sampai di " .. label)
                return true
            end

            local dt = RunService.Heartbeat:Wait()
            elapsed = elapsed + dt

            local direction = offset.Unit
            local step       = math.min(MerdekaConfig.DriveSpeed * dt, distance)
            local newPos     = currentPos + direction * step
            vehicle:PivotTo(CFrame.lookAt(newPos, newPos + direction))
        end

        mlog("Timeout drive ke " .. label)
        return false
    end

    local function driveToFlagSpot()
        local info = readDestinationLabel()
        if not info or not info.FlagNumber then
            mlog("Tidak bisa baca nomor bendera dari DestinationLabel: " .. tostring(info and info.Raw))
            return false
        end

        local targetPos = FLAG_SPOTS[info.FlagNumber]
        if not targetPos then
            mlog("Tidak ada data spot untuk Titik Bendera " .. info.FlagNumber)
            return false
        end

        mlog("Target: Titik Bendera " .. info.FlagNumber)
        return driveVehicleTo(targetPos, "flag spot " .. info.FlagNumber, MerdekaConfig.LongDriveTimeout)
    end

    -- ── Wait bendera terambil (DestinationLabel berubah) ──
    local function waitFlagCaptured(timeout)
        timeout = timeout or MerdekaConfig.FlagCaptureTimeout
        local ok, destinationLabel = pcall(function()
            return player.PlayerGui.MerdekaEvent.Container.Progress.DestinationRow.DestinationLabel
        end)
        if not ok or not destinationLabel then mlog("DestinationLabel not found"); return false end

        local baseline = destinationLabel.Text
        local elapsed = 0

        while elapsed < timeout do
            task.wait(0.5)
            elapsed = elapsed + 0.5
            local textOk, currentText = pcall(function() return destinationLabel.Text end)
            if textOk and currentText ~= baseline then
                mlog("Bendera didapat! DestinationLabel berubah: " .. baseline .. " -> " .. currentText)
                return true
            end
        end
        mlog("Timeout menunggu bendera terambil")
        return false
    end

    -- ── Drive balik bawa bendera + tunggu ke-drop (CarryFlag_<Player> hilang) ──
    local function isCarryingFlag()
        local ok, result = pcall(function()
            local carFolder = Workspace.Vehicles:FindFirstChild(player.Name .. "sCar")
            return carFolder ~= nil and carFolder:FindFirstChild("CarryFlag_" .. player.Name) ~= nil
        end)
        return ok and result
    end

    local function waitFlagDropped(timeout)
        timeout = timeout or MerdekaConfig.FlagDropTimeout
        local elapsed = 0
        while elapsed < timeout do
            if not isCarryingFlag() then
                mlog("Bendera sudah ke-drop (CarryFlag hilang)")
                return true
            end
            task.wait(0.5)
            elapsed = elapsed + 0.5
        end
        mlog("Timeout menunggu bendera ke-drop, CarryFlag masih ada")
        return false
    end

    local function driveBackToStartPoint()
        local targetPos = RETURN_FLAG_POSITION + Vector3.new(0, MerdekaConfig.ReturnYOffset, 0)
        if not driveVehicleTo(targetPos, "titik balik bendera", MerdekaConfig.LongDriveTimeout) then
            return false
        end
        return waitFlagDropped()
    end

    -- ── Exit mobil ──
    local function exitVehicle()
        local character = player.Character
        local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then mlog("Humanoid tidak ditemukan, tidak bisa exit car"); return false end
        humanoid.Sit = false
        mlog("Keluar dari mobil")
        return true
    end

    -- ── Poin (MerdekaShopData) — nilainya bisa balik dalam format ada koma
    -- (mis. "12,345"), jadi selalu strip karakter non-digit sebelum tonumber. ──
    local function fetchMerdekaPoints()
        local ok, result = pcall(function()
            return rp:WaitForChild("NetworkContainer", 15)
                :WaitForChild("RemoteFunctions", 15)
                :WaitForChild("MerdekaShopData", 15)
                :InvokeServer()
        end)
        if not ok then mlog("Gagal ambil MerdekaShopData: " .. tostring(result)); return nil end

        local raw = result
        if type(result) == "table" then
            raw = result.Points or result.Point or result.points or result.point
                or result.Total or result.total
        end

        local digits = tostring(raw or ""):gsub("%D", "")
        if digits == "" then return nil end
        return tonumber(digits)
    end
    MerdekaBrain.fetchPoints = fetchMerdekaPoints

    -- ── State machine ──
    local STATE = {
        INIT = "INIT", TELEPORT_NPC = "TELEPORT_NPC", INTERACT_NPC = "INTERACT_NPC",
        CREATE_LOBBY = "CREATE_LOBBY", SELECT_CAR = "SELECT_CAR", READY = "READY",
        START_RACE = "START_RACE", WAIT_VEHICLE = "WAIT_VEHICLE", WAIT_RACE_START = "WAIT_RACE_START",
        DRIVE_TO_FLAG = "DRIVE_TO_FLAG", WAIT_FLAG_CAPTURED = "WAIT_FLAG_CAPTURED",
        DRIVE_BACK = "DRIVE_BACK", EXIT_VEHICLE = "EXIT_VEHICLE", REQUEUE = "REQUEUE", FAILED = "FAILED",
    }

    function MerdekaBrain.run()
        mlog("Merdeka starting for " .. player.Name .. " (solo)...")
        local state = STATE.INIT

        while true do
            if state == STATE.INIT then
                state = remoteInit() and STATE.TELEPORT_NPC or STATE.FAILED

            elseif state == STATE.TELEPORT_NPC then
                mlog("Teleporting to NPC...")
                state = teleportToNpc() and STATE.INTERACT_NPC or STATE.FAILED

            elseif state == STATE.INTERACT_NPC then
                mlog("Interacting with NPC...")
                state = interactNpc() and STATE.CREATE_LOBBY or STATE.FAILED

            elseif state == STATE.CREATE_LOBBY then
                mlog("Creating lobby...")
                state = createLobby() and STATE.SELECT_CAR or STATE.FAILED

            elseif state == STATE.SELECT_CAR then
                state = selectRandomCar() and STATE.READY or STATE.FAILED

            elseif state == STATE.READY then
                state = toggleReady() and STATE.START_RACE or STATE.FAILED

            elseif state == STATE.START_RACE then
                state = startRace() and STATE.WAIT_VEHICLE or STATE.FAILED

            elseif state == STATE.WAIT_VEHICLE then
                mlog("Menunggu masuk mobil...")
                state = waitInVehicle() and STATE.WAIT_RACE_START or STATE.FAILED

            elseif state == STATE.WAIT_RACE_START then
                mlog("Menunggu race mulai...")
                state = waitRaceStart() and STATE.DRIVE_TO_FLAG or STATE.FAILED

            elseif state == STATE.DRIVE_TO_FLAG then
                state = driveToFlagSpot() and STATE.WAIT_FLAG_CAPTURED or STATE.FAILED

            elseif state == STATE.WAIT_FLAG_CAPTURED then
                state = waitFlagCaptured() and STATE.DRIVE_BACK or STATE.FAILED

            elseif state == STATE.DRIVE_BACK then
                state = driveBackToStartPoint() and STATE.EXIT_VEHICLE or STATE.FAILED

            elseif state == STATE.EXIT_VEHICLE then
                state = exitVehicle() and STATE.REQUEUE or STATE.FAILED

            elseif state == STATE.REQUEUE then
                mlog("Lap selesai, balik ke NPC buat lap berikutnya...")
                state = STATE.TELEPORT_NPC

            elseif state == STATE.FAILED then
                mlog("Merdeka failed. Reconnecting to recover...")
                ReturnLobby()
                break
            end
        end
    end
end

local function startMerdekaEvent(deviceId)
    log("[MERDEKA] Starting Merdeka for " .. player.Name .. " (" .. tostring(deviceId) .. ")")

    serverLock()

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
        if CoreGui:FindFirstChild("SamlongMerdekaUI") then CoreGui.SamlongMerdekaUI:Destroy() end
    end)

    local evGui = Instance.new("ScreenGui")
    evGui.Name           = "SamlongMerdekaUI"
    evGui.ResetOnSpawn   = false
    evGui.DisplayOrder   = 9999
    evGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    evGui.Parent         = CoreGui

    local evFrame = Instance.new("Frame", evGui)
    evFrame.Size             = UDim2.new(0, 480, 0, 220)
    evFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    evFrame.Position         = UDim2.new(0.5, 0, 0.4, 0)
    evFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    evFrame.BackgroundTransparency = 0.15
    evFrame.BorderSizePixel  = 0
    Instance.new("UICorner", evFrame).CornerRadius = UDim.new(0, 18)

    local stroke = Instance.new("UIStroke", evFrame)
    stroke.Color     = Color3.fromRGB(255, 60, 60)
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
    evName.Text                   = player.Name .. " (MERDEKA) · " .. tostring(deviceId)

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

    -- ── Fetch jumlah point ke web (poin bisa balik format koma, sudah
    -- di-strip di dalam MerdekaBrain.fetchPoints) ──
    safeSpawn(function()
        local initPts        = MerdekaBrain.fetchPoints() or 0
        local latestPts       = initPts
        local lastValChange   = os.time()
        evPoints.Text = tostring(latestPts) .. " PTS"
        log("[MERDEKA] Poin awal: " .. tostring(initPts))
        sendInit(tostring(initPts))
        apiUpdate(player.Name, initPts)

        -- Stuck detector: poin ga naik 10 menit → auto reconnect.
        safeSpawn(function()
            local STUCK_THRESHOLD = 600
            while true do
                task.wait(60)
                local elapsed = os.difftime(os.time(), lastValChange)
                if elapsed >= STUCK_THRESHOLD then
                    log("[MERDEKA] Stuck " .. math.floor(elapsed / 60) .. "m — auto reconnect")
                    lastValChange = os.time()
                    ReturnLobby()
                end
            end
        end)

        while true do
            task.wait(60)
            local cur = MerdekaBrain.fetchPoints()
            if cur and cur > 0 and cur ~= latestPts then
                latestPts     = cur
                lastValChange = os.time()
                log("[MERDEKA] Poin update: " .. tostring(cur))
            end
            evPoints.Text = tostring(latestPts) .. " PTS"
            sendUpdate(tostring(latestPts))
            safeApiUpdate(player.Name, latestPts)
        end
    end)

    -- ── Merdeka state machine ──
    safeSpawn(function()
        MerdekaBrain.run()
    end)
end

-- ═══════════════════════════════════
--  MODE: EVENT BCA (MyBCA bank courier)
--  Solo — sama seperti Merdeka, tiap akun jalanin quest sendiri di private
--  server sendiri (server_code gak di-share). Diadaptasi dari bca.lua: clear
--  map (platform pijakan + lantai raksasa menggantikan Terrain/Map yang
--  di-wipe) lalu quest 12-step (ngobrol NPC, spawn mobil, muat koper ke
--  bagasi, antar tiap koper ke ATM tujuannya, setor) diulang terus.
-- ═══════════════════════════════════
local BcaBrain = {}
do
    local VirtualInputManager = game:GetService("VirtualInputManager")

    local function blog(msg) log("[BCA] " .. tostring(msg)) end

    local function getCharacter()
        local character = player.Character
        if not character then
            character = player.CharacterAdded:Wait()
        end
        local hrp = character:WaitForChild("HumanoidRootPart")
        return character, hrp
    end

    -- Hotbar bawaan Roblox gak kepakai sama sekali di quest ini.
    local function bcaDeleteBackpack()
        local backpack = player:FindFirstChild("Backpack")
        if backpack then backpack:Destroy() end
    end

    --======================================================
    -- CLEAR MAP — landmark platforms + lantai kotak raksasa
    -- (pijakan pengganti Terrain/Map yang di-wipe)
    --======================================================
    local BCA_LANDMARKS = {
        { name = "Respawn",        cframe = CFrame.new(-2197.001709, 19.069168, 1447.533691),  size = Vector3.new(150, 4, 150) },
        { name = "CarSpawnerArea", cframe = CFrame.new(1860.007080, 13.370062, -4897.120605),   size = Vector3.new(500, 4, 500) },
        { name = "ATM1",  cframe = CFrame.new(6381.612793, 21.813574, -7198.071289),  size = Vector3.new(20, 4, 20) },
        { name = "ATM2",  cframe = CFrame.new(2220.207031, 28.077150, -4594.378418),  size = Vector3.new(20, 4, 20) },
        { name = "ATM3",  cframe = CFrame.new(832.588562, 22.856527, -3819.309082),   size = Vector3.new(20, 4, 20) },
        { name = "ATM4",  cframe = CFrame.new(-1907.274292, 23.770407, 1141.594482),  size = Vector3.new(20, 4, 20) },
        { name = "ATM5",  cframe = CFrame.new(-4522.882324, 25.727510, 4376.390137),  size = Vector3.new(20, 4, 20) },
        { name = "ATM6",  cframe = CFrame.new(-4506.811523, 23.649044, 9662.726562),  size = Vector3.new(20, 4, 20) },
        { name = "ATM7",  cframe = CFrame.new(-475.867584, 27.291304, 8732.920898),   size = Vector3.new(20, 4, 20) },
        { name = "ATM8",  cframe = CFrame.new(-232.495178, 23.529095, 10729.978516),  size = Vector3.new(20, 4, 20) },
        { name = "ATM9",  cframe = CFrame.new(1586.373901, 52.160751, 871.395325),    size = Vector3.new(20, 4, 20) },
        { name = "ATM10", cframe = CFrame.new(1990.800537, 23.063835, -3526.621582),  size = Vector3.new(20, 4, 20) },
    }

    local function buildBcaLandmarkPlatforms()
        local existing = workspace:FindFirstChild("BcaGroundPlatforms")
        if existing then existing:Destroy() end

        local folder = Instance.new("Folder")
        folder.Name = "BcaGroundPlatforms"
        folder.Parent = workspace

        for _, landmark in ipairs(BCA_LANDMARKS) do
            local part = Instance.new("Part")
            part.Name = landmark.name
            part.Size = landmark.size
            part.Anchored = true
            part.CanCollide = true
            part.CanTouch = true
            part.CanQuery = true
            part.Material = Enum.Material.Concrete
            part.Color = Color3.fromRGB(80, 80, 90)
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth

            local topPosition = landmark.cframe.Position
            part.CFrame = CFrame.new(topPosition - Vector3.new(0, landmark.size.Y / 2, 0))
            part.Parent = folder
        end

        blog("Landmark platforms dibuat: " .. #BCA_LANDMARKS)
    end

    local FLOOR_THICKNESS  = 2
    local FLOOR_MAX_CHUNK  = 1800
    local FLOOR_PADDING    = 400
    local FLOOR_Y_OFFSET   = 7

    local bcaFloorY          = nil
    local bcaFloorEntryPoint = nil

    local function buildBcaFloorBox()
        local floorMinX, floorMaxX = math.huge, -math.huge
        local floorMinZ, floorMaxZ = math.huge, -math.huge
        local carSpawnerFloorPosition = nil

        for _, landmark in ipairs(BCA_LANDMARKS) do
            if landmark.name == "CarSpawnerArea" or landmark.name:match("^ATM%d+$") then
                local pos = landmark.cframe.Position
                if landmark.name == "CarSpawnerArea" then carSpawnerFloorPosition = pos end
                if pos.X < floorMinX then floorMinX = pos.X end
                if pos.X > floorMaxX then floorMaxX = pos.X end
                if pos.Z < floorMinZ then floorMinZ = pos.Z end
                if pos.Z > floorMaxZ then floorMaxZ = pos.Z end
            end
        end

        floorMinX = floorMinX - FLOOR_PADDING; floorMaxX = floorMaxX + FLOOR_PADDING
        floorMinZ = floorMinZ - FLOOR_PADDING; floorMaxZ = floorMaxZ + FLOOR_PADDING

        bcaFloorY = carSpawnerFloorPosition and (carSpawnerFloorPosition.Y + FLOOR_Y_OFFSET) or 0
        bcaFloorEntryPoint = carSpawnerFloorPosition
            and Vector3.new(carSpawnerFloorPosition.X, bcaFloorY + 1, carSpawnerFloorPosition.Z)

        local existing = workspace:FindFirstChild("BcaFloorBox")
        if existing then existing:Destroy() end

        local folder = Instance.new("Folder")
        folder.Name = "BcaFloorBox"
        folder.Parent = workspace

        local totalWidth  = floorMaxX - floorMinX
        local totalDepth  = floorMaxZ - floorMinZ
        local chunkCountX = math.max(1, math.ceil(totalWidth / FLOOR_MAX_CHUNK))
        local chunkCountZ = math.max(1, math.ceil(totalDepth / FLOOR_MAX_CHUNK))
        local chunkWidth  = totalWidth / chunkCountX
        local chunkDepth  = totalDepth / chunkCountZ
        local partCount   = 0

        for ix = 1, chunkCountX do
            for iz = 1, chunkCountZ do
                local centerX = floorMinX + chunkWidth * (ix - 0.5)
                local centerZ = floorMinZ + chunkDepth * (iz - 0.5)

                local part = Instance.new("Part")
                part.Name = "FloorChunk_" .. ix .. "_" .. iz
                part.Size = Vector3.new(chunkWidth + 4, FLOOR_THICKNESS, chunkDepth + 4)
                part.CFrame = CFrame.new(centerX, bcaFloorY - FLOOR_THICKNESS / 2, centerZ)
                part.Anchored = true
                part.CanCollide = true
                part.CanTouch = true
                part.CanQuery = true
                part.Material = Enum.Material.Concrete
                part.Color = Color3.fromRGB(60, 60, 70)
                part.TopSurface = Enum.SurfaceType.Smooth
                part.BottomSurface = Enum.SurfaceType.Smooth
                part.Parent = folder

                partCount = partCount + 1
            end
        end

        blog("Lantai kotak dibuat: " .. partCount .. " part (" .. chunkCountX .. "x" .. chunkCountZ .. ") di Y=" .. tostring(bcaFloorY))
    end

    -- Whitelist/blacklist sama persis dengan bca.lua asli.
    local BCA_WHITELIST_NAMES = {
        MY_BCA_COLLAB = true, Vehicles = true, Lives = true,
        BankCourierRoute = true, __BankCourierTarget = true,
    }

    local BCA_BLACKLIST_NAMES = {
        "2026LahkokginiTitano", "Asset", "Client", "EditableBuilds", "Etc",
        "Hover", "LightingAmbientRevamp", "MELAWAI", "Map", "Minigames",
        "ModificationCache", "ModificationPart", "MoreVehicle", "NPC",
        "Rambu and props", "Refund", "SATPAM_NAVBLOCK", "StreetLampTemplate",
        "TeleportFolder", "Train", "Train2", "ZoneFolder", "duplikat temp",
        "ArrowModel", "Flag",
    }

    -- Index-based targets (referensi Workspace:GetChildren() index, RISKY
    -- kalau urutan children berubah — makanya tiap item di-log Name+ClassName
    -- sebelum di-Destroy buat verifikasi manual di console).
    local BCA_BLACKLIST_INDICES = { 27, 28, 29, 30, 31, 32, 33, 34 }

    local function bcaIsWhitelisted(instance)
        if not instance then return true end
        return BCA_WHITELIST_NAMES[instance.Name] == true
    end

    local function bcaClearMap()
        blog("===== CLEAR MAP START =====")

        for _, name in ipairs(BCA_BLACKLIST_NAMES) do
            local target = workspace:FindFirstChild(name)
            if target then
                if bcaIsWhitelisted(target) then
                    blog("SKIP (whitelisted): " .. name)
                else
                    target:Destroy()
                end
            end
        end

        local snapshot = workspace:GetChildren()
        local sortedIndices = {}
        for _, idx in ipairs(BCA_BLACKLIST_INDICES) do table.insert(sortedIndices, idx) end
        table.sort(sortedIndices, function(a, b) return a > b end)

        for _, idx in ipairs(sortedIndices) do
            local target = snapshot[idx]
            if target and target.Parent then
                if bcaIsWhitelisted(target) then
                    blog("SKIP index " .. idx .. " (whitelisted): " .. target.Name)
                else
                    blog("Deleting index " .. idx .. ": " .. target.Name .. " (" .. target.ClassName .. ")")
                    target:Destroy()
                end
            else
                blog("Index " .. idx .. " tidak valid / instance sudah hilang")
            end
        end

        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            blog("Clearing Terrain...")
            terrain:Clear()
        end

        blog("===== CLEAR MAP DONE =====")
    end

    --======================================================
    -- DRIVING HELPERS
    --======================================================
    local SPORT_TRANSMISSION_MODE = "S"

    local function tapKey(keyCode, holdTime)
        holdTime = holdTime or 0.15
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(holdTime)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end

    local function getChassisValue(valueName)
        local chassisInterface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
        if not chassisInterface then return nil end
        local values = chassisInterface:FindFirstChild("Values")
        return values and values:FindFirstChild(valueName)
    end

    local function releaseHandbrakeIfNeeded()
        local pbrakeValue = getChassisValue("PBrake")
        if not pbrakeValue then return end
        for _ = 1, 3 do
            if not pbrakeValue.Value then break end
            tapKey(Enum.KeyCode.P, 0.15)
            task.wait(0.3)
        end
    end

    local function engageHandbrake()
        local pbrakeValue = getChassisValue("PBrake")
        if not pbrakeValue then return end
        for _ = 1, 3 do
            if pbrakeValue.Value then break end
            tapKey(Enum.KeyCode.P, 0.15)
            task.wait(0.3)
        end
    end

    local function ensureForwardGearEngaged()
        local gearValue = getChassisValue("Gear")
        if not gearValue then return end
        for _ = 1, 3 do
            if gearValue.Value > 0 then break end
            tapKey(Enum.KeyCode.E, 0.15)
            task.wait(0.3)
        end
    end

    local function getTransmissionDisplayLabel()
        local chassisInterface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
        local speedo  = chassisInterface and chassisInterface:FindFirstChild("Speedo")
        local speedo1 = speedo and speedo:FindFirstChild("Speedo1")
        local main    = speedo1 and speedo1:FindFirstChild("Main")
        return main and main:FindFirstChild("Transmission")
    end

    local function ensureSportTransmissionMode()
        local transmissionLabel = getTransmissionDisplayLabel()
        if not transmissionLabel then return end
        for _ = 1, 5 do
            if transmissionLabel.Text == SPORT_TRANSMISSION_MODE then break end
            tapKey(Enum.KeyCode.M, 0.15)
            task.wait(0.3)
        end
    end

    local function performDriveMaintenance()
        releaseHandbrakeIfNeeded()
        ensureForwardGearEngaged()
        ensureSportTransmissionMode()
    end

    -- Teleport ke jalur lurus: hover -> freeze -> turun pelan (biar fisik
    -- mobil ga "kaget" begitu langsung nempel jalur yang baru di-stream-in).
    local function teleportToStraightRoad(startPos, lookAtPos)
        local character, hrp = getCharacter()
        local vehicles = workspace:FindFirstChild("Vehicles")
        local car = vehicles and vehicles:FindFirstChild(player.Name .. "sCar")

        local HOVER_HEIGHT, FREEZE_DURATION, LOWER_DURATION = 30, 1.5, 1.5

        local hoverPos    = startPos + Vector3.new(0, HOVER_HEIGHT, 0)
        local hoverCFrame = CFrame.new(hoverPos, hoverPos + (lookAtPos - startPos))
        local groundCFrame = CFrame.new(startPos, lookAtPos)

        if not car then
            hrp.CFrame = hoverCFrame
            task.wait(FREEZE_DURATION)
            hrp.CFrame = groundCFrame
            return
        end

        local oldCarCFrame = car:GetPivot()
        local offset = oldCarCFrame:ToObjectSpace(hrp.CFrame)

        local anchoredParts = {}
        for _, part in ipairs(car:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(anchoredParts, { part = part, wasAnchored = part.Anchored })
                part.Anchored = true
            end
        end

        car:PivotTo(hoverCFrame)
        hrp.CFrame = hoverCFrame * offset
        task.wait(FREEZE_DURATION)

        local lowerStart = tick()
        while tick() - lowerStart < LOWER_DURATION do
            local alpha = (tick() - lowerStart) / LOWER_DURATION
            local stepCFrame = hoverCFrame:Lerp(groundCFrame, alpha)
            car:PivotTo(stepCFrame)
            hrp.CFrame = stepCFrame * offset
            task.wait(0.03)
        end

        car:PivotTo(groundCFrame)
        hrp.CFrame = groundCFrame * offset

        for _, entry in ipairs(anchoredParts) do
            entry.part.Anchored = entry.wasAnchored
        end
    end

    -- Drive lurus lineStart -> lineEnd dalam kira-kira desiredSeconds detik
    -- (CFrame-drag murni, W ditahan cuma buat visual roda muter — posisi
    -- dilacak sendiri di currentPos, BUKAN dibaca ulang dari car:GetPivot()
    -- tiap frame, biar gerakan fisik asli dari wheel motor yang masih
    -- "narik" gara-gara W ketahan ga ikut double-count jarak tempuh).
    local function wrapDriveTimedTo(lineStart, lineEnd, desiredSeconds, arriveDistance)
        desiredSeconds = desiredSeconds or 55
        arriveDistance = arriveDistance or 15

        local vehicles = workspace:FindFirstChild("Vehicles")
        local car = vehicles and vehicles:FindFirstChild(player.Name .. "sCar")
        if not car then return false end

        local character, hrp = getCharacter()

        local fullLine = lineEnd - lineStart
        local totalDistance = fullLine.Magnitude
        local lineDir = fullLine.Unit
        local travelDistance = math.max(totalDistance - arriveDistance, 1)
        local speed = travelDistance / desiredSeconds

        for _, part in ipairs(car:GetDescendants()) do
            if part:IsA("BasePart") then part.Anchored = false end
        end

        performDriveMaintenance()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)

        local lastMaintenanceCheck, MAINTENANCE_INTERVAL = tick(), 2
        local lastStep = tick()
        local reached = false
        local currentPos = lineStart

        while true do
            if tick() - lastMaintenanceCheck > MAINTENANCE_INTERVAL then
                lastMaintenanceCheck = tick()
                performDriveMaintenance()
            end

            local now = tick()
            local dt = now - lastStep
            lastStep = now

            local carCFrame = car:GetPivot()
            local toEnd = lineEnd - currentPos
            local flatToEnd = Vector3.new(toEnd.X, 0, toEnd.Z)
            local distanceToEnd = flatToEnd.Magnitude

            if distanceToEnd <= arriveDistance then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)

                local finalCFrame = CFrame.new(currentPos, currentPos + lineDir)
                local finalOffset = carCFrame:ToObjectSpace(hrp.CFrame)
                car:PivotTo(finalCFrame)
                hrp.CFrame = finalCFrame * finalOffset

                for _, part in ipairs(car:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end

                engageHandbrake()
                reached = true
                break
            end

            local offset = carCFrame:ToObjectSpace(hrp.CFrame)
            local moveDistance = math.min(speed * dt, distanceToEnd)
            currentPos = currentPos + lineDir * moveDistance
            local newCFrame = CFrame.new(currentPos, currentPos + lineDir)

            car:PivotTo(newCFrame)
            hrp.CFrame = newCFrame * offset

            local travelVelocity = lineDir * speed
            for _, part in ipairs(car:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.AssemblyLinearVelocity = travelVelocity
                    part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end

            task.wait()
        end

        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        return reached
    end

    --======================================================
    -- CORE LOOKUPS
    --======================================================
    local function waitForChildSafe(parent, name, timeout)
        if not parent then return nil end
        local object = parent:FindFirstChild(name)
        if object then return object end
        local start = tick()
        while tick() - start < timeout do
            object = parent:FindFirstChild(name)
            if object then return object end
            task.wait(0.25)
        end
        return nil
    end

    local function getBCA()
        return waitForChildSafe(workspace, "MY_BCA_COLLAB", 10)
    end

    local function findPrompt(object)
        if not object then return nil end
        return object:FindFirstChildWhichIsA("ProximityPrompt", true)
    end

    local function interactObject(object)
        local prompt = findPrompt(object)
        if not prompt then return false end
        fireproximityprompt(prompt)
        return true
    end

    local function touchOnce()
        local camera = workspace.CurrentCamera
        if not camera then return false end
        local viewport = camera.ViewportSize
        local x, y = viewport.X * 0.5, viewport.Y * 0.885
        VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.Begin.Value, x, y)
        task.wait(0.1)
        VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.End.Value, x, y)
        return true
    end

    local function getNpcDialogRemote()
        local network = rp:FindFirstChild("NetworkContainer")
        local remoteEvents = network and network:FindFirstChild("RemoteEvents")
        return remoteEvents and remoteEvents:FindFirstChild("NpcDialog")
    end

    local function getBankCourierRemote()
        local network = rp:FindFirstChild("NetworkContainer")
        local remoteEvents = network and network:FindFirstChild("RemoteEvents")
        return remoteEvents and remoteEvents:FindFirstChild("BankCourier")
    end

    local function isActuallyVisible(guiObject)
        if not guiObject.Visible then return false end
        local parent = guiObject.Parent
        while parent do
            if parent:IsA("GuiObject") then
                if not parent.Visible then return false end
            elseif parent:IsA("ScreenGui") then
                if not parent.Enabled then return false end
            end
            parent = parent.Parent
        end
        return true
    end

    local function isNpcDialogVisible()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return false end
        local npcDialogGui = pg:FindFirstChild("NpcDialog")
        if not npcDialogGui then return false end
        local textShadow = npcDialogGui:FindFirstChild("TextShadow", true)
        if not textShadow then return false end
        if textShadow:IsA("GuiObject") then return textShadow.Visible end
        return false
    end

    -- NpcDialog "Finish" detector — hook game.__namecall sekali per sesi BCA
    -- (dipasang di awal BcaBrain.run(), bukan di top-level module, biar mode
    -- lain yang gak pakai BCA gak ikut kena overhead hook ini).
    local bcaFinishDetected = false
    local bcaFinishDetectorInstalled = false

    local function installBcaFinishDetector()
        if bcaFinishDetectorInstalled then return end
        local npcDialog = getNpcDialogRemote()
        if not npcDialog or not hookmetamethod then return end

        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and self == npcDialog then
                local args = { ... }
                if args[1] == "Finish" then
                    bcaFinishDetected = true
                end
            end
            return oldNamecall(self, ...)
        end))

        bcaFinishDetectorInstalled = true
    end

    --======================================================
    -- ATM / JOB HELPERS
    --======================================================
    local function atmGetInstanceCFrame(inst)
        if not inst then return nil end
        if inst:IsA("BasePart") then return inst.CFrame
        elseif inst:IsA("Model") then return inst:GetPivot()
        elseif inst:IsA("Attachment") then return CFrame.new(inst.WorldPosition) end
        return nil
    end

    local function atmTeleportPlayerTo(inst, zOffset)
        local cframe = atmGetInstanceCFrame(inst)
        if not cframe then return false end
        local _, hrp = getCharacter()
        hrp.CFrame = cframe * CFrame.new(0, 0, zOffset)
        return true
    end

    local atmClosestATM  = nil
    local hasEnteredFloor = false

    local function atmGetBagasiPoint()
        local vehicles = workspace:FindFirstChild("Vehicles")
        local car = vehicles and vehicles:FindFirstChild(player.Name .. "sCar")
        return car and car:FindFirstChild("BagasiPoint")
    end

    local function atmGetDestinationCFrame()
        local route = workspace:FindFirstChild("BankCourierRoute")
        local destination = route and route:FindFirstChild("To")
        return destination and destination.CFrame
    end

    local function atmFindClosestATM(destinationPosition)
        local bca = workspace:FindFirstChild("MY_BCA_COLLAB")
        local job = bca and bca:FindFirstChild("Job")
        local bankCourier = job and job:FindFirstChild("BankCourier")
        local atms = bankCourier and bankCourier:FindFirstChild("ATMs")
        if not atms then return nil end

        local closestATM, closestDistance = nil, math.huge
        for i = 1, 10 do
            local atm = atms:FindFirstChild("ATM" .. tostring(i))
            if atm then
                local atmCFrame = atmGetInstanceCFrame(atm)
                if atmCFrame then
                    local distance = (atmCFrame.Position - destinationPosition).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestATM = atm
                    end
                end
            end
        end
        return closestATM
    end

    local function atmGetStatusLabel()
        local pg = player:WaitForChild("PlayerGui")
        local jobGui = waitForChildSafe(pg, "Job", 10)
        local bankCourierGui = jobGui and waitForChildSafe(jobGui, "BankCourier", 10)
        local statusGui = bankCourierGui and waitForChildSafe(bankCourierGui, "Status", 10)
        return statusGui and waitForChildSafe(statusGui, "Atm", 10)
    end

    local function atmGetProgress()
        local label = atmGetStatusLabel()
        if not label then return nil, nil, nil end
        local text = tostring(label.Text)
        -- Bahasa-independent: cocokkan pola "X/Y" apapun, bukan frasa
        -- Indonesia literal ("ATM terisi:") yang gagal match kalau akun
        -- Roblox-nya di-set bahasa Inggris (label GUI ikut ke-translate).
        local current, total = text:match("(%d+)%s*/%s*(%d+)")
        if not current or not total then return nil, nil, text end
        return tonumber(current), tonumber(total), text
    end

    local function atmGetBankCourierGui()
        local pg = player:WaitForChild("PlayerGui")
        local jobGui = waitForChildSafe(pg, "Job", 10)
        return jobGui and waitForChildSafe(jobGui, "BankCourier", 10)
    end

    local function atmNormalizeAngle(angle)
        angle = angle % 360
        if angle < 0 then angle = angle + 360 end
        return angle
    end

    local function atmAngleDifference(a, b)
        local diff = math.abs(atmNormalizeAngle(a) - atmNormalizeAngle(b))
        return math.min(diff, 360 - diff)
    end

    local function atmCircularMidpoint(a, b)
        a = math.rad(atmNormalizeAngle(a))
        b = math.rad(atmNormalizeAngle(b))
        local x, y = math.cos(a) + math.cos(b), math.sin(a) + math.sin(b)
        if math.abs(x) < 0.000001 and math.abs(y) < 0.000001 then
            return atmNormalizeAngle(math.deg(a))
        end
        return atmNormalizeAngle(math.deg(math.atan2(y, x)))
    end

    local function atmRunGreatGapMinigame(beforeCurrent, bankCourierRemote)
        local bankCourierGui = atmGetBankCourierGui()
        if not bankCourierGui then blog("[12] BankCourier GUI tidak ditemukan!"); return false end

        local skill = waitForChildSafe(bankCourierGui, "Skill", 10)
        if not skill then blog("[12] Skill GUI tidak ditemukan!"); return false end

        local count = waitForChildSafe(skill, "Count", 5)
        local needleArm = waitForChildSafe(skill, "NeedleArm", 5)
        if not needleArm then blog("[12] NeedleArm tidak ditemukan!"); return false end
        local tip = waitForChildSafe(needleArm, "Tip", 5)
        if not tip then blog("[12] Tip tidak ditemukan!"); return false end
        local greatArc = waitForChildSafe(skill, "GreatArc", 5)
        if not greatArc then blog("[12] GreatArc tidak ditemukan!"); return false end
        local leftHalf  = waitForChildSafe(greatArc, "LeftHalf", 5)
        local rightHalf = waitForChildSafe(greatArc, "RightHalf", 5)
        if not leftHalf or not rightHalf then blog("[12] GreatArc Half tidak ditemukan!"); return false end

        local TARGET_TOLERANCE = 5
        local wasInsideTarget = false
        local minigameStart = tick()

        while tick() - minigameStart < 30 do
            local nowCurrent, nowTotal = atmGetProgress()
            if nowCurrent and nowTotal and nowCurrent > beforeCurrent then
                return true
            end

            if not skill.Visible then
                wasInsideTarget = false
                task.wait(0.01)
            elseif count and count.Visible then
                wasInsideTarget = false
                task.wait(0.03)
            else
                local tipRotation    = atmNormalizeAngle(tip.AbsoluteRotation)
                local leftRotation   = atmNormalizeAngle(leftHalf.AbsoluteRotation)
                local rightRotation  = atmNormalizeAngle(rightHalf.AbsoluteRotation)
                local targetCenter   = atmCircularMidpoint(leftRotation, rightRotation)
                local targetDifference = atmAngleDifference(tipRotation, targetCenter)
                local inTarget = targetDifference <= TARGET_TOLERANCE

                if inTarget then
                    if not wasInsideTarget then
                        wasInsideTarget = true
                        task.wait(0.01)
                        bankCourierRemote:FireServer("SkillPress", tip.AbsoluteRotation)
                    end
                else
                    wasInsideTarget = false
                end

                task.wait()
            end
        end

        return false
    end

    --======================================================
    -- STEP 1-12
    --======================================================
    local startPosition = Vector3.new(1805.003, 24.283, -4632.021)
    local carSpawnPosition = Vector3.new(1873.906, 23.369, -4887.753)
    local wrapTravelTimeSeconds = 65

    local function runStep1()
        local character, hrp = getCharacter()
        local wasAnchored = hrp.Anchored
        hrp.Anchored = true
        hrp.CFrame = CFrame.new(startPosition + Vector3.new(0, 50, 0))
        task.wait(2)
        hrp.CFrame = CFrame.new(startPosition)
        task.wait(0.3)
        hrp.Anchored = wasAnchored
        return true
    end

    local function npcDialogRound(roundLabel)
        bcaFinishDetected = false

        local bca = getBCA()
        if not bca then blog("[2] BCA belum siap!"); return false end

        local npc = waitForChildSafe(bca, "NPC_START_JOB", 10)
        if not npc then blog("[2] NPC_START_JOB tidak ditemukan!"); return false end

        if not interactObject(npc) then blog("[2] Prompt NPC tidak ditemukan!"); return false end

        task.wait(1)

        local hasBeenVisible = false
        local clickCount, maxClicks = 0, 100

        while clickCount < maxClicks do
            local finishDetected = bcaFinishDetected
            local dialogVisible = isNpcDialogVisible()
            if dialogVisible then hasBeenVisible = true end

            if finishDetected and hasBeenVisible and not dialogVisible then
                break
            end

            clickCount = clickCount + 1
            touchOnce()

            local waitStart = tick()
            while tick() - waitStart < 0.2 do
                local currentFinish = bcaFinishDetected
                local currentVisible = isNpcDialogVisible()
                if currentVisible then hasBeenVisible = true end
                if currentFinish and hasBeenVisible and not currentVisible then break end
                task.wait(0.05)
            end
        end

        local finalFinish  = bcaFinishDetected
        local finalVisible = isNpcDialogVisible()
        local success = finalFinish and hasBeenVisible and not finalVisible

        if not success then blog("[2] Dialog (" .. roundLabel .. ") gagal diverifikasi selesai") end

        return success
    end

    local function runStep2()
        -- NPC-nya butuh diajak ngobrol 2 ronde sebelum Car Spawner kebuka.
        if not npcDialogRound("1/2") then return false end
        task.wait(1)
        if not npcDialogRound("2/2") then return false end
        return true
    end

    local function runStep3()
        bcaFinishDetected = false

        local bca = getBCA()
        if not bca then blog("[3] BCA belum siap!"); return false end

        local carSpawner = waitForChildSafe(bca, "CAR_SPAWNER_NPC", 10)
        if not carSpawner then blog("[3] CAR_SPAWNER_NPC tidak ditemukan!"); return false end

        local character, hrp = getCharacter()
        hrp.CFrame = CFrame.new(carSpawnPosition)
        task.wait(1)

        if not interactObject(carSpawner) then blog("[3] Prompt Car Spawner tidak ditemukan!"); return false end

        task.wait(1)

        local clickCount, maxClicks = 0, 100
        while clickCount < maxClicks do
            local finishDetected = bcaFinishDetected
            local dialogVisible = isNpcDialogVisible()
            if finishDetected and not dialogVisible then break end

            clickCount = clickCount + 1
            touchOnce()

            local waitStart = tick()
            while tick() - waitStart < 0.2 do
                local currentFinish = bcaFinishDetected
                local currentVisible = isNpcDialogVisible()
                if currentFinish and not currentVisible then break end
                task.wait(0.05)
            end
        end

        local finalFinish = bcaFinishDetected
        local finalDialogVisible = isNpcDialogVisible()
        local success = finalFinish and not finalDialogVisible
        if not success then blog("[3] Dialog Car Spawner gagal diverifikasi selesai") end
        return success
    end

    local function runStep4()
        local character, hrp = getCharacter()
        hrp.CFrame = CFrame.new(carSpawnPosition)
        task.wait(1)

        local vehicles = waitForChildSafe(workspace, "Vehicles", 10)
        if not vehicles then blog("[4] Vehicles tidak ditemukan!"); return false end

        local carName = player.Name .. "sCar"
        local bankCourierRemote = getBankCourierRemote()
        if not bankCourierRemote then blog("[4] BankCourier tidak ditemukan!"); return false end

        bankCourierRemote:FireServer("RespawnCar")

        local car = nil
        local startTime = tick()
        while tick() - startTime < 30 do
            car = vehicles:FindFirstChild(carName)
            if car then break end
            task.wait(0.25)
        end

        if not car then blog("[4] " .. carName .. " tidak muncul!"); return false end
        return true
    end

    local function runStep5()
        local pg = player:WaitForChild("PlayerGui")
        local jobGui = waitForChildSafe(pg, "Job", 10)
        if not jobGui then blog("[5] Job GUI tidak ditemukan!"); return false end

        local bankCourierGui = waitForChildSafe(jobGui, "BankCourier", 10)
        if not bankCourierGui then blog("[5] BankCourier tidak ditemukan!"); return false end

        local statusGui = waitForChildSafe(bankCourierGui, "Status", 10)
        if not statusGui then blog("[5] Status tidak ditemukan!"); return false end

        local koperStatus = waitForChildSafe(statusGui, "Koper", 10)
        if not koperStatus then blog("[5] Status.Koper tidak ditemukan!"); return false end

        local function getKoperProgress()
            local text = tostring(koperStatus.Text)
            -- Bahasa-independent: sama seperti atmGetProgress(), jangan
            -- gantung ke frasa Indonesia literal.
            local current, total = text:match("(%d+)%s*/%s*(%d+)")
            if not current or not total then return nil, nil, text end
            return tonumber(current), tonumber(total), text
        end

        local bca = getBCA()
        if not bca then blog("[5] BCA belum siap!"); return false end

        local job = waitForChildSafe(bca, "Job", 10)
        if not job then blog("[5] Job BCA tidak ditemukan!"); return false end

        local bankCourierJob = waitForChildSafe(job, "BankCourier", 10)
        if not bankCourierJob then blog("[5] BankCourier Job tidak ditemukan!"); return false end

        local koperSpawn = waitForChildSafe(bankCourierJob, "KoperSpawn", 10)
        if not koperSpawn then blog("[5] KoperSpawn tidak ditemukan!"); return false end

        local koperPart = waitForChildSafe(koperSpawn, "Part", 10)
        if not koperPart then blog("[5] Part koper tidak ditemukan!"); return false end

        local koperPrompt = koperPart:FindFirstChild("Prompt")
            or koperPart:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not koperPrompt then blog("[5] Prompt koper tidak ditemukan!"); return false end

        local bankCourierRemote = getBankCourierRemote()
        if not bankCourierRemote then blog("[5] BankCourier Remote tidak ditemukan!"); return false end

        local vehicles = waitForChildSafe(workspace, "Vehicles", 10)
        if not vehicles then blog("[5] Vehicles tidak ditemukan!"); return false end

        local carName = player.Name .. "sCar"
        local car = vehicles:FindFirstChild(carName)
        if not car then blog("[5] Vehicle belum spawn!"); return false end

        local bagasiPoint = nil
        local bagasiStart = tick()
        while tick() - bagasiStart < 15 do
            car = vehicles:FindFirstChild(carName)
            if car then bagasiPoint = car:FindFirstChild("BagasiPoint", true) end
            if bagasiPoint then break end
            task.wait(0.25)
        end
        if not bagasiPoint then blog("[5] BagasiPoint tidak ditemukan!"); return false end

        local usedKopers = {}

        local function getAllKopers()
            local result = {}
            for _, obj in ipairs(koperSpawn:GetChildren()) do
                if obj.Name:match("^Koper%d+$") then table.insert(result, obj) end
            end
            table.sort(result, function(a, b)
                local aNumber = tonumber(a.Name:match("%d+")) or 0
                local bNumber = tonumber(b.Name:match("%d+")) or 0
                return aNumber < bNumber
            end)
            return result
        end

        local function isKoperAvailable(koper)
            if not koper or not koper.Parent then return false end
            local basePart = koper:IsA("BasePart") and koper or koper:FindFirstChildWhichIsA("BasePart", true)
            return basePart ~= nil
        end

        local function findNextKoper()
            local kopers = getAllKopers()
            for _, koper in ipairs(kopers) do
                if not usedKopers[koper] and isKoperAvailable(koper) then return koper end
            end
            -- Semua object udah kepakai tapi masih butuh lebih banyak koper
            -- dari jumlah instance yang ada — reset dan pakai ulang.
            if #kopers > 0 then
                usedKopers = {}
                for _, koper in ipairs(kopers) do
                    if isKoperAvailable(koper) then return koper end
                end
            end
            return nil
        end

        -- Prompt yang beneran di-fire tiap putaran selalu di koperPart
        -- ("Part") — satu titik tetap, bukan prompt per-instance koper.
        local function teleportToKoper()
            local _, root = getCharacter()
            root.CFrame = koperPart.CFrame * CFrame.new(0, 0, -3)
            return true
        end

        local function teleportToBagasi()
            local _, root = getCharacter()
            if bagasiPoint:IsA("BasePart") then
                root.CFrame = bagasiPoint.CFrame * CFrame.new(0, 0, -2)
            elseif bagasiPoint:IsA("Model") then
                root.CFrame = bagasiPoint:GetPivot() * CFrame.new(0, 0, -2)
            elseif bagasiPoint:IsA("Attachment") then
                root.CFrame = CFrame.new(bagasiPoint.WorldPosition)
            end
            return true
        end

        local function getMinigame()
            local timing = bankCourierGui:FindFirstChild("Timing")
            if not timing then return nil end
            local track, trunk = timing:FindFirstChild("Track"), timing:FindFirstChild("Trunk")
            if not track or not trunk then return nil end
            local koper, slot = track:FindFirstChild("Koper"), trunk:FindFirstChild("Slot")
            if not koper or not slot then return nil end
            return timing, track, koper, trunk, slot
        end

        local function waitForMinigame()
            local start = tick()
            while tick() - start < 10 do
                local timing, track, koper, trunk, slot = getMinigame()
                if koper and slot and isActuallyVisible(koper) and isActuallyVisible(slot) then
                    return timing, track, koper, trunk, slot
                end
                task.wait(0.05)
            end
            return nil
        end

        -- Sliding minigame: koper icon digeser server, LoadPress ditembak
        -- begitu titik tengahnya masuk rentang slot bagasi.
        local function loadOneKoper(beforeCurrent)
            teleportToBagasi()
            task.wait(0.5)

            local muatPrompt = bagasiPoint:FindFirstChild("MuatPrompt", true)
            if not muatPrompt or not muatPrompt:IsA("ProximityPrompt") then
                blog("[5] MuatPrompt tidak ditemukan!")
                return false
            end

            fireproximityprompt(muatPrompt)

            local timing, track, koper, trunk, slot = waitForMinigame()
            if not koper or not slot then blog("[5] Minigame tidak muncul!"); return false end

            task.wait(0.2)

            local locked = false
            local connection

            local function scanPosition()
                if locked then return true end
                if not koper.Parent or not slot.Parent then return false end

                local koperPosition = koper.Position
                local koperLeft = track.AbsolutePosition.X + (koperPosition.X.Scale * track.AbsoluteSize.X) + koperPosition.X.Offset
                local koperCenter = koperLeft + (koper.AbsoluteSize.X / 2)

                local slotPosition = slot.Position
                local slotLeft = trunk.AbsolutePosition.X + (slotPosition.X.Scale * trunk.AbsoluteSize.X) + slotPosition.X.Offset
                local slotRight = slotLeft + slot.AbsoluteSize.X

                if koperCenter >= slotLeft and koperCenter <= slotRight then
                    locked = true
                    task.wait(0.05)
                    bankCourierRemote:FireServer("LoadPress")
                    return true
                end
                return false
            end

            connection = koper:GetPropertyChangedSignal("Position"):Connect(function()
                if not locked then pcall(scanPosition) end
            end)

            local scanStart = tick()
            while not locked and tick() - scanStart < 30 do
                pcall(scanPosition)
                task.wait(0.01)
            end

            if connection then connection:Disconnect(); connection = nil end

            if not locked then blog("[5] Minigame gagal!"); return false end

            local counterStart = tick()
            while tick() - counterStart < 10 do
                local nowCurrent, nowTotal = getKoperProgress()
                if nowCurrent and nowTotal and nowCurrent > beforeCurrent then return true end
                task.wait(0.05)
            end

            blog("[5] Counter koper tidak berubah!")
            return false
        end

        while true do
            local current, total = getKoperProgress()
            if not current or not total then blog("[5] Tidak bisa membaca jumlah koper!"); break end
            if current >= total then break end

            local koper = findNextKoper()
            if not koper then
                local waitStart = tick()
                while tick() - waitStart < 15 do
                    koper = findNextKoper()
                    if koper then break end
                    task.wait(0.25)
                end
            end
            if not koper then blog("[5] Koper berikutnya tidak ditemukan!"); break end

            usedKopers[koper] = true

            if not teleportToKoper() then blog("[5] Gagal teleport ke koper!"); break end

            task.wait(0.8)
            fireproximityprompt(koperPrompt)
            task.wait(1)

            if not loadOneKoper(current) then blog("[5] Gagal load koper!"); break end

            task.wait(0.5)
        end

        local finalCurrent, finalTotal = getKoperProgress()
        if finalCurrent and finalTotal then
            return finalCurrent >= finalTotal
        end
        return false
    end

    local function runStep6()
        local function isInCar()
            local pg = player:WaitForChild("PlayerGui")
            return pg:FindFirstChild("A-Chassis Interface") ~= nil
        end

        if isInCar() then return true end

        local vehicles = workspace:FindFirstChild("Vehicles")
        if not vehicles then blog("[6] Vehicles tidak ditemukan!"); return false end

        local carName = player.Name .. "sCar"
        local car = vehicles:FindFirstChild(carName)
        if not car then blog("[6] " .. carName .. " belum ditemukan!"); return false end

        local body = car:FindFirstChild("Body")
        if not body then blog("[6] Body mobil tidak ditemukan!"); return false end

        local rm = body:FindFirstChild("RM")
        if not rm then blog("[6] RM pintu driver tidak ditemukan!"); return false end

        local function getRoot()
            local character = player.Character or player.CharacterAdded:Wait()
            return character:WaitForChild("HumanoidRootPart")
        end

        local rmCFrame = rm:IsA("BasePart") and rm.CFrame or (rm:IsA("Model") and rm:GetPivot())
        if not rmCFrame then blog("[6] CFrame RM tidak ditemukan!"); return false end

        local root = getRoot()
        root.CFrame = rmCFrame * CFrame.new(0, 0, -2)
        task.wait(0.5)

        local drivePrompt = nil
        for _, obj in ipairs(rm:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and (obj.ActionText == "Drive" or obj.ObjectText == "Drive") then
                drivePrompt = obj
                break
            end
        end
        if not drivePrompt then
            for _, obj in ipairs(rm:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj.Enabled then drivePrompt = obj; break end
            end
        end
        if not drivePrompt then
            local rmPosition = rm:IsA("BasePart") and rm.Position or (rm:IsA("Model") and rm:GetPivot().Position)
            if rmPosition then
                local closestDistance = 10
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Enabled then
                        local parent = obj.Parent
                        if parent and parent:IsA("BasePart") then
                            local distance = (parent.Position - rmPosition).Magnitude
                            if distance < closestDistance then
                                closestDistance = distance
                                drivePrompt = obj
                            end
                        end
                    end
                end
            end
        end
        if not drivePrompt then blog("[6] Drive Prompt tidak ditemukan!"); return false end

        for attempt = 1, 5 do
            if isInCar() then return true end

            root = getRoot()
            root.CFrame = rmCFrame * CFrame.new(0, 0, -2)
            task.wait(0.25)

            if drivePrompt and drivePrompt.Parent and drivePrompt.Enabled then
                fireproximityprompt(drivePrompt)
            else
                for _, obj in ipairs(rm:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") and obj.Enabled then drivePrompt = obj; break end
                end
                if drivePrompt then fireproximityprompt(drivePrompt) end
            end

            local start = tick()
            while tick() - start < 2 do
                if isInCar() then return true end
                task.wait(0.1)
            end
        end

        if isInCar() then return true end
        blog("[6] Gagal naik mobil!")
        return false
    end

    local function runStep7()
        local route = workspace:FindFirstChild("BankCourierRoute")
        if not route then blog("[7] BankCourierRoute tidak ditemukan!"); return false end

        local destination = route:FindFirstChild("To")
        if not destination then blog("[7] Route.To tidak ditemukan!"); return false end

        local destinationPosition = destination.CFrame.Position

        local closestATM = atmFindClosestATM(destinationPosition)
        if not closestATM then blog("[7] Tidak menemukan ATM!"); return false end

        local atmCFrame = atmGetInstanceCFrame(closestATM)
        if not atmCFrame then blog("[7] CFrame ATM tidak ditemukan!"); return false end

        task.wait(0.5)

        -- Lantai kotak sejajar tanah: teleport instan ke titik entry (atau
        -- geser 50 stud dari posisi mobil sekarang kalau udah pernah masuk
        -- lantai sebelumnya), lalu ditarik (wrap timed) lurus ke titik
        -- sejajar ATM tujuan — begitu masuk radius arrive, mobil berhenti
        -- di situ juga (ga ada lagi teleport naik/turun ke papan parkir).
        if bcaFloorEntryPoint and bcaFloorY then
            local ATM_FLOOR_ARRIVE_DISTANCE = 35
            local floorTargetPoint = Vector3.new(atmCFrame.Position.X, bcaFloorY + 1, atmCFrame.Position.Z)
            local driveLineStart = bcaFloorEntryPoint

            if not hasEnteredFloor then
                teleportToStraightRoad(bcaFloorEntryPoint, floorTargetPoint)
                hasEnteredFloor = true
            else
                local vehicles = workspace:FindFirstChild("Vehicles")
                local car = vehicles and vehicles:FindFirstChild(player.Name .. "sCar")
                local currentCarPos = car and car:GetPivot().Position

                if currentCarPos then
                    driveLineStart = currentCarPos
                    local mainDir = floorTargetPoint - currentCarPos
                    if mainDir.Magnitude > 0.001 then
                        mainDir = mainDir.Unit
                        local rightDir = Vector3.new(mainDir.Z, 0, -mainDir.X)
                        local SLIDE_DISTANCE, SLIDE_DURATION, SLIDE_ARRIVE_DISTANCE = 50, 1.5, 3
                        local slidePoint = currentCarPos + rightDir * SLIDE_DISTANCE
                        wrapDriveTimedTo(currentCarPos, slidePoint, SLIDE_DURATION, SLIDE_ARRIVE_DISTANCE)
                        driveLineStart = slidePoint
                    end
                else
                    teleportToStraightRoad(bcaFloorEntryPoint, floorTargetPoint)
                    driveLineStart = bcaFloorEntryPoint
                end
            end

            wrapDriveTimedTo(driveLineStart, floorTargetPoint, wrapTravelTimeSeconds, ATM_FLOOR_ARRIVE_DISTANCE)
        end

        return true
    end

    local function runStep8()
        local function isInCar()
            local pg = player:WaitForChild("PlayerGui")
            return pg:FindFirstChild("A-Chassis Interface") ~= nil
        end

        if not isInCar() then return true end

        local character = player.Character or player.CharacterAdded:Wait()
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        for _ = 1, 10 do
            if not isInCar() then return true end

            if not humanoid then
                character = player.Character or player.CharacterAdded:Wait()
                humanoid = character:FindFirstChildOfClass("Humanoid")
            end

            local seat = humanoid and humanoid.SeatPart
            if humanoid then humanoid.Jump = true; humanoid.Sit = false end

            task.wait(0.3)
            if not isInCar() then return true end

            if seat and seat:IsA("VehicleSeat") then
                seat.Disabled = true
                task.wait(0.2)
                seat.Disabled = false
            end

            task.wait(0.3)
        end

        if isInCar() then blog("[8] Gagal keluar mobil!"); return false end
        return true
    end

    local function runStep9()
        local bagasiPoint = atmGetBagasiPoint()
        if not bagasiPoint then blog("[9] BagasiPoint tidak ditemukan!"); return false end
        atmTeleportPlayerTo(bagasiPoint, -2)
        return true
    end

    local function runStep10()
        local bagasiPoint = atmGetBagasiPoint()
        if not bagasiPoint then blog("[10] BagasiPoint tidak ditemukan!"); return false end

        local ambilPrompt = bagasiPoint:FindFirstChild("AmbilPrompt")
        if not ambilPrompt then blog("[10] AmbilPrompt tidak ditemukan!"); return false end

        -- AmbilPrompt bertipe Hold — simulasikan tahan penuh HoldDuration.
        ambilPrompt:InputHoldBegin()
        task.wait(ambilPrompt.HoldDuration + 0.3)
        ambilPrompt:InputHoldEnd()

        return true
    end

    local function runStep11()
        local destinationCFrame = atmGetDestinationCFrame()
        if not destinationCFrame then blog("[11] Route.To tidak ditemukan!"); return false end

        local closestATM = atmFindClosestATM(destinationCFrame.Position)
        if not closestATM then blog("[11] Tidak menemukan ATM!"); return false end

        atmClosestATM = closestATM

        local atmScreen = closestATM:FindFirstChild("Screen_ATM_01", true)
        if not atmScreen then blog("[11] Screen_ATM_01 tidak ditemukan!"); return false end

        atmTeleportPlayerTo(atmScreen, -2)
        return true
    end

    local function runStep12()
        if not atmClosestATM then blog("[12] Belum ada ATM tujuan!"); return false end

        local beforeCurrent = atmGetProgress()
        if not beforeCurrent then blog("[12] Tidak bisa membaca progress ATM!"); return false end

        local bankCourierRemote = getBankCourierRemote()
        if not bankCourierRemote then blog("[12] BankCourier Remote tidak ditemukan!"); return false end

        -- Buka ATM: bukan ProximityPrompt, langsung FireServer "FillStart".
        bankCourierRemote:FireServer("FillStart")

        local success = atmRunGreatGapMinigame(beforeCurrent, bankCourierRemote)
        if not success then blog("[12] Minigame gagal / timeout!") end
        return success
    end

    -- Step 1-5 sekali (ngobrol NPC, spawn mobil, load semua koper ke
    -- bagasi). Step 6-12 diulang PER KOPER (naik mobil, antar ke ATM
    -- tujuan koper itu, keluar mobil, ambil koper, setor) sampai semua
    -- koper terkirim, baru balik ke Step 1 (ngobrol NPC lagi = job baru).
    local function runFullCycle()
        if not runStep1() then return false end
        task.wait(0.5)
        if not runStep2() then return false end
        task.wait(0.5)
        if not runStep3() then return false end
        task.wait(0.5)
        if not runStep4() then return false end
        task.wait(0.5)
        if not runStep5() then return false end
        task.wait(0.5)

        while true do
            local current, total = atmGetProgress()
            if not current or not total then blog("Gagal baca progress ATM!"); return false end
            if current >= total then
                blog("Semua koper terkirim (" .. current .. "/" .. total .. ")! Kembali ke NPC...")
                break
            end

            if not runStep6() then return false end
            task.wait(0.5)
            if not runStep7() then return false end
            task.wait(0.5)
            if not runStep8() then return false end
            task.wait(0.5)
            if not runStep9() then return false end
            task.wait(0.5)
            if not runStep10() then return false end
            task.wait(0.5)
            if not runStep11() then return false end
            task.wait(0.5)
            if not runStep12() then return false end
            task.wait(0.5)
        end

        return true
    end

    --======================================================
    -- SALDO MYBCA (dibaca dari GUI phone in-game, gak ada
    -- RemoteFunction yang expose raw data)
    --======================================================
    local function getSaldoAccumulatedLabel()
        local playerGui = player.PlayerGui
        local phoneGui  = playerGui:FindFirstChild("ACTUAL NEW PHONE")
        local container = phoneGui and phoneGui:FindFirstChild("Container")
        local holder    = container and container:FindFirstChild("Holder")
        local appContainer = holder and holder:FindFirstChild("AppContainer")
        local myBca     = appContainer and appContainer:FindFirstChild("MyBca")
        local poketRupiah = myBca and myBca:FindFirstChild("PoketRupiah")
        local pocketList  = poketRupiah and poketRupiah:FindFirstChild("PocketList")
        local balanceFrame = pocketList and pocketList:FindFirstChild("BalanceFrame")
        return balanceFrame and balanceFrame:FindFirstChild("Accumulated")
    end

    function BcaBrain.getSaldo()
        local label = getSaldoAccumulatedLabel()
        if not label then return 0 end
        local digits = (tostring(label.Text):gsub("%D", ""))
        if digits == "" then return 0 end
        return tonumber(digits) or 0
    end

    --======================================================
    -- MAIN LOOP — auto start, gak ada tombol AUTO ON/OFF lagi (beda dari
    -- bca.lua asli): begitu dipanggil, langsung deleteBackpack -> clear
    -- map -> mulai siklus, diulang terus (gagal = tunggu 5s, ulangi dari
    -- Step 1 — sama seperti master loop bca.lua asli).
    --======================================================
    function BcaBrain.run()
        blog("Starting for " .. player.Name .. "...")

        installBcaFinishDetector()

        bcaDeleteBackpack()
        player.ChildAdded:Connect(function(child)
            if child.Name == "Backpack" then
                task.wait()
                child:Destroy()
            end
        end)

        buildBcaLandmarkPlatforms()
        buildBcaFloorBox()
        bcaClearMap()

        task.wait(1)

        local cycleCount = 0
        while true do
            cycleCount = cycleCount + 1
            blog("Mulai siklus #" .. cycleCount .. "...")
            local success = runFullCycle()
            if success then
                blog("Siklus #" .. cycleCount .. " selesai! Mengulang...")
            else
                blog("Siklus #" .. cycleCount .. " gagal, coba lagi 5 detik lagi...")
                task.wait(5)
            end
            task.wait(1)
        end
    end
end

local function startMyBcaEvent(deviceId)
    log("[BCA] Starting Event BCA for " .. player.Name .. " (" .. tostring(deviceId) .. ")")

    serverLock()

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
        if CoreGui:FindFirstChild("SamlongBcaUI") then CoreGui.SamlongBcaUI:Destroy() end
    end)

    local evGui = Instance.new("ScreenGui")
    evGui.Name           = "SamlongBcaUI"
    evGui.ResetOnSpawn   = false
    evGui.DisplayOrder   = 9999
    evGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    evGui.Parent         = CoreGui

    local evFrame = Instance.new("Frame", evGui)
    evFrame.Size             = UDim2.new(0, 480, 0, 220)
    evFrame.AnchorPoint      = Vector2.new(0.5, 0.5)
    evFrame.Position         = UDim2.new(0.5, 0, 0.4, 0)
    evFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
    evFrame.BackgroundTransparency = 0.15
    evFrame.BorderSizePixel  = 0
    Instance.new("UICorner", evFrame).CornerRadius = UDim.new(0, 18)

    local stroke = Instance.new("UIStroke", evFrame)
    stroke.Color     = Color3.fromRGB(245, 158, 11)
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
    evName.Text                   = player.Name .. " (EVENT BCA) · " .. tostring(deviceId)

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
    evPoints.Text                   = "Rp -"

    -- ── Fetch saldo MyBCA ke web (poin-like, sama pola seperti mode lain) ──
    safeSpawn(function()
        local function formatWithCommas(digits)
            local reversed = digits:reverse()
            local grouped = reversed:gsub("(%d%d%d)", "%1,")
            grouped = grouped:reverse():gsub("^,", "")
            return grouped
        end

        local initSaldo     = BcaBrain.getSaldo()
        local latestSaldo   = initSaldo
        local lastValChange = os.time()
        evPoints.Text = "Rp " .. formatWithCommas(tostring(latestSaldo))
        log("[BCA] Saldo awal: " .. tostring(initSaldo))
        sendInit(tostring(initSaldo))
        apiUpdate(player.Name, initSaldo)

        -- Stuck detector: saldo ga naik 10 menit → auto reconnect.
        safeSpawn(function()
            local STUCK_THRESHOLD = 600
            while true do
                task.wait(60)
                local elapsed = os.difftime(os.time(), lastValChange)
                if elapsed >= STUCK_THRESHOLD then
                    log("[BCA] Stuck " .. math.floor(elapsed / 60) .. "m — auto reconnect")
                    lastValChange = os.time()
                    ReturnLobby()
                end
            end
        end)

        while true do
            task.wait(60)
            local cur = BcaBrain.getSaldo()
            if cur > 0 and cur ~= latestSaldo then
                latestSaldo   = cur
                lastValChange = os.time()
                log("[BCA] Saldo update: " .. tostring(cur))
            end
            evPoints.Text = "Rp " .. formatWithCommas(tostring(latestSaldo))
            sendUpdate(tostring(latestSaldo))
            safeApiUpdate(player.Name, latestSaldo)
        end
    end)

    -- ── BCA state machine ──
    safeSpawn(function()
        BcaBrain.run()
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
        -- event_mode "surender" reuses the Konvoi 1-stay/rest-leave mechanic
        -- (same winner/follower role, just routed to KonvoiBrain instead of RaceBrain)
        local eventMode = (data.event_mode or "race"):lower()
        if eventMode == "surender" then
            if jumpMode == "jump" then return "event_surender_follower"
            else                       return "event_surender_winner" end
        end

        -- nojump = winner (create+start lobby), jump = follower (join lobby)
        if jumpMode == "jump" then return "event_follower"
        else                       return "event_winner" end

    elseif jenis == "konvoi" then
        -- Same winner/follower convention as "event". Winner always Stays,
        -- every Follower always Leaves each round — no separate per-round
        -- Leave/Stay decision needed, it's just tied to this fixed role.
        if jumpMode == "jump" then return "konvoi_follower"
        else                       return "konvoi_winner" end

    elseif jenis == "merdeka" then
        -- Solo — each account creates and plays its own lobby, no winner/follower role.
        return "merdeka_solo"

    elseif jenis == "event_bca" then
        -- Solo — each account runs its own MyBCA bank-courier quest, no winner/follower role.
        return "event_bca_solo"
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
        elseif jenisFix == "minigame" or jenisFix == "event_bca" then
            joinRegion = "Jakarta"
        elseif jenisFix == "merdeka" then
            joinRegion = "Bandung"
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

        elseif mode == "event_surender_winner" then
            startEvent(true, true)

        elseif mode == "event_surender_follower" then
            startEvent(false, true)

        elseif mode == "konvoi_winner" then
            startKonvoiEvent(true, data.device_id)

        elseif mode == "konvoi_follower" then
            startKonvoiEvent(false, data.device_id)

        elseif mode == "merdeka_solo" then
            startMerdekaEvent(data.device_id)

        elseif mode == "event_bca_solo" then
            startMyBcaEvent(data.device_id)
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
