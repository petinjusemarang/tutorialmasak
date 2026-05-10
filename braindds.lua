-- SAMLONG DDS BRAIN — Auto execute for Drag Drive Simulator
-- Execute this script while already inside the DDS game

-- ═══════════════════════════════════
--  ANTI DOUBLE RUN
-- ═══════════════════════════════════
if getgenv()._samlongDDSRunning then
    print("[DDS] Already running, exit.")
    return
end
getgenv()._samlongDDSRunning = true

-- ═══════════════════════════════════
--  WAIT GAME LOADED
-- ═══════════════════════════════════
if not game:IsLoaded() then game.Loaded:Wait() end

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local player      = Players.LocalPlayer

local DDS_LOBBY_PLACE = 131378148336503
local IS_LOBBY        = (game.PlaceId == DDS_LOBBY_PLACE)

-- ═══════════════════════════════════
--  QUEUE ON TELEPORT
--  Agar braindds.lua auto-run setelah Luvio teleport ke Mandalika
-- ═══════════════════════════════════
local AUTOEXEC = [[
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(7)
getgenv()._samlongDDSRunning = nil
local ok, err = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/braindds.lua"))()
end)
if not ok then print("[DDS] Autoexec error: " .. tostring(err)) end
]]

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
--  CONFIG
-- ═══════════════════════════════════
local SHEETS_URL = "https://script.google.com/macros/s/AKfycbzBFd5ASlqRLk1pS4Kx3cvBujvFsCIr0QKrdtVO9xZv8fBPHp0L1CKKRwnjpQwD7qHrIw/exec"
local API_URL    = "https://samlongweb-production.up.railway.app"
local API_KEY    = "slg_prod_nJjQZJQ4kR98l9zTfTJ56CBgeDrzxaws0eFk7rYJg2SAhvu7WRloXti3KkiXRnYN"

-- ═══════════════════════════════════
--  LOG UI
-- ═══════════════════════════════════
local logGui = Instance.new("ScreenGui", player.PlayerGui)
logGui.Name         = "SamlongDDSLog"
logGui.ResetOnSpawn = false

local logFrame = Instance.new("Frame", logGui)
logFrame.Size             = UDim2.new(0, 420, 0, 200)
logFrame.Position         = UDim2.new(0, 20, 0, 100)
logFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
logFrame.BackgroundTransparency = 0.15
logFrame.BorderSizePixel  = 0

local logText = Instance.new("TextLabel", logFrame)
logText.Size                   = UDim2.new(1, -10, 1, -10)
logText.Position               = UDim2.new(0, 5, 0, 5)
logText.BackgroundTransparency = 1
logText.TextXAlignment         = Enum.TextXAlignment.Left
logText.TextYAlignment         = Enum.TextYAlignment.Top
logText.Font                   = Enum.Font.Code
logText.TextSize               = 13
logText.TextColor3             = Color3.fromRGB(251, 146, 60)
logText.TextWrapped            = true

local logs = ""
local function log(msg)
    print("[DDS] " .. msg)
    logs = logs .. msg .. "\n"
    local lines = {}
    for l in logs:gmatch("[^\n]+") do table.insert(lines, l) end
    if #lines > 15 then
        local trimmed = {}
        for i = #lines - 14, #lines do trimmed[#trimmed + 1] = lines[i] end
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
--  HTTP HELPER
-- ═══════════════════════════════════
local function req(opt)
    local r = (syn and syn.request) or (http and http.request) or request
    if not r then log("[ERROR] HTTP NOT SUPPORTED"); return end
    local ok, res = pcall(function() return r(opt) end)
    if ok and res then return res end
    log("[HTTP ERROR] " .. opt.Url)
end

-- ═══════════════════════════════════
--  API FUNCTIONS
-- ═══════════════════════════════════
local function getPS(username)
    log("Fetch job: " .. username)
    local res = req({
        Url     = API_URL .. "/api/private-server?username=" .. HttpService:UrlEncode(username),
        Method  = "GET",
        Headers = { ["x-api-key"] = API_KEY },
    })
    if res and res.StatusCode == 200 then
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok then log("Job OK → game=" .. tostring(data.game)); return data end
    end
    log("Fetch FAIL (status=" .. tostring(res and res.StatusCode) .. ")")
