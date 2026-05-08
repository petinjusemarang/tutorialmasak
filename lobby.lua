local CDID_PLACE_ID = 6911148748
local DDS_GAME_ID   = 7089588429

if game.GameId == DDS_GAME_ID then
    getgenv()._samlongDDSRunning = nil
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/braindds.lua"))()
elseif game.PlaceId == CDID_PLACE_ID then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/petinjusemarang/tutorialmasak/refs/heads/main/brain.lua"))()
else
    print("[LOBBY] Unknown: PlaceId=" .. tostring(game.PlaceId) .. " GameId=" .. tostring(game.GameId))
end
