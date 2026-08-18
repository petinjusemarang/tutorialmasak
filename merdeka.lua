local Players           = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")
local RunService         = game:GetService("RunService")

local Player = Players.LocalPlayer

--==================================================
-- ANTI DOUBLE RUN
-- Mencegah GUI/koneksi dobel kalau script kepencet run 2x.
--==================================================

if getgenv()._merdekaRunning then
    print("[MERDEKA] Already loaded, exit.")
    return
end
getgenv()._merdekaRunning = true

--==================================================
-- RUN STATE (dikontrol lewat GUI START/STOP)
-- Stopped dicek di tiap pergantian step DAN di dalam loop yang lama
-- (drive, homing, nunggu race mulai, nunggu bendera) supaya STOP bisa
-- motong di tengah-tengah step, bukan cuma nunggu step itu selesai dulu.
--==================================================

local RunState = {
    Stopped = true,
    Running = false,
}

local function isStopRequested()
    return RunState.Stopped
end

local StatusLabel

local function setStatus(text)
    print("[MERDEKA][STATUS] " .. text)
    if StatusLabel then
        StatusLabel.Text = text
    end
end

local runSequence -- diisi paling bawah, setelah semua step function ada


--==================================================
-- STEP 1: TELEPORT KE NPC START
--==================================================

local function step1_TeleportToNpc()
    setStatus("STEP 1: Teleport ke NPC")

    local NPC = Workspace.Event.Merdeka.LobbyNPC
    local RootPart = NPC:WaitForChild("HumanoidRootPart")

    Player.Character:WaitForChild("HumanoidRootPart")
    Player.Character:PivotTo(
        RootPart.CFrame * CFrame.new(0, 0, 3)
    )

    task.wait(0.5)
end


--==================================================
-- STEP 2: INTERAKSI NPC
--==================================================

local function step2_InteractNpc()
    setStatus("STEP 2: Interaksi NPC")

    local Prompt = Workspace.Event.Merdeka.LobbyNPC.HumanoidRootPart:WaitForChild("ProximityPrompt")
    fireproximityprompt(Prompt)

    task.wait(1)
end


--==================================================
-- STEP 3: CREATE LOBBY
--==================================================

local function step3_CreateLobby()
    setStatus("STEP 3: Create Lobby")

    local CreateLobby = ReplicatedStorage
        :WaitForChild("RaceRemotes")
        :WaitForChild("CreateLobby")

    CreateLobby:FireServer("Tim ProfessionalUnemploy", "merdeka")

    task.wait(1)
end


--==================================================
-- STEP 4-5: RANDOM PICK CAR + SELECT CAR
--==================================================

