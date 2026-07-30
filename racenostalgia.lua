-- RACEBRAIN V1 — Race lobby + ingame automation, looped across laps
-- NPC -> menu -> role -> lobby -> car -> ready -> start -> checkpoints -> finish
-- -> RaceAgainTeleport -> menu -> lobby -> ... (role stays fixed after the first pick)

-- ═══════════════════════════════════
--  ANTI DOUBLE RUN
-- ═══════════════════════════════════
if getgenv()._raceBrainRunning then
    print("[RACE] Already running, exit.")
    return
end
getgenv()._raceBrainRunning = true

-- ═══════════════════════════════════
--  WAIT GAME LOADED
-- ═══════════════════════════════════
if not game:IsLoaded() then game.Loaded:Wait() end

-- ═══════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local player            = Players.LocalPlayer

-- ═══════════════════════════════════
--  CONFIG
--  IsWinner is chosen at runtime via the role-selector GUI (see selectRole()).
--  The value below is only a fallback if the GUI is skipped/closed unexpectedly.
-- ═══════════════════════════════════
local Config = {
    IsWinner       = true, -- true = create lobby & start race, false = join & wait
    LobbyName      = "ProfessionalUnemploy's Lobby",
    LobbyTimeout    = 60,
    RetryDelay      = 1,
    RaceStartTimeout    = 120, -- followers may wait a while for the winner to fill 5 players + countdown
    StartRaceRetryInterval = 5,   -- winner refires StartRace every N seconds until it actually takes
    StartRaceLoopTimeout   = 300, -- give up firing StartRace after this many seconds total
    WinnerDriveSpeed    = 220, -- studs/sec for the winner (kept faster so the winner always finishes first)
    FollowerDriveSpeed  = 190, -- studs/sec for followers
    ArriveDistance      = 12,  -- how close (studs) counts as "reached" a checkpoint
    CheckpointLegTimeout = 30, -- max seconds to spend driving to a single checkpoint before giving up
    ScoreboardTimeout   = 60,  -- max seconds per attempt to wait for the Scoreboard (all racers finished)
    ScoreboardWaitAttempts = 5, -- how many ScoreboardTimeout-long attempts before finally giving up (5x60s = 5min)
    RaceAgainSettleDelay = 3,  -- pause after RaceAgainTeleport for the auto-teleport back to the NPC to land
    RequeueAttempts     = 10,  -- how many times to retry the whole RaceAgainTeleport->LeaveLobby->CloseScoreboard sequence
}

-- ═══════════════════════════════════
--  LOGGER
-- ═══════════════════════════════════
local Logger = {}

function Logger.info(msg)
    print("[Race] " .. tostring(msg))
end

function Logger.warn(msg)
    warn("[Race] " .. tostring(msg))
end

-- ═══════════════════════════════════
--  UTILS
-- ═══════════════════════════════════
local Utils = {}

-- Retries fn() up to `attempts` times (pcall-wrapped). Returns true on first success.
function Utils.retry(fn, attempts, delay, label)
    attempts = attempts or 5
    delay    = delay or Config.RetryDelay
    for i = 1, attempts do
        local ok, err = pcall(fn)
        if ok then
            return true
        end
        Logger.warn(string.format("[Retry] %s failed (%d/%d): %s", label or "action", i, attempts, tostring(err)))
        task.wait(delay)
    end
    return false
end

-- Polls conditionFn() until it returns a truthy value or timeout elapses.
-- conditionFn is pcall-wrapped so a missing GUI path just counts as "not yet".
function Utils.waitUntil(conditionFn, timeout, interval, label)
    interval = interval or 0.5
    local elapsed = 0
    while elapsed < timeout do
        local ok, result = pcall(conditionFn)
        if ok and result then
            return result
        end
        task.wait(interval)
        elapsed = elapsed + interval
    end
    Logger.warn("[Timeout] " .. (label or "condition") .. " not met after " .. timeout .. "s")
    return nil
