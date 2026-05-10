if getgenv()._samlongLobbyRunning then return end
getgenv()._samlongLobbyRunning = true

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)

local CDID_PLACE_ID = 6911148748
local DDS_GAME_ID   = 7089588429
local ws            = game:GetService("Workspace")

if game.GameId == DDS_GAME_ID then
    getgenv()._samlongDDSRunning = nil

    if ws:FindFirstChild("MANDALIKA") then
        -- Sudah di Mandalika → langsung execute braindds
        print("[LOBBY] DDS: Mandalika detected → braindds")
        loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/braindds.lua"))()

    elseif ws:FindFirstChild("BUILDING_COLOMADU") then
        -- Di lobby DDS → create private server ke Mandalika
        print("[LOBBY] DDS: Lobby detected → creating private server")
        pcall(function()
            local CreatePrivateServer = game:GetService("ReplicatedStorage")
                :WaitForChild("PrivateServerEvents")
                :WaitForChild("CreatePrivateServer")
            CreatePrivateServer:FireServer(114862923457266)
            print("[SAMLONG] Private Server Created!")
        end)
        -- Teleport otomatis, Delta autoexec re-trigger saat Mandalika load

    else
        -- Fallback: tidak bisa detect map, langsung execute
        print("[LOBBY] DDS: map unknown, fallback → braindds")
        loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/braindds.lua"))()
    end

elseif game.PlaceId == CDID_PLACE_ID then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/brain.lua"))()

else
    print("[LOBBY] Unknown: PlaceId=" .. tostring(game.PlaceId) .. " GameId=" .. tostring(game.GameId))
end
