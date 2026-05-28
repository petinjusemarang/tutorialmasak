-- GETPOINT.LUA — test baca poin event, tampil di GUI
-- Jalankan ini pas udah di server event

local player = game:GetService("Players").LocalPlayer
local pg = player:WaitForChild("PlayerGui", 15)

-- ── buat GUI sederhana ──────────────────────────────────────────
local screen = Instance.new("ScreenGui")
screen.Name = "GetPointTest"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = pg

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 180)
frame.Position = UDim2.new(0.5, -160, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
frame.BorderSizePixel = 0
frame.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "GETPOINT TEST"
title.TextColor3 = Color3.fromRGB(100, 200, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

local lblRaw = Instance.new("TextLabel")
lblRaw.Size = UDim2.new(1, -20, 0, 35)
lblRaw.Position = UDim2.new(0, 10, 0, 35)
lblRaw.BackgroundTransparency = 1
lblRaw.Text = "Raw: -"
lblRaw.TextColor3 = Color3.fromRGB(255, 255, 255)
lblRaw.TextScaled = true
lblRaw.Font = Enum.Font.Gotham
lblRaw.TextXAlignment = Enum.TextXAlignment.Left
lblRaw.Parent = frame

local lblParsed = Instance.new("TextLabel")
lblParsed.Size = UDim2.new(1, -20, 0, 35)
lblParsed.Position = UDim2.new(0, 10, 0, 75)
lblParsed.BackgroundTransparency = 1
lblParsed.Text = "Parsed: -"
lblParsed.TextColor3 = Color3.fromRGB(100, 255, 150)
lblParsed.TextScaled = true
lblParsed.Font = Enum.Font.GothamBold
lblParsed.TextXAlignment = Enum.TextXAlignment.Left
lblParsed.Parent = frame

local lblStatus = Instance.new("TextLabel")
lblStatus.Size = UDim2.new(1, -20, 0, 30)
lblStatus.Position = UDim2.new(0, 10, 0, 115)
lblStatus.BackgroundTransparency = 1
lblStatus.Text = "Status: waiting..."
lblStatus.TextColor3 = Color3.fromRGB(200, 200, 100)
lblStatus.TextScaled = true
lblStatus.Font = Enum.Font.Gotham
lblStatus.TextXAlignment = Enum.TextXAlignment.Left
lblStatus.Parent = frame

local lblLog = Instance.new("TextLabel")
lblLog.Size = UDim2.new(1, -20, 0, 25)
lblLog.Position = UDim2.new(0, 10, 0, 148)
lblLog.BackgroundTransparency = 1
lblLog.Text = ""
lblLog.TextColor3 = Color3.fromRGB(180, 180, 180)
lblLog.TextScaled = true
lblLog.Font = Enum.Font.Gotham
lblLog.TextXAlignment = Enum.TextXAlignment.Left
lblLog.Parent = frame

local function setStatus(txt, color)
    lblStatus.Text = "Status: " .. txt
    lblStatus.TextColor3 = color or Color3.fromRGB(200, 200, 100)
end

local function setLog(txt)
    lblLog.Text = txt
    print("[GETPOINT] " .. txt)
end

-- ── cari label ──────────────────────────────────────────────────
local function parsePoints(txt)
    return tonumber((txt or ""):gsub("[^%d]", "")) or 0
end

setStatus("Cari EVENT SHOP...")
local eventShop = pg:FindFirstChild("EVENT SHOP")
if not eventShop then
    setStatus("Nunggu EVENT SHOP...", Color3.fromRGB(255, 200, 50))
    eventShop = pg:WaitForChild("EVENT SHOP", 30)
end

if not eventShop then
    setStatus("EVENT SHOP GA KETEMU!", Color3.fromRGB(255, 80, 80))
    setLog("Cek nama GUI di Explorer")
    return
end

setLog("EVENT SHOP ketemu")

local ok, valLabel = pcall(function()
    return eventShop
        :WaitForChild("Shop", 10)
        :WaitForChild("TitleBar", 10)
        :WaitForChild("PointsPill", 10)
        :WaitForChild("Value", 10)
end)

if not ok or not valLabel then
    setStatus("PATH SALAH!", Color3.fromRGB(255, 80, 80))
    setLog(tostring(valLabel))
    return
end

setLog("Label ketemu: " .. valLabel.ClassName)
setStatus("Connected!", Color3.fromRGB(100, 255, 150))

-- ── tampil nilai langsung ────────────────────────────────────────
local function refresh()
    local raw = valLabel.Text
    local parsed = parsePoints(raw)
    lblRaw.Text = 'Raw: "' .. tostring(raw) .. '"'
    lblParsed.Text = "Parsed: " .. tostring(parsed)
    print("[GETPOINT] raw=" .. tostring(raw) .. " parsed=" .. tostring(parsed))
end

refresh()

-- listener
valLabel:GetPropertyChangedSignal("Text"):Connect(function()
    refresh()
    setLog("Text changed! t=" .. tostring(tick()))
end)

-- poll tiap 2 detik buat lihat perubahan
task.spawn(function()
    local t = 0
    while true do
        task.wait(2)
        t = t + 2
        lblStatus.Text = "Running +" .. t .. "s"
        refresh()
    end
end)

print("[GETPOINT] Script ready, monitoring...")