end

-- ═══════════════════════════════════
--  RACE REMOTE
-- ═══════════════════════════════════
local RaceRemote = {}
local remoteCache = {}

function RaceRemote.init()
    local ok, folder = pcall(function()
        return ReplicatedStorage:WaitForChild("RaceRemotes", 15)
    end)
    if not ok or not folder then
        Logger.warn("RaceRemotes folder not found")
        return false
    end

    local names = { "GetLobbies", "CreateLobby", "SelectCar", "ToggleReady", "StartRace", "JoinLobby", "RaceAgainTeleport", "LeaveLobby" }
    for _, name in ipairs(names) do
        local remOk, remote = pcall(function()
            return folder:WaitForChild(name, 15)
        end)
        if not remOk or not remote then
            Logger.warn("Remote not found: " .. name)
            return false
        end
        remoteCache[name] = remote
    end

    Logger.info("RaceRemotes ready")
    return true
end

function RaceRemote.getLobbies()
    return remoteCache.GetLobbies:InvokeServer()
end

function RaceRemote.createLobby(lobbyName)
    remoteCache.CreateLobby:FireServer(lobbyName)
end

function RaceRemote.selectCar(carId, carName)
    remoteCache.SelectCar:FireServer(carId, carName)
end

function RaceRemote.toggleReady()
    remoteCache.ToggleReady:FireServer()
end

function RaceRemote.startRace()
    remoteCache.StartRace:FireServer()
end

function RaceRemote.joinLobby(lobbyNumber)
    remoteCache.JoinLobby:FireServer(lobbyNumber)
end

function RaceRemote.raceAgainTeleport()
    remoteCache.RaceAgainTeleport:FireServer()
end

function RaceRemote.leaveLobby()
    remoteCache.LeaveLobby:FireServer()
end

-- ═══════════════════════════════════
--  CAR MANAGER
-- ═══════════════════════════════════
local CarManager = {}