end

local function sheetsRequest(url)
    pcall(function()
        local r = (syn and syn.request) or (http and http.request) or request
        if r then r({ Url = url, Method = "GET" }) end
    end)
end

local function sendInit(points)
    sheetsRequest(SHEETS_URL .. "?username=" .. player.Name .. "&points=" .. tostring(points) .. "&action=init")
end

local function sendUpdate(points)
    sheetsRequest(SHEETS_URL .. "?username=" .. player.Name .. "&points=" .. tostring(points) .. "&action=update")
end

local function apiUpdate(rawPoints)
    pcall(function()
        local r = (syn and syn.request) or (http and http.request) or request
        if r then
            r({
                Url     = API_URL .. "/api/update",
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = API_KEY },
                Body    = HttpService:JSONEncode({
                    username         = player.Name,
                    current_progress = rawPoints,
                    current_amount   = rawPoints,
                    user_id          = player.UserId,
                }),
            })
        end
    end)
end

local _lastSend  = -math.huge
local _lastValue = nil
local function safeApiUpdate(value)
    local now = os.clock()
    if now - _lastSend < 60 then return end
    if value == _lastValue then return end
    _lastSend  = now
    _lastValue = value
    apiUpdate(value)
end

-- ═══════════════════════════════════
--  ANTI-AFK
-- ═══════════════════════════════════
player.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

-- ═══════════════════════════════════
--  MAIN
-- ═══════════════════════════════════
log("Starting — " .. player.Name .. " | Place: " .. tostring(game.PlaceId) .. (IS_LOBBY and " [LOBBY]" or " [RACE MAP]"))

task.spawn(function()
    local ok, err = pcall(function()
        -- Wait character ready
        local char = player.Character or player.CharacterAdded:Wait()
        local w = 0
        while not char:FindFirstChild("HumanoidRootPart") and w < 10 do
            task.wait(0.5); w = w + 0.5
        end
        task.wait(3)

        -- Confirm job is DDS from API
        local data = getPS(player.Name)
        if not data then
            task.wait(10)
            data = getPS(player.Name)
        end
        if not data then
            log("No data from API, abort")
            return
        end

        local gameTag   = (data.game or "CDID"):upper()
        local inDDSGame = (game.GameId == 7089588429)
        if gameTag ~= "DDS" then
            if inDDSGame then
                showWrongGamePopup("CDID (Car Driving Indonesia)")
                log("API game=" .. gameTag .. " tapi GameId=DDS, lanjut...")
            else
                log("Job bukan DDS (game=" .. gameTag .. "), stop.")
                return
            end
        end

        log("Job confirmed DDS, starting...")

        -- Track RPValue
        task.spawn(function()
            local pd    = player:WaitForChild("PlayerData", 15)
            if not pd then log("PlayerData not found"); return end
            local rpVal = pd:WaitForChild("RPValue", 10)
            if not rpVal then log("RPValue not found"); return end

            task.wait(3)
            local initRP = rpVal.Value or 0
            log("RP awal: " .. tostring(initRP))
            sendInit(tostring(initRP))
            apiUpdate(initRP)

            while true do
                task.wait(60)
                local curRP = rpVal.Value or 0
                log("RP update: " .. tostring(curRP))
                sendUpdate(tostring(curRP))
                safeApiUpdate(curRP)
            end
        end)

        -- Execute DDS gameplay loader (key/script are Luvio executor globals)
        local qtOK = queueOnTeleport(AUTOEXEC)
        log("QoT registered: " .. tostring(qtOK))
        getgenv().key    = "234246b8-cb63-4ba6-b29c-17eaf5f38247"
        getgenv().script = "DDS"
        pcall(function()
            loadstring(game:HttpGet("https://cdn.luviohub.xyz/"))()
        end)
    end)
    getgenv()._samlongDDSRunning = false
    if not ok then
        log("Fatal error: " .. tostring(err))
    end
end)
