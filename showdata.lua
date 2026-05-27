-- SAMLONG SHOWDATA — serverlock + tampil GUI + kirim data
-- Versi ringan dari joki uang: TANPA autofarm/Euphoria, cuma show + track + send

if not game:IsLoaded() then game.Loaded:Wait() end

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local player            = Players.LocalPlayer

-- ═══════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════
local SHEETS_URL = "https://script.google.com/macros/s/AKfycbzBFd5ASlqRLk1pS4Kx3cvBujvFsCIr0QKrdtVO9xZv8fBPHp0L1CKKRwnjpQwD7qHrIw/exec"
local API_URL    = "https://samlongweb-production.up.railway.app"
local API_KEY    = "slg_prod_nJjQZJQ4kR98l9zTfTJ56CBgeDrzxaws0eFk7rYJg2SAhvu7WRloXti3KkiXRnYN"

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
--  SERVER LOCK
-- ═══════════════════════════════════
pcall(function()
    ReplicatedStorage
        :WaitForChild("NetworkContainer")
        :WaitForChild("RemoteEvents")
        :WaitForChild("Private Server")
        :FireServer("serverlock", {})
end)

-- ═══════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════
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
    if value == _lastValue and now - _lastSend < 600 then return end
    _lastSend  = now
    _lastValue = value
    apiUpdate(value)
end

local function formatUang(raw)
    local num = tonumber((raw:gsub("[^%d]", ""))) or 0
    if num >= 1000000000000 then
        local v = num / 1000000000000
        local d = math.floor(v * 10) / 10
        return d == math.floor(d) and string.format("%dT", math.floor(d)) or string.format("%.1fT", d):gsub("%.", ",")
    elseif num >= 1000000000 then
        local v = num / 1000000000
        local d = math.floor(v * 10) / 10
        return d == math.floor(d) and string.format("%dM", math.floor(d)) or string.format("%.1fM", d):gsub("%.", ",")
    elseif num >= 1000000 then
        local v = num / 1000000
        local d = math.floor(v * 10) / 10
        return d == math.floor(d) and string.format("%djt", math.floor(d)) or string.format("%.1fjt", d):gsub("%.", ",")
    elseif num >= 1000 then
        local v = num / 1000
        local d = math.floor(v * 10) / 10
        return d == math.floor(d) and string.format("%dK", math.floor(d)) or string.format("%.1fK", d):gsub("%.", ",")
    else
        return tostring(num)
    end
end


-- ═══════════════════════════════════
--  GUI
-- ═══════════════════════════════════
if CoreGui:FindFirstChild("SamlongJokiUI") then CoreGui.SamlongJokiUI:Destroy() end

local jokiGui = Instance.new("ScreenGui")
jokiGui.Name           = "SamlongJokiUI"
jokiGui.ResetOnSpawn   = false
jokiGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
jokiGui.Parent         = CoreGui

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
mainF.BorderSizePixel  = 0
Instance.new("UICorner", mainF).CornerRadius = UDim.new(0, 16)

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
ng.BorderSizePixel  = 0
Instance.new("UICorner", ng).CornerRadius = UDim.new(0, 12)

-- ═══════════════════════════════════
--  LOGIC
-- ═══════════════════════════════════
local lastEarn  = os.time()
local prevMoney = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0

moneyLabel:GetPropertyChangedSignal("Text"):Connect(function()
    local cur = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
    if cur ~= prevMoney then
        prevMoney     = cur
        lastEarn      = os.time()
        uangText.Text = moneyLabel.Text
    end
end)

-- Timer: update "earn terakhir" setiap detik, cek stuck 6 menit
task.spawn(function()
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
        end
    end
end)

-- Kirim data awal, lalu update setiap 60 detik
task.spawn(function()
    task.wait(3)
    local initFmt = formatUang(moneyLabel.Text)
    local initRaw = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
    sendInit(initFmt)
    apiUpdate(initRaw)
    while true do
        task.wait(60)
        local curFmt = formatUang(moneyLabel.Text)
        local curRaw = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
        sendUpdate(curFmt)
        safeApiUpdate(curRaw)
    end
end)

print("[SHOWDATA] Running — " .. player.Name)