-- Reads the car picker (same GUI/pattern used elsewhere in this project) and
-- returns a random CarId + DisplayName pair.
function CarManager.getRandomRaceCar()
    local ok, scrollingFrame = pcall(function()
        return player.PlayerGui.Main.Container.Spawner.ScrollingFrame
    end)
    if not ok or not scrollingFrame then
        return nil
    end

    local cars = {}
    for _, car in ipairs(scrollingFrame:GetChildren()) do
        if car:IsA("Frame") then
            local carId   = car.Name
            local carName = carId

            local label = car:FindFirstChildWhichIsA("TextLabel", true)
            if label then
                carName = label.Text
            end

            table.insert(cars, { Id = carId, Name = carName })
        end
    end

    if #cars == 0 then
        return nil
    end

    math.randomseed(tick())
    local selected = cars[math.random(1, #cars)]
    return selected.Id, selected.Name
end

function CarManager.selectRandomCar()
    local carId, carName = CarManager.getRandomRaceCar()
    if not carId then
        Logger.warn("No car found in Spawner ScrollingFrame")
        return false
    end

    local ok = Utils.retry(function()
        RaceRemote.selectCar(carId, carName)
    end, 5, Config.RetryDelay, "SelectCar")

    if ok then
        Logger.info("Car selected: " .. carId .. " (" .. carName .. ")")
    end
    return ok
end

-- ═══════════════════════════════════
--  PLAYER DETECTOR
-- ═══════════════════════════════════
local PlayerDetector = {}

function PlayerDetector.waitForRaceGui(timeout)
    return Utils.waitUntil(function()
        local pg = player:FindFirstChild("PlayerGui")
        return pg and pg:FindFirstChild("Race") and pg.Race:FindFirstChild("Container")
    end, timeout or 15, 0.5, "Race GUI")
end

-- CountdownLabel's "GO!" text doesn't register for every player, so instead
-- watch RaceHUD.TimerPanel.TimerLabel: its Text only starts ticking once the
-- race has actually begun. Sample it twice a beat apart and fire the moment
-- it changes.
function PlayerDetector.waitForRaceStart(timeout)
    local label = Utils.waitUntil(function()
        return player.PlayerGui.Race.Container.RaceHUD.TimerPanel.TimerLabel
    end, 15, 0.5, "TimerLabel lookup")

    if not label then
        return false
    end

    local elapsed  = 0
    local lastText = label.Text

    while elapsed < timeout do
        task.wait(1)
        elapsed = elapsed + 1

        local ok, currentText = pcall(function() return label.Text end)
        if ok and currentText ~= lastText then
            return true
        end
        if ok then
            lastText = currentText
        end
    end

    Logger.warn("[Timeout] Race timer never started ticking after " .. timeout .. "s")
    return false
end

-- Scoreboard (the "RACE STANDINGS" / "BALAP LAGI" popup) only becomes visible
-- once every racer in the lobby has finished or DNF'd, i.e. the race is truly
-- over for everyone — not just for us. That's the correct RaceAgainTeleport gate.
function PlayerDetector.waitForScoreboard(timeout)
    return Utils.waitUntil(function()
        return player.PlayerGui.Race.Container.Scoreboard.Visible
    end, timeout, 0.5, "Scoreboard visible")
end

-- Non-blocking single check, for polling mid-drive whether the group's race
-- already ended (e.g. enough other racers finished and stragglers got DNF'd).
function PlayerDetector.isScoreboardVisible()
    local ok, visible = pcall(function()
        return player.PlayerGui.Race.Container.Scoreboard.Visible
    end)
    return ok and visible
end

-- ═══════════════════════════════════
--  LOBBY MANAGER
-- ═══════════════════════════════════
local LobbyManager = {}
local lobbyCreated = false

function LobbyManager.createLobby()
    if lobbyCreated then
        Logger.warn("Lobby already created, skip")
        return true
    end

    local ok = Utils.retry(function()
        RaceRemote.createLobby(Config.LobbyName)
    end, 5, Config.RetryDelay, "CreateLobby")

    if ok then
        lobbyCreated = true
        Logger.info("Lobby created: " .. Config.LobbyName)
    end
    return ok
end

-- Scans JoinSection.LobbyList for any child named Lobby_<number> without
-- assuming which number will appear.
function LobbyManager.findLobby(timeout)
    return Utils.waitUntil(function()
        local lobbyList = player.PlayerGui.Race.Container.RaceMenu.JoinSection.LobbyList
        for _, child in ipairs(lobbyList:GetChildren()) do
            local num = child.Name:match("^Lobby_(%d+)$")
            if num then
                return tonumber(num)
            end
        end
        return nil
    end, timeout or Config.LobbyTimeout, 1, "FindLobby")
end

function LobbyManager.joinLobby(lobbyNumber)
    return Utils.retry(function()
        RaceRemote.joinLobby(lobbyNumber)
    end, 5, Config.RetryDelay, "JoinLobby")
end

-- Allows a fresh CreateLobby call on the next lap after RaceAgainTeleport.
function LobbyManager.reset()
    lobbyCreated = false
end

-- ═══════════════════════════════════
--  CHECKPOINT MANAGER
--  Fixed track waypoints (world positions), driven in order, car stays seated.
-- ═══════════════════════════════════
local CheckpointManager = {}

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

-- The vehicle is whatever Model the player's Humanoid is currently seated in.
local function getVehicle()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seatPart = humanoid and humanoid.SeatPart
    return seatPart and seatPart:FindFirstAncestorOfClass("Model")
end

-- Continuously repositions the whole vehicle (PivotTo moves all welded/motored
-- parts together, unlike teleporting just the HumanoidRootPart) in a straight
-- line toward targetPosition, facing travel direction, until within
-- Config.ArriveDistance or the leg times out. Winner drives faster than
-- followers so the lobby creator always finishes first.
function CheckpointManager.driveTo(targetPosition, index, total)
    local speed = Config.IsWinner and Config.WinnerDriveSpeed or Config.FollowerDriveSpeed
    local elapsed = 0
    local sinceScoreboardCheck = 0

    while elapsed < Config.CheckpointLegTimeout do
        local vehicle = getVehicle()
        if not vehicle then
            -- Losing the seat mid-drive usually means the group's race just
            -- ended and this straggler got DNF'd/ejected — which happens
            -- before the Scoreboard shows up. Give it a few seconds to
            -- appear before giving up, otherwise this returns false straight
            -- to STATE.FAILED and nothing is ever left running to close it.
            Logger.warn("Not seated in a vehicle, checking whether the race already ended for the group...")
            if PlayerDetector.waitForScoreboard(10) then
                Logger.info("Confirmed: Scoreboard appeared, race ended for the group. Stopping checkpoints.")
                return true
            end
            Logger.warn("Vehicle still missing and no Scoreboard, cannot drive to checkpoint " .. index)
            return false
        end

        local currentPos = vehicle:GetPivot().Position
        local offset      = targetPosition - currentPos
        local distance     = offset.Magnitude

        if distance <= Config.ArriveDistance then
            Logger.info(string.format("Checkpoint %d/%d reached", index, total))
            return true
        end

        local dt = RunService.Heartbeat:Wait()
        elapsed = elapsed + dt

        -- The race can end for the whole lobby once enough other racers
        -- finish; stragglers get DNF'd and their car effectively freezes.
        -- Bail out immediately instead of fighting a dead car until this
        -- leg's timeout, so RUN_CHECKPOINTS can hand off to WAIT_SCOREBOARD.
        sinceScoreboardCheck = sinceScoreboardCheck + dt
        if sinceScoreboardCheck >= 0.5 then
            sinceScoreboardCheck = 0
            if PlayerDetector.isScoreboardVisible() then
                Logger.info("Scoreboard appeared mid-drive (race already ended for the group), stopping checkpoints")
                return true
            end
        end

        local direction = offset.Unit
        local step       = math.min(speed * dt, distance)
        local newPos     = currentPos + direction * step

        vehicle:PivotTo(CFrame.lookAt(newPos, newPos + direction))
    end

    Logger.warn(string.format("Timeout driving to checkpoint %d/%d", index, total))
    return false
end

function CheckpointManager.runAll()
    local totalLegs = #CHECKPOINT_POSITIONS + 1 -- + Finish

    Logger.info("Driving through " .. totalLegs .. " checkpoints...")
    for i, position in ipairs(CHECKPOINT_POSITIONS) do
        if not CheckpointManager.driveTo(position, i, totalLegs) then
            return false
        end
    end

    if not CheckpointManager.driveTo(FINISH_POSITION, totalLegs, totalLegs) then
        return false
    end

    Logger.info("Last waypoint reached, waiting for server to confirm finish...")
    return true
end

-- ═══════════════════════════════════
--  READY (shared by winner + follower, never spammed)
-- ═══════════════════════════════════
local readyToggled = false

local function toggleReadyOnce()
    if readyToggled then
        return true
    end

    local ok = Utils.retry(function()
        RaceRemote.toggleReady()
    end, 5, Config.RetryDelay, "ToggleReady")

    if ok then
        readyToggled = true
        Logger.info("Ready toggled")
    end
    return ok
end

-- Allows Ready to be toggled again on the next lap after RaceAgainTeleport.
local function resetReadyState()
    readyToggled = false
end

-- ═══════════════════════════════════
--  ROLE SELECTOR GUI
--  Blocks until the admin picks Winner or Follower, then sets Config.IsWinner.
-- ═══════════════════════════════════
local function selectRole()
    local chosen = nil

    local gui = Instance.new("ScreenGui")
    gui.Name           = "RaceRoleSelector"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder   = 999
    gui.Parent         = player.PlayerGui

    local overlay = Instance.new("Frame", gui)
    overlay.Size                   = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3       = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel        = 0
    overlay.ZIndex                 = 100

    local box = Instance.new("Frame", gui)
    box.Size             = UDim2.new(0, 360, 0, 210)
    box.Position          = UDim2.new(0.5, -180, 0.5, -105)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    box.BorderSizePixel  = 0
    box.ZIndex           = 101
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel", box)
    title.Size                   = UDim2.new(1, -20, 0, 40)
    title.Position               = UDim2.new(0, 10, 0, 12)
    title.BackgroundTransparency = 1
    title.Font                   = Enum.Font.GothamBold
    title.TextSize               = 20
    title.TextColor3             = Color3.new(1, 1, 1)
    title.Text                   = "RaceBrain — Pilih Role"
    title.ZIndex                 = 102

    local winnerBtn = Instance.new("TextButton", box)
    winnerBtn.Size             = UDim2.new(1, -40, 0, 55)
    winnerBtn.Position         = UDim2.new(0, 20, 0, 65)
    winnerBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
    winnerBtn.Font             = Enum.Font.GothamBold
    winnerBtn.TextSize         = 18
    winnerBtn.TextColor3       = Color3.new(1, 1, 1)
    winnerBtn.Text             = "WINNER (Create Lobby)"
    winnerBtn.BorderSizePixel  = 0
    winnerBtn.ZIndex           = 102
    Instance.new("UICorner", winnerBtn).CornerRadius = UDim.new(0, 8)

    local followerBtn = Instance.new("TextButton", box)
    followerBtn.Size             = UDim2.new(1, -40, 0, 55)
    followerBtn.Position         = UDim2.new(0, 20, 0, 130)
    followerBtn.BackgroundColor3 = Color3.fromRGB(50, 110, 200)
    followerBtn.Font             = Enum.Font.GothamBold
    followerBtn.TextSize         = 18
    followerBtn.TextColor3       = Color3.new(1, 1, 1)
    followerBtn.Text             = "FOLLOWER (Join Lobby)"
    followerBtn.BorderSizePixel  = 0
    followerBtn.ZIndex           = 102
    Instance.new("UICorner", followerBtn).CornerRadius = UDim.new(0, 8)

    winnerBtn.MouseButton1Click:Connect(function()
        chosen = true
    end)
    followerBtn.MouseButton1Click:Connect(function()
        chosen = false
    end)

    Logger.info("Waiting for role selection (Winner/Follower)...")
    while chosen == nil do
        task.wait(0.2)
    end

    gui:Destroy()
    Logger.info("Role selected: " .. (chosen and "WINNER" or "FOLLOWER"))
    return chosen
end

-- ═══════════════════════════════════
--  TELEPORT TO NPC
-- ═══════════════════════════════════
local function teleportToNpc()
    local npc = Utils.waitUntil(function()
        return Workspace.Etc.Race.NPC:FindFirstChild("DA0ZA")
    end, 15, 0.5, "NPC lookup")

    if not npc then
        Logger.warn("NPC DA0ZA not found")
        return false
    end

    local targetCFrame
    if npc:IsA("BasePart") then
        targetCFrame = npc.CFrame
    else
        local part = npc:IsA("Model") and (npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart", true))
        targetCFrame = part and part.CFrame
    end

    if not targetCFrame then
        Logger.warn("NPC has no usable position")
        return false
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if not hrp then
        Logger.warn("HumanoidRootPart not found")
        return false
    end

    hrp.CFrame = targetCFrame + Vector3.new(0, 3, 5)
    task.wait(1) -- let character settle
    Logger.info("Teleported to NPC")
    return true
end

-- ═══════════════════════════════════
--  INTERACT NPC (open the race menu prompt)
-- ═══════════════════════════════════
local function interactNpc()
    local ok = Utils.retry(function()
        local prompt = Workspace.Etc.Race.NPC.DA0ZA.HumanoidRootPart.Prompt
        fireproximityprompt(prompt)
    end, 5, Config.RetryDelay, "InteractNPC")

    if ok then
        Logger.info("Interacted with NPC")
    end
    return ok
end

-- ═══════════════════════════════════
--  CLOSE SCOREBOARD (blocks NPC interaction until manually hidden)
-- ═══════════════════════════════════
local function closeScoreboard()
    local ok = Utils.retry(function()
        player.PlayerGui.Race.Container.Scoreboard.Visible = false
    end, 5, Config.RetryDelay, "CloseScoreboard")

    if ok then
        Logger.info("Scoreboard closed")
    end
    return ok
end

-- ═══════════════════════════════════
--  WINNER CONTROLLER
-- ═══════════════════════════════════
local WinnerController = {}

-- The player-count label is unreliable to parse, and StartRace is a no-op
-- server-side until enough players are in and ready. So instead of waiting on
-- that label, just fire StartRace every Config.StartRaceRetryInterval seconds
-- and watch RaceHUD.TimerPanel.TimerLabel — the moment it starts ticking, the
-- race actually began, whichever StartRace call caused it.
function WinnerController.spamStartRaceUntilStarted()
    local label = Utils.waitUntil(function()
        return player.PlayerGui.Race.Container.RaceHUD.TimerPanel.TimerLabel
    end, 15, 0.5, "TimerLabel lookup")

    if not label then
        Logger.warn("TimerLabel not found, cannot confirm race start")
        return false
    end

    local baselineText = label.Text
    local elapsed = 0

    while elapsed < Config.StartRaceLoopTimeout do
        pcall(function() RaceRemote.startRace() end)

        task.wait(Config.StartRaceRetryInterval)
        elapsed = elapsed + Config.StartRaceRetryInterval

        local ok, currentText = pcall(function() return label.Text end)
        if ok and currentText ~= baselineText then
            Logger.info("Race started!")
            return true
        end

        Logger.info(string.format("Race not started yet, retrying StartRace... (%ds elapsed)", elapsed))
    end

    Logger.warn("Race never started after " .. Config.StartRaceLoopTimeout .. "s of retrying")
    return false
end

function WinnerController.run()
    Logger.info("Role: WINNER")

    if not LobbyManager.createLobby() then
        return false
    end
    task.wait(Config.RetryDelay)

    if not CarManager.selectRandomCar() then
        return false
    end

    if not toggleReadyOnce() then
        return false
    end

    Logger.info("Firing StartRace every " .. Config.StartRaceRetryInterval .. "s until the race actually begins...")
    return WinnerController.spamStartRaceUntilStarted()
end

-- ═══════════════════════════════════
--  FOLLOWER CONTROLLER
-- ═══════════════════════════════════
local FollowerController = {}

function FollowerController.run()
    Logger.info("Role: FOLLOWER")

    local lobbyNumber = LobbyManager.findLobby(Config.LobbyTimeout)
    if not lobbyNumber then
        return false
    end
    Logger.info("Found lobby #" .. lobbyNumber)

    if not LobbyManager.joinLobby(lobbyNumber) then
        return false
    end
    task.wait(Config.RetryDelay)

    if not CarManager.selectRandomCar() then
        return false
    end

    if not toggleReadyOnce() then
        return false
    end

    Logger.info("Ready. Waiting for winner to start race...")
    return true
end

-- ═══════════════════════════════════
--  REQUEUE FOR NEXT LAP
--  RaceAgainTeleport -> LeaveLobby. (The Scoreboard itself is already closed
--  the instant it's detected, in STATE.WAIT_SCOREBOARD — see closeScoreboard()
--  call there — so getting stuck staring at it no longer depends on these
--  remotes succeeding.) A half-completed sequence can't resume from the
--  middle (e.g. LeaveLobby failing after RaceAgainTeleport already
--  succeeded), so retry the whole sequence as one unit rather than failing
--  permanently on the first miss.
-- ═══════════════════════════════════
local function requeueForNextLap()
    for attempt = 1, Config.RequeueAttempts do
        LobbyManager.reset()
        resetReadyState()

        local raceAgainOk = Utils.retry(function()
            RaceRemote.raceAgainTeleport()
        end, 5, Config.RetryDelay, "RaceAgainTeleport")

        if raceAgainOk then
            task.wait(Config.RaceAgainSettleDelay)

            local leftOk = Utils.retry(function()
                RaceRemote.leaveLobby()
            end, 5, Config.RetryDelay, "LeaveLobby")

            if leftOk then
                return true
            end
        end

        Logger.warn(string.format("Requeue sequence failed (attempt %d/%d), retrying from RaceAgainTeleport...", attempt, Config.RequeueAttempts))
        task.wait(Config.RetryDelay)
    end

    Logger.warn("Requeue sequence never succeeded after " .. Config.RequeueAttempts .. " attempts")
    return false
end

-- ═══════════════════════════════════
--  RACE CONTROLLER (state machine)
-- ═══════════════════════════════════
local RaceController = {}

local STATE = {
    INIT           = "INIT",
    SELECT_ROLE    = "SELECT_ROLE",
    TELEPORT_NPC   = "TELEPORT_NPC",
    INTERACT_NPC   = "INTERACT_NPC",
    OPEN_MENU      = "OPEN_MENU",
    ROLE_DETECTION = "ROLE_DETECTION",
    WINNER_FLOW    = "WINNER_FLOW",
    FOLLOWER_FLOW  = "FOLLOWER_FLOW",
    WAIT_RACE_START    = "WAIT_RACE_START",
    RUN_CHECKPOINTS    = "RUN_CHECKPOINTS",
    WAIT_SCOREBOARD    = "WAIT_SCOREBOARD",
    REQUEUE            = "REQUEUE",
    FAILED             = "FAILED",
}

function RaceController.run()
    Logger.info("RaceBrain V1 starting...")
    local state = STATE.INIT

    while true do
        if state == STATE.INIT then
            state = RaceRemote.init() and STATE.SELECT_ROLE or STATE.FAILED

        elseif state == STATE.SELECT_ROLE then
            Config.IsWinner = selectRole()
            state = STATE.TELEPORT_NPC

        elseif state == STATE.TELEPORT_NPC then
            Logger.info("Teleporting to NPC...")
            state = teleportToNpc() and STATE.INTERACT_NPC or STATE.FAILED

        elseif state == STATE.INTERACT_NPC then
            Logger.info("Interacting with NPC...")
            state = interactNpc() and STATE.OPEN_MENU or STATE.FAILED

        elseif state == STATE.OPEN_MENU then
            Logger.info("Opening race menu...")
            local opened = Utils.retry(function()
                RaceRemote.getLobbies()
            end, 5, Config.RetryDelay, "OpenMenu")
            state = (opened and PlayerDetector.waitForRaceGui(15)) and STATE.ROLE_DETECTION or STATE.FAILED

        elseif state == STATE.ROLE_DETECTION then
            state = Config.IsWinner and STATE.WINNER_FLOW or STATE.FOLLOWER_FLOW

        elseif state == STATE.WINNER_FLOW then
            state = WinnerController.run() and STATE.WAIT_RACE_START or STATE.FAILED

        elseif state == STATE.FOLLOWER_FLOW then
            state = FollowerController.run() and STATE.WAIT_RACE_START or STATE.FAILED

        elseif state == STATE.WAIT_RACE_START then
            Logger.info("Waiting for race to start (timer ticking)...")
            state = PlayerDetector.waitForRaceStart(Config.RaceStartTimeout) and STATE.RUN_CHECKPOINTS or STATE.FAILED

        elseif state == STATE.RUN_CHECKPOINTS then
            state = CheckpointManager.runAll() and STATE.WAIT_SCOREBOARD or STATE.FAILED

        elseif state == STATE.WAIT_SCOREBOARD then
            Logger.info("Waiting for Scoreboard (all racers finished)...")
            -- Keep retrying instead of failing on one timeout: a straggler can
            -- legitimately wait a long, unpredictable time for the rest of the
            -- lobby, and giving up here means the script exits with the
            -- Scoreboard still stuck open and nothing left running to close it.
            local scoreboardShown = false
            for attempt = 1, Config.ScoreboardWaitAttempts do
                if PlayerDetector.waitForScoreboard(Config.ScoreboardTimeout) then
                    scoreboardShown = true
                    break
                end
                Logger.warn(string.format("Still no Scoreboard after attempt %d/%d, continuing to wait...", attempt, Config.ScoreboardWaitAttempts))
            end

            if scoreboardShown then
                -- Close it the instant it appears, instead of leaving it open
                -- through the whole RaceAgainTeleport->LeaveLobby dance — that's
                -- what left followers stuck on it when those calls failed.
                closeScoreboard()
                state = STATE.REQUEUE
            else
                state = STATE.FAILED
            end

        elseif state == STATE.REQUEUE then
            Logger.info("Finished! Requeuing for the next lap...")
            state = requeueForNextLap() and STATE.INTERACT_NPC or STATE.FAILED

        elseif state == STATE.FAILED then
            Logger.warn("RaceBrain V1 failed.")
            break
        end
    end
end

-- ═══════════════════════════════════
--  POINTS HUD
--  Small always-on overlay mirroring Shop.TitleBar.PointsPill.Value.Text
--  ("xxx PTS"). Runs independently of the state machine so it stays live
--  across every lap regardless of what RaceController is currently doing.
-- ═══════════════════════════════════
local function parsePoints(text)
    return tostring(text or ""):match("%d+") or "0"
end

local function startPointsHud()
    local gui = Instance.new("ScreenGui")
    gui.Name           = "RacePointsHud"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder   = 998
    gui.Parent         = player.PlayerGui

    local box = Instance.new("Frame", gui)
    box.Size                   = UDim2.new(0, 160, 0, 44)
    box.Position               = UDim2.new(1, -170, 0, 10)
    box.BackgroundColor3       = Color3.fromRGB(20, 20, 25)
    box.BackgroundTransparency = 0.1
    box.BorderSizePixel        = 0
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)

    local label = Instance.new("TextLabel", box)
    label.Size                   = UDim2.new(1, -10, 1, 0)
    label.Position               = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 18
    label.TextColor3             = Color3.fromRGB(255, 220, 80)
    label.TextXAlignment         = Enum.TextXAlignment.Center
    label.Text                   = "... PTS"

    task.spawn(function()
        local valueLabel = Utils.waitUntil(function()
            return player.PlayerGui.Race.Container.Shop.TitleBar.PointsPill.Value
        end, 30, 1, "PointsPill.Value lookup")

        if not valueLabel then
            Logger.warn("PointsPill.Value not found, points HUD inactive")
            return
        end

        local function refresh()
            label.Text = parsePoints(valueLabel.Text) .. " PTS"
        end

        refresh()
        valueLabel:GetPropertyChangedSignal("Text"):Connect(refresh)
    end)
end

-- ═══════════════════════════════════
--  ENTRY POINT
-- ═══════════════════════════════════
startPointsHud()

task.spawn(function()
    local ok, err = pcall(RaceController.run)
    if not ok then
        Logger.warn("Fatal error: " .. tostring(err))
    end
    getgenv()._raceBrainRunning = false
end)