local function step4_SelectRandomCar()
    setStatus("STEP 4-5: Pilih & select mobil random")

    local ScrollingFrame = Player.PlayerGui
        .Main
        .Container
        .Spawner
        .ScrollingFrame

    local cars = {}

    for _, car in ipairs(ScrollingFrame:GetChildren()) do
        -- Hanya ambil Frame mobil (otomatis skip UIGridLayout/UIPadding dst)
        if car:IsA("Frame") then
            local carId = car.Name
            local carName = carId

            local textLabel = car:FindFirstChildWhichIsA("TextLabel", true)
            if textLabel and textLabel.Text ~= "" then
                carName = textLabel.Text
            end

            table.insert(cars, { Id = carId, Name = carName })
        end
    end

    if #cars == 0 then
        warn("[MERDEKA] Tidak ada mobil ditemukan!")
        return false
    end

    math.randomseed(os.time())
    local selected = cars[math.random(1, #cars)]

    print("========== RANDOM CAR ==========")
    print("Jumlah mobil :", #cars)
    print("Car ID       :", selected.Id)
    print("Car Name     :", selected.Name)
    print("================================")

    local SelectCar = ReplicatedStorage
        :WaitForChild("RaceRemotes")
        :WaitForChild("SelectCar")

    SelectCar:FireServer(selected.Id, selected.Name)

    print("[MERDEKA] Selected:", selected.Id, selected.Name)

    task.wait(1)
    return true
end


--==================================================
-- STEP 6: TOGGLE READY
--==================================================

local function step6_ToggleReady()
    setStatus("STEP 6: Toggle Ready")

    local ToggleReady = ReplicatedStorage
        :WaitForChild("RaceRemotes")
        :WaitForChild("ToggleReady")

    ToggleReady:FireServer()
    print("[MERDEKA] Ready toggled")

    task.wait(1)
end


--==================================================
-- STEP 7: START RACE
--==================================================

local function step7_StartRace()
    setStatus("STEP 7: Start Race")

    local StartRace = ReplicatedStorage
        :WaitForChild("RaceRemotes")
        :WaitForChild("StartRace")

    StartRace:FireServer()
    print("[MERDEKA] StartRace fired")
end


--==================================================
-- STEP 8: TUNGGU SAMPAI DUDUK DI MOBIL
-- Tandanya: PlayerGui["A-Chassis Interface"] muncul
--==================================================

local function step8_WaitInVehicle()
    setStatus("STEP 8: Tunggu masuk mobil")

    local chassisInterface = Player.PlayerGui:WaitForChild("A-Chassis Interface", 60)

    if chassisInterface then
        print("[MERDEKA] Sudah di dalam mobil (A-Chassis Interface terdeteksi)")
        return true
    end

    warn("[MERDEKA] Timeout menunggu A-Chassis Interface")
    return false
end


--==================================================
-- STEP 9: TUNGGU RACE MULAI
-- Tandanya: TimerLabel.Text berubah (angka countdown berkurang)
--==================================================

local function step9_WaitRaceStart(timeout)
    setStatus("STEP 9: Tunggu race mulai")
    timeout = timeout or 120

    local merdekaGui = Player.PlayerGui:WaitForChild("MerdekaEvent", 15)
    local timerLabel = merdekaGui.Container.Progress.TimerRow.TimerLabel

    local baseline = timerLabel.Text
    local elapsed = 0

    while elapsed < timeout do
        if isStopRequested() then
            warn("[MERDEKA] STOP ditekan, batal tunggu race mulai")
            return false
        end

        task.wait(1)
        elapsed = elapsed + 1

        local ok, currentText = pcall(function() return timerLabel.Text end)
        if ok and currentText ~= baseline then
            print("[MERDEKA] Race sudah mulai, timer berubah:", baseline, "->", currentText)
            return true
        end
    end

    warn("[MERDEKA] Timeout menunggu race mulai")
    return false
end


--==================================================
-- STEP 10-11: DRIVE KE TITIK BENDERA (data spot presisi)
-- Nomor bendera dibaca dari DestinationLabel ("Titik Bendera N"), lalu
-- langsung dicocokkan ke tabel FLAG_SPOTS hasil data collection manual.
-- Jauh lebih presisi & cepat daripada homing pakai feedback stud.
--==================================================

local function getVehicle()
    local character = Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seatPart = humanoid and humanoid.SeatPart
    return seatPart and seatPart:FindFirstAncestorOfClass("Model")
end

local function readDestinationLabel()
    local ok, label = pcall(function()
        return Player.PlayerGui.MerdekaEvent.Container.Progress.DestinationRow.DestinationLabel
    end)
    if not ok or not label then
        return nil
    end

    local text = label.Text or ""
    return {
        Raw        = text,
        FlagNumber = tonumber(text:match("[Bb]endera%s*(%d+)")),
    }
end

local FLAG_SPOTS = {
    [1] = CFrame.new(7012.628906, -0.680334, -2591.969238),
    [2] = CFrame.new(-2268.640381, -25.941872, 1519.879395),
    [3] = CFrame.new(1984.369751, -29.652336, -2880.953613),
    [4] = CFrame.new(10740.369141, -14.802860, 3876.270508),
    [5] = CFrame.new(4068.312500, -25.514038, -1497.882935),
    [6] = CFrame.new(2482.523193, 12.362131, 2324.760742),
    [7] = CFrame.new(1698.429932, -13.407356, 103.762543),
    [8] = CFrame.new(1325.503540, -23.932224, -2644.533447),
}

-- Menggeser vehicle sedikit demi sedikit ke targetPosition (bukan teleport
-- instan), sama seperti CheckpointManager.driveTo di racenostalgia.lua.
local DRIVE_SPEED       = 600 -- studs/sec
local ARRIVE_DISTANCE   = 12  -- dianggap "sampai" kalau sudah sedekat ini (studs)
local DRIVE_LEG_TIMEOUT = 30  -- detik default per perjalanan sebelum menyerah
local LONG_DRIVE_TIMEOUT = 180 -- dipakai buat perjalanan jauh (ke flag spot / balik)

local function driveVehicleTo(targetPosition, label, timeout)
    label   = label or "target"
    timeout = timeout or DRIVE_LEG_TIMEOUT
    local elapsed = 0

    while elapsed < timeout do
        if isStopRequested() then
            warn("[MERDEKA] STOP ditekan, batal drive ke " .. label)
            return false
        end

        local vehicle = getVehicle()
        if not vehicle then
            warn("[MERDEKA] Tidak duduk di vehicle, batal drive ke " .. label)
            return false
        end

        local currentPos = vehicle:GetPivot().Position
        local offset      = targetPosition - currentPos
        local distance     = offset.Magnitude

        if distance <= ARRIVE_DISTANCE then
            print("[MERDEKA] Sampai di " .. label)
            return true
        end

        local dt = RunService.Heartbeat:Wait()
        elapsed = elapsed + dt

        local direction = offset.Unit
        local step       = math.min(DRIVE_SPEED * dt, distance)
        local newPos     = currentPos + direction * step

        vehicle:PivotTo(CFrame.lookAt(newPos, newPos + direction))
    end

    warn("[MERDEKA] Timeout drive ke " .. label)
    return false
end

local function step10_DriveToFlagSpot()
    setStatus("STEP 10-11: Drive ke titik bendera")

    local info = readDestinationLabel()
    if not info or not info.FlagNumber then
        warn("[MERDEKA] Tidak bisa baca nomor bendera dari DestinationLabel: " .. tostring(info and info.Raw))
        return false
    end

    local targetCFrame = FLAG_SPOTS[info.FlagNumber]
    if not targetCFrame then
        warn("[MERDEKA] Tidak ada data spot untuk Titik Bendera " .. info.FlagNumber)
        return false
    end

    print("[MERDEKA] Target: Titik Bendera " .. info.FlagNumber)
    return driveVehicleTo(targetCFrame.Position, "flag spot " .. info.FlagNumber, LONG_DRIVE_TIMEOUT)
end


--==================================================
-- STEP 12: TUNGGU BENDERA TERAMBIL
-- Tandanya: DestinationLabel.Text berubah (mis. jadi "BAWA PULANG!")
-- Dicek via perubahan teks (bukan match string exact) supaya tetap
-- jalan walau bahasa/teksnya beda-beda.
--==================================================

local function step12_WaitFlagCaptured(timeout)
    setStatus("STEP 12: Tunggu bendera terambil")
    timeout = timeout or 30

    local destinationLabel = Player.PlayerGui.MerdekaEvent.Container.Progress.DestinationRow.DestinationLabel
    local baseline = destinationLabel.Text
    local elapsed = 0

    while elapsed < timeout do
        if isStopRequested() then
            warn("[MERDEKA] STOP ditekan, batal tunggu bendera")
            return false
        end

        task.wait(0.5)
        elapsed = elapsed + 0.5

        local ok, currentText = pcall(function() return destinationLabel.Text end)
        if ok and currentText ~= baseline then
            print("[MERDEKA] Bendera didapat! DestinationLabel berubah:", baseline, "->", currentText)
            return true
        end
    end

    warn("[MERDEKA] Timeout menunggu bendera terambil")
    return false
end


--==================================================
-- STEP 13: DRIVE KEMBALI BAWA BENDERA (titik balik fix)
--==================================================

-- Workspace.Event.Merdeka.BaseZone ternyata gak reliable (kadang gak
-- ketemu di server), jadi balik pakai koordinat tetap.
local RETURN_FLAG_CFRAME   = CFrame.new(1956.355713, -20.677620, -4444.123047)
local RETURN_FLAG_Y_OFFSET = 8 -- studs, biar mobil ga nyangkut/tenggelam di titik balik
local FLAG_DROP_TIMEOUT    = 15 -- detik nunggu CarryFlag_<Player> hilang setelah sampai

-- Instance Workspace.Vehicles.<Player>sCar.CarryFlag_<Player> cuma ada
-- selama bendera masih nempel di mobil. Begitu server beneran ngedrop
-- benderanya, instance ini hilang. Pakai ini sebagai tanda drop yang pasti,
-- bukan cuma ngasumsi "udah sampai titik = udah ke-drop" (itu yang bikin
-- kadang keburu exit car & teleport ke NPC padahal benderanya belum jatuh).
local function isCarryingFlag()
    local ok, result = pcall(function()
        local carFolder = Workspace.Vehicles:FindFirstChild(Player.Name .. "sCar")
        return carFolder ~= nil and carFolder:FindFirstChild("CarryFlag_" .. Player.Name) ~= nil
    end)
    return ok and result
end

local function waitFlagDropped(timeout)
    timeout = timeout or FLAG_DROP_TIMEOUT
    local elapsed = 0

    while elapsed < timeout do
        if isStopRequested() then
            warn("[MERDEKA] STOP ditekan, batal tunggu bendera ke-drop")
            return false
        end

        if not isCarryingFlag() then
            print("[MERDEKA] Bendera sudah ke-drop (CarryFlag hilang)")
            return true
        end

        task.wait(0.5)
        elapsed = elapsed + 0.5
    end

    warn("[MERDEKA] Timeout menunggu bendera ke-drop, CarryFlag masih ada")
    return false
end

local function step13_DriveBackToStartPoint()
    setStatus("STEP 13: Drive kembali bawa bendera")
    local targetPos = RETURN_FLAG_CFRAME.Position + Vector3.new(0, RETURN_FLAG_Y_OFFSET, 0)

    if not driveVehicleTo(targetPos, "titik balik bendera", LONG_DRIVE_TIMEOUT) then
        return false
    end

    setStatus("STEP 13: Tunggu bendera ke-drop")
    return waitFlagDropped()
end


--==================================================
-- STEP 14: EXIT MOBIL
-- racenostalgia.lua sendiri gak punya function exit car (dia gak pernah
-- keluar kursi manual, cuma ngandelin RaceAgainTeleport buat reset player).
-- Di sini keluar manual pakai Humanoid.Sit = false setelah bendera berhasil
-- dikembalikan ke base.
--==================================================

local function step14_ExitVehicle()
    setStatus("STEP 14: Keluar dari mobil")

    local character = Player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        warn("[MERDEKA] Humanoid tidak ditemukan, tidak bisa exit car")
        return false
    end

    humanoid.Sit = false
    print("[MERDEKA] Keluar dari mobil")

    return true
end


--==================================================
-- POIN (MerdekaShopData)
-- Dibaca ulang tiap lap lewat RemoteFunction InvokeServer, ditampilkan di
-- GUI. Nilai balikannya bisa berupa angka langsung atau tabel berisi field
-- poin (nama field belum pasti, jadi dicoba beberapa kemungkinan umum).
--==================================================

local PointsLabel

local function fetchMerdekaPoints()
    local ok, result = pcall(function()
        return ReplicatedStorage
            :WaitForChild("NetworkContainer")
            :WaitForChild("RemoteFunctions")
            :WaitForChild("MerdekaShopData")
            :InvokeServer()
    end)

    if not ok then
        warn("[MERDEKA] Gagal ambil MerdekaShopData: " .. tostring(result))
        return nil
    end

    if type(result) == "number" then
        return result
    end

    if type(result) == "table" then
        return result.Points or result.Point or result.points or result.point
            or result.Total or result.total
    end

    return tonumber(result)
end

local function refreshPoints()
    local points = fetchMerdekaPoints()
    if points and PointsLabel then
        PointsLabel.Text = tostring(points) .. " PTS"
        print("[MERDEKA] Poin: " .. tostring(points))
    end
end


--==================================================
-- SEQUENCE RUNNER
-- Dipanggil oleh tombol START. Berhenti begitu isStopRequested() true
-- (dicek sebelum tiap step) atau begitu ada step yang eksplisit
-- return false (kegagalan asli, bukan STOP).
--==================================================

runSequence = function()
    RunState.Running = true

    local steps = {
        step1_TeleportToNpc,
        step2_InteractNpc,
        step3_CreateLobby,
        step4_SelectRandomCar,
        step6_ToggleReady,
        step7_StartRace,
        step8_WaitInVehicle,
        step9_WaitRaceStart,
        step10_DriveToFlagSpot,
        step12_WaitFlagCaptured,
        step13_DriveBackToStartPoint,
        step14_ExitVehicle,
    }

    local lap = 0

    while not isStopRequested() do
        lap = lap + 1
        setStatus("LAP " .. lap .. " mulai")
        refreshPoints()

        for _, stepFn in ipairs(steps) do
            if isStopRequested() then
                setStatus("STOPPED")
                RunState.Running = false
                return
            end

            local ok, result = pcall(stepFn)

            if not ok then
                warn("[MERDEKA] Step error: " .. tostring(result))
                setStatus("ERROR di LAP " .. lap .. ": " .. tostring(result))
                RunState.Running = false
                RunState.Stopped = true
                return
            end

            if result == false then
                if isStopRequested() then
                    setStatus("STOPPED")
                else
                    setStatus("GAGAL di LAP " .. lap .. ", lihat output console")
                end
                RunState.Running = false
                RunState.Stopped = true
                return
            end
        end

        setStatus("LAP " .. lap .. " SELESAI, lanjut lap berikutnya...")
    end

    setStatus("STOPPED")
    RunState.Running = false
end


--==================================================
-- CONTROL GUI (START / STOP)
--==================================================

local function buildControlGui()
    local gui = Instance.new("ScreenGui")
    gui.Name           = "MerdekaControlGui"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder   = 999
    gui.Parent         = Player.PlayerGui

    local box = Instance.new("Frame", gui)
    box.Size             = UDim2.new(0, 230, 0, 140)
    box.Position         = UDim2.new(0, 20, 0, 20)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    box.BorderSizePixel  = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel", box)
    title.Size                   = UDim2.new(0.6, -8, 0, 24)
    title.Position               = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1
    title.Font                   = Enum.Font.GothamBold
    title.TextSize               = 16
    title.TextColor3             = Color3.new(1, 1, 1)
    title.TextXAlignment         = Enum.TextXAlignment.Left
    title.Text                   = "Merdeka"

    PointsLabel = Instance.new("TextLabel", box)
    PointsLabel.Size                   = UDim2.new(0.4, -8, 0, 24)
    PointsLabel.Position               = UDim2.new(0.6, 0, 0, 6)
    PointsLabel.BackgroundTransparency = 1
    PointsLabel.Font                   = Enum.Font.GothamBold
    PointsLabel.TextSize               = 14
    PointsLabel.TextColor3             = Color3.fromRGB(255, 220, 80)
    PointsLabel.TextXAlignment         = Enum.TextXAlignment.Right
    PointsLabel.Text                   = "... PTS"

    StatusLabel = Instance.new("TextLabel", box)
    StatusLabel.Size                   = UDim2.new(1, -16, 0, 32)
    StatusLabel.Position               = UDim2.new(0, 8, 0, 30)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font                   = Enum.Font.Gotham
    StatusLabel.TextSize               = 13
    StatusLabel.TextColor3             = Color3.fromRGB(255, 220, 80)
    StatusLabel.TextXAlignment         = Enum.TextXAlignment.Left
    StatusLabel.TextYAlignment         = Enum.TextYAlignment.Top
    StatusLabel.TextWrapped            = true
    StatusLabel.Text                   = "IDLE"

    local startBtn = Instance.new("TextButton", box)
    startBtn.Size             = UDim2.new(1, -16, 0, 32)
    startBtn.Position         = UDim2.new(0, 8, 0, 66)
    startBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    startBtn.Font             = Enum.Font.GothamBold
    startBtn.TextSize         = 15
    startBtn.TextColor3       = Color3.new(1, 1, 1)
    startBtn.BorderSizePixel  = 0
    startBtn.Text             = "START"
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 8)

    local stopBtn = Instance.new("TextButton", box)
    stopBtn.Size             = UDim2.new(1, -16, 0, 32)
    stopBtn.Position         = UDim2.new(0, 8, 0, 102)
    stopBtn.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
    stopBtn.Font             = Enum.Font.GothamBold
    stopBtn.TextSize         = 15
    stopBtn.TextColor3       = Color3.new(1, 1, 1)
    stopBtn.BorderSizePixel  = 0
    stopBtn.Text             = "STOP"
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 8)

    startBtn.MouseButton1Click:Connect(function()
        if RunState.Running then
            setStatus("Masih jalan, tekan STOP dulu kalau mau restart")
            return
        end

        RunState.Stopped = false
        task.spawn(runSequence)
    end)

    stopBtn.MouseButton1Click:Connect(function()
        RunState.Stopped = true
        setStatus("STOP ditekan, menghentikan...")
    end)

    task.spawn(refreshPoints)
end


--==================================================
-- ENTRY POINT
--==================================================

buildControlGui()
