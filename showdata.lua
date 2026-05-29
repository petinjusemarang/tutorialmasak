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
--  HTTP HELPER
-- ═══════════════════════════════════
local function req(opt)
    local r = (syn and syn.request) or (http and http.request) or request
    if not r then print("[SHOWDATA] HTTP not supported"); return end
    local ok, res = pcall(function() return r(opt) end)
    if ok and res then return res end
    print("[SHOWDATA] HTTP error: " .. opt.Url)
end

-- ═══════════════════════════════════
--  GET SLOT
-- ═══════════════════════════════════
local function getPS(username)
    local res = req({
        Url     = API_URL .. "/api/private-server?username=" .. HttpService:UrlEncode(username),
        Method  = "GET",
        Headers = { ["x-api-key"] = API_KEY },
    })
    if res and res.StatusCode == 200 then
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok and data then return data end
    end
    print("[SHOWDATA] getPS fail — status: " .. tostring(res and res.StatusCode))
    return nil
end

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
    local res = req({
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
    if res then
        if res.StatusCode == 200 then
            print("[SHOWDATA] apiUpdate OK — " .. tostring(rawPoints))
        elseif res.StatusCode == 404 then
            print("[SHOWDATA] apiUpdate 404 — tidak ada order aktif untuk " .. player.Name)
        else
            print("[SHOWDATA] apiUpdate " .. res.StatusCode .. " — " .. tostring(res.Body))
        end
    end
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
--  CEK SLOT AKTIF
-- ═══════════════════════════════════
print("[SHOWDATA] Cek slot untuk " .. player.Name .. "...")
local slotData = getPS(player.Name)

if not slotData then
    print("[SHOWDATA] ⚠ Slot tidak ditemukan di tracker!")
else
    print("[SHOWDATA] Slot OK — jenis: " .. tostring(slotData.jenis) .. " | server: " .. tostring(slotData.server_code))
end

-- ═══════════════════════════════════
--  JALANKAN LUVIOHUB DULU
-- ═══════════════════════════════════
print("[SHOWDATA] Menjalankan LuvioHub...")
pcall(function()
    getgenv().key    = "411572f1-0a19-42fc-ab0c-f386ad74bad6"
    getgenv().script = "Lite"
    loadstring(game:HttpGet("https://cdn.luviohub.xyz/"))()
end)

-- ═══════════════════════════════════
--  TOMBOL MUNCULKAN GUI
-- ═══════════════════════════════════
if CoreGui:FindFirstChild("SamlongJokiUI") then CoreGui.SamlongJokiUI:Destroy() end

local rootGui = Instance.new("ScreenGui")
rootGui.Name         = "SamlongJokiUI"
rootGui.ResetOnSpawn = false
rootGui.DisplayOrder = 9998
rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
rootGui.Parent       = CoreGui

-- Tombol kecil
local triggerBtn = Instance.new("TextButton", rootGui)
triggerBtn.Size             = UDim2.new(0, 180, 0, 38)
triggerBtn.Position         = UDim2.new(0, 10, 0.42, 0)
triggerBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
triggerBtn.BorderSizePixel  = 0
triggerBtn.Font             = Enum.Font.GothamBold
triggerBtn.TextSize         = 13
triggerBtn.TextColor3       = Color3.fromRGB(255, 220, 80)
triggerBtn.Text             = "📊 Samlong GUI"
triggerBtn.ZIndex           = 10
Instance.new("UICorner", triggerBtn).CornerRadius = UDim.new(0, 8)
local triggerStroke = Instance.new("UIStroke", triggerBtn)
triggerStroke.Color     = Color3.fromRGB(80, 160, 255)
triggerStroke.Thickness = 1.2

-- ═══════════════════════════════════
--  MAIN GUI (tersembunyi dulu)
-- ═══════════════════════════════════
local shadow = Instance.new("Frame", rootGui)
shadow.Size                   = UDim2.new(1, 0, 1, 0)
shadow.BackgroundColor3       = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.4
shadow.Visible                = false
shadow.ZIndex                 = 20

local mainF = Instance.new("Frame", rootGui)
mainF.Size             = UDim2.new(0, 520, 0, 240)
mainF.Position         = UDim2.new(0.5, 0, 0.5, 0)
mainF.AnchorPoint      = Vector2.new(0.5, 0.5)
mainF.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
mainF.BorderSizePixel  = 0
mainF.Visible          = false
mainF.ZIndex           = 21
Instance.new("UICorner", mainF).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", mainF)
mainStroke.Color     = Color3.fromRGB(80, 160, 255)
mainStroke.Thickness = 1.5

local usernameText = Instance.new("TextLabel", mainF)
usernameText.Size                   = UDim2.new(1, -40, 0, 50)
usernameText.Position               = UDim2.new(0, 20, 0, 12)
usernameText.BackgroundTransparency = 1
usernameText.Font                   = Enum.Font.GothamBlack
usernameText.TextScaled             = true
usernameText.TextColor3             = Color3.fromRGB(255, 220, 80)
usernameText.TextXAlignment         = Enum.TextXAlignment.Center
usernameText.Text                   = player.Name
usernameText.ZIndex                 = 22

local uangText = Instance.new("TextLabel", mainF)
uangText.Size                   = UDim2.new(1, -40, 0, 80)
uangText.Position               = UDim2.new(0, 20, 0, 65)
uangText.BackgroundTransparency = 1
uangText.Font                   = Enum.Font.GothamBlack
uangText.TextScaled             = true
uangText.TextColor3             = Color3.new(1, 1, 1)
uangText.TextXAlignment         = Enum.TextXAlignment.Center
uangText.Text                   = "..."
uangText.ZIndex                 = 22

local earnText = Instance.new("TextLabel", mainF)
earnText.Size                   = UDim2.new(1, -40, 0, 30)
earnText.Position               = UDim2.new(0, 20, 0, 148)
earnText.BackgroundTransparency = 1
earnText.Font                   = Enum.Font.GothamSemibold
earnText.TextScaled             = true
earnText.TextColor3             = Color3.fromRGB(200, 200, 200)
earnText.TextXAlignment         = Enum.TextXAlignment.Center
earnText.Text                   = "Earn terakhir: -"
earnText.ZIndex                 = 22

local slotStatus = Instance.new("TextLabel", mainF)
slotStatus.Size                   = UDim2.new(1, -40, 0, 24)
slotStatus.Position               = UDim2.new(0, 20, 0, 182)
slotStatus.BackgroundTransparency = 1
slotStatus.Font                   = Enum.Font.Gotham
slotStatus.TextScaled             = true
slotStatus.TextXAlignment         = Enum.TextXAlignment.Center
slotStatus.TextColor3             = slotData and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 100, 100)
slotStatus.Text                   = slotData
    and ("✓ " .. tostring(slotData.jenis):upper() .. " | " .. tostring(slotData.server_code))
    or  "⚠ Slot tidak ditemukan di tracker"
slotStatus.ZIndex                 = 22

-- Tombol tutup di GUI
local closeBtn = Instance.new("TextButton", mainF)
closeBtn.Size             = UDim2.new(0, 28, 0, 28)
closeBtn.Position         = UDim2.new(1, -36, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
closeBtn.BorderSizePixel  = 0
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 14
closeBtn.TextColor3       = Color3.new(1, 1, 1)
closeBtn.Text             = "✕"
closeBtn.ZIndex           = 23
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local ng = Instance.new("TextLabel", rootGui)
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
ng.ZIndex           = 25
Instance.new("UICorner", ng).CornerRadius = UDim.new(0, 12)

-- ═══════════════════════════════════
--  TOGGLE LOGIC
-- ═══════════════════════════════════
local guiShown = false
local trackingStarted = false

local function showMainGui()
    guiShown       = true
    shadow.Visible = true
    mainF.Visible  = true
    triggerBtn.Visible = false

    if not trackingStarted then
        trackingStarted = true

        -- Baca moneyLabel
        local moneyLabel = player:FindFirstChild("PlayerGui")
            and player.PlayerGui:FindFirstChild("Main")
            and player.PlayerGui.Main:FindFirstChild("Container")
            and player.PlayerGui.Main.Container:FindFirstChild("Hub")
            and player.PlayerGui.Main.Container.Hub:FindFirstChild("CashFrame")
            and player.PlayerGui.Main.Container.Hub.CashFrame:FindFirstChild("Frame")
            and player.PlayerGui.Main.Container.Hub.CashFrame.Frame:FindFirstChild("TextLabel")

        if moneyLabel then
            uangText.Text = moneyLabel.Text

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

            task.spawn(function()
                while true do
                    task.wait(1)
                    local elapsed = os.time() - lastEarn
                    earnText.Text = string.format(
                        "Earn terakhir: %02d menit %02d detik",
                        math.floor(elapsed / 60), elapsed % 60
                    )
                    if elapsed >= 360 and not ng.Visible then
                        ng.Visible = true
                    end
                end
            end)

            task.spawn(function()
                task.wait(3)
                local initFmt = formatUang(moneyLabel.Text)
                local initRaw = tonumber((moneyLabel.Text:gsub("[^%d]", ""))) or 0
                uangText.Text = moneyLabel.Text
                print("[SHOWDATA] Init — " .. initFmt .. " (" .. initRaw .. ")")
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
        else
            uangText.Text = "⚠ MoneyLabel tidak ditemukan"
            print("[SHOWDATA] MoneyLabel tidak ditemukan")
        end
    end
end

local function hideMainGui()
    guiShown           = false
    shadow.Visible     = false
    mainF.Visible      = false
    triggerBtn.Visible = true
end

triggerBtn.MouseButton1Click:Connect(showMainGui)
closeBtn.MouseButton1Click:Connect(hideMainGui)

print("[SHOWDATA] Running — " .. player.Name)
