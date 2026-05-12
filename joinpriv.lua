-- ═══════════════════════════════════════════════════════════
--  SAMLONG REJOIN v3 — Smart detect lobby/PS
--
--  Di LOBBY  → fetch server code → join private server → queue brain.lua
--  Di PS     → tombol REJOIN → firesignal ReturnMenu → balik ke lobby
--             → joinpriv.lua jalan lagi via queue_on_teleport → join PS
-- ═══════════════════════════════════════════════════════════

repeat task.wait() until game:IsLoaded()
task.wait(2)

local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local HttpSvc   = game:GetService("HttpService")
local CoreGui   = game:GetService("CoreGui")
local player    = Players.LocalPlayer

local API_URL = "https://samlongweb-production.up.railway.app"
local API_KEY = "slg_prod_nJjQZJQ4kR98l9zTfTJ56CBgeDrzxaws0eFk7rYJg2SAhvu7WRloXti3KkiXRnYN"

-- ═══════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════
local function httpReq(opt)
    local r = (syn and syn.request) or (http and http.request) or request
    if not r then return end
    local ok, res = pcall(function() return r(opt) end)
    if ok and res then return res end
end

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

local function getServerCode(username)
    local res = httpReq({
        Url     = API_URL .. "/api/private-server?username=" .. HttpSvc:UrlEncode(username),
        Method  = "GET",
        Headers = { ["x-api-key"] = API_KEY },
    })
    if res and res.StatusCode == 200 then
        local ok, data = pcall(function() return HttpSvc:JSONDecode(res.Body) end)
        if ok and data then return data end
    end
end

local function resolveRegion(data)
    if not data then return "JawaTimur" end
    local jenis = (data.jenis or ""):lower()
    if jenis == "event" then return "Seasonal"
    elseif jenis == "minigame" then return "Jakarta"
    else return "JawaTimur" end
end

-- ═══════════════════════════════════
--  DETECT: Lobby atau Private Server?
-- ═══════════════════════════════════
local pg = player:WaitForChild("PlayerGui", 10)
local hubGui = pg and pg:FindFirstChild("Hub")
if not hubGui then
    hubGui = pg and pg:WaitForChild("Hub", 15)
end

local isLobby = (hubGui ~= nil)
print("[REJOIN] State: " .. (isLobby and "LOBBY" or "PRIVATE SERVER"))

-- ═══════════════════════════════════
--  MODE: LOBBY → Join Private Server
-- ═══════════════════════════════════
if isLobby then
    print("[REJOIN] Lobby detected → joining private server...")
    task.wait(3)

    local username = player.Name
    local data = getServerCode(username)
    local serverCode = data and data.server_code ~= "" and data.server_code or nil

    -- Coba baca dari UI game kalau API belum ada
    if not serverCode and hubGui then
        local label = hubGui:FindFirstChild("Container")
        if label then label = label:FindFirstChild("Window") end
        if label then label = label:FindFirstChild("PrivateServer") end
        if label then label = label:FindFirstChild("ServerLabel") end
        if label then
            local w = 0
            repeat task.wait(0.5); w += 0.5
            until (label.Text ~= "" and label.Text ~= "None") or w >= 15
            if label.Text ~= "" and label.Text ~= "None" then
                serverCode = label.Text
                print("[REJOIN] Code dari UI: " .. serverCode)
            end
        end
    end

    -- Retry kalau belum ada
    if not serverCode then
        for i = 1, 6 do
            print("[REJOIN] Belum ada code, retry " .. i .. "/6 (10s)...")
            task.wait(10)
            local fresh = getServerCode(username)
            if fresh and fresh.server_code and fresh.server_code ~= "" then
                data = fresh
                serverCode = fresh.server_code
                break
            end
        end
    end

    if not serverCode then
        print("[REJOIN] ❌ Tidak ada server code.")
        return
    end

    print("[REJOIN] ✅ Code: " .. serverCode)

    -- Queue brain.lua untuk jalan setelah masuk PS
    queueOnTeleport([[
repeat task.wait() until game:IsLoaded()
task.wait(7)
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/brain.lua"))()
end)
]])
    print("[REJOIN] ✅ brain.lua queued")

    -- Join PS via remote
    local remote = RS:WaitForChild("NetworkContainer", 10)
    remote = remote and remote:WaitForChild("RemoteEvents", 5)
    remote = remote and remote:WaitForChild("PrivateServer", 5)

    if not remote then
        print("[REJOIN] ❌ Remote PrivateServer tidak ditemukan")
        return
    end

    local region = resolveRegion(data)
    task.wait(3)
    print("[REJOIN] 🚀 JOINING → " .. serverCode .. " | " .. region)
    remote:FireServer("Join", serverCode, region)
    print("[REJOIN] ✅ Join command sent!")
    return
end

-- ═══════════════════════════════════
--  MODE: PRIVATE SERVER → Rejoin Button
-- ═══════════════════════════════════

local function doRejoin()
    print("[REJOIN] 🔄 Return to lobby...")

    -- Queue joinpriv.lua untuk jalan di lobby nanti
    queueOnTeleport([[
repeat task.wait() until game:IsLoaded()
task.wait(5)
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/joinpriv.lua"))()
end)
]])
    print("[REJOIN] ✅ joinpriv.lua queued for lobby")

    task.wait(0.5)

    -- Fire ReturnMenu button → balik ke lobby
    pcall(function()
        local btn = player.PlayerGui
            .Settings.Canvas.Main.CanvasGroup.ScrollingFrame.ReturnMenu
        firesignal(btn.Activated)
    end)

    print("[REJOIN] ✅ ReturnMenu fired!")
end

-- Global function: getgenv().rejoin()
getgenv().rejoin = function()
    task.spawn(doRejoin)
end

-- GUI Button
pcall(function()
    local old = CoreGui:FindFirstChild("SamlongRejoin")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui", CoreGui)
gui.Name         = "SamlongRejoin"
gui.ResetOnSpawn = false

local frame = Instance.new("Frame", gui)
frame.Size                   = UDim2.new(0, 160, 0, 44)
frame.Position               = UDim2.new(1, -180, 0, 20)
frame.BackgroundColor3       = Color3.fromRGB(15, 15, 25)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel        = 0
frame.Active                 = true
frame.Draggable              = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", frame)
stroke.Color        = Color3.fromRGB(80, 160, 255)
stroke.Thickness    = 1.5
stroke.Transparency = 0.4

local btn = Instance.new("TextButton", frame)
btn.Size                   = UDim2.new(1, -8, 1, -8)
btn.Position               = UDim2.new(0, 4, 0, 4)
btn.BackgroundColor3       = Color3.fromRGB(40, 110, 255)
btn.BackgroundTransparency = 0.15
btn.BorderSizePixel        = 0
btn.Text                   = "🔄 REJOIN"
btn.Font                   = Enum.Font.GothamBold
btn.TextSize               = 16
btn.TextColor3             = Color3.new(1, 1, 1)
btn.AutoButtonColor        = true
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local cooldown = false
btn.MouseButton1Click:Connect(function()
    if cooldown then return end
    cooldown = true
    btn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    for i = 3, 1, -1 do
        btn.Text = "⏳ " .. i .. "..."
        task.wait(1)
    end
    btn.Text = "🚀 BYE!"
    doRejoin()
end)

print("[REJOIN] ✅ Button ready | getgenv().rejoin()")
